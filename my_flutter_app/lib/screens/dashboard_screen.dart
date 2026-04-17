import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/animated_widgets.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:my_flutter_app/widgets/app_top_bar.dart';
import 'package:my_flutter_app/widgets/responsive_helper.dart';
import 'package:my_flutter_app/widgets/tracker_card.dart';
import 'package:provider/provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const int _listPageSize = 5;
  static const int _gridPageSize = 4;

  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _filter = 'all';
  bool _isGridView = false;
  bool _filtersExpanded = false;
  int _listPage = 0;
  int _visibleGridCount = _gridPageSize;

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
  void dispose() {
    // Stop background scanning when dashboard unloads
    context.read<TrackerProvider>().stopBackgroundScanning();
    _searchController.dispose();
    super.dispose();
  }

  void _updateViewMode(bool isGridView) {
    setState(() {
      _isGridView = isGridView;
      _resetCollectionState();
    });
  }

  void _resetCollectionState() {
    _listPage = 0;
    _visibleGridCount = _gridPageSize;
  }

  void _updateSearchQuery(String value) {
    setState(() {
      _searchQuery = value;
      _resetCollectionState();
    });
  }

  void _updateFilter(String value) {
    setState(() {
      _filter = value;
      _resetCollectionState();
    });
  }

  void _goToListPage(int page) {
    setState(() {
      _listPage = page;
    });
  }

  void _showMoreGridItems(int totalTrackers) {
    setState(() {
      _visibleGridCount = (_visibleGridCount + _gridPageSize).clamp(
        _gridPageSize,
        totalTrackers,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, trackerProvider, child) {
        final theme = Theme.of(context);
        final colorScheme = theme.colorScheme;
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
          body: SafeArea(
            bottom: false,
            child: Column(
              children: [
                const AppTopBar(
                  title: 'Dashboard',
                  subtitle:
                      'Monitor tracker health, alerts, and recent activity.',
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      await Future.delayed(const Duration(milliseconds: 500));
                      if (!mounted) return;
                      trackerProvider.refreshTrackers();
                    },
                    color: colorScheme.primary,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      children: [
                        AppPageLayout(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildHeader(
                                totalTrackers: trackers.length,
                                connectedCount: connectedCount,
                                outOfRangeCount: outOfRangeCount,
                                disconnectedCount: disconnectedCount,
                                activeAlerts: activeAlerts.length,
                              ),
                              const SizedBox(height: 12),
                              _buildRegisteredTrackersSection(
                                filteredTrackers,
                                isMobile,
                                totalTrackers: trackers.length,
                                connectedCount: connectedCount,
                                outOfRangeCount: outOfRangeCount,
                                disconnectedCount: disconnectedCount,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader({
    required int totalTrackers,
    required int connectedCount,
    required int outOfRangeCount,
    required int disconnectedCount,
    required int activeAlerts,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Overview',
                  style: textTheme.titleSmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (activeAlerts > 0)
                  const Text(
                    'Needs attention',
                    style: TextStyle(
                      color: Color(0xFFB91C1C),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _buildOverviewPill(
                  icon: LucideIcons.users,
                  label: '$totalTrackers devices',
                ),
                _buildOverviewPill(
                  icon: LucideIcons.bell,
                  label: activeAlerts == 0
                      ? 'No open alerts'
                      : '$activeAlerts active alerts',
                  accentColor: activeAlerts == 0
                      ? const Color(0xFF0F766E)
                      : const Color(0xFFB91C1C),
                  backgroundColor: activeAlerts == 0
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFEF2F2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 420
                    ? 1
                    : constraints.maxWidth < 800
                    ? 2
                    : 3;
                final gap = 8.0;
                final itemWidth =
                    (constraints.maxWidth - ((columns - 1) * gap)) / columns;

                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
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

  Widget _buildOverviewPill({
    required IconData icon,
    required String label,
    Color accentColor = const Color(0xFF1D4ED8),
    Color backgroundColor = const Color(0xFFEFF6FF),
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pillColor = isDark
        ? accentColor.withValues(alpha: 0.16)
        : backgroundColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: pillColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: accentColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
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
    bool embedded = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final filters = [
      (
        'All',
        'all',
        totalTrackers,
        LucideIcons.layoutList,
        const Color(0xFF2563EB),
      ),
      (
        'Connected',
        'connected',
        connectedCount,
        LucideIcons.radioReceiver,
        const Color(0xFF16A34A),
      ),
      (
        'Out of Range',
        'out-of-range',
        outOfRangeCount,
        LucideIcons.mapPinOff,
        const Color(0xFFEA580C),
      ),
      (
        'Disconnected',
        'disconnected',
        disconnectedCount,
        LucideIcons.wifiOff,
        const Color(0xFFDC2626),
      ),
    ];
    final hasActiveCriteria = _searchQuery.isNotEmpty || _filter != 'all';
    final compactSummary = _searchQuery.isNotEmpty
        ? 'Search: "${_searchQuery.length > 18 ? '${_searchQuery.substring(0, 18)}...' : _searchQuery}"'
        : _filter == 'all'
        ? 'All devices'
        : filters.firstWhere((filter) => filter.$2 == _filter).$1;

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => setState(() => _filtersExpanded = !_filtersExpanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primary.withValues(
                          alpha: isDark ? 0.18 : 0.08,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        LucideIcons.search,
                        size: 16,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Search & filters',
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            compactSummary,
                            style: TextStyle(
                              color: hasActiveCriteria
                                  ? colorScheme.primary
                                  : textTheme.bodyMedium?.color,
                              fontSize: 12,
                              fontWeight: hasActiveCriteria
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasActiveCriteria)
                      TextButton(
                        onPressed: () {
                          _searchController.clear();
                          _updateSearchQuery('');
                          _updateFilter('all');
                        },
                        child: const Text('Clear'),
                      ),
                    AnimatedRotation(
                      turns: _filtersExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        LucideIcons.chevronDown,
                        size: 18,
                        color: theme.iconTheme.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: _updateSearchQuery,
                      decoration: InputDecoration(
                        hintText: 'Search by tracker name or device ID',
                        prefixIcon: Icon(
                          LucideIcons.search,
                          size: 18,
                          color: theme.iconTheme.color,
                        ),
                        suffixIcon: _searchQuery.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  _updateSearchQuery('');
                                },
                                icon: Icon(
                                  LucideIcons.x,
                                  size: 18,
                                  color: theme.iconTheme.color,
                                ),
                              ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final crossAxisCount = constraints.maxWidth < 280 ? 1 : 2;
                        final mainAxisExtent = crossAxisCount == 1 ? 72.0 : 82.0;

                        return GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: filters.length,
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            mainAxisExtent: mainAxisExtent,
                          ),
                          itemBuilder: (context, index) {
                            final filter = filters[index];
                            return _buildFilterTile(
                              label: filter.$1,
                              value: filter.$2,
                              count: filter.$3,
                              icon: filter.$4,
                              color: filter.$5,
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              crossFadeState: _filtersExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
              sizeCurve: Curves.easeInOut,
            ),
          ],
    );

    if (embedded) {
      return _buildEmbeddedSearchFiltersShell(body);
    }

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: body,
      ),
    );
  }

  /// Rounded “search field” shell for the tracker list (embedded mode).
  Widget _buildEmbeddedSearchFiltersShell(Widget child) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.55 : 1.0,
      ),
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.65),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFilterTile({
    required String label,
    required String value,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final isSelected = _filter == value;

    return Material(
      color: isSelected
          ? color.withValues(alpha: 0.1)
          : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _updateFilter(value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.55)
                  : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.16)
                      : theme.cardColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 15, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textTheme.bodyLarge?.color,
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count devices',
                      style: TextStyle(
                        color: isSelected ? color : textTheme.bodyMedium?.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDisplayModeSection({
    required bool compact,
    required bool isMobile,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final row = Row(
      children: [
        Icon(
          LucideIcons.layoutGrid,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Display mode',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        SizedBox(
          height: 38,
          child: _buildViewToggle(compact, height: 38),
        ),
      ],
    );

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(
        alpha: theme.brightness == Brightness.dark ? 0.45 : 1.0,
      ),
      borderRadius: BorderRadius.circular(16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 14,
            vertical: compact ? 10 : 12,
          ),
          child: row,
        ),
      ),
    );
  }

  Widget _buildRegisteredTrackersSection(
    List<Tracker> filteredTrackers,
    bool isMobile, {
    required int totalTrackers,
    required int connectedCount,
    required int outOfRangeCount,
    required int disconnectedCount,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final hasTrackers = filteredTrackers.isNotEmpty;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            isDark ? const Color(0xFF172033) : const Color(0xFFFFFFFF),
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FBFF),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.16 : 0.04),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTrackersHeaderContent(
            filteredTrackers.length,
            isMobile,
            totalTrackers: totalTrackers,
            connectedCount: connectedCount,
            outOfRangeCount: outOfRangeCount,
            disconnectedCount: disconnectedCount,
          ),
          if (hasTrackers)
            Divider(
              height: 1,
              thickness: 1,
              color: colorScheme.outlineVariant,
            ),
          _buildTrackerCollection(
            filteredTrackers,
            connectFirstListCard: hasTrackers,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackersHeaderContent(
    int filteredCount,
    bool isMobile, {
    required int totalTrackers,
    required int connectedCount,
    required int outOfRangeCount,
    required int disconnectedCount,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final countLabel = '$filteredCount device${filteredCount == 1 ? "" : "s"}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 420;

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Tracker library',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 6),
              if (compact) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Registered Trackers',
                        style: textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                          height: 1.15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _buildDeviceCountPill(countLabel, colorScheme, isDark),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _buildAddTrackerButton(isCompact: true),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildAllTrackersRadarButton(isCompact: true),
                    ),
                  ],
                ),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registered Trackers',
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildDeviceCountPill(countLabel, colorScheme, isDark),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAddTrackerButton(isCompact: isMobile),
                        const SizedBox(width: 10),
                        _buildAllTrackersRadarButton(isCompact: isMobile),
                      ],
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              _buildDisplayModeSection(compact: compact, isMobile: isMobile),
              const SizedBox(height: 12),
              _buildSearchAndFilters(
                totalTrackers: totalTrackers,
                connectedCount: connectedCount,
                outOfRangeCount: outOfRangeCount,
                disconnectedCount: disconnectedCount,
                embedded: true,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDeviceCountPill(
    String countLabel,
    ColorScheme colorScheme,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.22),
        ),
      ),
      child: Text(
        countLabel,
        style: TextStyle(
          color: colorScheme.primary,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _buildAllTrackersRadarButton({required bool isCompact}) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilledButton.tonalIcon(
      onPressed: () {
        HapticFeedback.lightImpact();
        context.push('/radar');
      },
      icon: Icon(LucideIcons.scanSearch, size: isCompact ? 17 : 18),
      label: Text(isCompact ? 'Radar' : 'Radar map'),
      style: FilledButton.styleFrom(
        foregroundColor: colorScheme.primary,
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.55),
        minimumSize: Size(0, isCompact ? 44 : 46),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 12 : 16,
          vertical: 10,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: isCompact ? 13 : 14,
        ),
      ),
    );
  }

  Widget _buildAddTrackerButton({required bool isCompact}) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilledButton.icon(
      onPressed: () => context.push(
              '/hubs/select?t=${DateTime.now().millisecondsSinceEpoch}',
            ),
      icon: Icon(LucideIcons.plus, size: isCompact ? 17 : 18),
      label: Text(isCompact ? 'Add' : 'Add tracker'),
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        minimumSize: Size(0, isCompact ? 44 : 46),
        padding: EdgeInsets.symmetric(
          horizontal: isCompact ? 14 : 18,
          vertical: 10,
        ),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: TextStyle(
          fontWeight: FontWeight.w800,
          fontSize: isCompact ? 13 : 14,
        ),
      ),
    );
  }

  Widget _buildViewToggle(bool isMobile, {double height = 40}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final radius = height * 0.42;

    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildViewToggleSegment(
            label: 'List',
            icon: LucideIcons.list,
            isSelected: !_isGridView,
            isLeading: true,
            height: height,
            radius: radius,
            onTap: () => _updateViewMode(false),
          ),
          _buildViewToggleSegment(
            label: isMobile ? 'Grid' : 'Cards',
            icon: LucideIcons.layoutGrid,
            isSelected: _isGridView,
            isLeading: false,
            height: height,
            radius: radius,
            onTap: () => _updateViewMode(true),
          ),
        ],
      ),
    );
  }

  Widget _buildViewToggleSegment({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isLeading,
    required double height,
    required double radius,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: isLeading ? Radius.circular(radius - 1) : Radius.zero,
          right: isLeading ? Radius.zero : Radius.circular(radius - 1),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? colorScheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: isLeading ? Radius.circular(radius - 1) : Radius.zero,
              right: isLeading ? Radius.zero : Radius.circular(radius - 1),
            ),
            border: Border(
              right: isLeading
                  ? BorderSide(color: colorScheme.outlineVariant)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected
                    ? colorScheme.primary
                    : theme.iconTheme.color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? colorScheme.primary
                      : textTheme.bodyLarge?.color,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrackerCollection(
    List<Tracker> trackers, {
    bool connectFirstListCard = false,
  }) {
    final theme = Theme.of(context);

    if (trackers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
        child: Column(
          children: [
            Icon(
              LucideIcons.users,
              size: 36,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No trackers match your filters',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try clearing the search field or switching to a different status.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    final totalPages = (trackers.length / _listPageSize).ceil();
    final currentPage = totalPages == 0
        ? 0
        : _listPage.clamp(0, totalPages - 1);
    final listTrackers = trackers
        .skip(currentPage * _listPageSize)
        .take(_listPageSize)
        .toList();
    final visibleGridCount = trackers.length <= _gridPageSize
        ? trackers.length
        : _visibleGridCount.clamp(_gridPageSize, trackers.length);
    final gridTrackers = trackers.take(visibleGridCount).toList();

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 220),
      child: _isGridView
          ? Padding(
              padding: EdgeInsets.fromLTRB(
                12,
                connectFirstListCard ? 10 : 0,
                12,
                12,
              ),
              child: _buildGridView(
                gridTrackers,
                totalTrackers: trackers.length,
                visibleCount: visibleGridCount,
              ),
            )
          : _buildListView(
              listTrackers,
              currentPage: currentPage,
              totalPages: totalPages,
              totalTrackers: trackers.length,
              flatFirstCard: connectFirstListCard,
            ),
    );
  }

  Widget _buildStatCard(String title, int count, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: isDark ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 14),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCounter(
                  count: count,
                  style: TextStyle(
                    color: textTheme.bodyLarge?.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                  duration: const Duration(milliseconds: 500),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(
                    color: textTheme.bodyMedium?.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(
    List<Tracker> trackers, {
    required int currentPage,
    required int totalPages,
    required int totalTrackers,
    bool flatFirstCard = false,
  }) {
    return Column(
      key: const ValueKey('list-view'),
      children: [
        ...trackers.asMap().entries.map(
          (entry) {
            final i = entry.key;
            final tracker = entry.value;
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 16 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: TrackerCard(
                key: ValueKey(tracker.id),
                tracker: tracker,
                flatTop: flatFirstCard && i == 0 && currentPage == 0,
              ),
            );
          },
        ),
        if (totalPages > 1) ...[
          const SizedBox(height: 8),
          _buildListPagination(
            currentPage: currentPage,
            totalPages: totalPages,
            totalTrackers: totalTrackers,
          ),
        ],
      ],
    );
  }

  Widget _buildGridView(
    List<Tracker> trackers, {
    required int totalTrackers,
    required int visibleCount,
  }) {
    return Column(
      key: const ValueKey('grid-view'),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final crossAxisCount = constraints.maxWidth < 520 ? 1 : 2;
            final mainAxisExtent = crossAxisCount == 1 ? 252.0 : 268.0;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                mainAxisExtent: mainAxisExtent,
              ),
              itemCount: trackers.length,
              itemBuilder: (context, index) {
                final shellTracker = trackers[index];

                return Selector<TrackerProvider, Tracker>(
                  key: ValueKey(shellTracker.id),
                  selector: (_, p) =>
                      p.getTracker(shellTracker.id) ?? shellTracker,
                  builder: (context, live, _) {
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
                      child: _buildGridCard(live),
                    );
                  },
                );
              },
            );
          },
        ),
        if (visibleCount < totalTrackers) ...[
          const SizedBox(height: 14),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => _showMoreGridItems(totalTrackers),
              icon: const Icon(LucideIcons.chevronsDown, size: 16),
              label: Text('See more (${totalTrackers - visibleCount} left)'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildListPagination({
    required int currentPage,
    required int totalPages,
    required int totalTrackers,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final start = (currentPage * _listPageSize) + 1;
    final end = ((currentPage + 1) * _listPageSize).clamp(0, totalTrackers);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Showing $start-$end of $totalTrackers',
                      style: TextStyle(
                        color: textTheme.bodyMedium?.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: currentPage == 0
                              ? null
                              : () => _goToListPage(currentPage - 1),
                          icon: const Icon(LucideIcons.chevronLeft, size: 18),
                          tooltip: 'Previous page',
                        ),
                        Text(
                          '${currentPage + 1}/$totalPages',
                          style: TextStyle(
                            color: textTheme.bodyLarge?.color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: currentPage >= totalPages - 1
                              ? null
                              : () => _goToListPage(currentPage + 1),
                          icon: const Icon(LucideIcons.chevronRight, size: 18),
                          tooltip: 'Next page',
                        ),
                      ],
                    ),
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Showing $start-$end of $totalTrackers',
                        style: TextStyle(
                          color: textTheme.bodyMedium?.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: currentPage == 0
                          ? null
                          : () => _goToListPage(currentPage - 1),
                      icon: const Icon(LucideIcons.chevronLeft, size: 18),
                      tooltip: 'Previous page',
                    ),
                    Text(
                      '${currentPage + 1}/$totalPages',
                      style: TextStyle(
                        color: textTheme.bodyLarge?.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    IconButton(
                      onPressed: currentPage >= totalPages - 1
                          ? null
                          : () => _goToListPage(currentPage + 1),
                      icon: const Icon(LucideIcons.chevronRight, size: 18),
                      tooltip: 'Next page',
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildGridCard(Tracker tracker) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
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
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/tracker/${tracker.id}'),
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(
                    alpha: theme.brightness == Brightness.dark ? 0.18 : 0.08,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  LucideIcons.radioReceiver,
                  size: 22,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tracker.name,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    'Signal',
                    style: TextStyle(
                      color: textTheme.bodySmall?.color,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${tracker.signalStrength}%',
                    style: TextStyle(
                      color: textTheme.bodyLarge?.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: tracker.signalStrength / 100,
                  minHeight: 4,
                  backgroundColor: colorScheme.outlineVariant.withValues(
                    alpha: 0.35,
                  ),
                  color: tracker.signalStrength >= 70
                      ? Colors.green.shade500
                      : tracker.signalStrength >= 40
                          ? Colors.orange.shade500
                          : Colors.red.shade500,
                ),
              ),
              if (tracker.rssi != null || tracker.distance != null) ...[
                const SizedBox(height: 6),
                Text(
                  [
                    if (tracker.rssi != null) '${tracker.rssi} dBm',
                    if (tracker.distance != null)
                      '${tracker.distance!.toStringAsFixed(1)} m',
                  ].join(' · '),
                  style: TextStyle(
                    color: textTheme.bodySmall?.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const Spacer(),
              Text(
                tracker.deviceId,
                style: TextStyle(
                  color: textTheme.bodyMedium?.color,
                  fontSize: 12,
                ),
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
