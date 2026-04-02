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

  Future<void> _handlePing() async {
    setState(() {
      _isPinging = true;
    });

    try {
      final success =
          await context.read<TrackerProvider>().pingTracker(widget.tracker.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Ping successful for ${widget.tracker.name}'
                  : 'Failed to ping ${widget.tracker.name}',
            ),
            duration: const Duration(seconds: 3),
            backgroundColor:
                success ? Colors.green.shade600 : Colors.red.shade600,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error pinging device: $e'),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPinging = false;
        });
      }
    }
  }

  Color _getStatusColor() {
    switch (widget.tracker.status) {
      case TrackerStatus.connected:
        return Colors.green.shade600;
      case TrackerStatus.outOfRange:
        return Colors.orange.shade600;
      case TrackerStatus.disconnected:
        return Colors.red.shade600;
    }
  }

  Color _getStatusBackgroundColor() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (widget.tracker.status) {
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

  String _getStatusText() {
    switch (widget.tracker.status) {
      case TrackerStatus.connected:
        return 'Connected';
      case TrackerStatus.outOfRange:
        return 'Out of Range';
      case TrackerStatus.disconnected:
        return 'Disconnected';
    }
  }

  Widget _getSignalIcon() {
    if (widget.tracker.status == TrackerStatus.disconnected) {
      return const Icon(LucideIcons.wifiOff, color: Colors.red, size: 20);
    }
    if (widget.tracker.signalStrength >= 70) {
      return const Icon(LucideIcons.signalHigh, color: Colors.green, size: 20);
    }
    if (widget.tracker.signalStrength >= 40) {
      return const Icon(
        LucideIcons.signalMedium,
        color: Colors.orange,
        size: 20,
      );
    }
    return const Icon(LucideIcons.signalLow, color: Colors.red, size: 20);
  }

  Widget? _getBatteryIcon() {
    if (widget.tracker.batteryLevel == null) return null;
    if (widget.tracker.batteryLevel! >= 60) {
      return Icon(LucideIcons.battery, color: Colors.green.shade600, size: 16);
    }
    if (widget.tracker.batteryLevel! >= 30) {
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
          context.push('/tracker/${widget.tracker.id}');
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
                  if (isCompact) _buildCompactHeader() else _buildWideHeader(),
                  const SizedBox(height: 14),
                  _buildSignalSection(),
                  if (widget.tracker.rssi != null ||
                      widget.tracker.distance != null ||
                      widget.tracker.serialNumber != null) ...[
                    const SizedBox(height: 14),
                    Divider(height: 1, color: colorScheme.outlineVariant),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        _buildMetric(
                          'RSSI',
                          widget.tracker.rssi != null
                              ? '${widget.tracker.rssi} dBm'
                              : '-- dBm',
                        ),
                        _buildMetric(
                          'Distance',
                          widget.tracker.distance != null
                              ? '${widget.tracker.distance!.toStringAsFixed(2)} m'
                              : '-- m',
                        ),
                        if (widget.tracker.serialNumber != null)
                          _buildMetric('Serial', widget.tracker.serialNumber!),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildPingButton(),
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
            const SizedBox(width: 10),
            _buildSignalBatteryPill(),
          ],
        ),
        const SizedBox(height: 10),
        _buildStatusChip(),
      ],
    );
  }

  Widget _buildWideHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildDeviceSummary()),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildStatusChip(),
            const SizedBox(height: 10),
            _buildSignalBatteryPill(),
          ],
        ),
      ],
    );
  }

  Widget _buildDeviceSummary() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.tracker.name,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Device ID: ${widget.tracker.deviceId}',
          style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          'Last seen: ${_formatLastSeen(widget.tracker.lastSeen)}',
          style: theme.textTheme.labelSmall?.copyWith(fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
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
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalBatteryPill() {
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
          _getSignalIcon(),
          if (widget.tracker.batteryLevel != null) ...[
            const SizedBox(width: 10),
            _getBatteryIcon()!,
            const SizedBox(width: 4),
            Text(
              '${widget.tracker.batteryLevel}%',
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

  Widget _buildSignalSection() {
    final theme = Theme.of(context);
    final signalColor = widget.tracker.signalStrength >= 70
        ? Colors.green.shade500
        : widget.tracker.signalStrength >= 40
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
              '${widget.tracker.signalStrength}%',
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
            value: widget.tracker.signalStrength / 100,
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

  Widget _buildPingButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: (_isPinging || widget.tracker.status == TrackerStatus.disconnected) ? null : _handlePing,
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
