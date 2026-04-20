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
        
        final filteredTrackers = _searchQuery.isEmpty
            ? hubTrackers
            : hubTrackers
                .where((t) =>
                    t.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                    (t.serialNumber?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false))
                .toList();

        return Scaffold(
          appBar: AppBar(
            title: Text('Hub: ${widget.hubBleId.substring(0, 8).toUpperCase()}...'),
            elevation: 0,
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
              _RadarTabContent(trackers: hubTrackers),
              // Trackers tab
              _TrackersTabContent(
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
                    context.push('/hubs/select');
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
  final List<Tracker> trackers;

  const _RadarTabContent({required this.trackers});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
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

class _TrackersTabContent extends StatefulWidget {
  final List<Tracker> trackers;
  final List<Tracker> allTrackers;
  final TextEditingController searchController;
  final Function(String) onSearchChanged;

  const _TrackersTabContent({
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
