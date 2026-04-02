import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/skeleton_loader.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  @override
  void initState() {
    super.initState();
    // Start BLE scanning when screen loads
    Future.delayed(Duration.zero, () {
      if (!mounted) return;
      context.read<TrackerProvider>().scanForTrackers();
    });
  }

  @override
  void dispose() {
    // Stop scanning when leaving the screen
    context.read<TrackerProvider>().stopScanning();
    super.dispose();
  }

  void _startPairing(PendingTracker tracker) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PairingDialog(tracker: tracker),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, provider, child) {
        final theme = Theme.of(context);
        final pendingTrackers = provider.pendingTrackers;
        final isScanning = provider.isScanning;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Add Tracker'),
            actions: [
              IconButton(
                icon: Icon(
                  LucideIcons.refreshCw,
                  color: isScanning
                      ? theme.iconTheme.color?.withValues(alpha: 0.45)
                      : theme.iconTheme.color,
                ),
                onPressed: isScanning ? null : () {
                  provider.scanForTrackers();
                },
                tooltip: 'Scan Again',
              ),
            ],
          ),
          body: isScanning
              ? _buildScanningState()
              : pendingTrackers.isEmpty
                  ? _buildEmptyState(context, provider)
                  : _buildListState(pendingTrackers),
        );
      },
    );
  }

  Widget _buildScanningState() {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scanning for Devices...',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Looking for ESP32 trackers nearby',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: theme.colorScheme.outlineVariant,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Skeleton loaders
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return const SkeletonTrackerCard();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, TrackerProvider provider) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.radioReceiver,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: 24),
          Text(
            'No trackers found',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Make sure ESP32 trackers are powered on.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => provider.scanForTrackers(),
            child: const Text('Scan Again'),
          )
        ],
      ),
    );
  }

  Widget _buildListState(List<PendingTracker> trackers) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            '${trackers.length} Device${trackers.length != 1 ? 's' : ''} Found',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: trackers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.info,
                        size: 48,
                        color: theme.colorScheme.outline,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No devices found',
                        style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text('Make sure Bluetooth and location permissions are enabled.',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
                          textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: trackers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tracker = trackers[index];
                    final serialNumber = tracker.serialNumber ?? "Unknown";
                    final distance = tracker.rssi != null 
                        ? " • ${((tracker.rssi! + 100) * 2).clamp(0, 100).toInt()}% signal"
                        : "";
                    
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (100 * index)),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), 
                        side: BorderSide(color: colorScheme.outlineVariant)
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: Icon(
                          LucideIcons.radio,
                          color: colorScheme.primary,
                          size: 28,
                        ),
                        title: Text('ESP32 Tracker', 
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          )),
                        subtitle: Text('Serial: $serialNumber$distance',
                          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
                        trailing: ElevatedButton(
                          onPressed: () => _startPairing(tracker),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            minimumSize: const Size(0, 36)
                          ),
                          child: const Text('Connect'),
                        ),
                      ),
                    ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PairingDialog extends StatefulWidget {
  final PendingTracker tracker;

  const _PairingDialog({required this.tracker});

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final serialNumber = widget.tracker.serialNumber ?? widget.tracker.deviceId;
    _nameController = TextEditingController(text: 'Tracker_$serialNumber');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _finishRegistration() async {
    final deviceName = _nameController.text;
    
    // Register the device in the provider
    await context.read<TrackerProvider>().registerDevice(widget.tracker, deviceName);
    
    // Show success message
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✓ $deviceName registered successfully'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }

    if (!mounted) return;

    // Close the dialog
    context.pop();

    // Return to dashboard (pop the pairing screen)
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(32),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade600.withValues(alpha: 0.12),
              shape: BoxShape.circle
            ),
            child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
          ),
          const SizedBox(height: 20),
          Text(
            'Device Detected!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text('Serial: ${widget.tracker.serialNumber ?? "Unknown"}',
            style: theme.textTheme.bodySmall?.copyWith(fontSize: 12)),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Device Name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), 
                borderSide: BorderSide.none
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _finishRegistration,
              child: const Text('Register Device'),
            ),
          ),
        ],
      ),
    );
  }
}
