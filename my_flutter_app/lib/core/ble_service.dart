import 'dart:math' as math;
import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:my_flutter_app/core/kalman_filter.dart';
import 'package:my_flutter_app/models/mock_data.dart';

// ============================================================================
// Configuration Constants
// ============================================================================

/// TX Power at 1 meter in dBm (device transmit power)
const double TX_POWER_DBM = -65;

/// Path loss exponent (free space = 2.0, indoor = 2.5-3.5)
const double FREE_SPACE_PATH_LOSS = 2.0;

/// RSSI threshold for filtering weak signals
const int RSSI_THRESHOLD = -100;

/// Scan duration in seconds
const double SCAN_DURATION = 5.0;

/// Display/UI update interval in seconds
const double DISPLAY_INTERVAL = 1.0;

/// Minimum and maximum distance bounds in meters
const double MIN_DISTANCE_M = 0.1;
const double MAX_DISTANCE_M = 9999;

/// Kalman Filter Parameters
const double KALMAN_PROCESS_NOISE = 0.01;
const double KALMAN_MEASUREMENT_NOISE = 2.5;
const double KALMAN_INITIAL_UNCERTAINTY = 10.0;

// ============================================================================
// Tracker Data Structure
// ============================================================================

/// Stores detected tracker information with Kalman filtering
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

  /// Update tracker with new RSSI measurement
  void updateRssi(int newRssi) {
    rssi = newRssi;
    rssiFiltered = kalmanFilter.update(newRssi.toDouble());
    lastUpdated = DateTime.now();

    // Keep history for graphing (max 100 points)
    if (rssiHistory.length > 100) {
      rssiHistory.removeAt(0);
    }
    rssiHistory.add(rssiFiltered);
  }

  /// Update distance based on filtered RSSI
  void updateDistance(double newDistance) {
    distance = newDistance;
  }
}

/// BLE Service - Manages Bluetooth Low Energy device scanning
/// Note: flutter_blue_plus package not yet installed in pubspec.yaml
/// Using mock implementation for MVP development
class BleService {
  static final BleService _instance = BleService._internal();

  // Configuration parameters
  double _txPower = TX_POWER_DBM;
  double _pathLoss = FREE_SPACE_PATH_LOSS;
  int _rssiThreshold = RSSI_THRESHOLD;

  // Active tracker data during scanning
  final Map<String, TrackerData> _activeTrackers = {};
  
  // Continuous scanning state
  bool _isContinuousScanRunning = false;
  Function(List<PendingTracker>)? _continuousScanCallback;
  Timer? _continuousScanTimer;
  StreamSubscription? _scanSubscription;

  factory BleService() {
    return _instance;
  }

  BleService._internal();

  // ============================================================================
  // Configuration Methods
  // ============================================================================

  /// Get current TX power setting
  double get txPower => _txPower;

  /// Get current path loss exponent setting
  double get pathLoss => _pathLoss;

  /// Get current RSSI threshold setting
  int get rssiThreshold => _rssiThreshold;

  /// Update scanner configuration
  void setConfig({
    double? txPower,
    double? pathLoss,
    int? rssiThreshold,
  }) {
    if (txPower != null) _txPower = txPower;
    if (pathLoss != null) _pathLoss = pathLoss;
    if (rssiThreshold != null) _rssiThreshold = rssiThreshold;
  }

  /// Reset configuration to defaults
  void resetConfig() {
    _txPower = TX_POWER_DBM;
    _pathLoss = FREE_SPACE_PATH_LOSS;
    _rssiThreshold = RSSI_THRESHOLD;
  }

  // ============================================================================
  // Device Parsing & Distance Calculation
  // ============================================================================

  /// Parse device name to extract ESP32 tracker info
  /// Expected format: esp32_indiv_[SERIAL_NUMBER]
  /// Example: esp32_indiv_03F2 → ("esp32_indiv", "03F2")
  static ({String deviceId, String serialNumber})? parseDeviceName(String? name) {
    if (name == null || !name.startsWith("esp32_indiv_")) {
      return null;
    }

    final deviceId = "esp32_indiv";
    final serialNumber = name.substring(12); // Everything after "esp32_indiv_"

    if (serialNumber.isEmpty) {
      return null;
    }

    return (deviceId: deviceId, serialNumber: serialNumber);
  }

  /// Calculate distance from RSSI using Free Space Path Loss model
  /// Formula: distance (m) = 10^((TX_POWER - RSSI) / (10 * PATH_LOSS))
  static double calculateDistance(int rssi, {
    double txPower = TX_POWER_DBM,
    double pathLoss = FREE_SPACE_PATH_LOSS,
    double minDistance = MIN_DISTANCE_M,
    double maxDistance = MAX_DISTANCE_M,
  }) {
    if (rssi == 0) return 0.0;

    final distance = math.pow(10.0, (txPower - rssi) / (10 * pathLoss)).toDouble();
    return distance.clamp(minDistance, maxDistance);
  }

  /// Calculate distance using current instance configuration
  double calculateDistanceWithConfig(int rssi) {
    return calculateDistance(
      rssi,
      txPower: _txPower,
      pathLoss: _pathLoss,
    );
  }

  /// Scan for ESP32 tracker devices via BLE
  /// Uses flutter_blue_plus to perform actual BLE scanning
  /// Applies Kalman filtering and RSSI threshold filtering
  /// Returns a list of discovered PendingTracker objects
  Future<List<PendingTracker>> scanForTrackers({
    Duration scanDuration = const Duration(seconds: 5),
  }) async {
    try {
      // Clear previous tracking data
      _activeTrackers.clear();

      // Check Bluetooth availability
      if (!await isBluetoothAvailable()) {
        print('[BleService] Bluetooth not available');
        return [];
      }

      // Check Bluetooth is enabled
      if (!await isBluetoothOn()) {
        print('[BleService] Bluetooth is off');
        return [];
      }

      print('[BleService] Starting BLE scan for ${scanDuration.inSeconds}s...');
      
      final result = <PendingTracker>[];

      // Start listening to scan results BEFORE starting the scan
      final scanSubscription = FlutterBluePlus.onScanResults.listen(
        (scanResults) {
          print('[BleService] Got ${scanResults.length} scan results');

          for (final scanResult in scanResults) {
            final device = scanResult.device;

            // Get device name (prefer advName if available)
            final name = device.advName.isNotEmpty ? device.advName : device.name;
            final rssi = scanResult.rssi;
            final address = device.remoteId.toString();

            // Debug: Log all found devices
            if (name.isNotEmpty) {
              print('[BleService] Device: "$name", RSSI: $rssi, Address: $address');
            }

            // Parse device name for ESP32 trackers
            final parsed = parseDeviceName(name);
            if (parsed == null) {
              continue;
            }

            final (deviceId: deviceId, serialNumber: serialNumber) = parsed;

            print('[BleService] ✓ Matched ESP32: $serialNumber, RSSI: $rssi dBm');

            // Filter by RSSI threshold
            if (rssi < _rssiThreshold) {
              print('[BleService] RSSI $rssi below threshold $_rssiThreshold, skipping');
              continue;
            }

            // Store or update tracker data with Kalman filtering
            final trackerData = _activeTrackers.putIfAbsent(
              serialNumber,
              () => TrackerData(
                deviceId: deviceId,
                serialNumber: serialNumber,
                bleAddress: address,
                initialRssi: rssi,
                initialDistance: calculateDistanceWithConfig(rssi),
              ),
            );

            // Update with new measurement (applies Kalman filtering)
            trackerData.updateRssi(rssi);
            trackerData.updateDistance(
              calculateDistanceWithConfig(rssi),
            );

            // Calculate signal strength percentage from filtered RSSI
            final signalStrength =
                (100 + trackerData.rssiFiltered).clamp(0.0, 100.0).toInt();
            final distance = trackerData.distance;

            // Only add unique devices (latest data)
            result.removeWhere((p) => p.serialNumber == serialNumber);
            result.add(
              PendingTracker(
                deviceId: deviceId,
                signalStrength: signalStrength,
                discovered: DateTime.now(),
                serialNumber: serialNumber,
                bleAddress: address,
                rssi: rssi,
                rssiFiltered: trackerData.rssiFiltered,
                distance: distance,
                rssiHistory: List.from(trackerData.rssiHistory),
              ),
            );

            print('[BleService] Added/updated: $serialNumber (Signal: $signalStrength%, Distance: ${distance.toStringAsFixed(2)}m)');
          }
        },
        onError: (e) {
          print('[BleService] Scan stream error: $e');
        },
      );

      // Start scanning (uses timeout to control duration)
      await FlutterBluePlus.startScan(
        timeout: scanDuration,
        continuousUpdates: true,
      );

      // Wait for the scan to complete (startScan with timeout handles this)
      // but we keep the listener alive during scanning
      await Future.delayed(scanDuration + const Duration(milliseconds: 100));

      // Cancel subscription
      await scanSubscription.cancel();

      print('[BleService] Scan complete. Found ${_activeTrackers.length} ESP32 trackers.');
      return result;
    } catch (e) {
      print('[BleService] Error scanning: $e');
      return [];
    }
  }

  /// Stop BLE scanning
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
      print('[BleService] Scan stopped');
    } catch (e) {
      print('[BleService] Error stopping scan: $e');
    }
  }

  /// Start continuous background scanning with live updates (like the Python app)
  /// Scans in 1-second cycles continuously, mimicking Python's behavior
  /// Each cycle: start scan → get live callbacks → stop → restart
  Future<void> startContinuousScanning({
    required Function(List<PendingTracker>) onTrackerUpdate,
  }) async {
    if (_isContinuousScanRunning) {
      print('[BleService] Continuous scanning already running');
      return;
    }

    try {
      // Check Bluetooth availability
      if (!await isBluetoothAvailable()) {
        print('[BleService] Bluetooth not available');
        return;
      }

      if (!await isBluetoothOn()) {
        print('[BleService] Bluetooth is off');
        return;
      }

      _isContinuousScanRunning = true;
      _continuousScanCallback = onTrackerUpdate;

      print('[BleService] ✓ Starting continuous BLE scanning (1s cycles)...');
      
      // Set up listener for scan results BEFORE starting scan
      _scanSubscription = FlutterBluePlus.onScanResults.listen(
        (scanResults) {
          if (!_isContinuousScanRunning) return;

          final result = <PendingTracker>[];

          for (final scanResult in scanResults) {
            final device = scanResult.device;
            final name = device.advName.isNotEmpty ? device.advName : device.name;
            final rssi = scanResult.rssi;
            final address = device.remoteId.toString();

            // Parse device name for ESP32 trackers
            final parsed = parseDeviceName(name);
            if (parsed == null) continue;

            final (deviceId: deviceId, serialNumber: serialNumber) = parsed;

            print('[BleService] Detected: $serialNumber, RSSI: $rssi');

            // Filter by RSSI threshold
            if (rssi < _rssiThreshold) {
              print('[BleService] RSSI $rssi below threshold, skipping');
              continue;
            }

            // Update or create tracker data with Kalman filtering
            final trackerData = _activeTrackers.putIfAbsent(
              serialNumber,
              () => TrackerData(
                deviceId: deviceId,
                serialNumber: serialNumber,
                bleAddress: address,
                initialRssi: rssi,
                initialDistance: calculateDistanceWithConfig(rssi),
              ),
            );

            // Update with new measurement
            trackerData.updateRssi(rssi);
            trackerData.updateDistance(calculateDistanceWithConfig(rssi));

            final signalStrength = (100 + trackerData.rssiFiltered).clamp(0.0, 100.0).toInt();

            print('[BleService] Updated $serialNumber: Filtered RSSI=${trackerData.rssiFiltered.toStringAsFixed(1)}, Distance=${trackerData.distance.toStringAsFixed(2)}m');

            result.add(
              PendingTracker(
                deviceId: deviceId,
                signalStrength: signalStrength,
                discovered: DateTime.now(),
                serialNumber: serialNumber,
                bleAddress: address,
                rssi: rssi,
                rssiFiltered: trackerData.rssiFiltered,
                distance: trackerData.distance,
                rssiHistory: List.from(trackerData.rssiHistory),
              ),
            );
          }

          // Call callback with updated trackers
          if (result.isNotEmpty) {
            print('[BleService] Calling update callback with ${result.length} trackers');
            _continuousScanCallback?.call(result);
          }
        },
        onError: (e) {
          print('[BleService] Scan stream error: $e');
        },
      );

      // Start initial scan
      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 1));
      
      // Restart scan every 1.1 seconds (scan duration + small overlap for processing)
      // This mimics Python's continuous scanning pattern
      _continuousScanTimer = Timer.periodic(const Duration(milliseconds: 1100), (timer) async {
        if (!_isContinuousScanRunning) {
          timer.cancel();
          return;
        }

        try {
          await FlutterBluePlus.stopScan();
          await Future.delayed(const Duration(milliseconds: 50)); // Brief pause before restart
          await FlutterBluePlus.startScan(timeout: const Duration(seconds: 1));
          print('[BleService] Restarted continuous scan cycle');
        } catch (e) {
          print('[BleService] Error restarting scan: $e');
        }
      });

      print('[BleService] Continuous scanning initialized with 1.1s cycle');
    } catch (e) {
      print('[BleService] Error starting continuous scan: $e');
      _isContinuousScanRunning = false;
      _continuousScanCallback = null;
    }
  }

  /// Stop continuous scanning
  Future<void> stopContinuousScanning() async {
    if (!_isContinuousScanRunning) return;

    try {
      _continuousScanTimer?.cancel();
      _continuousScanTimer = null;
      
      await _scanSubscription?.cancel();
      _scanSubscription = null;
      
      await FlutterBluePlus.stopScan();
      
      _isContinuousScanRunning = false;
      _continuousScanCallback = null;
      _activeTrackers.clear();
      
      print('[BleService] ✓ Continuous scanning stopped');
    } catch (e) {
      print('[BleService] Error stopping continuous scan: $e');
      _isContinuousScanRunning = false;
    }
  }

  /// Check if continuous scanning is running
  bool get isContinuousScanRunning => _isContinuousScanRunning;

  /// Check if Bluetooth is available on the device
  Future<bool> isBluetoothAvailable() async {
    try {
      final isAvailable = await FlutterBluePlus.isAvailable;
      return isAvailable;
    } catch (e) {
      print('[BleService] Error checking Bluetooth availability: $e');
      return false;
    }
  }

  /// Check if Bluetooth is currently enabled
  Future<bool> isBluetoothOn() async {
    try {
      final isOn = await FlutterBluePlus.isOn;
      return isOn;
    } catch (e) {
      print('[BleService] Error checking Bluetooth state: $e');
      return false;
    }
  }

  /// Request to turn on Bluetooth (may prompt user on Android)
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
      print('[BleService] Bluetooth enabled');
    } catch (e) {
      print('[BleService] Error turning on Bluetooth: $e');
    }
  }

  /// Ping a registered device via BLE GATT
  /// Sends a ping command to the device
  /// Note: Device disables GATT for ~3 seconds after ping, caller should wait 4.2s before retry
  Future<bool> pingDevice(String deviceAddress) async {
    try {
      print('[BleService] Starting ping for device: $deviceAddress');

      // Create BluetoothDevice from address
      final targetDevice = BluetoothDevice.fromId(deviceAddress);

      // Connect with 3 second timeout
      print('[BleService] Connecting to device for ping...');
      await targetDevice.connect(timeout: const Duration(seconds: 3));
      print('[BleService] Connected, discovering services...');

      // Discover services and characteristics
      final services = await targetDevice.discoverServices();

      // Find the ping characteristic (UUID from ESP32 firmware)
      const pingCharUuid = '12345678-1234-5678-1234-56789abcdef1';
      BluetoothCharacteristic? pingChar;

      for (final service in services) {
        for (final char in service.characteristics) {
          // Compare UUID strings (flutter_blue_plus uses lowercase)
          if (char.uuid.toString().toLowerCase() == pingCharUuid.toLowerCase()) {
            pingChar = char;
            print('[BleService] Found ping characteristic');
            break;
          }
        }
        if (pingChar != null) break;
      }

      if (pingChar == null) {
        print('[BleService] Ping characteristic not found on device');
        await targetDevice.disconnect();
        return false;
      }

      // Write ping command (0x01 byte) to trigger device reset
      print('[BleService] Writing ping command (0x01)...');
      await pingChar.write([0x01], withoutResponse: false);
      print('[BleService] Ping command sent successfully');

      // Disconnect immediately after ping
      print('[BleService] Disconnecting after ping...');
      await targetDevice.disconnect();
      print('[BleService] Ping completed successfully');

      return true;
    } catch (e) {
      print('[BleService] Ping error: $e');

      // Attempt graceful disconnect on error
      try {
        final targetDevice = BluetoothDevice.fromId(deviceAddress);
        await targetDevice.disconnect();
      } catch (_) {
        // Ignore disconnect errors
      }

      return false;
    }
  }
}
