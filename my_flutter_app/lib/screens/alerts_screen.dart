import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/app_page_layout.dart';
import 'package:my_flutter_app/widgets/app_top_bar.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<TrackerProvider>().alerts.reversed.toList();
    final unreadCount = alerts.where((alert) => !alert.acknowledged).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const AppTopBar(
              title: 'Alerts',
              subtitle: 'Review recent tracker events and jump to details.',
            ),
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                children: [
                  AppPageLayout(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSummaryCard(alerts.length, unreadCount),
                        const SizedBox(height: 20),
                        if (alerts.isEmpty)
                          _buildEmptyState()
                        else
                          Column(
                            children: alerts
                                .map((alert) => _buildAlertCard(context, alert))
                                .toList(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(int totalAlerts, int unreadCount) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.bellRing,
              color: Color(0xFF2563EB),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alert Center',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  totalAlerts == 0
                      ? 'Everything looks stable right now.'
                      : '$unreadCount unread of $totalAlerts total alerts.',
                  style: const TextStyle(color: Color(0xFF64748B), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          children: const [
            Icon(LucideIcons.bellOff, size: 56, color: Color(0xFFCBD5E1)),
            SizedBox(height: 16),
            Text(
              'No active alerts',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF334155),
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Trackers are operating normally. New alerts will appear here automatically.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF64748B), height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(BuildContext context, Alert alert) {
    late final Color surfaceColor;
    late final Color accentColor;
    late final IconData icon;

    switch (alert.type) {
      case 'disconnected':
        surfaceColor = const Color(0xFFFEF2F2);
        accentColor = const Color(0xFFDC2626);
        icon = LucideIcons.wifiOff;
        break;
      case 'out-of-range':
        surfaceColor = const Color(0xFFFFF7ED);
        accentColor = const Color(0xFFEA580C);
        icon = LucideIcons.mapPinOff;
        break;
      case 'reconnected':
      default:
        surfaceColor = const Color(0xFFF0FDF4);
        accentColor = const Color(0xFF16A34A);
        icon = LucideIcons.badgeCheck;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: alert.acknowledged ? Colors.white : surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: alert.acknowledged
              ? const Color(0xFFE2E8F0)
              : accentColor.withValues(alpha: 0.28),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/tracker/${alert.trackerId}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.message,
                      style: TextStyle(
                        fontWeight: alert.acknowledged
                            ? FontWeight.w500
                            : FontWeight.w700,
                        color: const Color(0xFF0F172A),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      timeago.format(alert.timestamp),
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              alert.acknowledged
                  ? const Icon(LucideIcons.check, color: Color(0xFF16A34A))
                  : PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'acknowledge') {
                          HapticFeedback.lightImpact();
                          context.read<TrackerProvider>().acknowledgeAlert(
                            alert.id,
                          );
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'acknowledge',
                          child: Row(
                            children: [
                              Icon(
                                LucideIcons.check,
                                size: 16,
                                color: Color(0xFF2563EB),
                              ),
                              SizedBox(width: 8),
                              Text('Mark as read'),
                            ],
                          ),
                        ),
                      ],
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
