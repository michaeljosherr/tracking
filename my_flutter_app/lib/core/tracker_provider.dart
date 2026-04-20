import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_flutter_app/core/ble_service.dart';
import 'package:my_flutter_app/core/device_heading_listener.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

/// Result of attempting to register a tracker serial on a specific hub.
enum SerialRegistrationOutcome {
  success,
  /// Same serial already saved for this hub.
  duplicateOnThisHub,
  /// Serial is registered under a different hub connection.
  blockedOtherHub,
  invalid,
}

class TrackerProvider with ChangeNotifier {
  final List<Tracker> _trackers = [];
  final List<Alert> _alerts = List.from(mockAlerts);
  final _uuid = const Uuid();
  final _ble = BleService();

  bool _isScanningHubs = false;
  List<DiscoveredHub> _discoveredHubs = [];
  final Set<String> _savedHubBleIds = {};

  bool _isBackgroundScanning = false;
  final Set<String> _pingingDevices = {};
  Timer? _offlineCheckTimer;

  final Map<String, int> _autoBearingCloseStreak = {};

  /// Smooths hub-reported distance (WiFi RSSI path-loss is noisy; raw values can jump to 200–400 m).
  final Map<String, double> _distanceEmaBySerial = {};

  static const double _autoBearingMaxDistanceM = 1.2;
  static const int _autoBearingMinRssiDbm = -58;
  static const int _autoBearingStreakRequired = 6;

  static const String _trackersStorageKey = 'registered_trackers';
  static const String _hubIdsStorageKey = 'saved_hub_ble_ids';
  static const int _offlineThresholdSeconds = 20;

  List<Tracker> get trackers => _trackers;
  List<Alert> get alerts => _alerts;
  bool get isScanningHubs => _isScanningHubs;

  /// Stable list reference until the next hub scan assigns a new list — avoids
  /// hub UI rebuilding on every unrelated tracker/BLE [notifyListeners].
  List<DiscoveredHub> get discoveredHubs => _discoveredHubs;

  /// Hub BLE ids the user has explicitly opened or that have trackers.
  List<String> get savedHubBleIds => _savedHubBleIds.toList()..sort();

  bool get isBackgroundScanning => _isBackgroundScanning;

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

  /// Get trackers scoped to a specific hub
  List<Tracker> getTrackersForHub(String hubBleId) {
    return _trackers
        .where((t) => t.bleAddress?.trim() == hubBleId.trim())
        .toList();
  }

  /// Get all hubs (by their BLE IDs) that have trackers
  List<String> getAllHubIds() {
    final hubIds = <String>{};
    for (final t in _trackers) {
      if (t.bleAddress != null && t.bleAddress!.isNotEmpty) {
        hubIds.add(t.bleAddress!);
      }
    }
    return hubIds.toList()..sort();
  }

  /// Get count of trackers for a hub
  int getTrackerCountForHub(String hubBleId) {
    return _trackers.where((t) => t.bleAddress?.trim() == hubBleId.trim()).length;
  }

  /// Get connection status summary for a hub
  ({int connected, int outOfRange, int disconnected}) getHubStatusSummary(String hubBleId) {
    final hubTrackers = getTrackersForHub(hubBleId);
    var connected = 0, outOfRange = 0, disconnected = 0;
    for (final t in hubTrackers) {
      switch (t.status) {
        case TrackerStatus.connected:
          connected++;
        case TrackerStatus.outOfRange:
          outOfRange++;
        case TrackerStatus.disconnected:
          disconnected++;
      }
    }
    return (connected: connected, outOfRange: outOfRange, disconnected: disconnected);
  }

  /// EMA + max step so the dashboard does not jump hundreds of meters on one bad RSSI sample.
  double? _smoothHubDistanceM(String serial, double? rawMeters) {
    if (rawMeters == null || rawMeters.isNaN || rawMeters.isInfinite) {
      return rawMeters;
    }
    final prev = _distanceEmaBySerial[serial];
    if (prev == null) {
      final v = rawMeters.clamp(0.05, 500.0);
      _distanceEmaBySerial[serial] = v;
      return v;
    }
    var target = rawMeters.clamp(0.05, 500.0);
    const maxStepM = 14.0;
    if ((target - prev).abs() > maxStepM) {
      target = prev + maxStepM * (target > prev ? 1 : -1);
    }
    const alpha = 0.22;
    final next = prev + alpha * (target - prev);
    _distanceEmaBySerial[serial] = next;
    return next;
  }

  List<String> _distinctHubBleIdsForBackground() {
    final s = <String>{..._savedHubBleIds};
    for (final t in _trackers) {
      if (t.bleAddress != null) s.add(t.bleAddress!);
    }
    return s.toList();
  }

  Future<void> initialize() async {
    await _loadTrackers();
    await _loadHubIds();
    print('[TrackerProvider] Initialized with ${_trackers.length} saved tracker(s)');

    if (_trackers.isNotEmpty) {
      await _ensureHeadingForTracking();
      print('[TrackerProvider] Auto-starting background scanning after loading ${_trackers.length} tracker(s)');
      await startBackgroundScanning();
    }
  }

  Future<void> _ensureHeadingForTracking() async {
    if (kIsWeb) return;
    await Permission.locationWhenInUse.request();
    DeviceHeadingStore.ensureStarted();
  }

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

  Future<void> _loadHubIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_hubIdsStorageKey) ?? [];
      _savedHubBleIds
        ..clear()
        ..addAll(list);
      for (final t in _trackers) {
        if (t.bleAddress != null) {
          _savedHubBleIds.add(t.bleAddress!);
        }
      }
    } catch (e) {
      print('[TrackerProvider] Error loading hub ids: $e');
    }
  }

  Future<void> _saveHubIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_hubIdsStorageKey, _savedHubBleIds.toList());
    } catch (e) {
      print('[TrackerProvider] Error saving hub ids: $e');
    }
  }

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

  Tracker? _trackerBySerial(String? serial) {
    if (serial == null || serial.isEmpty) return null;
    for (final t in _trackers) {
      if (t.serialNumber == serial) return t;
    }
    return null;
  }

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

  void resetScannerConfig() {
    _ble.resetConfig();
    notifyListeners();
  }

  /// Serializes hub discovery so concurrent calls (init + pop + refresh) cannot
  /// corrupt BLE state or leave [_isScanningHubs] stuck true.
  Future<void> _scanForHubsTail = Future<void>.value();

  /// Stops scans and lets the Android stack settle before connecting to a hub.
  /// Returns false if BLE permissions are not granted (Android 12+ needs scan/connect).
  Future<bool> prepareForDedicatedHubSession() async {
    final ok = await ensureBlePermissions();
    if (!ok) {
      print('[TrackerProvider] prepareForDedicatedHubSession: permissions denied');
      return false;
    }
    await stopBackgroundScanning();
    await stopDedicatedHubStream();
    await _ble.stopScan();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return true;
  }

  /// Runtime BLE permissions (required on Android 12+ for scan/connect).
  Future<bool> ensureBlePermissions() async {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.android) {
      final scan = await Permission.bluetoothScan.request();
      final conn = await Permission.bluetoothConnect.request();
      if (scan.isGranted && conn.isGranted) {
        return true;
      }
      print(
        '[TrackerProvider] BLE scan/connect not granted: $scan, $conn — trying location fallback',
      );
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      final bt = await Permission.bluetooth.request();
      if (bt.isGranted) {
        return true;
      }
    }
    final loc = await Permission.locationWhenInUse.request();
    return loc.isGranted;
  }

  /// BLE scan for advertising hubs (user picks one next).
  Future<void> scanForHubs({
    Duration duration = const Duration(seconds: 6),
  }) async {
    final run =
        _scanForHubsTail.then((_) => _scanForHubsBody(duration: duration));
    _scanForHubsTail = run.catchError((Object _) {});
    await run;
  }

  Future<void> _scanForHubsBody({
    required Duration duration,
  }) async {
    await stopBackgroundScanning();
    await stopDedicatedHubStream();
    await _ble.stopScan();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    if (!await ensureBlePermissions()) {
      print('[TrackerProvider] scanForHubs: BLE permissions not granted');
      return;
    }

    _isScanningHubs = true;
    _discoveredHubs = [];
    notifyListeners();

    try {
      _discoveredHubs = await _ble
          .scanForHubs(scanDuration: duration)
          .timeout(
            const Duration(seconds: 35),
            onTimeout: () {
              print('[TrackerProvider] scanForHubs timed out');
              return [];
            },
          );
    } catch (e) {
      print('[TrackerProvider] scanForHubs error: $e');
    } finally {
      _isScanningHubs = false;
      notifyListeners();
    }
  }

  /// Remember that this hub is part of the user's setup (shows in Settings, background rotation).
  Future<void> rememberHubConnection(String hubBleId) async {
    if (_savedHubBleIds.contains(hubBleId)) return;
    _savedHubBleIds.add(hubBleId);
    await _saveHubIds();
    notifyListeners();
  }

  /// Remove hub and all trackers tied to it. Frees serials for other hubs.
  Future<void> removeHubConnection(String hubBleId) async {
    await stopDedicatedHubStream();
    await stopBackgroundScanning();

    _savedHubBleIds.remove(hubBleId);
    for (final t in _trackers.where((x) => x.bleAddress == hubBleId)) {
      if (t.serialNumber != null) {
        _distanceEmaBySerial.remove(t.serialNumber!);
      }
    }
    _trackers.removeWhere((t) => t.bleAddress == hubBleId);
    await _saveHubIds();
    await _saveTrackers();

    if (_trackers.isEmpty) {
      DeviceHeadingStore.stop();
    } else {
      await startBackgroundScanning();
    }
    notifyListeners();
  }

  Future<void> startDedicatedHubStream(
    String hubBleId,
    void Function(List<PendingTracker>) onUpdate,
  ) {
    return _ble.startDedicatedHubStream(hubBleId, onUpdate);
  }

  Future<void> stopDedicatedHubStream() {
    return _ble.stopDedicatedHubStream();
  }

  Future<void> startBackgroundScanning() async {
    if (_isBackgroundScanning || _trackers.isEmpty) {
      if (_trackers.isEmpty) {
        print('[TrackerProvider] Cannot start background scanning: no registered trackers');
      }
      return;
    }

    _isBackgroundScanning = true;
    print('[TrackerProvider] ✓ Background hub rotation for ${_trackers.length} tracker(s)');

    try {
      await _ble.startContinuousScanning(
        onTrackerUpdate: _onContinuousScanUpdate,
        hubBleIds: _distinctHubBleIdsForBackground,
      );

      _offlineCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        _checkForOfflineTrackers();
      });
    } catch (e) {
      print('[TrackerProvider] Error starting continuous scan: $e');
      _isBackgroundScanning = false;
      notifyListeners();
    }
  }

  void _checkForOfflineTrackers() {
    final now = DateTime.now();
    var statusChanged = false;

    for (int i = 0; i < _trackers.length; i++) {
      final tracker = _trackers[i];
      final timeSinceLastSeen = now.difference(tracker.lastSeen).inSeconds;

      if (timeSinceLastSeen > _offlineThresholdSeconds &&
          tracker.status != TrackerStatus.disconnected) {
        print('[TrackerProvider] Marking "${tracker.name}" as offline (last seen ${timeSinceLastSeen}s ago)');
        _trackers[i] = tracker.copyWith(status: TrackerStatus.disconnected);
        statusChanged = true;
      }
    }

    if (statusChanged) {
      notifyListeners();
    }
  }

  void _onContinuousScanUpdate(List<PendingTracker> scannedTrackers) {
    if (scannedTrackers.isEmpty) {
      return;
    }

    var updated = false;

    for (final scanned in scannedTrackers) {
      final index = _trackers.indexWhere(
        (t) => t.serialNumber == scanned.serialNumber,
      );

      if (index != -1) {
        final tracker = _trackers[index];
        final serial = tracker.serialNumber ?? '';
        final dist = serial.isNotEmpty
            ? _smoothHubDistanceM(serial, scanned.distance)
            : scanned.distance;
        var updatedTracker = tracker.copyWith(
          rssi: scanned.rssi,
          rssiFiltered: scanned.rssiFiltered,
          distance: dist,
          lastSeen: DateTime.now(),
          signalStrength: scanned.signalStrength,
          status: TrackerStatus.connected,
        );

        final beforeBearing = updatedTracker.tagCompassBearingDeg;
        updatedTracker = _applyProximityAutoTagBearing(updatedTracker);
        _trackers[index] = updatedTracker;
        if (beforeBearing == null &&
            updatedTracker.tagCompassBearingDeg != null) {
          unawaited(_saveTrackers());
        }
        updated = true;
      }
    }

    if (updated) {
      notifyListeners();
    }
  }

  Tracker _applyProximityAutoTagBearing(Tracker t) {
    if (t.tagCompassBearingDeg != null) return t;

    final h = DeviceHeadingStore.heading.value;
    if (h == null) return t;

    final d = t.distance;
    final rssi = t.rssi;
    final veryCloseByDistance =
        d != null && d > 0 && d < _autoBearingMaxDistanceM;
    final veryStrongByRssi =
        rssi != null && rssi >= _autoBearingMinRssiDbm;
    final looksClose = veryCloseByDistance || veryStrongByRssi;

    final id = t.id;
    if (looksClose) {
      _autoBearingCloseStreak[id] = (_autoBearingCloseStreak[id] ?? 0) + 1;
    } else {
      _autoBearingCloseStreak[id] = 0;
    }

    if ((_autoBearingCloseStreak[id] ?? 0) >= _autoBearingStreakRequired) {
      _autoBearingCloseStreak[id] = 0;
      return t.copyWith(tagCompassBearingDeg: _normCompassHeading(h));
    }
    return t;
  }

  Future<void> stopBackgroundScanning() async {
    if (!_isBackgroundScanning) return;

    _isBackgroundScanning = false;

    _offlineCheckTimer?.cancel();
    _offlineCheckTimer = null;

    try {
      await _ble.stopContinuousScanning();
      print('[TrackerProvider] ✓ Stopped background scanning');
    } catch (e) {
      print('[TrackerProvider] Error stopping background scan: $e');
    }

    notifyListeners();
  }

  Future<bool> pingTracker(String trackerId) async {
    final tracker = getTracker(trackerId);
    if (tracker == null ||
        tracker.bleAddress == null ||
        tracker.serialNumber == null) {
      print('[TrackerProvider] Cannot ping: missing hub BLE address or serial');
      return false;
    }

    if (_pingingDevices.contains(trackerId)) {
      print('[TrackerProvider] Already pinging ${tracker.name}, please wait...');
      return false;
    }

    _pingingDevices.add(trackerId);

    try {
      print('[TrackerProvider] Pinging tracker via hub: ${tracker.name}');
      final success = await _ble.pingTrackerOnHub(
        hubBleAddress: tracker.bleAddress!,
        serialNumber: tracker.serialNumber!,
      );

      if (success) {
        print('[TrackerProvider] ✓ Ping successful for ${tracker.name}');
      } else {
        print('[TrackerProvider] ✗ Ping failed for ${tracker.name}');
        return false;
      }

      return true;
    } catch (e) {
      print('[TrackerProvider] Ping error: $e');
      return false;
    } finally {
      _pingingDevices.remove(trackerId);
      print('[TrackerProvider] Ping operation complete for ${tracker.name}');
    }
  }

  void renameTracker(String id, String newName) {
    final index = _trackers.indexWhere((t) => t.id == id);
    if (index != -1) {
      _trackers[index] = _trackers[index].copyWith(name: newName);

      for (var i = 0; i < _alerts.length; i++) {
        if (_alerts[i].trackerId == id) {
          _alerts[i] = _alerts[i].copyWith(trackerName: newName);
        }
      }

      notifyListeners();
      _saveTrackers();
    }
  }

  double _normCompassHeading(double degrees) {
    var v = degrees % 360.0;
    if (v < 0) v += 360.0;
    return v;
  }

  Future<void> setTrackerTagCompassBearing(String id, double bearingDeg) async {
    final index = _trackers.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _trackers[index] = _trackers[index].copyWith(
      tagCompassBearingDeg: _normCompassHeading(bearingDeg),
    );
    notifyListeners();
    await _saveTrackers();
  }

  Future<void> clearTrackerTagCompassBearing(String id) async {
    final index = _trackers.indexWhere((t) => t.id == id);
    if (index == -1) return;
    _autoBearingCloseStreak.remove(id);
    _trackers[index] = _trackers[index].copyWith(tagCompassBearingDeg: null);
    notifyListeners();
    await _saveTrackers();
  }

  /// Register a tag discovered on [expectedHubBleId]. Serial is unique app-wide per hub ownership rules.
  Future<SerialRegistrationOutcome> registerDeviceOnHub(
    PendingTracker pendingTracker,
    String name,
    String expectedHubBleId,
  ) async {
    final serial = pendingTracker.serialNumber;
    if (serial == null || serial.isEmpty) {
      return SerialRegistrationOutcome.invalid;
    }
    if (pendingTracker.bleAddress != null &&
        pendingTracker.bleAddress != expectedHubBleId) {
      return SerialRegistrationOutcome.invalid;
    }

    final existing = _trackerBySerial(serial);
    if (existing != null) {
      if (existing.bleAddress == expectedHubBleId) {
        return SerialRegistrationOutcome.duplicateOnThisHub;
      }
      return SerialRegistrationOutcome.blockedOtherHub;
    }

    final newId = _uuid.v4();

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
      batteryLevel: 100,
      rssi: rssiValue,
      rssiFiltered: rssiFilteredValue,
      distance: distance,
      serialNumber: pendingTracker.serialNumber,
      bleAddress: expectedHubBleId,
    );

    _trackers.add(newTracker);
    await rememberHubConnection(expectedHubBleId);

    print('[TrackerProvider] ✓ Registered device: "$name" ($serial) on hub $expectedHubBleId');
    notifyListeners();

    await _ensureHeadingForTracking();

    await _saveTrackers();

    return SerialRegistrationOutcome.success;
  }

  Future<void> unregisterTracker(String id) async {
    final t = getTracker(id);
    _autoBearingCloseStreak.remove(id);
    if (t?.serialNumber != null) {
      _distanceEmaBySerial.remove(t!.serialNumber!);
    }
    _trackers.removeWhere((x) => x.id == id);

    // Keep hub BLE ids in Connections until the user removes the hub explicitly
    // (Settings / Remove hub). Deleting trackers alone should not drop the hub
    // from prefs or confuse the next Add trackers / BLE session.

    if (_trackers.isEmpty) {
      DeviceHeadingStore.stop();
      await stopBackgroundScanning();
      await stopDedicatedHubStream();
      await _ble.stopScan();
    }

    notifyListeners();

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

  void refreshTrackers() {
    for (var i = 0; i < _trackers.length; i++) {
      final tracker = _trackers[i];
      _trackers[i] = tracker.copyWith(lastSeen: DateTime.now());
    }
    notifyListeners();
  }
}
