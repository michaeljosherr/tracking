import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:my_flutter_app/core/kalman_filter.dart';
import 'package:my_flutter_app/models/mock_data.dart';

// ============================================================================
// Hub + tracker protocol (esp_hubBLEWifi_trackerWifi / esp32_hub.ino)
// ============================================================================

/// Hub GAP name (BLE advertising)
const String hubBleGapName = 'ESP32_TRACKER_HUB';

/// Nordic UART–style service used by the hub
const String hubServiceUuidStr = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
const String hubRxUuidStr = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
const String hubTxUuidStr = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

final Guid hubServiceGuid = Guid(hubServiceUuidStr);

/// Telemetry line from hub TX notifications:
/// `TRACKER:esp32_indiv:<serial>:RSSI:<rssi>:DISTANCE:<meters>:IP:<ip>`
final RegExp _hubTrackerLine = RegExp(
  r'^TRACKER:esp32_indiv:([^:]+):RSSI:(-?\d+):DISTANCE:([\d.]+):IP:([0-9.]+)\s*$',
);

// ============================================================================
// Configuration (distance fallbacks when only RSSI is available)
// ============================================================================

const double TX_POWER_DBM = -65;
const double FREE_SPACE_PATH_LOSS = 2.0;
const int RSSI_THRESHOLD = -100;
const double MIN_DISTANCE_M = 0.1;
const double MAX_DISTANCE_M = 9999;

const double KALMAN_PROCESS_NOISE = 0.01;
const double KALMAN_MEASUREMENT_NOISE = 2.5;
const double KALMAN_INITIAL_UNCERTAINTY = 10.0;

// ============================================================================
// Tracker Data (Kalman on Wi‑Fi RSSI; hub also merges phone↔hub BLE for display distance)
// ============================================================================

class TrackerData {
  final String deviceId;
  final String serialNumber;
  final String bleAddress;
  late int rssi;
  late double rssiFiltered;
  late double distance;
  late DateTime lastUpdated;
  final KalmanFilter kalmanFilter;
  final List<double> rssiHistory = [];

  TrackerData({
    required this.deviceId,
    required this.serialNumber,
    required this.bleAddress,
    required int initialRssi,
    required double initialDistance,
  })  : rssi = initialRssi,
        rssiFiltered = initialRssi.toDouble(),
        distance = initialDistance,
        lastUpdated = DateTime.now(),
        kalmanFilter = KalmanFilter(
          processNoise: KALMAN_PROCESS_NOISE,
          measurementNoise: KALMAN_MEASUREMENT_NOISE,
          initialUncertainty: KALMAN_INITIAL_UNCERTAINTY,
        );

  void updateRssi(int newRssi) {
    rssi = newRssi;
    rssiFiltered = kalmanFilter.update(newRssi.toDouble());
    lastUpdated = DateTime.now();
    if (rssiHistory.length > 100) {
      rssiHistory.removeAt(0);
    }
    rssiHistory.add(rssiFiltered);
  }

  void updateDistance(double newDistance) {
    distance = newDistance;
  }
}

/// One discoverable hub from a BLE scan (deduped by [remoteId]).
class DiscoveredHub {
  DiscoveredHub({
    required this.remoteId,
    required this.displayName,
    required this.rssi,
  });

  final String remoteId;
  final String displayName;
  final int rssi;
}

/// BLE: connect to hub(s), consume TX notifications, parse tracker lines.
class BleService {
  static final BleService _instance = BleService._internal();

  double _txPower = TX_POWER_DBM;
  double _pathLoss = FREE_SPACE_PATH_LOSS;
  int _rssiThreshold = RSSI_THRESHOLD;

  final Map<String, TrackerData> _activeTrackers = {};

  bool _isContinuousScanRunning = false;
  Function(List<PendingTracker>)? _continuousScanCallback;
  List<String> Function()? _backgroundHubIds;

  bool _dedicatedHubActive = false;
  Future<void>? _dedicatedHubFuture;
  void Function(String hubBleId)? _backgroundHubConnectingCallback;
  void Function(String hubBleId)? _backgroundHubConnectedCallback;
  void Function(String hubBleId)? _backgroundHubDisconnectedCallback;

  StreamSubscription<List<int>>? _hubNotifySubscription;
  StreamSubscription<BluetoothConnectionState>? _hubConnectionSubscription;
  Future<void>? _hubSessionFuture;
  String _hubLineBuffer = '';

  BluetoothDevice? _connectedHub;
  BluetoothCharacteristic? _hubRx;
  BluetoothCharacteristic? _hubTx;

  /// Phone ↔ hub BLE link: updated from [BluetoothDevice.readRssi] while connected.
  Timer? _hubRssiPollTimer;
  double? _phoneToHubDistanceM;

  /// flutter_blue_plus enforces ~2s between GATT connects per device on Android.
  final Map<String, DateTime> _lastTransientHubDisconnectUtc = {};
  Future<void> _pingSerialTail = Future<void>.value();

  static const Duration _hubPingBleGap = Duration(milliseconds: 2200);

  Future<void> _waitTransientHubPingGap(String hubBleAddress) async {
    final key = hubBleAddress.trim();
    final last = _lastTransientHubDisconnectUtc[key];
    if (last == null) return;
    final elapsed = DateTime.now().difference(last);
    if (elapsed < _hubPingBleGap) {
      await Future<void>.delayed(_hubPingBleGap - elapsed);
    }
  }

  void _markTransientHubDisconnected(String hubBleAddress) {
    _lastTransientHubDisconnectUtc[hubBleAddress.trim()] = DateTime.now();
  }

  factory BleService() {
    return _instance;
  }

  BleService._internal();

  double get txPower => _txPower;
  double get pathLoss => _pathLoss;
  int get rssiThreshold => _rssiThreshold;

  void setConfig({
    double? txPower,
    double? pathLoss,
    int? rssiThreshold,
  }) {
    if (txPower != null) _txPower = txPower;
    if (pathLoss != null) _pathLoss = pathLoss;
    if (rssiThreshold != null) _rssiThreshold = rssiThreshold;
  }

  void resetConfig() {
    _txPower = TX_POWER_DBM;
    _pathLoss = FREE_SPACE_PATH_LOSS;
    _rssiThreshold = RSSI_THRESHOLD;
  }

  static bool uuidEquals(Guid a, String b) =>
      a.toString().toLowerCase() == b.toLowerCase();

  /// Legacy: direct tracker advertisement name (BLE-only trackers).
  static ({String deviceId, String serialNumber})? parseDeviceName(String? name) {
    if (name == null || !name.startsWith('esp32_indiv_')) {
      return null;
    }
    const prefix = 'esp32_indiv_';
    final serialNumber = name.substring(prefix.length);
    if (serialNumber.isEmpty) return null;
    return (deviceId: 'esp32_indiv', serialNumber: serialNumber);
  }

  static double calculateDistance(
    int rssi, {
    double txPower = TX_POWER_DBM,
    double pathLoss = FREE_SPACE_PATH_LOSS,
    double minDistance = MIN_DISTANCE_M,
    double maxDistance = MAX_DISTANCE_M,
  }) {
    if (rssi == 0) return 0.0;
    final distance =
        math.pow(10.0, (txPower - rssi) / (10 * pathLoss)).toDouble();
    return distance.clamp(minDistance, maxDistance);
  }

  double calculateDistanceWithConfig(int rssi) {
    return calculateDistance(
      rssi,
      txPower: _txPower,
      pathLoss: _pathLoss,
    );
  }

  /// Rough phone ↔ tag estimate when only (1) phone↔hub BLE range and (2) hub↔tag
  /// Wi‑Fi range are known: assume the two legs meet at ~90° at the hub (third side
  /// of a right triangle). Not exact, but aligns the UI with “distance from this
  /// phone” better than showing hub↔tag alone.
  static double combinePhoneHubAndHubTagLegs(
    double phoneToHubM,
    double hubToTagM,
  ) {
    final a = phoneToHubM.clamp(0.05, 500.0);
    final b = hubToTagM.clamp(0.05, 500.0);
    return math.sqrt(a * a + b * b);
  }

  void _stopHubRssiPolling() {
    _hubRssiPollTimer?.cancel();
    _hubRssiPollTimer = null;
    _phoneToHubDistanceM = null;
  }

  void _primePhoneToHubFromScanCache(String hubBleId) {
    final want = hubBleId.trim();
    for (final r in FlutterBluePlus.lastScanResults) {
      if (r.device.remoteId.toString() != want) continue;
      if (!scanResultIsHub(r)) continue;
      _phoneToHubDistanceM = calculateDistanceWithConfig(r.rssi);
      return;
    }
  }

  Future<void> _readPhoneToHubDistanceOnce(BluetoothDevice hub) async {
    try {
      if (!hub.isConnected) return;
      final rssi = await hub.readRssi();
      _phoneToHubDistanceM = calculateDistanceWithConfig(rssi);
    } catch (e) {
      print('[BleService] readRssi (phone↔hub): $e');
    }
  }

  void _startHubRssiPolling(BluetoothDevice hub) {
    _hubRssiPollTimer?.cancel();
    _hubRssiPollTimer = Timer.periodic(const Duration(milliseconds: 750), (_) async {
      await _readPhoneToHubDistanceOnce(hub);
    });
  }

  static bool scanResultIsHub(ScanResult r) {
    final adv =
        r.device.advName.isNotEmpty ? r.device.advName : r.device.platformName;
    final plat = r.device.platformName;
    if (adv == hubBleGapName || plat == hubBleGapName) {
      return true;
    }
    if (adv.contains('TRACKER_HUB')) {
      return true;
    }
    for (final u in r.advertisementData.serviceUuids) {
      if (uuidEquals(u, hubServiceUuidStr)) {
        return true;
      }
    }
    return false;
  }

  static Map<String, String>? parseHubTrackerLine(String line) {
    final m = _hubTrackerLine.firstMatch(line.trim());
    if (m == null) return null;
    final serial = m.group(1)!;
    if (serial == 'BOOT') return null;
    return {
      'serial': serial,
      'rssi': m.group(2)!,
      'distance': m.group(3)!,
      'ip': m.group(4)!,
    };
  }

  ({BluetoothCharacteristic rx, BluetoothCharacteristic tx})?
      _findUartCharacteristics(List<BluetoothService> services) {
    BluetoothCharacteristic? rx;
    BluetoothCharacteristic? tx;
    for (final s in services) {
      if (!uuidEquals(s.uuid, hubServiceUuidStr)) continue;
      for (final c in s.characteristics) {
        if (uuidEquals(c.uuid, hubRxUuidStr)) {
          rx = c;
        } else if (uuidEquals(c.uuid, hubTxUuidStr)) {
          tx = c;
        }
      }
    }
    if (rx == null || tx == null) return null;
    return (rx: rx, tx: tx);
  }

  void _appendHubPayload(
    List<int> value,
    void Function(Map<String, String> parsed) onParsed,
  ) {
    _hubLineBuffer += utf8.decode(value, allowMalformed: true);
    int nl;
    while ((nl = _hubLineBuffer.indexOf('\n')) >= 0) {
      final line = _hubLineBuffer.substring(0, nl);
      _hubLineBuffer = _hubLineBuffer.substring(nl + 1);
      final parsed = parseHubTrackerLine(line);
      if (parsed != null) {
        onParsed(parsed);
      }
    }
  }

  void _processParsedForPending(
    Map<String, String> parsed,
    String hubBleId,
    List<PendingTracker> batch,
  ) {
    final serial = parsed['serial']!;
    final rssi = int.tryParse(parsed['rssi'] ?? '') ?? -100;
    // Hub firmware embeds DISTANCE using its own TX-power constants (often very
    // different from [txPower] here), which makes meters disagree badly with the
    // RSSI in the same line (e.g. -18 dBm but ~80 m). Always derive the hub↔tag
    // leg from [rssi] with the same model as the rest of the app so the value
    // matches what we show as RSSI.
    final distFromHub = calculateDistanceWithConfig(rssi);

    // RSSI here is Wi‑Fi (tag↔hub AP), not phone BLE. Combine with phone↔hub BLE
    // range (see [_phoneToHubDistanceM]) so [PendingTracker.distance] reflects an
    // approximate phone↔tag estimate.

    final trackerData = _activeTrackers.putIfAbsent(
      serial,
      () => TrackerData(
        deviceId: 'esp32_indiv',
        serialNumber: serial,
        bleAddress: hubBleId,
        initialRssi: rssi,
        initialDistance: distFromHub,
      ),
    );

    trackerData.updateRssi(rssi);
    trackerData.updateDistance(distFromHub);

    final phoneHub = _phoneToHubDistanceM;
    final displayDistance = phoneHub != null
        ? combinePhoneHubAndHubTagLegs(phoneHub, distFromHub)
        : distFromHub;

    final signalStrength =
        (100 + trackerData.rssiFiltered).clamp(0.0, 100.0).toInt();

    batch.removeWhere((p) => p.serialNumber == serial);
    batch.add(
      PendingTracker(
        deviceId: 'esp32_indiv',
        signalStrength: signalStrength,
        discovered: DateTime.now(),
        serialNumber: serial,
        bleAddress: hubBleId,
        rssi: rssi,
        rssiFiltered: trackerData.rssiFiltered,
        distance: displayDistance,
        rssiHistory: List.from(trackerData.rssiHistory),
      ),
    );
  }

  /// Scan for all advertising hubs (deduped by device id, strongest RSSI kept).
  Future<List<DiscoveredHub>> scanForHubs({
    Duration scanDuration = const Duration(seconds: 6),
  }) async {
    final out = <String, ScanResult>{};
    try {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 150));

      if (!await isBluetoothAvailable() || !await isBluetoothOn()) {
        return [];
      }

      await FlutterBluePlus.startScan(
        timeout: scanDuration,
        continuousUpdates: true,
      );
      await Future.delayed(scanDuration + const Duration(milliseconds: 150));
      await FlutterBluePlus.stopScan();

      for (final r in FlutterBluePlus.lastScanResults) {
        if (!scanResultIsHub(r)) continue;
        final id = r.device.remoteId.toString();
        if (!out.containsKey(id) || r.rssi > out[id]!.rssi) {
          out[id] = r;
        }
      }

      final list = out.values.map((r) {
        final name = r.device.advName.isNotEmpty
            ? r.device.advName
            : r.device.platformName;
        return DiscoveredHub(
          remoteId: r.device.remoteId.toString(),
          displayName: name.isNotEmpty ? name : hubBleGapName,
          rssi: r.rssi,
        );
      }).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));

      return list;
    } catch (e) {
      print('[BleService] scanForHubs error: $e');
      return [];
    }
  }

  Future<void> _disconnectHub() async {
    _stopHubRssiPolling();
    await _hubNotifySubscription?.cancel();
    _hubNotifySubscription = null;
    await _hubConnectionSubscription?.cancel();
    _hubConnectionSubscription = null;
    _hubLineBuffer = '';
    if (_connectedHub != null && _connectedHub!.isConnected) {
      try {
        await _connectedHub!.disconnect();
      } catch (_) {}
    }
    _connectedHub = null;
    _hubRx = null;
    _hubTx = null;
  }

  /// One-shot: connect to [hubBleId], collect tracker lines, disconnect.
  Future<List<PendingTracker>> scanTrackersOnHub({
    required String hubBleId,
    Duration listenDuration = const Duration(seconds: 5),
  }) async {
    try {
      _activeTrackers.clear();

      if (!await isBluetoothAvailable() || !await isBluetoothOn()) {
        return [];
      }

      final hub = BluetoothDevice.fromId(hubBleId);
      await hub.connect(
        timeout: const Duration(seconds: 15),
        mtu: 512,
      );

      final services = await hub.discoverServices();
      final pair = _findUartCharacteristics(services);
      if (pair == null) {
        await hub.disconnect();
        return [];
      }

      await pair.tx.setNotifyValue(true);
      _stopHubRssiPolling();
      _primePhoneToHubFromScanCache(hubBleId);
      await _readPhoneToHubDistanceOnce(hub);

      final result = <PendingTracker>[];

      final sub = pair.tx.onValueReceived.listen((value) {
        _appendHubPayload(value, (parsed) {
          _processParsedForPending(parsed, hubBleId, result);
        });
      });

      hub.cancelWhenDisconnected(sub);

      await Future.delayed(listenDuration);

      await sub.cancel();
      await hub.disconnect();

      return result;
    } catch (e) {
      print('[BleService] scanTrackersOnHub error: $e');
      return [];
    } finally {
      _stopHubRssiPolling();
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('[BleService] Error stopping scan: $e');
    }
  }

  Future<void> startContinuousScanning({
    required Function(List<PendingTracker>) onTrackerUpdate,
    required List<String> Function() hubBleIds,
    void Function(String hubBleId)? onHubConnecting,
    void Function(String hubBleId)? onHubConnected,
    void Function(String hubBleId)? onHubDisconnected,
  }) async {
    // If rotation is already running, return without touching the connection.
    // (Calling [stopDedicatedHubStream] here would disconnect the active
    // background session, then we'd hit this guard and return — leaving BLE dead
    // and no hub telemetry on the dashboard.)
    if (_isContinuousScanRunning) {
      return;
    }

    // End any dedicated add-trackers session before starting background rotation.
    await stopDedicatedHubStream();

    if (!await isBluetoothAvailable() || !await isBluetoothOn()) {
      return;
    }

    _isContinuousScanRunning = true;
    _continuousScanCallback = onTrackerUpdate;
    _backgroundHubIds = hubBleIds;
    _backgroundHubConnectingCallback = onHubConnecting;
    _backgroundHubConnectedCallback = onHubConnected;
    _backgroundHubDisconnectedCallback = onHubDisconnected;
    _activeTrackers.clear();

    _hubSessionFuture = _runBackgroundHubRotationLoop();
    print('[BleService] Multi-hub background session started');
  }

  Future<void> _runBackgroundHubRotationLoop() async {
    while (_isContinuousScanRunning) {
      final ids = _backgroundHubIds?.call() ?? [];
      if (ids.isEmpty) {
        await Future.delayed(const Duration(seconds: 2));
        continue;
      }

      for (final hubId in ids) {
        if (!_isContinuousScanRunning) break;

        _activeTrackers.clear();
        await _listenOneHubUntilDisconnect(
          hubBleId: hubId,
          onBatch: _continuousScanCallback,
          shouldContinue: () => _isContinuousScanRunning,
          primeScannerCache: false,
        );

        if (!_isContinuousScanRunning) break;
        await Future.delayed(const Duration(milliseconds: 400));
      }
    }

    await _disconnectHub();
  }

  /// Live stream for a single hub (add-trackers screen). Mutually exclusive with background.
  Future<void> startDedicatedHubStream(
    String hubBleId,
    void Function(List<PendingTracker>) onUpdate,
  ) async {
    await stopDedicatedHubStream();
    _dedicatedHubActive = true;
    _activeTrackers.clear();
    _dedicatedHubFuture = _runDedicatedHubLoop(hubBleId, onUpdate);
  }

  Future<void> _runDedicatedHubLoop(
    String hubBleId,
    void Function(List<PendingTracker>) onUpdate,
  ) async {
    while (_dedicatedHubActive) {
      onUpdate(<PendingTracker>[]);
      _activeTrackers.clear();

      var gotTelemetry = false;
      void batchHandler(List<PendingTracker> list) {
        if (list.isNotEmpty) gotTelemetry = true;
        onUpdate(list);
      }

      await _listenOneHubUntilDisconnect(
        hubBleId: hubBleId,
        onBatch: batchHandler,
        shouldContinue: () => _dedicatedHubActive,
        primeScannerCache: true,
      );

      // Quick second session without another long scan if the first ended with no packets
      // (stack race after disconnect, or hub BLE client slot timing).
      if (_dedicatedHubActive && !gotTelemetry) {
        await Future.delayed(const Duration(milliseconds: 650));
        gotTelemetry = false;
        await _listenOneHubUntilDisconnect(
          hubBleId: hubBleId,
          onBatch: batchHandler,
          shouldContinue: () => _dedicatedHubActive,
          primeScannerCache: false,
        );
      }

      if (_dedicatedHubActive) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    await _disconnectHub();
  }

  Future<void> stopDedicatedHubStream() async {
    _dedicatedHubActive = false;
    await _disconnectHub();
    if (_dedicatedHubFuture != null) {
      try {
        await _dedicatedHubFuture!.timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            print(
              '[BleService] stopDedicatedHubStream: dedicated future timed out',
            );
          },
        );
      } catch (e) {
        print('[BleService] stopDedicatedHubStream: $e');
      } finally {
        await _disconnectHub();
      }
    }
    _dedicatedHubFuture = null;
  }

  /// Android often requires a recent scan before [BluetoothDevice.connect] works
  /// reliably (desktop Bleak scans first). [dedicatedAddScreen] uses a longer scan.
  Future<void> _primeHubScannerCache({required bool dedicatedAddScreen}) async {
    if (!dedicatedAddScreen) return;
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 4),
        continuousUpdates: true,
        withServices: [hubServiceGuid],
      );
      await Future.delayed(const Duration(milliseconds: 3200));
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  Future<void> _primeBackgroundHubScannerCache(String hubBleId) async {
    final want = hubBleId.trim();
    final alreadyCached = FlutterBluePlus.lastScanResults.any(
      (r) => scanResultIsHub(r) && r.device.remoteId.toString() == want,
    );
    if (alreadyCached) return;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 3),
        continuousUpdates: true,
        withServices: [hubServiceGuid],
      );
      for (var i = 0; i < 12; i++) {
        final found = FlutterBluePlus.lastScanResults.any(
          (r) => scanResultIsHub(r) && r.device.remoteId.toString() == want,
        );
        if (found) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  /// Prefer the [ScanResult.device] from the last scan so the OS BLE cache is warm.
  BluetoothDevice _hubDeviceForId(String hubBleId) {
    final want = hubBleId.trim();
    for (final r in FlutterBluePlus.lastScanResults) {
      if (!scanResultIsHub(r)) continue;
      if (r.device.remoteId.toString() == want) {
        return r.device;
      }
    }
    return BluetoothDevice.fromId(want);
  }

  Future<void> _listenOneHubUntilDisconnect({
    required String hubBleId,
    required void Function(List<PendingTracker>)? onBatch,
    required bool Function() shouldContinue,
    bool primeScannerCache = false,
  }) async {
    if (!shouldContinue()) return;

    BluetoothDevice? hub;
    try {
      if (!primeScannerCache) {
        _backgroundHubConnectingCallback?.call(hubBleId);
      }
      await _primeHubScannerCache(dedicatedAddScreen: primeScannerCache);
      if (!primeScannerCache) {
        await _primeBackgroundHubScannerCache(hubBleId);
      }

      if (!shouldContinue()) return;

      try {
        final bonded = await FlutterBluePlus.systemDevices([hubServiceGuid]);
        for (final d in bonded) {
          if (d.remoteId.toString() == hubBleId.trim()) {
            hub = d;
            break;
          }
        }
      } catch (_) {}

      hub ??= _hubDeviceForId(hubBleId);

      await hub.connect(
        timeout: Duration(seconds: primeScannerCache ? 15 : 6),
        mtu: 512,
      );
      if (!shouldContinue()) {
        await hub.disconnect();
        return;
      }

      final services = await hub.discoverServices();
      final pair = _findUartCharacteristics(services);
      if (pair == null) {
        await hub.disconnect();
        return;
      }

      _connectedHub = hub;
      _hubRx = pair.rx;
      _hubTx = pair.tx;
      if (!primeScannerCache) {
        _backgroundHubConnectedCallback?.call(hubBleId);
      }

      await pair.tx.setNotifyValue(true);

      _stopHubRssiPolling();
      _primePhoneToHubFromScanCache(hubBleId);
      await _readPhoneToHubDistanceOnce(hub);
      _startHubRssiPolling(hub);

      final batch = <PendingTracker>[];

      await _hubNotifySubscription?.cancel();
      _hubNotifySubscription = pair.tx.onValueReceived.listen((value) {
        if (!shouldContinue()) return;
        _appendHubPayload(value, (parsed) {
          _processParsedForPending(parsed, hubBleId, batch);
          if (batch.isNotEmpty && onBatch != null) {
            onBatch(List.from(batch));
          }
        });
      });
      hub.cancelWhenDisconnected(_hubNotifySubscription!);

      final completer = Completer<void>();
      var ignoreEarlyDisconnect = true;
      Future<void>.delayed(const Duration(milliseconds: 450), () {
        ignoreEarlyDisconnect = false;
      });
      _hubConnectionSubscription = hub.connectionState.listen((state) {
        if (state != BluetoothConnectionState.disconnected) return;
        if (ignoreEarlyDisconnect) return;
        if (!completer.isCompleted) completer.complete();
      });

      await completer.future;

      await _hubNotifySubscription?.cancel();
      _hubNotifySubscription = null;
      await _hubConnectionSubscription?.cancel();
      _hubConnectionSubscription = null;
      _stopHubRssiPolling();
      _connectedHub = null;
      _hubRx = null;
      _hubTx = null;
      _hubLineBuffer = '';
      if (!primeScannerCache) {
        _backgroundHubDisconnectedCallback?.call(hubBleId);
      }
    } catch (e) {
      print('[BleService] Hub session error: $e');
      _stopHubRssiPolling();
      try {
        if (hub != null && hub.isConnected) await hub.disconnect();
      } catch (_) {}
      if (!primeScannerCache) {
        _backgroundHubDisconnectedCallback?.call(hubBleId);
      }
    }
  }

  Future<void> stopContinuousScanning() async {
    _isContinuousScanRunning = false;
    _continuousScanCallback = null;
    _backgroundHubIds = null;
    _backgroundHubConnectingCallback = null;
    _backgroundHubConnectedCallback = null;
    _backgroundHubDisconnectedCallback = null;

    await _disconnectHub();

    if (_hubSessionFuture != null) {
      try {
        await _hubSessionFuture!.timeout(
          const Duration(seconds: 12),
          onTimeout: () {
            print(
              '[BleService] stopContinuousScanning: hub session future timed out',
            );
          },
        );
      } catch (e) {
        print('[BleService] stopContinuousScanning session: $e');
      } finally {
        await _disconnectHub();
      }
    }
    _hubSessionFuture = null;

    _activeTrackers.clear();
  }

  bool get isContinuousScanRunning => _isContinuousScanRunning;

  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isBluetoothOn() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (e) {
      return false;
    }
  }

  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      print('[BleService] Error turning on Bluetooth: $e');
    }
  }

  Future<bool> pingTrackerOnHub({
    required String hubBleAddress,
    required String serialNumber,
  }) async {
    final prev = _pingSerialTail;
    final gate = Completer<void>();
    _pingSerialTail = gate.future;
    await prev;
    try {
      await _waitTransientHubPingGap(hubBleAddress);
      return await _pingTrackerOnHubUnserialized(
        hubBleAddress: hubBleAddress,
        serialNumber: serialNumber,
      );
    } finally {
      gate.complete();
    }
  }

  Future<bool> _pingTrackerOnHubUnserialized({
    required String hubBleAddress,
    required String serialNumber,
  }) async {
    try {
      print('[BleService] Ping via hub $hubBleAddress serial=$serialNumber');

      if (_connectedHub != null &&
          _connectedHub!.remoteId.toString() == hubBleAddress &&
          _hubRx != null &&
          _hubTx != null &&
          _connectedHub!.isConnected) {
        return _pingWithRetry(
          _hubRx!,
          _hubTx!,
          serialNumber,
        );
      }

      await _primeBackgroundHubScannerCache(hubBleAddress);
      final hub = BluetoothDevice.fromId(hubBleAddress);
      await hub.connect(timeout: const Duration(seconds: 8), mtu: 512);
      final services = await hub.discoverServices();
      final pair = _findUartCharacteristics(services);
      if (pair == null) {
        await hub.disconnect();
        _markTransientHubDisconnected(hubBleAddress);
        return false;
      }

      final ok = await _pingWithRetry(
        pair.rx,
        pair.tx,
        serialNumber,
      );
      await hub.disconnect();
      _markTransientHubDisconnected(hubBleAddress);
      return ok;
    } catch (e) {
      print('[BleService] Ping error: $e');
      return false;
    }
  }

  Future<bool> _pingWithRetry(
    BluetoothCharacteristic rx,
    BluetoothCharacteristic tx,
    String serialNumber,
  ) async {
    final first = await _pingUsingCharacteristics(rx, tx, serialNumber);
    if (first) return true;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _pingUsingCharacteristics(rx, tx, serialNumber);
  }

  Future<bool> _pingUsingCharacteristics(
    BluetoothCharacteristic rx,
    BluetoothCharacteristic tx,
    String serialNumber,
  ) async {
    final completer = Completer<bool>();
    late StreamSubscription<List<int>> sub;
    var buffer = '';

    sub = tx.onValueReceived.listen((value) {
      buffer += utf8.decode(value, allowMalformed: true);
      while (true) {
        final nl = buffer.indexOf('\n');
        if (nl < 0) break;
        final line = buffer.substring(0, nl);
        buffer = buffer.substring(nl + 1);
        final t = line.trim();
        if (t.startsWith('PING_RESULT:$serialNumber:')) {
          final rest = t.substring('PING_RESULT:$serialNumber:'.length);
          if (!completer.isCompleted) {
            completer.complete(rest == 'SUCCESS');
          }
        }
      }
    });

    await tx.setNotifyValue(true);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    final cmd = utf8.encode('PING:$serialNumber\n');
    await rx.write(cmd, withoutResponse: false);

    final success = await completer.future
        .timeout(const Duration(seconds: 5), onTimeout: () => false);

    await sub.cancel();
    return success;
  }
}
