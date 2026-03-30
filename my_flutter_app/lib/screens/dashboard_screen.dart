import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/animated_widgets.dart';
import 'package:my_flutter_app/widgets/app_bottom_nav_bar.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:my_flutter_app/widgets/responsive_helper.dart';
import 'package:my_flutter_app/widgets/tracker_card.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _filter = 'all';
  bool _isGridView = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, trackerProvider, child) {
        final trackers = trackerProvider.trackers;
        final connectedCount = trackerProvider.connectedCount;
        final outOfRangeCount = trackerProvider.outOfRangeCount;
        final disconnectedCount = trackerProvider.disconnectedCount;
        final activeAlerts = trackerProvider.activeAlerts;
        final isMobile = context.responsive.isMobile;

        final filteredTrackers = trackers.where((tracker) {
          final query = _searchQuery.toLowerCase();
          final matchesSearch =
              tracker.name.toLowerCase().contains(query) ||
              tracker.deviceId.toLowerCase().contains(query);
          final matchesFilter =
              _filter == 'all' ||
              (_filter == 'connected' &&
                  tracker.status == TrackerStatus.connected) ||
              (_filter == 'out-of-range' &&
                  tracker.status == TrackerStatus.outOfRange) ||
              (_filter == 'disconnected' &&
                  tracker.status == TrackerStatus.disconnected);
          return matchesSearch && matchesFilter;
        }).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: () async {
                await Future.delayed(const Duration(milliseconds: 500));
                if (!mounted) return;
                trackerProvider.refreshTrackers();
              },
              color: const Color(0xFF2563EB),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                children: [
                  AppPageLayout(
                    includeBottomSafeArea: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(
                          connectedCount: connectedCount,
                          outOfRangeCount: outOfRangeCount,
                          disconnectedCount: disconnectedCount,
                          activeAlerts: activeAlerts.length,
                        ),
                        if (activeAlerts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildAlertBanner(activeAlerts.length),
                        ],
                        const SizedBox(height: 16),
                        _buildSearchAndFilters(
                          totalTrackers: trackers.length,
                          connectedCount: connectedCount,
                          outOfRangeCount: outOfRangeCount,
                          disconnectedCount: disconnectedCount,
                        ),
                        const SizedBox(height: 24),
                        _buildTrackersHeader(filteredTrackers.length, isMobile),
                        const SizedBox(height: 16),
                        _buildTrackerCollection(filteredTrackers),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => context.push('/pairing'),
            backgroundColor: const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            icon: const Icon(LucideIcons.plus, size: 18),
            label: Text(isMobile ? 'Add' : 'Add Tracker'),
          ),
          bottomNavigationBar: const AppBottomNavBar(currentPath: '/'),
        );
      },
    );
  }

  Widget _buildHeader({
    required int connectedCount,
    required int outOfRangeCount,
    required int disconnectedCount,
    required int activeAlerts,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x33FFFFFF),
                              borderRadius: BorderRadius.all(
                                Radius.circular(14),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(10),
                              child: Icon(
                                LucideIcons.radioReceiver,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Tracker Dashboard',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Monitor status, scan devices, and act on alerts from one place.',
                        style: TextStyle(color: Color(0xD9FFFFFF), height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeaderAction(
                      icon: LucideIcons.bell,
                      badgeCount: activeAlerts,
                      onPressed: () => context.push('/alerts'),
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderAction(
                      icon: LucideIcons.settings,
                      onPressed: () => context.push('/settings'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 420
                    ? 1
                    : constraints.maxWidth < 800
                    ? 2
                    : 3;
                final itemWidth =
                    (constraints.maxWidth - ((columns - 1) * 12)) / columns;

                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatCard(
                        'Connected',
                        connectedCount,
                        LucideIcons.radioReceiver,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatCard(
                        'Out of Range',
                        outOfRangeCount,
                        LucideIcons.mapPinOff,
                      ),
                    ),
                    SizedBox(
                      width: itemWidth,
                      child: _buildStatCard(
                        'Disconnected',
                        disconnectedCount,
                        LucideIcons.wifiOff,
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    int badgeCount = 0,
    required VoidCallback onPressed,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: const Color(0x26FFFFFF),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(child: Icon(icon, color: Colors.white, size: 20)),
            ),
          ),
        ),
        if (badgeCount > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: const Color(0xFF1E3A8A), width: 2),
              ),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAlertBanner(int activeAlerts) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Color(0xFFB91C1C),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$activeAlerts active ${activeAlerts == 1 ? "alert needs" : "alerts need"} attention.',
              style: const TextStyle(
                color: Color(0xFF7F1D1D),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => context.push('/alerts'),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters({
    required int totalTrackers,
    required int connectedCount,
    required int outOfRangeCount,
    required int disconnectedCount,
  }) {
    final filters = [
      ('All', 'all', totalTrackers),
      ('Connected', 'connected', connectedCount),
      ('Out of Range', 'out-of-range', outOfRangeCount),
      ('Disconnected', 'disconnected', disconnectedCount),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'Search by tracker name or device ID',
                prefixIcon: const Icon(
                  LucideIcons.search,
                  size: 18,
                  color: Color(0xFF64748B),
                ),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                        icon: const Icon(
                          LucideIcons.x,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: filters
                  .map(
                    (filter) => ChoiceChip(
                      label: Text('${filter.$1} (${filter.$3})'),
                      selected: _filter == filter.$2,
                      onSelected: (_) => setState(() => _filter = filter.$2),
                      selectedColor: const Color(0xFFDBEAFE),
                      side: BorderSide(
                        color: _filter == filter.$2
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFFE2E8F0),
                      ),
                      labelStyle: TextStyle(
                        color: _filter == filter.$2
                            ? const Color(0xFF1D4ED8)
                            : const Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackersHeader(int filteredCount, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = constraints.maxWidth < 520;
        final title = const Text(
          'Active Trackers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        );
        final subtitle = Text(
          '$filteredCount device${filteredCount == 1 ? "" : "s"}',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        );

        if (shouldStack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              title,
              const SizedBox(height: 8),
              Row(
                children: [
                  subtitle,
                  const Spacer(),
                  _buildViewToggle(isMobile),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [title, const SizedBox(height: 6), subtitle],
              ),
            ),
            _buildViewToggle(isMobile),
          ],
        );
      },
    );
  }

  Widget _buildViewToggle(bool isMobile) {
    return SegmentedButton<bool>(
      segments: [
        const ButtonSegment<bool>(
          value: false,
          icon: Icon(LucideIcons.list, size: 18),
          label: Text('List'),
        ),
        ButtonSegment<bool>(
          value: true,
          icon: const Icon(LucideIcons.layoutGrid, size: 18),
          label: Text(isMobile ? 'Grid' : 'Cards'),
        ),
      ],
      selected: {_isGridView},
      onSelectionChanged: (selection) {
        setState(() => _isGridView = selection.first);
      },
      showSelectedIcon: false,
      style: ButtonStyle(
        visualDensity: VisualDensity.compact,
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }

  Widget _buildTrackerCollection(List<Tracker> trackers) {
    if (trackers.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
          child: Column(
            children: const [
              Icon(LucideIcons.users, size: 42, color: Color(0xFFCBD5E1)),
              SizedBox(height: 16),
              Text(
                'No trackers match your filters',
                style: TextStyle(
                  color: Color(0xFF334155),
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Try clearing the search field or switching to a different status.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _isGridView ? _buildGridView(trackers) : _buildListView(trackers),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AnimatedCounter(
              count: count,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
              duration: const Duration(milliseconds: 700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<Tracker> trackers) {
    return Column(
      key: const ValueKey('list-view'),
      children: trackers
          .map(
            (tracker) => TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: TrackerCard(tracker: tracker),
            ),
          )
          .toList(),
    );
  }

  Widget _buildGridView(List<Tracker> trackers) {
    return LayoutBuilder(
      key: const ValueKey('grid-view'),
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 640
            ? 1
            : constraints.maxWidth < 980
            ? 2
            : 3;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 14,
            mainAxisSpacing: 14,
            childAspectRatio: crossAxisCount == 1 ? 2.0 : 1.08,
          ),
          itemCount: trackers.length,
          itemBuilder: (context, index) {
            final tracker = trackers[index];

            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: Duration(milliseconds: 250 + (40 * index)),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.96 + (0.04 * value),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: _buildGridCard(tracker),
            );
          },
        );
      },
    );
  }

  Widget _buildGridCard(Tracker tracker) {
    Color statusColor;
    String statusText;
    switch (tracker.status) {
      case TrackerStatus.connected:
        statusColor = Colors.green.shade600;
        statusText = 'Connected';
        break;
      case TrackerStatus.outOfRange:
        statusColor = Colors.orange.shade600;
        statusText = 'Out of Range';
        break;
      case TrackerStatus.disconnected:
        statusColor = Colors.red.shade600;
        statusText = 'Disconnected';
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/tracker/${tracker.id}'),
        splashColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.radioReceiver,
                  size: 22,
                  color: Color(0xFF2563EB),
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: Text(
                  tracker.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Color(0xFF0F172A),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tracker.deviceId,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
