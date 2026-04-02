import 'package:flutter/material.dart';
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
  /// Updates tracker RSSI and distance every second
  void startBackgroundScanning() {
    if (_isBackgroundScanning || _trackers.isEmpty) {
      return;
    }

    _isBackgroundScanning = true;
    print('[TrackerProvider] ✓ Starting background scanning for ${_trackers.length} trackers');

    // Scan every 1 second and update registered trackers
    _backgroundScanTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      try {
        final scannedTrackers = await _ble.scanForTrackers(
          scanDuration: const Duration(milliseconds: 500),
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
    var updated = false;

    for (final scanned in scannedTrackers) {
      // Find matching registered tracker
      final index = _trackers.indexWhere(
        (t) => t.serialNumber == scanned.serialNumber,
      );

      if (index != -1) {
        final tracker = _trackers[index];

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
        updated = true;
      }
    }

    if (updated) {
      notifyListeners();
    }
  }

  // ============================================================================
  // Ping Feature
  // ============================================================================

  /// Ping a tracker device via BLE GATT
  Future<bool> pingTracker(String trackerId) async {
    final tracker = getTracker(trackerId);
    if (tracker == null || tracker.bleAddress == null) {
      print('[TrackerProvider] Cannot ping: tracker not found or no BLE address');
      return false;
    }

    try {
      print('[TrackerProvider] Pinging tracker: ${tracker.name}');
      final success = await _ble.pingDevice(tracker.bleAddress!);

      if (success) {
        print('[TrackerProvider] ✓ Ping successful for ${tracker.name}');
      } else {
        print('[TrackerProvider] ✗ Ping failed for ${tracker.name}');
      }

      return success;
    } catch (e) {
      print('[TrackerProvider] Ping error: $e');
      return false;
    }
  }
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
