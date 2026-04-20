import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/all_trackers_radar.dart';
import 'package:my_flutter_app/widgets/tracker_card.dart';

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
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, provider, _) {
        final hubTrackers = provider.getTrackersForHub(widget.hubBleId)
          ..sort((a, b) => a.name.compareTo(b.name));
        final hubName = provider.getHubDisplayName(
          widget.hubBleId,
          fallbackName: 'Hub',
        );
        
        final filteredTrackers = _searchQuery.isEmpty
            ? hubTrackers
            : hubTrackers
                .where((t) =>
                    t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (t.serialNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
                .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text(hubName),
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Rename hub',
                onPressed: () => _renameHub(context, provider, hubName),
                icon: const Icon(LucideIcons.pencilLine),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(LucideIcons.radar, size: 18),
                      SizedBox(width: 6),
                      Text('Radar'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(LucideIcons.list, size: 18),
                      const SizedBox(width: 6),
                      const Text('Trackers'),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          hubTrackers.length.toString(),
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              // Radar tab
              _RadarTabContent(
                hubBleId: widget.hubBleId,
                trackers: hubTrackers,
              ),
              // Trackers tab
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
              ? FloatingActionButton(
                  onPressed: () {
                    context.push('/hubs/trackers?hubId=${Uri.encodeComponent(widget.hubBleId)}');
                  },
                  tooltip: 'Add tracker to this hub',
                  child: const Icon(LucideIcons.plus),
                )
              : null,
        );
      },
    );
  }
}

class _RadarTabContent extends StatelessWidget {
  final String hubBleId;
  final List<Tracker> trackers;

  const _RadarTabContent({
    required this.hubBleId,
    required this.trackers,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _HubCalibrationSection(
              hubBleId: hubBleId,
              trackers: trackers,
            ),
            const SizedBox(height: 16),
            if (trackers.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        LucideIcons.radar,
                        size: 48,
                        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No trackers added yet',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add trackers from the Trackers tab to see them on the radar',
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              AllTrackersRadarPanel(trackers: trackers),
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
      final message = e.toString()
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
    final provider = context.read<TrackerProvider>();
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
              Icon(
                LucideIcons.slidersHorizontal,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Calibration',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Matches the desktop tool: enter a known tracker distance and use the current RSSI to calibrate TX power for this hub.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _CalibrationStat(
                  label: 'TX power',
                  value: '${provider.txPower.toStringAsFixed(1)} dBm',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CalibrationStat(
                  label: 'Path loss',
                  value: provider.pathLoss.toStringAsFixed(1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Kalman distance smoothing: process noise 0.15, measurement noise 20.0, outlier rejection 3σ.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          if (strongest != null)
            Text(
              'Using strongest connected tracker: ${strongest.name} (${strongest.rssi} dBm)',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            )
          else
            Text(
              'Connect at least one tracker on this hub before calibrating.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _distanceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Known distance (meters)',
              hintText: '1.0',
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
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
                ),
              ),
              const SizedBox(width: 12),
              TextButton(
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
                child: const Text('Reset'),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  provider.resetDistanceKalmanFilters();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Distance Kalman filters reset'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Reset Kalman'),
              ),
            ],
          ),
          if (_lastResult != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'Applied using ${_lastResult!.trackerName} (${_lastResult!.trackerSerial}) at ${_lastResult!.knownDistanceM.toStringAsFixed(1)} m and RSSI ${_lastResult!.rssi} dBm. New TX power: ${_lastResult!.txPower.toStringAsFixed(1)} dBm.',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CalibrationStat extends StatelessWidget {
  const _CalibrationStat({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
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

    return CustomScrollView(
      slivers: [
        // Search bar
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.searchController,
                    decoration: InputDecoration(
                      hintText: 'Search trackers...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: theme.colorScheme.outlineVariant),
                      ),
                    ),
                    onChanged: widget.onSearchChanged,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () {
                    setState(() => _isGridView = !_isGridView);
                  },
                  icon: Icon(_isGridView ? LucideIcons.list : LucideIcons.grid3x3),
                  tooltip: _isGridView ? 'List view' : 'Grid view',
                ),
              ],
            ),
          ),
        ),

        // Empty state
        if (widget.trackers.isEmpty)
          SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.packageOpen,
                      size: 48,
                      color: theme.colorScheme.outline.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.searchQuery.isEmpty ? 'No trackers yet' : 'No results found',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.searchQuery.isEmpty
                          ? 'Add trackers to this hub to get started'
                          : 'Try a different search term',
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    if (widget.searchQuery.isEmpty) ...[
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.push('/hubs/trackers?hubId=${Uri.encodeComponent(widget.hubBleId)}');
                        },
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: const Text('Add Trackers'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          )
        else if (_isGridView)
          // Grid view
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return TrackerCard(tracker: widget.trackers[index]);
                },
                childCount: widget.trackers.length,
              ),
            ),
          )
        else
          // List view
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            sliver: SliverList(
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
      ],
    );
  }
}

extension on _TrackersTabContent {
  String get searchQuery => searchController.text;
}
