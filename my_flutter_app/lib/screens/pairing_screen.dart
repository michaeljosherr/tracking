import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:my_flutter_app/widgets/skeleton_loader.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  @override
  void initState() {
    super.initState();
    // Start BLE scanning when screen loads
    Future.delayed(Duration.zero, () {
      context.read<TrackerProvider>().scanForTrackers();
    });
  }

  @override
  void dispose() {
    // Stop scanning when leaving the screen
    context.read<TrackerProvider>().stopScanning();
    super.dispose();
  }

  void _startPairing(PendingTracker tracker) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _PairingDialog(tracker: tracker),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackerProvider>(
      builder: (context, provider, child) {
        final pendingTrackers = provider.pendingTrackers;
        final isScanning = provider.isScanning;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: const Text('Add Tracker', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
            iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
            actions: [
              IconButton(
                icon: Icon(LucideIcons.refreshCw, color: isScanning ? const Color(0xFF94A3B8) : const Color(0xFF0F172A)),
                onPressed: isScanning ? null : () {
                  provider.scanForTrackers();
                },
                tooltip: 'Scan Again',
              ),
            ],
          ),
          body: isScanning
              ? _buildScanningState()
              : pendingTrackers.isEmpty
                  ? _buildEmptyState(context, provider)
                  : _buildListState(pendingTrackers),
        );
      },
    );
  }

  Widget _buildScanningState() {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Scanning for Devices...', 
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              const SizedBox(height: 8),
              const Text('Looking for ESP32 trackers nearby', 
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
              const SizedBox(height: 12),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 4,
                  backgroundColor: const Color(0xFFE2E8F0),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.blue.shade400,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Skeleton loaders
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: 4,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return const SkeletonTrackerCard();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, TrackerProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.radioReceiver, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 24),
          const Text('No trackers found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          const Text('Make sure ESP32 trackers are powered on.', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => provider.scanForTrackers(),
            child: const Text('Scan Again'),
          )
        ],
      ),
    );
  }

  Widget _buildListState(List<PendingTracker> trackers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Text('${trackers.length} Device${trackers.length != 1 ? 's' : ''} Found', 
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: trackers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.info, size: 48, color: const Color(0xFFCBD5E1)),
                      const SizedBox(height: 16),
                      const Text('No devices found', 
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 24),
                        child: Text('Make sure Bluetooth and location permissions are enabled.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          textAlign: TextAlign.center),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: trackers.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tracker = trackers[index];
                    final serialNumber = tracker.serialNumber ?? "Unknown";
                    final distance = tracker.rssi != null 
                        ? " • ${((tracker.rssi! + 100) * 2).clamp(0, 100).toInt()}% signal"
                        : "";
                    
                    return TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 300 + (100 * index)),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, 20 * (1 - value)),
                          child: Opacity(
                            opacity: value,
                            child: child,
                          ),
                        );
                      },
                      child: Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12), 
                        side: const BorderSide(color: Color(0xFFE2E8F0))
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        leading: const Icon(LucideIcons.radio, color: Color(0xFF2563EB), size: 28),
                        title: Text('ESP32 Tracker', 
                          style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                        subtitle: Text('Serial: $serialNumber$distance',
                          style: const TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                        trailing: ElevatedButton(
                          onPressed: () => _startPairing(tracker),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            minimumSize: const Size(0, 36)
                          ),
                          child: const Text('Connect'),
                        ),
                      ),
                    ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _PairingDialog extends StatefulWidget {
  final PendingTracker tracker;

  const _PairingDialog({required this.tracker});

  @override
  State<_PairingDialog> createState() => _PairingDialogState();
}

class _PairingDialogState extends State<_PairingDialog> {
  late TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    final serialNumber = widget.tracker.serialNumber ?? widget.tracker.deviceId;
    _nameController = TextEditingController(text: 'Tracker_$serialNumber');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _finishRegistration() {
    context.read<TrackerProvider>().registerDevice(widget.tracker, _nameController.text);
    context.pop(); // close dialog
    context.pop(); // go back to dashboard
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(32),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.shade50, 
              shape: BoxShape.circle
            ),
            child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
          ),
          const SizedBox(height: 20),
          const Text('Device Detected!', 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
          const SizedBox(height: 8),
          Text('Serial: ${widget.tracker.serialNumber ?? "Unknown"}',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 20),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: 'Device Name',
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8), 
                borderSide: BorderSide.none
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: _finishRegistration,
              child: const Text('Register Device'),
            ),
          ),
        ],
      ),
    );
  }
}
