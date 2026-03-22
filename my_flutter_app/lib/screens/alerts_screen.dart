import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:timeago/timeago.dart' as timeago;

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final alerts = context.watch<TrackerProvider>().alerts.reversed.toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('System Alerts', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
      ),
      body: alerts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.bellOff, size: 64, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 16),
                  const Text('No Alerts', style: TextStyle(fontSize: 18, color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('System is operating normally.', style: TextStyle(color: Color(0xFF94A3B8))),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: alerts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final alert = alerts[index];
                
                Color bgColor;
                Color iconColor;
                IconData icon;

                switch (alert.type) {
                  case 'disconnected':
                    bgColor = Colors.red.shade50;
                    iconColor = Colors.red.shade600;
                    icon = LucideIcons.wifiOff;
                    break;
                  case 'out-of-range':
                    bgColor = Colors.orange.shade50;
                    iconColor = Colors.orange.shade600;
                    icon = LucideIcons.mapPinOff;
                    break;
                  case 'reconnected':
                  default:
                    bgColor = Colors.green.shade50;
                    iconColor = Colors.green.shade600;
                    icon = Icons.check_circle;
                }

                return Card(
                  elevation: 0,
                  color: alert.acknowledged ? Colors.white : bgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: alert.acknowledged ? const Color(0xFFE2E8F0) : iconColor.withOpacity(0.3),
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: iconColor.withOpacity(0.1), shape: BoxShape.circle),
                      child: Icon(icon, color: iconColor),
                    ),
                    title: Text(alert.message, style: TextStyle(fontWeight: alert.acknowledged ? FontWeight.normal : FontWeight.bold, color: const Color(0xFF0F172A))),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(timeago.format(alert.timestamp), style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                    ),
                    trailing: alert.acknowledged
                        ? const Icon(LucideIcons.check, color: Colors.green)
                        : TextButton(
                            onPressed: () => context.read<TrackerProvider>().acknowledgeAlert(alert.id),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF2563EB),
                            ),
                            child: const Text('Acknowledge'),
                          ),
                  ),
                );
              },
            ),
    );
  }
}
