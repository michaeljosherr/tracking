import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/core/tracker_provider.dart';
import 'package:my_flutter_app/models/mock_data.dart';

class PairingScreen extends StatefulWidget {
  const PairingScreen({super.key});

  @override
  State<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends State<PairingScreen> {
  bool _isScanning = true;

  @override
  void initState() {
    super.initState();
    // Simulate a brief scan delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _isScanning = false);
    });
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
    final pendingTrackers = context.watch<TrackerProvider>().pendingTrackers;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Add Tracker', style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.refreshCw),
            onPressed: () {
              setState(() => _isScanning = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _isScanning = false);
              });
            },
          ),
        ],
      ),
      body: _isScanning
          ? _buildScanningState()
          : pendingTrackers.isEmpty
              ? _buildEmptyState()
              : _buildListState(pendingTrackers),
    );
  }

  Widget _buildScanningState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Scanning for devices...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          const Text('Ensure the tracker is powered on and nearby.', style: TextStyle(color: Color(0xFF64748B))),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.radioReceiver, size: 64, color: Color(0xFFCBD5E1)),
          const SizedBox(height: 24),
          const Text('No trackers found', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
          const SizedBox(height: 8),
          const Text('Make sure devices are in pairing mode.', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              setState(() => _isScanning = true);
              Future.delayed(const Duration(seconds: 2), () {
                if (mounted) setState(() => _isScanning = false);
              });
            },
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
          child: Text('Available Devices', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: trackers.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final tracker = trackers[index];
              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Color(0xFFE2E8F0))),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: const Icon(LucideIcons.radio, color: Color(0xFF2563EB), size: 28),
                  title: Text('Tracker_${tracker.deviceId}', style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
                  subtitle: Text('Signal: ${tracker.signalStrength}%', style: const TextStyle(color: Color(0xFF64748B))),
                  trailing: ElevatedButton(
                    onPressed: () => _startPairing(tracker),
                    style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        minimumSize: const Size(0, 36)),
                    child: const Text('Connect'),
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
  bool _waitingForButton = true;
  String _customName = '';

  @override
  void initState() {
    super.initState();
    _customName = 'Tracker_${widget.tracker.deviceId}';
    
    // Simulate user pressing the physical button after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _waitingForButton = false);
    });
  }

  void _finishPairing() {
    context.read<TrackerProvider>().registerDevice(widget.tracker, _customName);
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
        children: _waitingForButton ? _buildWaitingContent() : _buildSuccessContent(),
      ),
    );
  }

  List<Widget> _buildWaitingContent() {
    return [
      const SizedBox(
        width: 48, height: 48,
        child: CircularProgressIndicator(color: Color(0xFF2563EB), strokeWidth: 3),
      ),
      const SizedBox(height: 24),
      const Text('Awaiting Confirmation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      const SizedBox(height: 12),
      Text(
        'Please press the physical button on Tracker_${widget.tracker.deviceId} to confirm pairing.',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF64748B), height: 1.5),
      ),
    ];
  }

  List<Widget> _buildSuccessContent() {
    return [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
        child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 32),
      ),
      const SizedBox(height: 20),
      const Text('Pairing Successful!', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
      const SizedBox(height: 20),
      TextField(
        onChanged: (val) => _customName = val,
        decoration: InputDecoration(
          labelText: 'Assign a Name (Optional)',
          filled: true,
          fillColor: const Color(0xFFF1F5F9),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
        ),
        controller: TextEditingController(text: _customName),
      ),
      const SizedBox(height: 24),
      SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton(
          onPressed: _finishPairing,
          child: const Text('Complete Registration'),
        ),
      ),
    ];
  }
}
