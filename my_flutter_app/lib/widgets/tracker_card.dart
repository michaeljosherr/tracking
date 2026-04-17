import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:provider/provider.dart';

class TrackerCard extends StatefulWidget {
  final Tracker tracker;

  const TrackerCard({super.key, required this.tracker});

  @override
  State<TrackerCard> createState() => _TrackerCardState();
}

class _TrackerCardState extends State<TrackerCard> {
  bool _isPinging = false;

  /// Prefer provider copy so list rows stay in sync with BLE even if a parent
  /// subtree skips updating this widget's configuration.
  Tracker _displayTracker(BuildContext context) {
    return context.select<TrackerProvider, Tracker?>(
          (p) => p.getTracker(widget.tracker.id),
        ) ??
        widget.tracker;
  }

  Future<void> _handlePing() async {
    final provider = context.read<TrackerProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final trackerId = widget.tracker.id;
    final fallbackName = widget.tracker.name;

    setState(() {
      _isPinging = true;
    });

    try {
      final success = await provider.pingTracker(trackerId);

      if (!mounted) return;
      final name =
          provider.getTracker(trackerId)?.name ?? fallbackName;
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Ping successful for $name'
                : 'Failed to ping $name',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor:
              success ? Colors.green.shade600 : Colors.red.shade600,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(
          content: Text('Error pinging device: $e'),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.red.shade600,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPinging = false;
        });
      }
    }
  }

  Color _getStatusColor(Tracker tracker) {
    switch (tracker.status) {
      case TrackerStatus.connected:
        return Colors.green.shade600;
      case TrackerStatus.outOfRange:
        return Colors.orange.shade600;
      case TrackerStatus.disconnected:
        return Colors.red.shade600;
    }
  }

  Color _getStatusBackgroundColor(Tracker tracker) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (tracker.status) {
      case TrackerStatus.connected:
        return isDark
            ? Colors.green.shade600.withValues(alpha: 0.16)
            : Colors.green.shade50;
      case TrackerStatus.outOfRange:
        return isDark
            ? Colors.orange.shade600.withValues(alpha: 0.16)
            : Colors.orange.shade50;
      case TrackerStatus.disconnected:
        return isDark
            ? Colors.red.shade600.withValues(alpha: 0.16)
            : Colors.red.shade50;
    }
  }

  String _getStatusText(Tracker tracker) {
    switch (tracker.status) {
      case TrackerStatus.connected:
        return 'Connected';
      case TrackerStatus.outOfRange:
        return 'Out of Range';
      case TrackerStatus.disconnected:
        return 'Disconnected';
    }
  }

  Widget _getSignalIcon(Tracker tracker) {
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

  Widget? _getBatteryIcon(Tracker tracker) {
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
    final tracker = _displayTracker(context);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/tracker/${tracker.id}');
        },
        splashColor: colorScheme.primary.withValues(alpha: 0.1),
        highlightColor: colorScheme.primary.withValues(alpha: 0.05),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCompact)
                    _buildCompactHeader(tracker)
                  else
                    _buildWideHeader(tracker),
                  const SizedBox(height: 14),
                  _buildSignalSection(tracker),
                  if (tracker.rssi != null ||
                      tracker.distance != null ||
                      tracker.serialNumber != null) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 18,
                      runSpacing: 10,
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
                    const SizedBox(height: 14),
                    _buildPingButton(tracker),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCompactHeader(Tracker tracker) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildDeviceSummary(tracker)),
            const SizedBox(width: 10),
            _buildSignalBatteryPill(tracker),
          ],
        ),
        const SizedBox(height: 10),
        _buildStatusChip(tracker),
      ],
    );
  }

  Widget _buildWideHeader(Tracker tracker) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildDeviceSummary(tracker)),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildStatusChip(tracker),
            const SizedBox(height: 10),
            _buildSignalBatteryPill(tracker),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceSummary(Tracker tracker) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tracker.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Device ID: ${tracker.deviceId}',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Last seen: ${_formatLastSeen(tracker.lastSeen)}',
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatusChip(Tracker tracker) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _getStatusBackgroundColor(tracker),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: _getStatusColor(tracker),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _getStatusText(tracker).toUpperCase(),
            style: TextStyle(
              color: _getStatusColor(tracker),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBatteryPill(Tracker tracker) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _getSignalIcon(tracker),
          if (tracker.batteryLevel != null) ...[
            const SizedBox(width: 10),
            _getBatteryIcon(tracker)!,
            const SizedBox(width: 4),
            Text(
              '${tracker.batteryLevel}%',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignalSection(Tracker tracker) {
    final theme = Theme.of(context);
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
            Text(
              'Signal Strength',
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              '${tracker.signalStrength}%',
              style: TextStyle(
                color: theme.textTheme.bodyLarge?.color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: tracker.signalStrength / 100,
            backgroundColor: theme.colorScheme.outlineVariant.withValues(
              alpha: 0.4,
            ),
            color: signalColor,
            minHeight: 7,
          ),
        ),
      ],
    );
  }

  Widget _buildMetric(String label, String value) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.textTheme.bodyMedium?.color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: theme.textTheme.bodyLarge?.color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPingButton(Tracker tracker) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_isPinging || tracker.status == TrackerStatus.disconnected) ? null : _handlePing,
        icon: _isPinging
            ? SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Colors.blue.shade600,
            ),
          ),
        )
            : const Icon(LucideIcons.radio),
        label: Text(_isPinging ? 'Pinging...' : 'Ping Device'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blue.shade600,
          side: BorderSide(color: Colors.blue.shade600),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}
