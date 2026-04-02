import 'package:flutter/material.dart';
import 'dart:async';
import 'package:my_flutter_app/core/ble_service.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:uuid/uuid.dart';

class TrackerProvider with ChangeNotifier {
  final List<Tracker> _trackers = [];
  final List<Alert> _alerts = List.from(mockAlerts);
  final List<PendingTracker> _pendingTrackers = [];
  final _uuid = const Uuid();
  final _ble = BleService();

  bool _isScanning = false;
  bool _isBackgroundScanning = false;
  Timer? _backgroundScanTimer;
  final Set<String> _pingingDevices = {};  // Track devices currently being pinged

  List<Tracker> get trackers => _trackers;
  List<Alert> get alerts => _alerts;
  List<PendingTracker> get pendingTrackers => _pendingTrackers;
  bool get isScanning => _isScanning;
  bool get isBackgroundScanning => _isBackgroundScanning;

  // Configuration getters
  double get txPower => _ble.txPower;
  double get pathLoss => _ble.pathLoss;
  int get rssiThreshold => _ble.rssiThreshold;

  List<Alert> get activeAlerts =>
      _alerts.where((a) => !a.acknowledged).toList();

  int get connectedCount =>
      _trackers.where((t) => t.status == TrackerStatus.connected).length;
  int get outOfRangeCount =>
      _trackers.where((t) => t.status == TrackerStatus.outOfRange).length;
  int get disconnectedCount =>
      _trackers.where((t) => t.status == TrackerStatus.disconnected).length;

  Tracker? getTracker(String id) {
    try {
      return _trackers.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  // ============================================================================
  // Configuration Methods
  // ============================================================================

  /// Update scanner configuration parameters
  void setScannerConfig({
    double? txPower,
    double? pathLoss,
    int? rssiThreshold,
  }) {
    _ble.setConfig(
      txPower: txPower,
      pathLoss: pathLoss,
      rssiThreshold: rssiThreshold,
    );
    notifyListeners();
  }

  /// Reset scanner configuration to defaults
  void resetScannerConfig() {
    _ble.resetConfig();
    notifyListeners();
  }

  /// Scan for ESP32 Tracker devices via BLE
  Future<void> scanForTrackers({
    Duration duration = const Duration(seconds: 5),
  }) async {
    _isScanning = true;
    notifyListeners();

    try {
      final scannedTrackers = await _ble.scanForTrackers(
        scanDuration: duration,
      );
      _pendingTrackers.clear();
      _pendingTrackers.addAll(scannedTrackers);
      notifyListeners();
    } catch (e) {
      print('[TrackerProvider] Error scanning: $e');
    } finally {
      _isScanning = false;
      notifyListeners();
    }
  }

  /// Stop BLE scanning
  Future<void> stopScanning() async {
    try {
      await _ble.stopScan();
    } catch (e) {
      print('[TrackerProvider] Error stopping scan: $e');
    }
    _isScanning = false;
    notifyListeners();
  }

  // ============================================================================
  // Background Scanning (Dashboard)
  // ============================================================================

  /// Start continuous background scanning for registered trackers
  /// Scans for 1 second every second, updates tracker RSSI and distance in real-time
  void startBackgroundScanning() {
    if (_isBackgroundScanning || _trackers.isEmpty) {
      if (_trackers.isEmpty) {
        print('[TrackerProvider] Cannot start background scanning: no registered trackers');
      }
      return;
    }

    _isBackgroundScanning = true;
    print('[TrackerProvider] ✓ Starting background scanning for ${_trackers.length} registered tracker(s)');
    print('[TrackerProvider] Registered trackers: ${_trackers.map((t) => t.serialNumber).join(', ')}');

    // Scan every 1 second and update registered trackers
    // Using 1 second scan duration for reliable device detection
    _backgroundScanTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final scannedTrackers = await _ble.scanForTrackers(
          scanDuration: const Duration(seconds: 1),
        );

        // Update registered trackers with scan results
        _updateTrackersFromScan(scannedTrackers);
      } catch (e) {
        print('[TrackerProvider] Background scan error: $e');
      }
    });

    notifyListeners();
  }

  /// Stop continuous background scanning
  void stopBackgroundScanning() {
    _backgroundScanTimer?.cancel();
    _backgroundScanTimer = null;
    _isBackgroundScanning = false;
    print('[TrackerProvider] ✓ Stopped background scanning');
    notifyListeners();
  }

  /// Update registered trackers with new scan data
  void _updateTrackersFromScan(List<PendingTracker> scannedTrackers) {
    if (scannedTrackers.isEmpty) {
      print('[TrackerProvider] No devices scanned this cycle');
      return;
    }

    print('[TrackerProvider] Scanned ${scannedTrackers.length} device(s), checking against ${_trackers.length} registered tracker(s)');
    var updated = false;

    for (final scanned in scannedTrackers) {
      print('[TrackerProvider]   Checking scanned device: ${scanned.serialNumber}, RSSI: ${scanned.rssi}, Distance: ${scanned.distance?.toStringAsFixed(2)}m');
      
      // Find matching registered tracker
      final index = _trackers.indexWhere(
        (t) => t.serialNumber == scanned.serialNumber,
      );

      if (index != -1) {
        final tracker = _trackers[index];
        print('[TrackerProvider]   ✓ Found match for ${scanned.serialNumber}, updating tracker "${tracker.name}"');

        // Update RSSI and distance
        final updatedTracker = tracker.copyWith(
          rssi: scanned.rssi,
          rssiFiltered: scanned.rssiFiltered,
          distance: scanned.distance,
          lastSeen: DateTime.now(),
          signalStrength: scanned.signalStrength,
          status: TrackerStatus.connected,
        );

        _trackers[index] = updatedTracker;
        print('[TrackerProvider]   Updated: ${tracker.name} → Distance: ${updatedTracker.distance?.toStringAsFixed(2)}m, Signal: ${updatedTracker.signalStrength}%');
        updated = true;
      } else {
        print('[TrackerProvider]   ✗ No registered tracker found for ${scanned.serialNumber}');
      }
    }

    if (updated) {
      print('[TrackerProvider] ✓ Notifying listeners of ${_trackers.length} tracker updates');
      notifyListeners();
    } else {
      print('[TrackerProvider] No trackers were updated this scan cycle');
    }
  }

  // ============================================================================
  // Ping Feature
  // ============================================================================

  /// Ping a tracker device via BLE GATT
  /// Returns true if ping succeeded, false otherwise
  /// Prevents multiple simultaneous pings to the same device
  Future<bool> pingTracker(String trackerId) async {
    final tracker = getTracker(trackerId);
    if (tracker == null || tracker.bleAddress == null) {
      print('[TrackerProvider] Cannot ping: tracker not found or no BLE address');
      return false;
    }

    // Prevent multiple simultaneous pings to the same device
    if (_pingingDevices.contains(trackerId)) {
      print('[TrackerProvider] Already pinging ${tracker.name}, please wait...');
      return false;
    }

    // Mark device as currently pinging
    _pingingDevices.add(trackerId);

    try {
      print('[TrackerProvider] Pinging tracker: ${tracker.name}');
      final success = await _ble.pingDevice(tracker.bleAddress!);

      if (success) {
        print('[TrackerProvider] ✓ Ping successful for ${tracker.name}');
      } else {
        print('[TrackerProvider] ✗ Ping failed for ${tracker.name}');
        return false;
      }

      // Wait for device GATT state to fully reset + safety margin
      // Device disables GATT for ~3 seconds after ping, wait 4.2s to ensure full recovery
      print('[TrackerProvider] Waiting for device GATT recovery (4.2s)...');
      await Future.delayed(const Duration(milliseconds: 4200));

      return true;
    } catch (e) {
      print('[TrackerProvider] Ping error: $e');
      return false;
    } finally {
      // Remove device from pinging set
      _pingingDevices.remove(trackerId);
      print('[TrackerProvider] Ping operation complete for ${tracker.name}');
    }
  }

  // ============================================================================
  // Tracker Management Methods
  // ============================================================================

  /// Rename a registered tracker device
  void renameTracker(String id, String newName) {
    final index = _trackers.indexWhere((t) => t.id == id);
    if (index != -1) {
      _trackers[index] = _trackers[index].copyWith(name: newName);

      // Also update name in any related alerts
      for (var i = 0; i < _alerts.length; i++) {
        if (_alerts[i].trackerId == id) {
          _alerts[i] = _alerts[i].copyWith(trackerName: newName);
        }
      }

      notifyListeners();
    }
  }

  /// Register a discovered BLE device as an active tracker
  void registerDevice(PendingTracker pendingTracker, String name) {
    // Generate a unique ID
    final newId = _uuid.v4();

    // Use filtered RSSI if available, otherwise calculate from raw RSSI
    final rssiValue = pendingTracker.rssi;
    final rssiFilteredValue = pendingTracker.rssiFiltered ?? rssiValue?.toDouble();
    final distance = pendingTracker.distance ??
        (rssiValue != null ? BleService.calculateDistance(rssiValue) : null);

    final newTracker = Tracker(
      id: newId,
      deviceId: pendingTracker.deviceId,
      name: name,
      status: TrackerStatus.connected,
      signalStrength: pendingTracker.signalStrength,
      lastSeen: pendingTracker.discovered,
      batteryLevel: 100, // Default for new registration
      // BLE fields
      rssi: rssiValue,
      rssiFiltered: rssiFilteredValue,
      distance: distance,
      serialNumber: pendingTracker.serialNumber,
      bleAddress: pendingTracker.bleAddress,
    );

    // Remove from pending
    _pendingTrackers.removeWhere((p) => p.deviceId == pendingTracker.deviceId);

    // Add to registered
    _trackers.add(newTracker);
    print('[TrackerProvider] ✓ Registered device: "$name" (${pendingTracker.serialNumber})');
    print('[TrackerProvider] Total trackers: ${_trackers.length}');
    notifyListeners();
  }

  void unregisterTracker(String id) {
    _trackers.removeWhere((t) => t.id == id);
    notifyListeners();
  }

  void acknowledgeAlert(String alertId) {
    final index = _alerts.indexWhere((a) => a.id == alertId);
    if (index != -1) {
      _alerts[index] = _alerts[index].copyWith(acknowledged: true);
      notifyListeners();
    }
  }

  void acknowledgeAllAlerts() {
    var changed = false;

    for (var i = 0; i < _alerts.length; i++) {
      if (!_alerts[i].acknowledged) {
        _alerts[i] = _alerts[i].copyWith(acknowledged: true);
        changed = true;
      }
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Refresh tracker data (simulate data update from BLE)
  void refreshTrackers() {
    // Simulate updating tracker statuses
    for (var i = 0; i < _trackers.length; i++) {
      final tracker = _trackers[i];
      // Update last seen timestamp
      _trackers[i] = tracker.copyWith(lastSeen: DateTime.now());
    }
    notifyListeners();
  }
}
