import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:my_flutter_app/core/kalman_filter.dart';
import 'package:my_flutter_app/models/mock_data.dart';

// ============================================================================
// Hub + tracker BLE protocol (mirrors esp_hubBLEWifi_trackerWifi/esp32_hub.ino)
// ============================================================================
//
// The hub advertises a Nordic UART service. Once connected we subscribe to
// the TX characteristic and receive newline-delimited tracker telemetry of
// the form:
//
//   TRACKER:esp32_indiv:<serial>:RSSI:<rssi>:DISTANCE:<meters>:IP:<ip>
//
// Commands (e.g. PING:<serial>) are written to the RX characteristic and the
// hub responds asynchronously over TX with a `PING_RESULT:<serial>:<status>`
// line.
//
// Design goals (matches the Python desktop GUI esp32_hub_gui.py which is
// known to keep up with 40+ trackers without dropping the connection):
//
//   * Hold ONE persistent BLE connection to the active hub. No background
//     rotation or speculative disconnect/reconnect cycles — those are what
//     caused the Flutter app to drop while the hub was healthy.
//   * Request HIGH connection priority right after connect. Default Android
//     intervals (~30-50ms) cannot drain the hub's burst of ~40 notifications
//     every 3s and the link gets terminated. HIGH brings it down to ~7-15ms.
//   * Keep a serial->state map and emit aggregated snapshots on a timer
//     (mirrors Python's `_emit_snapshot()` loop) instead of forwarding every
//     single notification. Avoids overwhelming the UI thread.
//   * Stale-timeout per tracker (9s, same as Python default) so trackers
//     that disappear from the hub feed stop being treated as live without
//     having to drop the BLE link.
//   * If the user has more than one saved hub, rotate through them but only
//     after the current connection is actually lost — never voluntarily.
// ============================================================================

const String hubBleGapName = 'ESP32_TRACKER_HUB';
const String hubServiceUuidStr = '6E400001-B5A3-F393-E0A9-E50E24DCCA9E';
const String hubRxUuidStr = '6E400002-B5A3-F393-E0A9-E50E24DCCA9E';
const String hubTxUuidStr = '6E400003-B5A3-F393-E0A9-E50E24DCCA9E';

final Guid hubServiceGuid = Guid(hubServiceUuidStr);

final RegExp _hubTrackerLine = RegExp(
  r'^TRACKER:esp32_indiv:([^:]+):RSSI:(-?\d+):DISTANCE:([\d.]+):IP:([0-9.]+)\s*$',
);

// ============================================================================
// Defaults for distance estimation. Same constants as Python GUI defaults.
// ============================================================================

const double TX_POWER_DBM = -65;
const double FREE_SPACE_PATH_LOSS = 2.0;
const int RSSI_THRESHOLD = -100;
const double MIN_DISTANCE_M = 0.1;
const double MAX_DISTANCE_M = 9999;

const double KALMAN_PROCESS_NOISE = 0.01;
const double KALMAN_MEASUREMENT_NOISE = 2.5;
const double KALMAN_INITIAL_UNCERTAINTY = 10.0;

/// Per-tracker live state held in [BleService] while a hub session is active.
/// Mirrors Python's `_rows` + `_last_seen_ts` + `_distance_filters` maps.
class _DetectedTracker {
  _DetectedTracker({
    required this.serialNumber,
    required this.hubBleId,
    required int initialRssi,
    required double initialDistance,
  })  : rssi = initialRssi,
        rssiFiltered = initialRssi.toDouble(),
        distance = initialDistance,
        ip = '',
        lastSeenMs = DateTime.now().millisecondsSinceEpoch,
        kalman = KalmanFilter(
          processNoise: KALMAN_PROCESS_NOISE,
          measurementNoise: KALMAN_MEASUREMENT_NOISE,
          initialUncertainty: KALMAN_INITIAL_UNCERTAINTY,
        );

  final String serialNumber;
  final String hubBleId;
  final KalmanFilter kalman;
  final List<double> rssiHistory = [];

  int rssi;
  double rssiFiltered;
  double distance;
  String ip;
  int lastSeenMs;

  void updateFromHubLine({required int rssi, required double distance, required String ip}) {
    this.rssi = rssi;
    rssiFiltered = kalman.update(rssi.toDouble());
    this.distance = distance;
    this.ip = ip;
    lastSeenMs = DateTime.now().millisecondsSinceEpoch;
    if (rssiHistory.length > 100) {
      rssiHistory.removeAt(0);
    }
    rssiHistory.add(rssiFiltered);
  }

  PendingTracker toPending() {
    final signal = (100 + rssiFiltered).clamp(0.0, 100.0).toInt();
    return PendingTracker(
      deviceId: 'esp32_indiv',
      signalStrength: signal,
      discovered: DateTime.fromMillisecondsSinceEpoch(lastSeenMs),
      serialNumber: serialNumber,
      bleAddress: hubBleId,
      rssi: rssi,
      rssiFiltered: rssiFiltered,
      distance: distance,
      rssiHistory: List<double>.from(rssiHistory),
    );
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

/// Singleton BLE coordinator.
///
/// Two top-level operating modes share the same persistent-connection loop:
///
///   * Background mode: started by [startContinuousScanning], used for the
///     dashboard. Keeps a connection to one of the user's saved hubs alive
///     and emits `PendingTracker` snapshots on a timer.
///   * Dedicated mode: started by [startDedicatedHubStream], used by the
///     "Add trackers" screen. Same loop but pinned to one hub id and primes
///     a discovery scan first so the OS BLE cache is warm.
class BleService {
  static final BleService _instance = BleService._internal();
  factory BleService() => _instance;
  BleService._internal();

  // --- Tunable constants -----------------------------------------------------

  /// How long to keep a tracker as "online" after its last hub TX line.
  /// Matches Python's `stale_timeout_ms` default.
  static const Duration _trackerStale = Duration(milliseconds: 9000);

  /// Periodic snapshot cadence — same as Python's `poll_interval_s`.
  static const Duration _emitInterval = Duration(milliseconds: 400);

  /// Backoff after a session ends before we attempt to reconnect or rotate.
  static const Duration _reconnectBackoff = Duration(milliseconds: 1200);

  /// Used by [pingTrackerOnHub] to avoid stomping the dedicated/continuous
  /// session right after we tore it down for a one-shot ping connect.
  static const Duration _hubPingBleGap = Duration(milliseconds: 2200);

  // --- Distance config -------------------------------------------------------

  double _txPower = TX_POWER_DBM;
  double _pathLoss = FREE_SPACE_PATH_LOSS;
  int _rssiThreshold = RSSI_THRESHOLD;

  double get txPower => _txPower;
  double get pathLoss => _pathLoss;
  int get rssiThreshold => _rssiThreshold;

  void setConfig({double? txPower, double? pathLoss, int? rssiThreshold}) {
    if (txPower != null) _txPower = txPower;
    if (pathLoss != null) _pathLoss = pathLoss;
    if (rssiThreshold != null) _rssiThreshold = rssiThreshold;
    // Mirror Python: clear filters so the new constants take effect right away.
    _detected.clear();
  }

  void resetConfig() {
    _txPower = TX_POWER_DBM;
    _pathLoss = FREE_SPACE_PATH_LOSS;
    _rssiThreshold = RSSI_THRESHOLD;
    _detected.clear();
  }

  // --- Active session state --------------------------------------------------

  /// All trackers we've seen on the current hub session, keyed by serial.
  /// Mirrors Python's `_rows` dictionary. Entries with `lastSeenMs` older than
  /// [_trackerStale] are filtered out at emit time but kept around so a brief
  /// dropout doesn't lose their RSSI history / Kalman state.
  final Map<String, _DetectedTracker> _detected = {};
  String _lineBuffer = '';

  BluetoothDevice? _connectedHub;
  String? _connectedHubId;
  BluetoothCharacteristic? _hubRx;
  BluetoothCharacteristic? _hubTx;

  StreamSubscription<List<int>>? _txSubscription;
  StreamSubscription<BluetoothConnectionState>? _connSubscription;
  Timer? _emitTimer;

  // Continuous (background) mode bookkeeping.
  bool _backgroundActive = false;
  Future<void>? _backgroundFuture;
  void Function(List<PendingTracker>)? _backgroundCallback;
  List<String> Function()? _backgroundHubIds;
  void Function(String hubBleId)? _onHubConnecting;
  void Function(String hubBleId)? _onHubConnected;
  void Function(String hubBleId)? _onHubDisconnected;

  // Dedicated (add-trackers) mode bookkeeping.
  bool _dedicatedActive = false;
  Future<void>? _dedicatedFuture;
  String? _dedicatedHubId;
  void Function(List<PendingTracker>)? _dedicatedCallback;

  /// Used by [pingTrackerOnHub] to serialize its short BLE side-trips and
  /// avoid clobbering the live monitoring connection.
  Future<void> _pingSerialTail = Future<void>.value();
  final Map<String, DateTime> _lastSidetripDisconnectUtc = {};

  bool get isContinuousScanRunning => _backgroundActive;

  // --- Helpers ---------------------------------------------------------------

  static bool uuidEquals(Guid a, String b) =>
      a.toString().toLowerCase() == b.toLowerCase();

  /// Legacy helper: parse a tracker GAP name like `esp32_indiv_<serial>`.
  static ({String deviceId, String serialNumber})? parseDeviceName(String? name) {
    if (name == null || !name.startsWith('esp32_indiv_')) return null;
    final serial = name.substring('esp32_indiv_'.length);
    if (serial.isEmpty) return null;
    return (deviceId: 'esp32_indiv', serialNumber: serial);
  }

  static double calculateDistance(
    int rssi, {
    double txPower = TX_POWER_DBM,
    double pathLoss = FREE_SPACE_PATH_LOSS,
    double minDistance = MIN_DISTANCE_M,
    double maxDistance = MAX_DISTANCE_M,
  }) {
    if (rssi == 0) return 0.0;
    final d = math.pow(10.0, (txPower - rssi) / (10 * pathLoss)).toDouble();
    return d.clamp(minDistance, maxDistance);
  }

  double calculateDistanceWithConfig(int rssi) {
    return calculateDistance(rssi, txPower: _txPower, pathLoss: _pathLoss);
  }

  /// Rough phone↔tag estimate when only phone↔hub and hub↔tag legs are known.
  /// Treated as a right triangle. Kept for backwards compatibility — we no
  /// longer use this in the hot path because it confuses calibration.
  static double combinePhoneHubAndHubTagLegs(double phoneToHubM, double hubToTagM) {
    final a = phoneToHubM.clamp(0.05, 500.0);
    final b = hubToTagM.clamp(0.05, 500.0);
    return math.sqrt(a * a + b * b);
  }

  static bool scanResultIsHub(ScanResult r) {
    final adv = r.device.advName.isNotEmpty ? r.device.advName : r.device.platformName;
    final plat = r.device.platformName;
    if (adv == hubBleGapName || plat == hubBleGapName) return true;
    if (adv.contains('TRACKER_HUB')) return true;
    for (final u in r.advertisementData.serviceUuids) {
      if (uuidEquals(u, hubServiceUuidStr)) return true;
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
        if (uuidEquals(c.uuid, hubRxUuidStr)) rx = c;
        if (uuidEquals(c.uuid, hubTxUuidStr)) tx = c;
      }
    }
    if (rx == null || tx == null) return null;
    return (rx: rx, tx: tx);
  }

  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isBluetoothOn() async {
    try {
      final state = await FlutterBluePlus.adapterState.first;
      return state == BluetoothAdapterState.on;
    } catch (_) {
      return false;
    }
  }

  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      print('[BleService] turnOn error: $e');
    }
  }

  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
  }

  // --- Hub discovery ---------------------------------------------------------

  Future<List<DiscoveredHub>> scanForHubs({
    Duration scanDuration = const Duration(seconds: 6),
  }) async {
    try {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
      await Future<void>.delayed(const Duration(milliseconds: 150));

      if (!await isBluetoothAvailable() || !await isBluetoothOn()) return [];

      await FlutterBluePlus.startScan(
        timeout: scanDuration,
        continuousUpdates: true,
      );
      await Future<void>.delayed(scanDuration + const Duration(milliseconds: 150));
      await FlutterBluePlus.stopScan();

      final byId = <String, ScanResult>{};
      for (final r in FlutterBluePlus.lastScanResults) {
        if (!scanResultIsHub(r)) continue;
        final id = r.device.remoteId.toString();
        if (!byId.containsKey(id) || r.rssi > byId[id]!.rssi) {
          byId[id] = r;
        }
      }

      return byId.values.map((r) {
        final name = r.device.advName.isNotEmpty ? r.device.advName : r.device.platformName;
        return DiscoveredHub(
          remoteId: r.device.remoteId.toString(),
          displayName: name.isNotEmpty ? name : hubBleGapName,
          rssi: r.rssi,
        );
      }).toList()
        ..sort((a, b) => b.rssi.compareTo(a.rssi));
    } catch (e) {
      print('[BleService] scanForHubs error: $e');
      return [];
    }
  }

  // --- Public entry points ---------------------------------------------------

  /// Background dashboard monitor. Holds a persistent connection to whichever
  /// hub from [hubBleIds] is currently reachable; rotates only on disconnect.
  Future<void> startContinuousScanning({
    required void Function(List<PendingTracker>) onTrackerUpdate,
    required List<String> Function() hubBleIds,
    void Function(String hubBleId)? onHubConnecting,
    void Function(String hubBleId)? onHubConnected,
    void Function(String hubBleId)? onHubDisconnected,
  }) async {
    if (_backgroundActive) return;

    // Make sure no dedicated session is squatting on the BLE link first.
    await stopDedicatedHubStream();

    if (!await isBluetoothAvailable() || !await isBluetoothOn()) return;

    _backgroundActive = true;
    _backgroundCallback = onTrackerUpdate;
    _backgroundHubIds = hubBleIds;
    _onHubConnecting = onHubConnecting;
    _onHubConnected = onHubConnected;
    _onHubDisconnected = onHubDisconnected;

    print('[BleService] Background hub monitor started');
    _backgroundFuture = _runBackgroundLoop();
  }

  Future<void> stopContinuousScanning() async {
    if (!_backgroundActive) return;
    _backgroundActive = false;

    await _tearDownActiveSession();

    if (_backgroundFuture != null) {
      try {
        await _backgroundFuture!.timeout(const Duration(seconds: 12));
      } catch (e) {
        print('[BleService] stopContinuousScanning: $e');
      }
    }
    _backgroundFuture = null;
    _backgroundCallback = null;
    _backgroundHubIds = null;
    _onHubConnecting = null;
    _onHubConnected = null;
    _onHubDisconnected = null;
    _detected.clear();
  }

  /// Live stream for the "add trackers" screen. Mutually exclusive with
  /// [startContinuousScanning]; we tear the background loop down first so the
  /// Android stack doesn't have to juggle two GATT clients.
  Future<void> startDedicatedHubStream(
    String hubBleId,
    void Function(List<PendingTracker>) onUpdate,
  ) async {
    await stopDedicatedHubStream();
    _dedicatedActive = true;
    _dedicatedHubId = hubBleId;
    _dedicatedCallback = onUpdate;
    _detected.clear();
    print('[BleService] Dedicated hub stream started for $hubBleId');
    _dedicatedFuture = _runDedicatedLoop();
  }

  Future<void> stopDedicatedHubStream() async {
    if (!_dedicatedActive) return;
    _dedicatedActive = false;

    await _tearDownActiveSession();

    if (_dedicatedFuture != null) {
      try {
        await _dedicatedFuture!.timeout(const Duration(seconds: 12));
      } catch (e) {
        print('[BleService] stopDedicatedHubStream: $e');
      }
    }
    _dedicatedFuture = null;
    _dedicatedHubId = null;
    _dedicatedCallback = null;
    _detected.clear();
  }

  /// One-shot helper retained for callers that want to grab a quick tracker
  /// list without keeping the connection. Internally it uses the dedicated
  /// stream and waits for a single emit.
  Future<List<PendingTracker>> scanTrackersOnHub({
    required String hubBleId,
    Duration listenDuration = const Duration(seconds: 5),
  }) async {
    final completer = Completer<List<PendingTracker>>();
    var snapshot = <PendingTracker>[];

    await startDedicatedHubStream(hubBleId, (list) {
      snapshot = list;
    });

    await Future<void>.delayed(listenDuration);
    if (!completer.isCompleted) completer.complete(snapshot);

    await stopDedicatedHubStream();
    return completer.future;
  }

  // --- Inner loops -----------------------------------------------------------

  Future<void> _runBackgroundLoop() async {
    var rotateIndex = 0;
    while (_backgroundActive) {
      final ids = _backgroundHubIds?.call() ?? const <String>[];
      if (ids.isEmpty) {
        await Future<void>.delayed(const Duration(seconds: 2));
        continue;
      }

      // Stable, deterministic rotation: walk the list in order. We only ever
      // advance after a session ends (i.e. the hub disconnected), so a single
      // healthy hub will keep its connection forever.
      if (rotateIndex >= ids.length) rotateIndex = 0;
      final hubId = ids[rotateIndex];
      rotateIndex++;

      _onHubConnecting?.call(hubId);
      final ok = await _runHubSession(
        hubBleId: hubId,
        primeScannerCache: false,
        onConnected: () => _onHubConnected?.call(hubId),
        emit: (list) => _backgroundCallback?.call(list),
        shouldContinue: () => _backgroundActive,
      );
      _onHubDisconnected?.call(hubId);

      if (!_backgroundActive) break;

      // If this hub failed outright, try the next one quickly so we don't get
      // stuck on a dead entry. Healthy disconnects (long sessions) get a full
      // backoff so we don't thrash the radio.
      await Future<void>.delayed(ok ? _reconnectBackoff : const Duration(milliseconds: 400));
    }

    await _tearDownActiveSession();
  }

  Future<void> _runDedicatedLoop() async {
    while (_dedicatedActive) {
      final hubId = _dedicatedHubId;
      if (hubId == null) break;

      // Reset the visible state so the UI shows "scanning" between sessions
      // instead of stale rows from the previous attempt.
      _detected.clear();
      _dedicatedCallback?.call(const <PendingTracker>[]);

      await _runHubSession(
        hubBleId: hubId,
        primeScannerCache: true,
        onConnected: null,
        emit: (list) => _dedicatedCallback?.call(list),
        shouldContinue: () => _dedicatedActive,
      );

      if (!_dedicatedActive) break;
      await Future<void>.delayed(_reconnectBackoff);
    }

    await _tearDownActiveSession();
  }

  /// Runs ONE persistent session against [hubBleId]. Returns once the link
  /// drops (clean or otherwise). The bool return is `true` if we managed to
  /// fully attach to the hub at least once during this call; it's used by the
  /// caller to decide between "long backoff" (healthy hub that just dropped)
  /// and "short backoff" (hub couldn't connect at all).
  Future<bool> _runHubSession({
    required String hubBleId,
    required bool primeScannerCache,
    required void Function()? onConnected,
    required void Function(List<PendingTracker>) emit,
    required bool Function() shouldContinue,
  }) async {
    BluetoothDevice? hub;
    var attached = false;
    try {
      if (!shouldContinue()) return false;
      await _primeHubScannerCache(longScan: primeScannerCache, target: hubBleId);
      if (!shouldContinue()) return false;

      hub = await _resolveHubDevice(hubBleId);

      await hub.connect(
        timeout: Duration(seconds: primeScannerCache ? 15 : 8),
        mtu: 512,
      );
      if (!shouldContinue()) {
        try {
          await hub.disconnect();
        } catch (_) {}
        return false;
      }

      // HIGH connection priority is critical — without it, Android's default
      // ~30-50ms interval cannot drain the hub's burst of ~40 notifications
      // every 3s and the link gets terminated mid-burst.
      await _requestHighPriority(hub);

      final services = await hub.discoverServices();
      final pair = _findUartCharacteristics(services);
      if (pair == null) {
        print('[BleService] Hub $hubBleId missing UART service');
        try {
          await hub.disconnect();
        } catch (_) {}
        return false;
      }

      _connectedHub = hub;
      _connectedHubId = hubBleId;
      _hubRx = pair.rx;
      _hubTx = pair.tx;
      _lineBuffer = '';

      await pair.tx.setNotifyValue(true);
      attached = true;
      onConnected?.call();
      print('[BleService] ✓ Hub session active: $hubBleId');

      _txSubscription = pair.tx.onValueReceived.listen((value) {
        _ingestPayload(value, hubBleId);
      });
      hub.cancelWhenDisconnected(_txSubscription!);

      // Periodic emit timer mirrors the Python GUI's `_emit_snapshot()` loop.
      // We aggregate the per-notification updates and push a snapshot at a
      // fixed cadence so the UI doesn't get hammered when the hub bursts.
      _emitTimer?.cancel();
      _emitTimer = Timer.periodic(_emitInterval, (_) {
        if (!shouldContinue()) return;
        final snapshot = _buildSnapshot();
        emit(snapshot);
      });

      // Wait until the hub drops us. flutter_blue_plus reports the initial
      // disconnected state once before the connect completes, so we filter on
      // the *current* connection state rather than firing on every event.
      final completer = Completer<void>();
      _connSubscription = hub.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          if (!completer.isCompleted) completer.complete();
        }
      });

      // Belt and braces: also exit if the caller stops the loop while we're
      // mid-session.
      Future<void> watchAbort() async {
        while (!completer.isCompleted && shouldContinue()) {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
        if (!completer.isCompleted) completer.complete();
      }

      unawaited(watchAbort());
      await completer.future;
      print('[BleService] Hub session ended: $hubBleId');
    } catch (e) {
      print('[BleService] Hub session error ($hubBleId): $e');
    } finally {
      _emitTimer?.cancel();
      _emitTimer = null;
      try {
        await _txSubscription?.cancel();
      } catch (_) {}
      _txSubscription = null;
      try {
        await _connSubscription?.cancel();
      } catch (_) {}
      _connSubscription = null;
      try {
        if (hub != null && hub.isConnected) {
          await hub.disconnect();
        }
      } catch (_) {}
      _connectedHub = null;
      _connectedHubId = null;
      _hubRx = null;
      _hubTx = null;
      _lineBuffer = '';
      // Push one last empty-or-stale snapshot so the UI doesn't keep
      // displaying stuck "online" trackers after the hub drops.
      try {
        emit(_buildSnapshot());
      } catch (_) {}
    }
    return attached;
  }

  Future<void> _requestHighPriority(BluetoothDevice hub) async {
    if (kIsWeb) return;
    try {
      if (!Platform.isAndroid) return;
    } catch (_) {
      return;
    }
    try {
      await hub.requestConnectionPriority(
        connectionPriorityRequest: ConnectionPriority.high,
      );
    } catch (e) {
      // Non-fatal: not all Android stacks honor this.
      print('[BleService] requestConnectionPriority failed: $e');
    }
  }

  Future<BluetoothDevice> _resolveHubDevice(String hubBleId) async {
    final want = hubBleId.trim();
    // Prefer a recently-scanned device — its OS BLE cache is warm.
    for (final r in FlutterBluePlus.lastScanResults) {
      if (!scanResultIsHub(r)) continue;
      if (r.device.remoteId.toString() == want) return r.device;
    }
    try {
      final bonded = await FlutterBluePlus.systemDevices([hubServiceGuid]);
      for (final d in bonded) {
        if (d.remoteId.toString() == want) return d;
      }
    } catch (_) {}
    return BluetoothDevice.fromId(want);
  }

  Future<void> _primeHubScannerCache({
    required bool longScan,
    required String target,
  }) async {
    final want = target.trim();
    final alreadyCached = FlutterBluePlus.lastScanResults.any(
      (r) => scanResultIsHub(r) && r.device.remoteId.toString() == want,
    );
    if (alreadyCached && !longScan) return;

    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {}
    try {
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: longScan ? 4 : 3),
        continuousUpdates: true,
        withServices: [hubServiceGuid],
      );
      final maxWaitMs = longScan ? 3200 : 1200;
      for (var elapsed = 0; elapsed < maxWaitMs; elapsed += 100) {
        final hit = FlutterBluePlus.lastScanResults.any(
          (r) => scanResultIsHub(r) && r.device.remoteId.toString() == want,
        );
        if (hit) break;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    } finally {
      try {
        await FlutterBluePlus.stopScan();
      } catch (_) {}
    }
  }

  // --- Notification ingest + snapshot building ------------------------------

  void _ingestPayload(List<int> value, String hubBleId) {
    _lineBuffer += utf8.decode(value, allowMalformed: true);
    int nl;
    while ((nl = _lineBuffer.indexOf('\n')) >= 0) {
      final line = _lineBuffer.substring(0, nl);
      _lineBuffer = _lineBuffer.substring(nl + 1);
      final parsed = parseHubTrackerLine(line);
      if (parsed != null) {
        _absorbTrackerLine(parsed, hubBleId);
      }
    }
  }

  void _absorbTrackerLine(Map<String, String> parsed, String hubBleId) {
    final serial = parsed['serial']!;
    final rssi = int.tryParse(parsed['rssi'] ?? '') ?? -100;
    final ip = parsed['ip'] ?? '';

    // Recompute distance with our calibration so what the UI shows tracks the
    // RSSI we display rather than whatever fixed TX power the firmware used.
    final distance = calculateDistanceWithConfig(rssi);

    final entry = _detected.putIfAbsent(
      serial,
      () => _DetectedTracker(
        serialNumber: serial,
        hubBleId: hubBleId,
        initialRssi: rssi,
        initialDistance: distance,
      ),
    );
    entry.updateFromHubLine(rssi: rssi, distance: distance, ip: ip);
  }

  /// Build a snapshot of every tracker still considered live. Mirrors the
  /// Python GUI's `_emit_snapshot()` — drops anything stale beyond
  /// [_trackerStale] but keeps the underlying entry around so a brief gap
  /// doesn't blow away its Kalman state.
  List<PendingTracker> _buildSnapshot() {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final out = <PendingTracker>[];
    final stale = _trackerStale.inMilliseconds;
    for (final entry in _detected.values) {
      if (nowMs - entry.lastSeenMs > stale) continue;
      out.add(entry.toPending());
    }
    return out;
  }

  Future<void> _tearDownActiveSession() async {
    _emitTimer?.cancel();
    _emitTimer = null;
    try {
      await _txSubscription?.cancel();
    } catch (_) {}
    _txSubscription = null;
    try {
      await _connSubscription?.cancel();
    } catch (_) {}
    _connSubscription = null;
    if (_connectedHub != null) {
      try {
        if (_connectedHub!.isConnected) {
          await _connectedHub!.disconnect();
        }
      } catch (_) {}
    }
    _connectedHub = null;
    _connectedHubId = null;
    _hubRx = null;
    _hubTx = null;
    _lineBuffer = '';
  }

  // --- Ping -----------------------------------------------------------------

  Future<bool> pingTrackerOnHub({
    required String hubBleAddress,
    required String serialNumber,
  }) async {
    final prev = _pingSerialTail;
    final gate = Completer<void>();
    _pingSerialTail = gate.future;
    await prev;
    try {
      await _waitSidetripGap(hubBleAddress);
      return await _pingImpl(hubBleAddress: hubBleAddress, serialNumber: serialNumber);
    } finally {
      gate.complete();
    }
  }

  Future<bool> _pingImpl({
    required String hubBleAddress,
    required String serialNumber,
  }) async {
    try {
      // Reuse the live monitoring connection if we're already attached to
      // this hub — no need to drop and reconnect just for a ping.
      if (_connectedHub != null &&
          _connectedHubId != null &&
          _connectedHubId!.trim().toUpperCase() == hubBleAddress.trim().toUpperCase() &&
          _hubRx != null &&
          _hubTx != null &&
          _connectedHub!.isConnected) {
        return _pingWithRetry(_hubRx!, _hubTx!, serialNumber);
      }

      // Otherwise do a one-shot connect.
      await _primeHubScannerCache(longScan: false, target: hubBleAddress);
      final hub = await _resolveHubDevice(hubBleAddress);
      await hub.connect(timeout: const Duration(seconds: 8), mtu: 512);
      await _requestHighPriority(hub);
      final services = await hub.discoverServices();
      final pair = _findUartCharacteristics(services);
      if (pair == null) {
        try {
          await hub.disconnect();
        } catch (_) {}
        _markSidetrip(hubBleAddress);
        return false;
      }
      final ok = await _pingWithRetry(pair.rx, pair.tx, serialNumber);
      try {
        await hub.disconnect();
      } catch (_) {}
      _markSidetrip(hubBleAddress);
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
    final first = await _pingOnce(rx, tx, serialNumber);
    if (first) return true;
    await Future<void>.delayed(const Duration(milliseconds: 350));
    return _pingOnce(rx, tx, serialNumber);
  }

  Future<bool> _pingOnce(
    BluetoothCharacteristic rx,
    BluetoothCharacteristic tx,
    String serialNumber,
  ) async {
    final completer = Completer<bool>();
    var buffer = '';
    StreamSubscription<List<int>>? sub;
    sub = tx.onValueReceived.listen((value) {
      buffer += utf8.decode(value, allowMalformed: true);
      while (true) {
        final nl = buffer.indexOf('\n');
        if (nl < 0) break;
        final line = buffer.substring(0, nl).trim();
        buffer = buffer.substring(nl + 1);
        if (line.startsWith('PING_RESULT:$serialNumber:')) {
          final rest = line.substring('PING_RESULT:$serialNumber:'.length);
          if (!completer.isCompleted) completer.complete(rest == 'SUCCESS');
        }
      }
    });

    try {
      await tx.setNotifyValue(true);
      await Future<void>.delayed(const Duration(milliseconds: 120));
      await rx.write(utf8.encode('PING:$serialNumber\n'), withoutResponse: false);
      return await completer.future
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
    } finally {
      try {
        await sub.cancel();
      } catch (_) {}
    }
  }

  Future<void> _waitSidetripGap(String hubBleAddress) async {
    final last = _lastSidetripDisconnectUtc[hubBleAddress.trim().toUpperCase()];
    if (last == null) return;
    final elapsed = DateTime.now().difference(last);
    if (elapsed < _hubPingBleGap) {
      await Future<void>.delayed(_hubPingBleGap - elapsed);
    }
  }

  void _markSidetrip(String hubBleAddress) {
    _lastSidetripDisconnectUtc[hubBleAddress.trim().toUpperCase()] = DateTime.now();
  }
}
