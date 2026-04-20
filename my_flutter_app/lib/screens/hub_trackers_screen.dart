import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';

/// Add trackers for a single selected hub. Serials are app-unique until removed or hub is deleted.
class HubTrackersScreen extends StatefulWidget {
  const HubTrackersScreen({super.key, required this.hubBleId});

  final String hubBleId;

  @override
  State<HubTrackersScreen> createState() => _HubTrackersScreenState();
}

class _HubTrackersScreenState extends State<HubTrackersScreen> {
  List<PendingTracker> _live = [];
  bool _streamError = false;
  bool _refreshing = false;
  bool _disposed = false;
  Timer? _liveDebounce;
  List<PendingTracker>? _livePending;
  late TrackerProvider _provider;

  Future<void> _startDedicatedSession() async {
    final p = _provider;
    if (!await p.prepareForDedicatedHubSession()) {
      if (mounted) setState(() => _streamError = true);
      return;
    }
    await p.rememberHubConnection(widget.hubBleId);
    await p.startDedicatedHubStream(widget.hubBleId, _onLive);
  }

  /// Restarts BLE to this hub (same as leaving and re-entering). Helps after
  /// unregistering trackers or when telemetry does not appear.
  Future<void> _refreshHubSession() async {
    if (_refreshing) return;
    setState(() {
      _refreshing = true;
      _streamError = false;
      _live = [];
    });
    try {
      final p = _provider;
      if (!await p.prepareForDedicatedHubSession()) {
        if (mounted) setState(() => _streamError = true);
        return;
      }
      await p.rememberHubConnection(widget.hubBleId);
      await p.startDedicatedHubStream(widget.hubBleId, _onLive);
    } catch (e) {
      if (mounted) setState(() => _streamError = true);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _provider = context.read<TrackerProvider>();
    Future.microtask(() async {
      if (!mounted) return;
      try {
        await _startDedicatedSession();
      } catch (e) {
        if (mounted) setState(() => _streamError = true);
      }
    });
  }

  void _onLive(List<PendingTracker> list) {
    if (_disposed || !mounted) return;
    _livePending = list;
    _liveDebounce?.cancel();
    _liveDebounce = Timer(const Duration(milliseconds: 250), () {
      _liveDebounce = null;
      if (_disposed || !mounted) return;
      final next = _livePending;
      if (next == null) return;
      setState(() => _live = List<PendingTracker>.from(next));
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _liveDebounce?.cancel();
    unawaited(
      Future<void>(() async {
        await _provider.stopDedicatedHubStream();
        await _provider.startBackgroundScanning();
      }),
    );
    super.dispose();
  }

  void _register(PendingTracker pending) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _RegisterDialog(pending: pending, hubBleId: widget.hubBleId),
    );
  }

  String _registeredSignature(TrackerProvider p) {
    final onHub =
        p.trackers.where((t) => t.bleAddress == widget.hubBleId).toList()
          ..sort((a, b) => a.id.compareTo(b.id));
    return onHub.map((t) => '${t.id}|${t.serialNumber}|${t.name}').join(';');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Ignore the value: only re-listen when trackers on this hub are added/removed/renamed,
    // not on every distance/RSSI tick from the dashboard BLE path.
    context.select<TrackerProvider, String>((p) => _registeredSignature(p));
    final provider = context.read<TrackerProvider>();
    final registered = provider.trackers
        .where((t) => t.bleAddress == widget.hubBleId)
        .toList();

    if (_streamError) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Hub'),
          actions: [
            Semantics(
              label: 'Scan again',
              button: true,
              child: IconButton(
                icon: Icon(
                  LucideIcons.refreshCw,
                  color: _refreshing
                      ? theme.iconTheme.color?.withValues(alpha: 0.45)
                      : theme.iconTheme.color,
                ),
                onPressed: _refreshing ? null : _refreshHubSession,
              ),
            ),
          ],
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not open a BLE session to this hub. Try again or pick the hub from the scan list.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add trackers'),
        actions: [
          Semantics(
            label: 'Scan again',
            button: true,
            child: IconButton(
              icon: Icon(
                LucideIcons.refreshCw,
                color: _refreshing
                    ? theme.iconTheme.color?.withValues(alpha: 0.45)
                    : theme.iconTheme.color,
              ),
              onPressed: _refreshing ? null : _refreshHubSession,
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "You're currently scanning for trackers",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _refreshing
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          'Reconnecting to hub…',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : _live.isEmpty && registered.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Waiting for tracker telemetry from the hub. '
                        'Ensure tags are on the hub Wi‑Fi. Tap refresh to reconnect.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (registered.isNotEmpty) ...[
                        Text(
                          'Registered here',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        ...registered.map(
                          (t) => Card(
                            child: ListTile(
                              leading: Icon(
                                LucideIcons.check,
                                color: theme.colorScheme.primary,
                              ),
                              title: Text(t.name),
                              subtitle: Text('Serial ${t.serialNumber}'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_live.isNotEmpty) ...[
                        Text(
                          'Available to add',
                          style: theme.textTheme.labelLarge,
                        ),
                        const SizedBox(height: 8),
                        ..._live.map((pending) {
                          final serial = pending.serialNumber ?? '?';
                          final already = provider.trackers.any(
                            (t) =>
                                t.serialNumber == serial &&
                                t.bleAddress == widget.hubBleId,
                          );
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                LucideIcons.radio,
                                color: theme.colorScheme.secondary,
                              ),
                              title: Text('Serial $serial'),
                              subtitle: Text(
                                pending.distance != null
                                    ? '~${pending.distance!.toStringAsFixed(1)} m · ${pending.rssi ?? "?"} dBm'
                                    : 'RSSI ${pending.rssi ?? "?"} dBm',
                              ),
                              trailing: already
                                  ? Text(
                                      'Added',
                                      style: theme.textTheme.bodySmall,
                                    )
                                  : FilledButton(
                                      onPressed: () => _register(pending),
                                      child: const Text('Add'),
                                    ),
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RegisterDialog extends StatefulWidget {
  const _RegisterDialog({required this.pending, required this.hubBleId});

  final PendingTracker pending;
  final String hubBleId;

  @override
  State<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends State<_RegisterDialog> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final serial = widget.pending.serialNumber ?? widget.pending.deviceId;
    _nameController = TextEditingController(text: 'Tracker_$serial');
  }

  @override
  void dispose() {
    // Prevent EditableText from pushing updates to a disposed controller.
    FocusManager.instance.primaryFocus?.unfocus();
    // Do NOT dispose the controller here. During dialog teardown, focus change
    // notifications can fire and try to update the controller after it's disposed,
    // causing "TextEditingController was used after being disposed" exceptions.
    // _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final provider = context.read<TrackerProvider>();
    final outcome = await provider.registerDeviceOnHub(
      widget.pending,
      _nameController.text.trim().isEmpty
          ? 'Tracker'
          : _nameController.text.trim(),
      widget.hubBleId,
    );

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    switch (outcome) {
      case SerialRegistrationOutcome.success:
        messenger.showSnackBar(
          SnackBar(
            content: Text('Registered ${_nameController.text}'),
            backgroundColor: Colors.green.shade700,
          ),
        );
        context.pop();
        return;
      case SerialRegistrationOutcome.duplicateOnThisHub:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('This serial is already added for this hub.'),
          ),
        );
        return;
      case SerialRegistrationOutcome.blockedOtherHub:
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'This serial is already assigned to another hub. Remove it there or delete that hub in Settings.',
            ),
          ),
        );
        return;
      case SerialRegistrationOutcome.invalid:
        messenger.showSnackBar(
          const SnackBar(content: Text('Could not register this device.')),
        );
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Name this tracker'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Serial ${widget.pending.serialNumber ?? "?"}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _submit(),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}
