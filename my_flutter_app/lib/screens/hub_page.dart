import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/all_trackers_radar.dart';
import 'package:my_flutter_app/widgets/tracker_card.dart';

/// Max width for primary content column on tablets/desktops so text and
/// forms don't stretch awkwardly wide.
const double _kContentMaxWidth = 960;

/// Breakpoint above which the Radar tab switches to a two-column layout
/// (overview + calibration on the left, radar panel on the right).
const double _kWideLayoutBreakpoint = 900;

/// Responsive horizontal padding used consistently across sections.
EdgeInsets _pagePadding(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  final horizontal = width >= 1024
      ? 32.0
      : width >= 600
          ? 24.0
          : 16.0;
  return EdgeInsets.symmetric(horizontal: horizontal, vertical: 16);
}

/// Dedicated page for managing a single hub and its trackers.
/// Shows radar for this hub's trackers only, tracker list, and management options.
class HubPage extends StatefulWidget {
  const HubPage({super.key, required this.hubBleId});

  final String hubBleId;

  @override
  State<HubPage> createState() => _HubPageState();
}

class _HubPageState extends State<HubPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  Future<void> _renameHub(
    BuildContext context,
    TrackerProvider provider,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename hub'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Hub name',
            hintText: 'Enter a hub name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (newName == null || !context.mounted) return;

    final cleaned = newName.trim();
    if (cleaned.isEmpty || cleaned == currentName) return;

    await provider.renameHub(widget.hubBleId, cleaned);
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<TrackerProvider>(
      builder: (context, provider, _) {
        final hubTrackers = provider.getTrackersForHub(widget.hubBleId)
          ..sort((a, b) => a.name.compareTo(b.name));
        final hubName = provider.getHubDisplayName(
          widget.hubBleId,
          fallbackName: 'Hub',
        );
        final connectedCount = hubTrackers
            .where((t) => t.status == TrackerStatus.connected)
            .length;

        final filteredTrackers = _searchQuery.isEmpty
            ? hubTrackers
            : hubTrackers
                .where((t) =>
                    t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (t.serialNumber
                            ?.toLowerCase()
                            .contains(_searchQuery.toLowerCase()) ??
                        false))
                .toList();

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            titleSpacing: 0,
            title: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    hubName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hubTrackers.isEmpty
                        ? 'Add a tracker to get started'
                        : '$connectedCount of ${hubTrackers.length} connected',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'Rename hub',
                onPressed: () => _renameHub(context, provider, hubName),
                icon: const Icon(LucideIcons.pencilLine),
              ),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  labelPadding: const EdgeInsets.symmetric(horizontal: 12),
                  tabs: [
                    const Tab(
                      iconMargin: EdgeInsets.only(bottom: 2),
                      child: _TabLabel(
                        icon: LucideIcons.radar,
                        label: 'Radar',
                      ),
                    ),
                    Tab(
                      iconMargin: const EdgeInsets.only(bottom: 2),
                      child: _TabLabel(
                        icon: LucideIcons.list,
                        label: 'Trackers',
                        trailingBadge: hubTrackers.length.toString(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _RadarTabContent(
                hubBleId: widget.hubBleId,
                trackers: hubTrackers,
                connectedCount: connectedCount,
              ),
              _TrackersTabContent(
                hubBleId: widget.hubBleId,
                trackers: filteredTrackers,
                allTrackers: hubTrackers,
                searchController: _searchController,
                onSearchChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
            ],
          ),
          floatingActionButton: _tabController.index == 1
              ? FloatingActionButton.extended(
                  onPressed: () {
                    context.push(
                        '/hubs/trackers?hubId=${Uri.encodeComponent(widget.hubBleId)}');
                  },
                  tooltip: 'Add tracker to this hub',
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Add tracker'),
                )
              : null,
        );
      },
    );
  }
}

/// Tab label with icon, label, and optional trailing badge.
class _TabLabel extends StatelessWidget {
  const _TabLabel({
    required this.icon,
    required this.label,
    this.trailingBadge,
  });

  final IconData icon;
  final String label;
  final String? trailingBadge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (trailingBadge != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              trailingBadge!,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Wraps content in a max-width centered column so that on tablet/desktop
/// the form doesn't stretch edge-to-edge.
class _ConstrainedContent extends StatelessWidget {
  const _ConstrainedContent({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _kContentMaxWidth),
        child: child,
      ),
    );
  }
}

class _RadarTabContent extends StatelessWidget {
  final String hubBleId;
  final List<Tracker> trackers;
  final int connectedCount;

  const _RadarTabContent({
    required this.hubBleId,
    required this.trackers,
    required this.connectedCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _kWideLayoutBreakpoint;
        final radarPanel = trackers.isEmpty
            ? _EmptyRadarPlaceholder(theme: theme)
            : AllTrackersRadarPanel(trackers: trackers);

        return SingleChildScrollView(
          padding: _pagePadding(context),
          child: _ConstrainedContent(
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _HubOverviewCard(
                              trackers: trackers,
                              connectedCount: connectedCount,
                            ),
                            const SizedBox(height: 16),
                            _HubCalibrationSection(
                              hubBleId: hubBleId,
                              trackers: trackers,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(flex: 6, child: radarPanel),
                    ],
                  )
                : Column(
                    children: [
                      _HubOverviewCard(
                        trackers: trackers,
                        connectedCount: connectedCount,
                      ),
                      const SizedBox(height: 16),
                      _HubCalibrationSection(
                        hubBleId: hubBleId,
                        trackers: trackers,
                      ),
                      const SizedBox(height: 16),
                      radarPanel,
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class _EmptyRadarPlaceholder extends StatelessWidget {
  const _EmptyRadarPlaceholder({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.radar,
              size: 36,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No trackers added yet',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add trackers from the Trackers tab to see them on the radar',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Compact at-a-glance stats card for the hub (connected / total / strongest).
class _HubOverviewCard extends StatelessWidget {
  const _HubOverviewCard({
    required this.trackers,
    required this.connectedCount,
  });

  final List<Tracker> trackers;
  final int connectedCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TrackerProvider>();
    final connected = trackers
        .where((t) => t.status == TrackerStatus.connected && t.rssi != null)
        .toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    final strongest = connected.isNotEmpty ? connected.first : null;
    final total = trackers.length;
    final healthPct = total == 0 ? 0.0 : connectedCount / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
            theme.colorScheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.radioTower,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hub overview',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              _HealthChip(
                percent: healthPct,
                totalTrackers: total,
                theme: theme,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OverviewStat(
                icon: LucideIcons.wifi,
                label: 'Connected',
                value: '$connectedCount / $total',
                color: theme.colorScheme.primary,
              ),
              _OverviewStat(
                icon: LucideIcons.signalHigh,
                label: 'Strongest',
                value: strongest?.rssi != null
                    ? '${strongest!.rssi} dBm'
                    : '—',
                color: Colors.green.shade600,
              ),
              _OverviewStat(
                icon: LucideIcons.zap,
                label: 'TX power',
                value: '${provider.txPower.toStringAsFixed(1)} dBm',
                color: Colors.orange.shade700,
              ),
              _OverviewStat(
                icon: LucideIcons.activity,
                label: 'Path loss',
                value: provider.pathLoss.toStringAsFixed(1),
                color: theme.colorScheme.tertiary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthChip extends StatelessWidget {
  const _HealthChip({
    required this.percent,
    required this.totalTrackers,
    required this.theme,
  });
  final double percent;
  /// When 0, this is onboarding — do not imply the hub radio is dead.
  final int totalTrackers;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (totalTrackers == 0) {
      color = const Color(0xFF0D9488);
      label = 'Set up';
    } else if (percent >= 0.75) {
      color = Colors.green.shade600;
      label = 'Healthy';
    } else if (percent >= 0.35) {
      color = Colors.orange.shade600;
      label = 'Partial';
    } else {
      color = Colors.red.shade500;
      label = 'Offline';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
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
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 140),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HubCalibrationSection extends StatefulWidget {
  const _HubCalibrationSection({
    required this.hubBleId,
    required this.trackers,
  });

  final String hubBleId;
  final List<Tracker> trackers;

  @override
  State<_HubCalibrationSection> createState() => _HubCalibrationSectionState();
}

class _HubCalibrationSectionState extends State<_HubCalibrationSection> {
  final TextEditingController _distanceController = TextEditingController(
    text: '1.0',
  );
  bool _isApplying = false;
  bool _showAdvanced = false;
  HubCalibrationResult? _lastResult;

  @override
  void dispose() {
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _applyCalibration(TrackerProvider provider) async {
    final knownDistance = double.tryParse(_distanceController.text.trim());
    if (knownDistance == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter a valid calibration distance.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isApplying = true);
    try {
      final result = await provider.calibrateHubTxPower(
        hubBleId: widget.hubBleId,
        knownDistanceM: knownDistance,
      );
      if (!mounted) return;
      setState(() => _lastResult = result);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Calibration applied: TX power ${result.txPower.toStringAsFixed(1)} dBm',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst('Bad state: ', '')
          .replaceFirst('Invalid argument(s): ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isApplying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final provider = context.watch<TrackerProvider>();
    final connected = widget.trackers
        .where((t) => t.status == TrackerStatus.connected && t.rssi != null)
        .toList()
      ..sort((a, b) => (b.rssi ?? -999).compareTo(a.rssi ?? -999));
    final strongest = connected.isNotEmpty ? connected.first : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.slidersHorizontal,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Calibration',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: _showAdvanced ? 'Hide details' : 'Show details',
                onPressed: () {
                  setState(() => _showAdvanced = !_showAdvanced);
                },
                icon: Icon(
                  _showAdvanced
                      ? LucideIcons.chevronUp
                      : LucideIcons.chevronDown,
                  size: 18,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          _StrongestTrackerBanner(
            theme: theme,
            strongest: strongest,
            registeredCount: widget.trackers.length,
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _showAdvanced
                ? Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: _AdvancedCalibrationDetails(theme: theme),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 420;
              final input = TextField(
                controller: _distanceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Known distance (m)',
                  hintText: '1.0',
                  prefixIcon: const Icon(LucideIcons.ruler, size: 18),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
              final applyBtn = FilledButton.icon(
                onPressed: _isApplying || strongest == null
                    ? null
                    : () => _applyCalibration(provider),
                icon: _isApplying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(LucideIcons.slidersHorizontal, size: 16),
                label: Text(_isApplying ? 'Applying...' : 'Apply calibration'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );

              if (narrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    input,
                    const SizedBox(height: 10),
                    applyBtn,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: input),
                  const SizedBox(width: 10),
                  applyBtn,
                ],
              );
            },
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                onPressed: () {
                  provider.resetScannerConfig();
                  provider.resetDistanceKalmanFilters();
                  setState(() => _lastResult = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Calibration reset to defaults'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('Reset'),
              ),
              TextButton.icon(
                onPressed: () {
                  provider.resetDistanceKalmanFilters();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Distance Kalman filters reset'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                icon: const Icon(LucideIcons.waves, size: 16),
                label: const Text('Reset Kalman'),
              ),
            ],
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer
                    .withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    LucideIcons.circleCheck,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Applied using ${_lastResult!.trackerName} (${_lastResult!.trackerSerial}) '
                      'at ${_lastResult!.knownDistanceM.toStringAsFixed(1)} m '
                      'and RSSI ${_lastResult!.rssi} dBm. '
                      'New TX power: ${_lastResult!.txPower.toStringAsFixed(1)} dBm.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StrongestTrackerBanner extends StatelessWidget {
  const _StrongestTrackerBanner({
    required this.theme,
    required this.strongest,
    required this.registeredCount,
  });

  final ThemeData theme;
  final Tracker? strongest;
  final int registeredCount;

  @override
  Widget build(BuildContext context) {
    final hasLive = strongest != null;
    if (hasLive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              LucideIcons.signalHigh,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Using strongest tracker: ${strongest!.name} (${strongest!.rssi} dBm)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (registeredCount == 0) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.25),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              LucideIcons.tags,
              size: 16,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Register a tracker on this hub first. Calibration needs live RSSI from a tag — use the Trackers tab or the + button.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.orange.shade50.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.wifiOff,
            size: 16,
            color: Colors.orange.shade800,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No live RSSI from your trackers yet. Bring a tag in range or check power, then try calibrating.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.orange.shade900,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedCalibrationDetails extends StatelessWidget {
  const _AdvancedCalibrationDetails({required this.theme});
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How it works',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Matches the desktop tool: enter a known tracker distance and '
            'use the current RSSI to calibrate TX power for this hub.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Kalman smoothing',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Process noise 0.15 · measurement noise 20.0 · outlier rejection 3σ.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackersTabContent extends StatefulWidget {
  final String hubBleId;
  final List<Tracker> trackers;
  final List<Tracker> allTrackers;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;

  const _TrackersTabContent({
    required this.hubBleId,
    required this.trackers,
    required this.allTrackers,
    required this.searchController,
    required this.onSearchChanged,
  });

  @override
  State<_TrackersTabContent> createState() => _TrackersTabContentState();
}

class _TrackersTabContentState extends State<_TrackersTabContent> {
  bool _isGridView = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final horizontalPad = width >= 1024
        ? 32.0
        : width >= 600
            ? 24.0
            : 16.0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: _ConstrainedContent(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPad, 16, horizontalPad, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: widget.searchController,
                      decoration: InputDecoration(
                        hintText: 'Search trackers...',
                        prefixIcon: const Icon(LucideIcons.search, size: 18),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              BorderSide(color: theme.colorScheme.outline),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                              color: theme.colorScheme.outlineVariant),
                        ),
                        suffixIcon: widget.searchController.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(LucideIcons.x, size: 16),
                                onPressed: () {
                                  widget.searchController.clear();
                                  widget.onSearchChanged('');
                                },
                              ),
                      ),
                      onChanged: widget.onSearchChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _ViewToggle(
                    isGrid: _isGridView,
                    onChanged: (v) => setState(() => _isGridView = v),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: _ConstrainedContent(
            child: Padding(
              padding: EdgeInsets.fromLTRB(horizontalPad, 0, horizontalPad, 8),
              child: Row(
                children: [
                  Text(
                    widget.searchController.text.isEmpty
                        ? '${widget.allTrackers.length} tracker'
                            '${widget.allTrackers.length == 1 ? '' : 's'}'
                        : '${widget.trackers.length} of '
                            '${widget.allTrackers.length} match',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (widget.trackers.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: _EmptyTrackersState(
              hubBleId: widget.hubBleId,
              isSearching: widget.searchController.text.isNotEmpty,
              theme: theme,
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontalPad,
              8,
              horizontalPad,
              88,
            ),
            sliver: _ConstrainedSliver(
              sliver: _isGridView
                  ? SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 260,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            TrackerCard(tracker: widget.trackers[index]),
                        childCount: widget.trackers.length,
                      ),
                    )
                  : SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final tracker = widget.trackers[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TrackerCard(tracker: tracker),
                          );
                        },
                        childCount: widget.trackers.length,
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}

/// Sliver variant of `_ConstrainedContent` that keeps slivers centered and
/// capped to the content max width on wide screens.
class _ConstrainedSliver extends StatelessWidget {
  const _ConstrainedSliver({required this.sliver});
  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        if (width <= _kContentMaxWidth) {
          return sliver;
        }
        final pad = (width - _kContentMaxWidth) / 2;
        return SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: pad),
          sliver: sliver,
        );
      },
    );
  }
}

class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.isGrid, required this.onChanged});

  final bool isGrid;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget button(IconData icon, bool selected, VoidCallback onTap,
        String tooltip) {
      return Tooltip(
        message: tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: selected
                  ? theme.colorScheme.primary.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          button(LucideIcons.list, !isGrid, () => onChanged(false), 'List view'),
          const SizedBox(width: 2),
          button(LucideIcons.grid3x3, isGrid, () => onChanged(true), 'Grid view'),
        ],
      ),
    );
  }
}

class _EmptyTrackersState extends StatelessWidget {
  const _EmptyTrackersState({
    required this.hubBleId,
    required this.isSearching,
    required this.theme,
  });

  final String hubBleId;
  final bool isSearching;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSearching ? LucideIcons.search : LucideIcons.packageOpen,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isSearching ? 'No results found' : 'No trackers yet',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'Try a different search term'
                  : 'Add trackers to this hub to get started',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (!isSearching) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  context.push(
                      '/hubs/trackers?hubId=${Uri.encodeComponent(hubBleId)}');
                },
                icon: const Icon(LucideIcons.plus, size: 18),
                label: const Text('Add trackers'),
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
          ],
        ),
      ),
    );
  }
}
