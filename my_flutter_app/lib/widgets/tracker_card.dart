import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  Color _getStatusBackgroundColor() {
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
        return 'Connected';
      case TrackerStatus.outOfRange:
        return 'Out of Range';
      case TrackerStatus.disconnected:
        return 'Disconnected';
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
      return const Icon(
        LucideIcons.signalMedium,
        color: Colors.orange,
        size: 20,
      );
    }
    return const Icon(LucideIcons.signalLow, color: Colors.red, size: 20);
  }

  Widget? _getBatteryIcon() {
    if (tracker.batteryLevel == null) return null;
    if (tracker.batteryLevel! >= 60) {
      return Icon(LucideIcons.battery, color: Colors.green.shade600, size: 16);
    }
    if (tracker.batteryLevel! >= 30) {
      return Icon(
        LucideIcons.batteryMedium,
        color: Colors.orange.shade600,
        size: 16,
      );
    }
    return Icon(LucideIcons.batteryLow, color: Colors.red.shade600, size: 16);
  }

  String _formatLastSeen(DateTime date) {
    final seconds = DateTime.now().difference(date).inSeconds;
    if (seconds < 10) return 'Just now';
    if (seconds < 60) return '${seconds}s ago';
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m ago';
    final hours = minutes ~/ 60;
    return '${hours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/tracker/${tracker.id}');
        },
        splashColor: const Color(0xFF2563EB).withValues(alpha: 0.1),
        highlightColor: const Color(0xFF2563EB).withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompact) _buildCompactHeader() else _buildWideHeader(),
                  const SizedBox(height: 18),
                  _buildSignalSection(),
                  if (tracker.rssi != null ||
                      tracker.distance != null ||
                      tracker.serialNumber != null) ...[
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 24,
                      runSpacing: 12,
                      children: [
                        _buildMetric(
                          'RSSI',
                          tracker.rssi != null
                              ? '${tracker.rssi} dBm'
                              : '-- dBm',
                        ),
                        _buildMetric(
                          'Distance',
                          tracker.distance != null
                              ? '${tracker.distance!.toStringAsFixed(2)} m'
                              : '-- m',
                        ),
                        if (tracker.serialNumber != null)
                          _buildMetric('Serial', tracker.serialNumber!),
                      ],
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDeviceSummary()),
            const SizedBox(width: 12),
            _buildSignalBatteryPill(),
          ],
        ),
        const SizedBox(height: 12),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildWideHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildDeviceSummary()),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildStatusChip(),
            const SizedBox(height: 12),
            _buildSignalBatteryPill(),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceSummary() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tracker.name,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: Color(0xFF0F172A),
          ),
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
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _getStatusBackgroundColor(),
        borderRadius: BorderRadius.circular(999),
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
    );
  }

  Widget _buildSignalBatteryPill() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getSignalIcon(),
          if (tracker.batteryLevel != null) ...[
            const SizedBox(width: 10),
            _getBatteryIcon()!,
            const SizedBox(width: 4),
            Text(
              '${tracker.batteryLevel}%',
              style: const TextStyle(
                color: Color(0xFF475569),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignalSection() {
    final signalColor = tracker.signalStrength >= 70
        ? Colors.green.shade500
        : tracker.signalStrength >= 40
        ? Colors.orange.shade500
        : Colors.red.shade500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Signal Strength',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${tracker.signalStrength}%',
              style: const TextStyle(
                color: Color(0xFF334155),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: tracker.signalStrength / 100,
            backgroundColor: const Color(0xFFF1F5F9),
            color: signalColor,
            minHeight: 9,
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
