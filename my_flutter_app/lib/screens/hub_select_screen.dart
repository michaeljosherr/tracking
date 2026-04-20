import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/ble_service.dart';
import 'package:my_flutter_app/core/route_observers.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/widgets/skeleton_loader.dart';

/// Stable rebuild key for hub list + scanning (record/List equality was flaky).
String _hubSelectBuildKey(TrackerProvider p) {
  if (p.isScanningHubs) {
    return 'scan';
  }
  return p.discoveredHubs
      .map((e) => '${e.remoteId}\u001f${e.rssi}')
      .join('\u001e');
}

/// Scan for BLE hubs; user picks one to add trackers on the next screen.
class HubSelectScreen extends StatefulWidget {
  const HubSelectScreen({super.key});

  @override
  State<HubSelectScreen> createState() => _HubSelectScreenState();
}

class _HubSelectScreenState extends State<HubSelectScreen> with RouteAware {
  Timer? _scanDebounce;
  bool _routeAwareSubscribed = false;

  void _scheduleScan({Duration debounce = const Duration(milliseconds: 160)}) {
    _scanDebounce?.cancel();
    if (debounce.inMilliseconds == 0) {
      // Scan immediately without debounce
      if (!mounted) return;
      unawaited(context.read<TrackerProvider>().scanForHubs());
    } else {
      _scanDebounce = Timer(debounce, () {
        if (!mounted) return;
        unawaited(context.read<TrackerProvider>().scanForHubs());
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Scan immediately when page loads - don't debounce
    _scheduleScan(debounce: Duration.zero);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeAwareSubscribed) {
      return;
    }
    final route = ModalRoute.of(context);
    if (route is PageRoute<void>) {
      _routeAwareSubscribed = true;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _scanDebounce?.cancel();
    appRouteObserver.unsubscribe(this);
    final p = context.read<TrackerProvider>();
    unawaited(p.startBackgroundScanning());
    super.dispose();
  }

  /// Fires when a route pushed on top of hub select (e.g. add trackers) is popped.
  @override
  void didPopNext() {
    // When returning from hub trackers screen (after hub reset), scan immediately
    // without debounce to quickly rediscover the hub that just restarted advertising.
    // Add small delay to ensure dedicated hub stream has stopped before scanning.
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _scheduleScan(debounce: Duration.zero);
      }
    });
  }

  void _openHub(DiscoveredHub hub) {
    final encoded = Uri.encodeComponent(hub.remoteId);
    context.push('/hubs/trackers?hubId=$encoded');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Selector<TrackerProvider, String>(
      selector: (_, p) => _hubSelectBuildKey(p),
      builder: (context, selectedKey, _) {
        final provider = context.read<TrackerProvider>();
        final hubs = provider.discoveredHubs;
        final scanning = provider.isScanningHubs;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Choose a hub'),
            actions: [
              Semantics(
                label: 'Scan again',
                button: true,
                child: IconButton(
                  icon: Icon(
                    LucideIcons.refreshCw,
                    color: scanning
                        ? theme.iconTheme.color?.withValues(alpha: 0.45)
                        : theme.iconTheme.color,
                  ),
                  onPressed: scanning
                      ? null
                      : () => provider.scanForHubs(),
                ),
              ),
            ],
          ),
          body: scanning
              ? _buildScanning(theme)
              : hubs.isEmpty
                  ? _buildEmpty(context, provider)
                  : ListView.separated(
                      key: ValueKey<String>(selectedKey),
                      padding: const EdgeInsets.all(16),
                      itemCount: hubs.length,
                      separatorBuilder: (_, i) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final h = hubs[i];
                        return Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: theme.colorScheme.outlineVariant),
                          ),
                          child: ListTile(
                            leading: Icon(
                              LucideIcons.radioTower,
                              color: theme.colorScheme.primary,
                            ),
                            title: Text(
                              h.displayName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              'Signal ${h.rssi} dBm · ${h.remoteId}',
                              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => _openHub(h),
                          ),
                        );
                      },
                    ),
        );
      },
    );
  }

  Widget _buildScanning(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Scanning for hubs…',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select ESP32_TRACKER_HUB when more than one is in range.',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 12),
              RepaintBoundary(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (_, i) => const SizedBox(height: 12),
            itemBuilder: (_, i) => const SkeletonTrackerCard(),
          ),
        ),
      ],
    );
  }

  Widget _buildEmpty(BuildContext context, TrackerProvider provider) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
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
              'No hubs found',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Power on a hub, ensure it advertises as ESP32_TRACKER_HUB, then scan again.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => provider.scanForHubs(),
              icon: const Icon(LucideIcons.refreshCw),
              label: const Text('Scan again'),
            ),
          ],
        ),
      ),
    );
  }
}
