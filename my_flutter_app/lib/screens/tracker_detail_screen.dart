import 'package:flutter/material.dart';
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
      builder: (context) => AlertDialog(
        title: const Text('Rename Tracker'),
        content: TextField(
          controller: TextEditingController(text: newName),
          onChanged: (val) => newName = val,
          decoration: const InputDecoration(
            labelText: 'Tracker Name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              context.read<TrackerProvider>().renameTracker(tracker.id, newName);
              context.pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showUnregisterConfirm(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unregister Tracker?'),
        content: const Text(
            'This tracker will be removed from your dashboard and will no longer send updates.'),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              context.read<TrackerProvider>().unregisterTracker(trackerId);
              context.pop();
              context.pop(); // Back to dashboard
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Unregister'),
          ),
        ],
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
            onPressed: () => _showRenameDialog(context, tracker),
            tooltip: 'Rename Tracker',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            _buildHeaderCard(tracker),
            const SizedBox(height: 24),
            _buildStatsGrid(tracker),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _showUnregisterConfirm(context),
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
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.5,
      children: [
        _buildDetailCard('Signal Strength', '${tracker.signalStrength}%', Icons.bar_chart),
        _buildDetailCard('Battery Level', tracker.batteryLevel == null ? '--' : '${tracker.batteryLevel}%', LucideIcons.battery),
        _buildDetailCard('Last Seen', timeago.format(tracker.lastSeen), LucideIcons.clock),
        _buildDetailCard('Location', 'Hub Vicinity', LucideIcons.mapPin),
      ],
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
}
