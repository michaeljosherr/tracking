import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/widgets/hub_card.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    // Background scanning is auto-started by TrackerProvider.initialize()
    // when trackers are loaded, but we can also start it here if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TrackerProvider>();
      // Only start if not already scanning and trackers exist
      if (!provider.isBackgroundScanning && provider.trackers.isNotEmpty) {
        provider.startBackgroundScanning();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, trackerProvider, child) {
        final hubIds = trackerProvider.getAllHubIds();
        final hasHubs = hubIds.isNotEmpty;
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard'),
            elevation: 0,
            centerTitle: false,
          ),
          body: hasHubs
              ? CustomScrollView(
                  slivers: [
                    // Header section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connected Hubs',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${hubIds.length} hub${hubIds.length != 1 ? 's' : ''} · ${trackerProvider.trackers.length} tracker${trackerProvider.trackers.length != 1 ? 's' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Hub cards grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      sliver: SliverGrid(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: MediaQuery.of(context).size.width > 600 ? 2 : 1,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 1.2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final hubBleId = hubIds[index];
                            final trackers = trackerProvider.getTrackersForHub(hubBleId);
                            final trackerCount = trackers.length;
                            
                            // Generate display name
                            final displayName = 'Hub ${index + 1}';
                            final firstTracker = trackers.isNotEmpty ? trackers.first : null;
                            final connectedAt = firstTracker?.lastSeen ?? DateTime.now();

                            return HubCard(
                              hubBleId: hubBleId,
                              displayName: displayName,
                              connectedAt: connectedAt,
                              trackerCount: trackerCount,
                            );
                          },
                          childCount: hubIds.length,
                        ),
                      ),
                    ),

                    // Quick actions section
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Actions',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      context.push('/hubs/select');
                                    },
                                    icon: const Icon(LucideIcons.plus, size: 18),
                                    label: const Text('Add Hub'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () {
                                      context.go('/settings');
                                    },
                                    icon: const Icon(LucideIcons.settings, size: 18),
                                    label: const Text('Manage'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 20)),
                  ],
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        LucideIcons.radioTower,
                        size: 64,
                        color: theme.colorScheme.outline.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hubs connected',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Connect to a hub to get started',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.push('/hubs/select');
                        },
                        icon: const Icon(LucideIcons.plus),
                        label: const Text('Connect Hub'),
                      ),
                    ],
                  ),
                ),
          floatingActionButton: hasHubs
              ? FloatingActionButton.extended(
                  onPressed: () {
                    context.push('/hubs/select');
                  },
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Add Hub'),
                )
              : null,
        );
      },
    );
  }
}
