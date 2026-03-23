import 'package:flutter/material.dart';
import 'package:my_flutter_app/core/ble_service.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:uuid/uuid.dart';

class TrackerProvider with ChangeNotifier {
  final List<Tracker> _trackers = List.from(mockTrackers);
  final List<Alert> _alerts = List.from(mockAlerts);
  final List<PendingTracker> _pendingTrackers = [];
  final _uuid = const Uuid();
  final _ble = BleService();

  bool _isScanning = false;

  List<Tracker> get trackers => _trackers;
  List<Alert> get alerts => _alerts;
  List<PendingTracker> get pendingTrackers => _pendingTrackers;
  bool get isScanning => _isScanning;

  List<Alert> get activeAlerts => _alerts.where((a) => !a.acknowledged).toList();

  int get connectedCount => _trackers.where((t) => t.status == TrackerStatus.connected).length;
  int get outOfRangeCount => _trackers.where((t) => t.status == TrackerStatus.outOfRange).length;
  int get disconnectedCount => _trackers.where((t) => t.status == TrackerStatus.disconnected).length;

  Tracker? getTracker(String id) {
    try {
      return _trackers.firstWhere((t) => t.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Scan for ESP32 Tracker devices via BLE
  Future<void> scanForTrackers({Duration duration = const Duration(seconds: 5)}) async {
    _isScanning = true;
    notifyListeners();

    try {
      final scannedTrackers = await _ble.scanForTrackers(scanDuration: duration);
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
    
    // Calculate distance from RSSI
    final distance = pendingTracker.rssi != null 
        ? BleService.calculateDistance(pendingTracker.rssi!)
        : null;
    
    final newTracker = Tracker(
      id: newId,
      deviceId: pendingTracker.deviceId,
      name: name,
      status: TrackerStatus.connected,
      signalStrength: pendingTracker.signalStrength,
      lastSeen: DateTime.now(),
      batteryLevel: 100, // Default for new registration
      // BLE fields
      rssi: pendingTracker.rssi,
      rssiFiltered: pendingTracker.rssi?.toDouble(),
      distance: distance,
      serialNumber: pendingTracker.serialNumber,
      bleAddress: pendingTracker.bleAddress,
    );

    // Remove from pending
    _pendingTrackers.removeWhere((p) => p.deviceId == pendingTracker.deviceId);

    // Add to registered
    _trackers.add(newTracker);
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
}
