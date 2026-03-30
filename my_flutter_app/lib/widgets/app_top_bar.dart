import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/responsive_helper.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class AppTopBar extends StatefulWidget {
  final String title;
  final String? subtitle;

  const AppTopBar({super.key, required this.title, this.subtitle});

  @override
  State<AppTopBar> createState() => _AppTopBarState();
}

class _AppTopBarState extends State<AppTopBar> {
  final GlobalKey _alertsMenuAnchorKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackerProvider>();
    final horizontalPadding = context.responsive.responsiveValue(
      mobile: 16.0,
      tablet: 24.0,
      desktop: 32.0,
    );
    final alerts = List<Alert>.from(provider.alerts)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final unreadAlerts = alerts.where((alert) => !alert.acknowledged).toList();
    final menuAlerts = (unreadAlerts.isNotEmpty ? unreadAlerts : alerts)
        .take(3)
        .toList();

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FBFF), Color(0xFFF1F6FE)],
          ),
          border: const Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 18,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFFFFF), Color(0xFFF7FAFF)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFDCE8F8)),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withValues(alpha: 0.05),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 6,
                              height: widget.subtitle != null ? 42 : 28,
                              margin: const EdgeInsets.only(top: 4, right: 14),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFF60A5FA),
                                    Color(0xFF2563EB),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withValues(alpha: 0.12),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Tracker workspace',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.35,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    widget.title,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                      height: 1.05,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  if (widget.subtitle != null) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      widget.subtitle!,
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 12.5,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAlertsMenuButton(
                            recentAlerts: menuAlerts,
                            badgeCount: unreadAlerts.length,
                          ),
                          const SizedBox(width: 8),
                          _buildActionButton(
                            key: const ValueKey('profile-topbar-button'),
                            icon: LucideIcons.settings,
                            onTap: () => context.push('/settings'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    Key? key,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF4F8FF)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E4FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1D4ED8).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        key: key,
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: Icon(icon, color: const Color(0xFF2563EB), size: 18),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertsMenuButton({
    required List<Alert> recentAlerts,
    required int badgeCount,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          decoration: BoxDecoration(
            color: badgeCount > 0
                ? const Color(0xFFF4F8FF)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: badgeCount > 0
                  ? const Color(0xFFD6E4FF)
                  : const Color(0xFFE5EAF0),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            key: _alertsMenuAnchorKey,
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () => _showAlertsMenu(recentAlerts, badgeCount),
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    LucideIcons.bell,
                    color: badgeCount > 0
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF475569),
                    size: 18,
                  ),
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
              child: _AlertsMenuPanel(
                recentAlerts: recentAlerts,
                unreadCount: unreadCount,
                caretLeft: caretLeft,
                onSelect: (value) => Navigator.of(dialogContext).pop(value),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0, -0.02),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut),
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
}

class _AlertsMenuPanel extends StatelessWidget {
  final List<Alert> recentAlerts;
  final int unreadCount;
  final double caretLeft;
  final ValueChanged<String> onSelect;

  const _AlertsMenuPanel({
    required this.recentAlerts,
    required this.unreadCount,
    required this.caretLeft,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
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
                  _AlertsMenuHeader(
                    totalShown: recentAlerts.length,
                    unreadCount: unreadCount,
                  ),
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
                      (alert) => _AlertMenuTile(
                        alert: alert,
                        onTap: () => onSelect('tracker:${alert.trackerId}'),
                      ),
                    ),
                  if (unreadCount > 0) ...[
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    _AlertsMenuAction(
                      icon: LucideIcons.checkCheck,
                      label: 'Mark all as read',
                      color: const Color(0xFF0F766E),
                      onTap: () => onSelect('mark-all'),
                    ),
                  ],
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  _AlertsMenuAction(
                    icon: LucideIcons.list,
                    label: 'View all alerts',
                    color: const Color(0xFF2563EB),
                    onTap: () => onSelect('view-all'),
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
}

class _AlertsMenuHeader extends StatelessWidget {
  final int totalShown;
  final int unreadCount;

  const _AlertsMenuHeader({
    required this.totalShown,
    required this.unreadCount,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _AlertsMenuAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AlertsMenuAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}

class _AlertMenuTile extends StatelessWidget {
  final Alert alert;
  final VoidCallback onTap;

  const _AlertMenuTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
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

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Container(
          width: 268,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
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
        ),
      ),
    );
  }
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
