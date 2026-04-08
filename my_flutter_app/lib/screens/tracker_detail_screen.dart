import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:timeago/timeago.dart' as timeago;

class TrackerDetailScreen extends StatelessWidget {
  final String trackerId;

  const TrackerDetailScreen({super.key, required this.trackerId});

  void _showRenameDialog(BuildContext context, Tracker tracker) {
    String newName = tracker.name;
    showDialog(
      context: context,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: AlertDialog(
          title: const Text('Rename Tracker', style: TextStyle(fontWeight: FontWeight.w600)),
          content: TextField(
            controller: TextEditingController(text: newName),
            onChanged: (val) => newName = val,
            decoration: InputDecoration(
              labelText: 'Tracker Name',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
              ),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.read<TrackerProvider>().renameTracker(tracker.id, newName);
                context.pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showUnregisterConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.8, end: 1.0),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        builder: (context, value, child) {
          return Transform.scale(
            scale: value,
            child: Opacity(
              opacity: value,
              child: child,
            ),
          );
        },
        child: AlertDialog(
          title: const Text('Unregister Tracker?', style: TextStyle(fontWeight: FontWeight.w600)),
          content: const Text(
              'This tracker will be removed from your dashboard and will no longer send updates.'),
          actions: [
            TextButton(
              onPressed: () => context.pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                HapticFeedback.mediumImpact();
                await context.read<TrackerProvider>().unregisterTracker(trackerId);
                if (context.mounted) {
                  context.pop();
                  context.pop(); // Back to dashboard
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Unregister'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final tracker = context.watch<TrackerProvider>().getTracker(trackerId);

    if (tracker == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Tracker not found.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tracker Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, size: 20),
            onPressed: () {
              HapticFeedback.lightImpact();
              _showRenameDialog(context, tracker);
            },
            tooltip: 'Rename Tracker',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Breadcrumb Navigation
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.pop();
                  },
                  child: const Row(
                    children: [
                      Icon(LucideIcons.radio, size: 16, color: Color(0xFF2563EB)),
                      SizedBox(width: 4),
                      Text('Dashboard', style: TextStyle(color: Color(0xFF2563EB), fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: theme.iconTheme.color?.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tracker.name,
                    style: textTheme.bodySmall?.copyWith(fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildHeaderCard(context, tracker),
            const SizedBox(height: 24),
            _buildStatsGrid(context, tracker),
            const SizedBox(height: 32),
            if (tracker.rssi != null || tracker.bleAddress != null) ...[
              _buildBleDetailsCard(context, tracker),
              const SizedBox(height: 32),
            ],
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  _showUnregisterConfirm(context);
                },
                icon: const Icon(LucideIcons.trash2, size: 18),
                label: const Text('Unregister Tracker'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade200),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard(BuildContext context, Tracker tracker) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Color statusColor;
    String statusText;
    switch (tracker.status) {
      case TrackerStatus.connected:
        statusColor = Colors.green;
        statusText = 'Connected';
        break;
      case TrackerStatus.disconnected:
        statusColor = Colors.red;
        statusText = 'Disconnected';
        break;
      case TrackerStatus.outOfRange:
        statusColor = Colors.orange;
        statusText = 'Out of Range';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withValues(
                alpha: isDark ? 0.16 : 0.08,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.radio, size: 48, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          Text(
            tracker.name,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${tracker.deviceId}',
            style: theme.textTheme.bodyMedium?.copyWith(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(statusText.toUpperCase(),
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.w700, fontSize: 12, letterSpacing: 0.5)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, Tracker tracker) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth < 360
            ? 1
            : constraints.maxWidth < 720
            ? 2
            : 4;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: crossAxisCount == 1 ? 2.8 : crossAxisCount == 2 ? 1.5 : 1.2,
          children: [
            _buildDetailCard(
              context,
              'Signal Strength',
              '${tracker.signalStrength}%',
              Icons.bar_chart,
            ),
            _buildDetailCard(
              context,
              'Battery Level',
              tracker.batteryLevel == null ? '--' : '${tracker.batteryLevel}%',
              LucideIcons.battery,
            ),
            _buildDetailCard(
              context,
              'Last Seen',
              timeago.format(tracker.lastSeen),
              LucideIcons.clock,
            ),
            _buildDetailCard(
              context,
              'Location',
              'Hub Vicinity',
              LucideIcons.mapPin,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBleDetailsCard(BuildContext context, Tracker tracker) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.14 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.bluetooth, size: 20, color: Color(0xFF2563EB)),
              const SizedBox(width: 8),
              Text(
                'BLE Information',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: theme.colorScheme.outlineVariant, height: 1),
          const SizedBox(height: 16),
          if (tracker.serialNumber != null) ...[
            _buildBleDetailRow(context, 'Serial Number', tracker.serialNumber!),
            const SizedBox(height: 12),
          ],
          if (tracker.rssi != null) ...[
            _buildBleDetailRow(context, 'RSSI', '${tracker.rssi} dBm'),
            const SizedBox(height: 12),
          ],
          if (tracker.rssiFiltered != null) ...[
            _buildBleDetailRow(
              context,
              'RSSI (Filtered)',
              '${tracker.rssiFiltered?.toStringAsFixed(1)} dBm',
            ),
            const SizedBox(height: 12),
          ],
          if (tracker.distance != null) ...[
            _buildBleDetailRow(
              context,
              'Distance',
              '${tracker.distance?.toStringAsFixed(2)} m',
            ),
            const SizedBox(height: 12),
          ],
          if (tracker.bleAddress != null) ...[
            _buildBleDetailRow(context, 'MAC Address', tracker.bleAddress!),
          ],
        ],
      ),
    );
  }

  Widget _buildBleDetailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 360;

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.right,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
