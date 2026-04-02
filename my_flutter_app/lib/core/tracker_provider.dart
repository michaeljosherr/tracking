import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
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
  final Set<String> _pingingDevices = {};  // Track devices currently being pinged

  static const String _trackersStorageKey = 'registered_trackers';

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

  /// Initialize tracker provider and load saved trackers
  Future<void> initialize() async {
    await _loadTrackers();
    print('[TrackerProvider] Initialized with ${_trackers.length} saved tracker(s)');
  }

  /// Load trackers from SharedPreferences
  Future<void> _loadTrackers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackersJson = prefs.getStringList(_trackersStorageKey) ?? [];
      
      _trackers.clear();
      for (final json in trackersJson) {
        try {
          final tracker = Tracker.fromJson(jsonDecode(json) as Map<String, dynamic>);
          _trackers.add(tracker);
          print('[TrackerProvider] Loaded tracker: ${tracker.name} (${tracker.serialNumber})');
        } catch (e) {
          print('[TrackerProvider] Error loading tracker: $e');
        }
      }
      
      if (_trackers.isNotEmpty) {
        notifyListeners();
      }
    } catch (e) {
      print('[TrackerProvider] Error loading trackers: $e');
    }
  }

  /// Save trackers to SharedPreferences
  Future<void> _saveTrackers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackersJson = _trackers
          .map((tracker) => jsonEncode(tracker.toJson()))
          .toList();
      
      await prefs.setStringList(_trackersStorageKey, trackersJson);
      print('[TrackerProvider] Saved ${_trackers.length} tracker(s) to storage');
    } catch (e) {
      print('[TrackerProvider] Error saving trackers: $e');
    }
  }

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
  /// Uses continuous BLE scanning like the Python app (always scanning, lives updates)
  /// No gaps between scans - detection happens in real-time as devices advertise
  Future<void> startBackgroundScanning() async {
    if (_isBackgroundScanning || _trackers.isEmpty) {
      if (_trackers.isEmpty) {
        print('[TrackerProvider] Cannot start background scanning: no registered trackers');
      }
      return;
    }

    _isBackgroundScanning = true;
    print('[TrackerProvider] ✓ Starting continuous background scanning for ${_trackers.length} registered tracker(s)');
    print('[TrackerProvider] Registered trackers: ${_trackers.map((t) => t.serialNumber).join(', ')}');

    try {
      // Start continuous scanning with live callbacks
      // This matches the Python app behavior: scanner runs continuously
      await _ble.startContinuousScanning(
        onTrackerUpdate: _onContinuousScanUpdate,
      );
    } catch (e) {
      print('[TrackerProvider] Error starting continuous scan: $e');
      _isBackgroundScanning = false;
      notifyListeners();
    }
  }

  /// Handle continuous scan updates from BLE service
  /// Called whenever devices are detected during continuous scanning
  void _onContinuousScanUpdate(List<PendingTracker> scannedTrackers) {
    if (scannedTrackers.isEmpty) return;

    var updated = false;

    for (final scanned in scannedTrackers) {
      // Find matching registered tracker by serial number
      final index = _trackers.indexWhere(
        (t) => t.serialNumber == scanned.serialNumber,
      );

      if (index != -1) {
        final tracker = _trackers[index];

        // Update RSSI and distance in real-time
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

  /// Stop continuous background scanning
  Future<void> stopBackgroundScanning() async {
    if (!_isBackgroundScanning) return;

    _isBackgroundScanning = false;

    try {
      await _ble.stopContinuousScanning();
      print('[TrackerProvider] ✓ Stopped background scanning');
    } catch (e) {
      print('[TrackerProvider] Error stopping background scan: $e');
    }

    notifyListeners();
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
      _saveTrackers();  // Persist rename
    }
  }

  /// Register a discovered BLE device as an active tracker
  Future<void> registerDevice(PendingTracker pendingTracker, String name) async {
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
    
    // Persist to storage
    await _saveTrackers();
  }

  Future<void> unregisterTracker(String id) async {
    _trackers.removeWhere((t) => t.id == id);
    notifyListeners();
    
    // Persist to storage
    await _saveTrackers();
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
