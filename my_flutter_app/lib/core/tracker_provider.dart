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

  List<Tracker> get trackers => _trackers;
  List<Alert> get alerts => _alerts;
  List<PendingTracker> get pendingTrackers => _pendingTrackers;
  bool get isScanning => _isScanning;

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
