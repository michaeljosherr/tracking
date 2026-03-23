import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/models/mock_data.dart';

class TrackerCard extends StatelessWidget {
  final Tracker tracker;

  const TrackerCard({super.key, required this.tracker});

  Color _getStatusColor() {
    switch (tracker.status) {
      case TrackerStatus.connected:
        return Colors.green.shade600;
      case TrackerStatus.outOfRange:
        return Colors.orange.shade600;
      case TrackerStatus.disconnected:
        return Colors.red.shade600;
    }
  }

  Color _getStatusBgColor() {
    switch (tracker.status) {
      case TrackerStatus.connected:
        return Colors.green.shade50;
      case TrackerStatus.outOfRange:
        return Colors.orange.shade50;
      case TrackerStatus.disconnected:
        return Colors.red.shade50;
    }
  }

  String _getStatusText() {
    switch (tracker.status) {
      case TrackerStatus.connected:
        return 'connected';
      case TrackerStatus.outOfRange:
        return 'Out of Range';
      case TrackerStatus.disconnected:
        return 'disconnected';
    }
  }

  Widget _getSignalIcon() {
    if (tracker.status == TrackerStatus.disconnected) {
      return const Icon(LucideIcons.wifiOff, color: Colors.red, size: 20);
    }
    if (tracker.signalStrength >= 70) {
      return const Icon(LucideIcons.signalHigh, color: Colors.green, size: 20);
    }
    if (tracker.signalStrength >= 40) {
      return const Icon(LucideIcons.signalMedium, color: Colors.orange, size: 20);
    }
    return const Icon(LucideIcons.signalLow, color: Colors.red, size: 20);
  }

  Widget? _getBatteryIcon() {
    if (tracker.batteryLevel == null) return null;
    if (tracker.batteryLevel! >= 60) {
      return Icon(LucideIcons.battery, color: Colors.green.shade600, size: 16);
    }
    if (tracker.batteryLevel! >= 30) {
      return Icon(LucideIcons.batteryMedium, color: Colors.orange.shade600, size: 16);
    }
    return Icon(LucideIcons.batteryLow, color: Colors.red.shade600, size: 16);
  }

  String _formatLastSeen(DateTime date) {
    final seconds = DateTime.now().difference(date).inSeconds;
    if (seconds < 10) return "Just now";
    if (seconds < 60) return "${seconds}s ago";
    final minutes = seconds ~/ 60;
    if (minutes < 60) return "${minutes}m ago";
    final hours = minutes ~/ 60;
    return "${hours}h ago";
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE2E8F0)), // Slate 200
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/tracker/${tracker.id}'),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              tracker.name,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: Color(0xFF0F172A)), // Slate 900
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getStatusBgColor(),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _getStatusText().toUpperCase(),
                                    style: TextStyle(
                                      color: _getStatusColor(),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Device ID: ${tracker.deviceId}',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last seen: ${_formatLastSeen(tracker.lastSeen)}',
                          style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _getSignalIcon(),
                      ),
                      const SizedBox(height: 12),
                      if (tracker.batteryLevel != null)
                        Row(
                          children: [
                            _getBatteryIcon()!,
                            const SizedBox(width: 6),
                            Text(
                              '${tracker.batteryLevel}%',
                              style: const TextStyle(color: Color(0xFF64748B), fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Signal Strength', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                  Text('${tracker.signalStrength}%', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: tracker.signalStrength / 100,
                  backgroundColor: const Color(0xFFF1F5F9), // Slate 100
                  color: tracker.signalStrength >= 70
                      ? Colors.green.shade500
                      : tracker.signalStrength >= 40
                          ? Colors.orange.shade500
                          : Colors.red.shade500,
                  minHeight: 8,
                ),
              ),
              // BLE Data Section
              if (tracker.rssi != null || tracker.distance != null) ...[
                const SizedBox(height: 16),
                Divider(color: const Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('RSSI', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          tracker.rssi != null ? '${tracker.rssi} dBm' : '-- dBm',
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Distance', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text(
                          tracker.distance != null ? '${tracker.distance?.toStringAsFixed(2)} m' : '-- m',
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (tracker.serialNumber != null)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Serial', style: TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
                          const SizedBox(height: 4),
                          Text(
                            tracker.serialNumber!,
                            style: const TextStyle(color: Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
