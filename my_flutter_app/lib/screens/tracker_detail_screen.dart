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
    final tracker = context.watch<TrackerProvider>().getTracker(trackerId);

    if (tracker == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Tracker not found.')),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Tracker Details',
            style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
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
                const Icon(LucideIcons.chevronRight, size: 16, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tracker.name,
                    style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildHeaderCard(tracker),
            const SizedBox(height: 24),
            _buildStatsGrid(tracker),
            const SizedBox(height: 32),
            if (tracker.rssi != null || tracker.bleAddress != null) ...[
              _buildBleDetailsCard(tracker),
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

  Widget _buildHeaderCard(Tracker tracker) {
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFEFF6FF), shape: BoxShape.circle),
            child: const Icon(LucideIcons.radio, size: 48, color: Color(0xFF2563EB)),
          ),
          const SizedBox(height: 16),
          Text(tracker.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text('ID: ${tracker.deviceId}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 14)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
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

  Widget _buildStatsGrid(Tracker tracker) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 500;
        return GridView.count(
          crossAxisCount: isSmallScreen ? 2 : 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: isSmallScreen ? 1.5 : 1.2,
          children: [
            _buildDetailCard('Signal Strength', '${tracker.signalStrength}%', Icons.bar_chart),
            _buildDetailCard('Battery Level', tracker.batteryLevel == null ? '--' : '${tracker.batteryLevel}%', LucideIcons.battery),
            _buildDetailCard('Last Seen', timeago.format(tracker.lastSeen), LucideIcons.clock),
            _buildDetailCard('Location', 'Hub Vicinity', LucideIcons.mapPin),
          ],
        );
      },
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: const Color(0xFF64748B)),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
        ],
      ),
    );
  }

  Widget _buildBleDetailsCard(Tracker tracker) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.bluetooth, size: 20, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('BLE Information', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: const Color(0xFFE2E8F0), height: 1),
          const SizedBox(height: 16),
          if (tracker.serialNumber != null) ...[
            _buildBleDetailRow('Serial Number', tracker.serialNumber!),
            const SizedBox(height: 12),
          ],
          if (tracker.rssi != null) ...[
            _buildBleDetailRow('RSSI', '${tracker.rssi} dBm'),
            const SizedBox(height: 12),
          ],
          if (tracker.rssiFiltered != null) ...[
            _buildBleDetailRow('RSSI (Filtered)', '${tracker.rssiFiltered?.toStringAsFixed(1)} dBm'),
            const SizedBox(height: 12),
          ],
          if (tracker.distance != null) ...[
            _buildBleDetailRow('Distance', '${tracker.distance?.toStringAsFixed(2)} m'),
            const SizedBox(height: 12),
          ],
          if (tracker.bleAddress != null) ...[
            _buildBleDetailRow('MAC Address', tracker.bleAddress!),
          ],
        ],
      ),
    );
  }

  Widget _buildBleDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500)),
        Text(value, style: const TextStyle(color: Color(0xFF0F172A), fontSize: 14, fontWeight: FontWeight.w600)),
      ],
    );
  }
}
