import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:my_flutter_app/widgets/app_top_bar.dart';
import 'package:my_flutter_app/widgets/hub_card.dart';
import 'package:my_flutter_app/widgets/responsive_helper.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<TrackerProvider>();
      final hasWork =
          provider.trackers.isNotEmpty || provider.savedHubBleIds.isNotEmpty;
      if (!provider.isBackgroundScanning && hasWork) {
        provider.startBackgroundScanning();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, provider, _) {
        final hubIds = provider.getAllHubIds();
        final hasHubs = hubIds.isNotEmpty;

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const AppTopBar(
                  title: 'Dashboard',
                  subtitle:
                      'Overview of your hubs and connected trackers.',
                ),
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: [
                      AppPageLayout(
                        child: hasHubs
                            ? _DashboardContent(
                                provider: provider,
                                hubIds: hubIds,
                              )
                            : const _DashboardEmptyState(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          floatingActionButton: hasHubs
              ? FloatingActionButton.extended(
                  onPressed: () => context.push('/hubs/select'),
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Add hub'),
                )
              : null,
        );
      },
    );
  }
}

/// Main dashboard content when at least one hub is saved.
class _DashboardContent extends StatelessWidget {
  const _DashboardContent({
    required this.provider,
    required this.hubIds,
  });

  final TrackerProvider provider;
  final List<String> hubIds;

  @override
  Widget build(BuildContext context) {
    final trackers = provider.trackers;
    final connectedTrackers = trackers
        .where((t) => t.status == TrackerStatus.connected)
        .length;
    final outOfRange = trackers
        .where((t) => t.status == TrackerStatus.outOfRange)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SummaryCard(
          hubCount: hubIds.length,
          trackerCount: trackers.length,
          connectedCount: connectedTrackers,
          outOfRangeCount: outOfRange,
        ),
        const SizedBox(height: 20),
        _SectionTitle(
          title: 'Your hubs',
          trailing: Text(
            '${hubIds.length} hub${hubIds.length == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
        const SizedBox(height: 12),
        _HubsGrid(provider: provider, hubIds: hubIds),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Gradient hero card showing aggregate counts, styled to match the alerts
/// summary card on the other bottom-nav screens.
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.hubCount,
    required this.trackerCount,
    required this.connectedCount,
    required this.outOfRangeCount,
  });

  final int hubCount;
  final int trackerCount;
  final int connectedCount;
  final int outOfRangeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: isDark ? 0.18 : 0.08,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  LucideIcons.radioTower,
                  color: colorScheme.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Fleet overview',
                      style: textTheme.headlineSmall?.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      trackerCount == 0
                          ? 'No trackers registered yet.'
                          : '$connectedCount of $trackerCount connected'
                              '${outOfRangeCount > 0 ? ' · $outOfRangeCount out of range' : ''}.',
                      style: textTheme.bodyMedium?.copyWith(height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 8.0;
              // 4 across on wider screens, 2 across on phones — always fills
              // the row cleanly instead of collapsing into a long vertical list.
              final columns = constraints.maxWidth >= 520 ? 4 : 2;
              final tileWidth =
                  (constraints.maxWidth - spacing * (columns - 1)) / columns;
              final tiles = [
                _StatTile(
                  icon: LucideIcons.radioTower,
                  label: 'Hubs',
                  value: '$hubCount',
                  color: colorScheme.primary,
                ),
                _StatTile(
                  icon: LucideIcons.radio,
                  label: 'Trackers',
                  value: '$trackerCount',
                  color: colorScheme.tertiary,
                ),
                _StatTile(
                  icon: LucideIcons.wifi,
                  label: 'Connected',
                  value: '$connectedCount',
                  color: Colors.green.shade600,
                ),
                _StatTile(
                  icon: LucideIcons.mapPinOff,
                  label: 'Out of range',
                  value: '$outOfRangeCount',
                  color: outOfRangeCount > 0
                      ? Colors.orange.shade700
                      : colorScheme.onSurfaceVariant,
                ),
              ];
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final tile in tiles)
                    SizedBox(width: tileWidth, child: tile),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title.toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color,
                letterSpacing: 0.6,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Responsive list/grid of hub cards. On phones we use a single column so
/// each card can size itself to its natural height (preventing overflow).
/// On wider screens we lay out tiles with `Wrap` + fixed widths so cards
/// still size vertically to their content.
class _HubsGrid extends StatelessWidget {
  const _HubsGrid({required this.provider, required this.hubIds});

  final TrackerProvider provider;
  final List<String> hubIds;

  @override
  Widget build(BuildContext context) {
    final r = context.responsive;
    final columns = r.isDesktop
        ? 3
        : r.isTablet
            ? 2
            : 1;

    Widget cardAt(int index) {
      final hubBleId = hubIds[index];
      final trackers = provider.getTrackersForHub(hubBleId);
      final displayName = provider.getHubDisplayName(
        hubBleId,
        fallbackName: 'Hub ${index + 1}',
      );
      final firstTracker = trackers.isNotEmpty ? trackers.first : null;
      final connectedAt = firstTracker?.lastSeen ?? DateTime.now();
      return HubCard(
        hubBleId: hubBleId,
        displayName: displayName,
        connectedAt: connectedAt,
        trackerCount: trackers.length,
      );
    }

    if (columns == 1) {
      return Column(
        children: [
          for (var i = 0; i < hubIds.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            cardAt(i),
          ],
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        final tileWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (var i = 0; i < hubIds.length; i++)
              SizedBox(width: tileWidth, child: cardAt(i)),
          ],
        );
      },
    );
  }
}

class _DashboardEmptyState extends StatelessWidget {
  const _DashboardEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colorScheme.outlineVariant),
        ),
        child: Column(
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.radioTower,
                size: 40,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No hubs connected',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to an ESP32 hub to start discovering and tracking devices nearby.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.push('/hubs/select'),
              icon: const Icon(LucideIcons.plus, size: 18),
              label: const Text('Connect hub'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
