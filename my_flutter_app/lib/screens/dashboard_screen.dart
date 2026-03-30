import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/animated_widgets.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:my_flutter_app/widgets/responsive_helper.dart';
import 'package:my_flutter_app/widgets/tracker_card.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _AlertsMenuCaret extends StatelessWidget {
  const _AlertsMenuCaret();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 12,
      child: CustomPaint(painter: _AlertsMenuCaretPainter()),
    );
  }
}

class _AlertsMenuCaretPainter extends CustomPainter {
  const _AlertsMenuCaretPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = Colors.white;
    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(path, fillPaint);

    final borderPath = Path()
      ..moveTo(size.width / 2, 0.5)
      ..lineTo(size.width - 0.5, size.height - 0.5)
      ..moveTo(size.width / 2, 0.5)
      ..lineTo(0.5, size.height - 0.5);

    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DashboardScreenState extends State<DashboardScreen> {
  final GlobalKey _alertsMenuAnchorKey = GlobalKey();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _filter = 'all';
  bool _isGridView = false;
  bool _filtersExpanded = false;

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
        final alerts = List<Alert>.from(trackerProvider.alerts)
          ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        final unreadAlerts = alerts
            .where((alert) => !alert.acknowledged)
            .toList();
        final menuAlerts = (unreadAlerts.isNotEmpty ? unreadAlerts : alerts)
            .take(3)
            .toList();
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
                          recentAlerts: menuAlerts,
                          totalTrackers: trackers.length,
                          connectedCount: connectedCount,
                          outOfRangeCount: outOfRangeCount,
                          disconnectedCount: disconnectedCount,
                          activeAlerts: activeAlerts.length,
                        ),
                        const SizedBox(height: 12),
                        _buildSearchAndFilters(
                          totalTrackers: trackers.length,
                          connectedCount: connectedCount,
                          outOfRangeCount: outOfRangeCount,
                          disconnectedCount: disconnectedCount,
                        ),
                        const SizedBox(height: 18),
                        _buildTrackersHeader(filteredTrackers.length, isMobile),
                        const SizedBox(height: 12),
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
        );
      },
    );
  }

  Widget _buildHeader({
    required List<Alert> recentAlerts,
    required int totalTrackers,
    required int connectedCount,
    required int outOfRangeCount,
    required int disconnectedCount,
    required int activeAlerts,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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
                              color: Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.all(
                                Radius.circular(12),
                              ),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(9),
                              child: Icon(
                                LucideIcons.radioReceiver,
                                size: 18,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Tracker Dashboard',
                              style: TextStyle(
                                color: Color(0xFF0F172A),
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Text(
                        'See tracker health, active issues, and recent device status in one compact view.',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontSize: 13,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildAlertsMenuButton(
                      recentAlerts: recentAlerts,
                      badgeCount: activeAlerts,
                    ),
                    const SizedBox(width: 8),
                    _buildHeaderAction(
                      icon: LucideIcons.settings,
                      onPressed: () => context.go('/settings'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            const SizedBox(height: 14),
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
                  spacing: 10,
                  runSpacing: 10,
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
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Icon(icon, color: const Color(0xFF334155), size: 18),
              ),
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
                border: Border.all(color: Colors.white, width: 2),
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

  Widget _buildAlertsMenuButton({
    required List<Alert> recentAlerts,
    required int badgeCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          key: _alertsMenuAnchorKey,
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: () => _showAlertsMenu(recentAlerts, badgeCount),
            borderRadius: BorderRadius.circular(14),
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Icon(
                  LucideIcons.bell,
                  color: Color(0xFF334155),
                  size: 18,
                ),
              ),
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
                border: Border.all(color: Colors.white, width: 2),
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

  Future<void> _showAlertsMenu(
    List<Alert> recentAlerts,
    int unreadCount,
  ) async {
    final anchorContext = _alertsMenuAnchorKey.currentContext;
    if (anchorContext == null) return;

    final button = anchorContext.findRenderObject() as RenderBox;
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    const menuWidth = 296.0;
    const screenPadding = 12.0;
    final buttonTopLeft = button.localToGlobal(Offset.zero, ancestor: overlay);
    final left = (buttonTopLeft.dx + button.size.width - menuWidth)
        .clamp(screenPadding, overlay.size.width - menuWidth - screenPadding)
        .toDouble();
    final top = buttonTopLeft.dy + button.size.height + 12;
    final caretLeft = (buttonTopLeft.dx + (button.size.width / 2) - left - 8)
        .clamp(18.0, menuWidth - 34.0)
        .toDouble();

    final selectedValue = await showGeneralDialog<String>(
      context: context,
      barrierLabel: 'Recent alerts',
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.08),
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (dialogContext, _, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.of(dialogContext).pop(),
              ),
            ),
            Positioned(
              left: left,
              top: top,
              width: menuWidth,
              child: _buildAlertsMenuPanel(
                dialogContext: dialogContext,
                recentAlerts: recentAlerts,
                unreadCount: unreadCount,
                caretLeft: caretLeft,
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: ScaleTransition(
            alignment: Alignment.topRight,
            scale: Tween<double>(begin: 0.96, end: 1.0).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );

    if (!mounted || selectedValue == null) return;

    if (selectedValue == 'mark-all') {
      context.read<TrackerProvider>().acknowledgeAllAlerts();
      return;
    }

    if (selectedValue == 'view-all') {
      context.go('/alerts');
      return;
    }

    if (selectedValue.startsWith('tracker:')) {
      final trackerId = selectedValue.replaceFirst('tracker:', '');
      context.push('/tracker/$trackerId');
    }
  }

  Widget _buildAlertsMenuPanel({
    required BuildContext dialogContext,
    required List<Alert> recentAlerts,
    required int unreadCount,
    required double caretLeft,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Material(
            color: Colors.white,
            surfaceTintColor: Colors.white,
            elevation: 14,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAlertsMenuHeader(recentAlerts.length, unreadCount),
                  if (recentAlerts.isEmpty)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 6, 16, 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'No recent alerts',
                          style: TextStyle(color: Color(0xFF64748B)),
                        ),
                      ),
                    )
                  else
                    ...recentAlerts.map(
                      (alert) => _buildAlertMenuTile(
                        alert: alert,
                        onTap: () => Navigator.of(
                          dialogContext,
                        ).pop('tracker:${alert.trackerId}'),
                      ),
                    ),
                  if (unreadCount > 0) ...[
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _buildAlertsMenuAction(
                      icon: LucideIcons.checkCheck,
                      label: 'Mark all as read',
                      color: const Color(0xFF0F766E),
                      onTap: () => Navigator.of(dialogContext).pop('mark-all'),
                    ),
                  ],
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _buildAlertsMenuAction(
                    icon: LucideIcons.list,
                    label: 'View all alerts',
                    color: const Color(0xFF2563EB),
                    onTap: () => Navigator.of(dialogContext).pop('view-all'),
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned(top: 1, left: caretLeft, child: const _AlertsMenuCaret()),
      ],
    );
  }

  Widget _buildAlertsMenuHeader(int totalShown, int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          const Text(
            'Recent alerts',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF0F172A),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: unreadCount > 0
                  ? const Color(0xFFFEF2F2)
                  : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              unreadCount > 0 ? '$unreadCount unread' : '$totalShown shown',
              style: TextStyle(
                color: unreadCount > 0
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF2563EB),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertsMenuAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertMenuTile({
    required Alert alert,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: _buildAlertMenuRow(alert),
      ),
    );
  }

  Widget _buildAlertMenuRow(Alert alert) {
    final accentColor = switch (alert.type) {
      'disconnected' => const Color(0xFFDC2626),
      'out-of-range' => const Color(0xFFEA580C),
      _ => const Color(0xFF16A34A),
    };

    final icon = switch (alert.type) {
      'disconnected' => LucideIcons.wifiOff,
      'out-of-range' => LucideIcons.mapPinOff,
      _ => LucideIcons.badgeCheck,
    };

    return Container(
      width: 268,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        alert.trackerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                    if (!alert.acknowledged)
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Unread',
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  alert.message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeago.format(alert.timestamp),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          const Icon(
            LucideIcons.chevronRight,
            size: 16,
            color: Color(0xFFCBD5E1),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewPill({
    required IconData icon,
    required String label,
    Color accentColor = const Color(0xFF1D4ED8),
    Color backgroundColor = const Color(0xFFEFF6FF),
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: accentColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: accentColor,
              fontSize: 12,
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
  }) {
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        LucideIcons.search,
                        size: 16,
                        color: Color(0xFF2563EB),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Search & filters',
                            style: TextStyle(
                              color: Color(0xFF334155),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            compactSummary,
                            style: TextStyle(
                              color: hasActiveCriteria
                                  ? const Color(0xFF2563EB)
                                  : const Color(0xFF64748B),
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
                          setState(() {
                            _searchQuery = '';
                            _filter = 'all';
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    AnimatedRotation(
                      turns: _filtersExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        LucideIcons.chevronDown,
                        size: 18,
                        color: Color(0xFF64748B),
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
                      onChanged: (value) =>
                          setState(() => _searchQuery = value),
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
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filters.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 8,
                            crossAxisSpacing: 8,
                            childAspectRatio: 2.55,
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
    final isSelected = _filter == value;

    return Material(
      color: isSelected
          ? color.withValues(alpha: 0.1)
          : const Color(0xFFF8FAFC),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => setState(() => _filter = value),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? color.withValues(alpha: 0.55)
                  : const Color(0xFFE2E8F0),
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
                      : Colors.white,
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
                        color: const Color(0xFF334155),
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
                        color: isSelected ? color : const Color(0xFF64748B),
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

  Widget _buildTrackersHeader(int filteredCount, bool isMobile) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final shouldStack = constraints.maxWidth < 520;
        final title = const Text(
          'Active Trackers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF0F172A),
          ),
        );
        final subtitle = Text(
          '$filteredCount device${filteredCount == 1 ? "" : "s"}',
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
            fontSize: 13,
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
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 16),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedCounter(
                  count: count,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1,
                  ),
                  duration: const Duration(milliseconds: 500),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 12,
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
