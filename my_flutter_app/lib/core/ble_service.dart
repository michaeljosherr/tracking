import 'dart:math' as math;
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:my_flutter_app/models/mock_data.dart';

class BleService {
  static final BleService _instance = BleService._internal();

  factory BleService() {
    return _instance;
  }

  BleService._internal();

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
    double txPower = -65,
    double pathLoss = 2.0,
    double minDistance = 0.1,
    double maxDistance = 9999,
  }) {
    if (rssi == 0) return 0.0;

    final distance = math.pow(10.0, (txPower - rssi) / (10 * pathLoss)).toDouble();
    return distance.clamp(minDistance, maxDistance);
  }

  /// Scan for ESP32 tracker devices
  /// Returns a list of discovered PendingTracker objects
  Future<List<PendingTracker>> scanForTrackers({
    Duration scanDuration = const Duration(seconds: 5),
  }) async {
    final trackers = <String, PendingTracker>{};

    try {
      // Start scanning
      await FlutterBluePlus.startScan(timeout: scanDuration);

      // Listen to scan results
      FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          final device = result.device;
          final name = device.name;
          final rssi = result.rssi;
          final address = device.remoteId.toString();

          // Check if it's an ESP32 tracker
          final parsed = parseDeviceName(name);
          if (parsed == null) continue;

          // Skip weak signals
          if (rssi < -100) continue;

          final deviceId = "${parsed.deviceId}_${parsed.serialNumber}";

          // Store latest scan result
          if (!trackers.containsKey(deviceId) ||
              trackers[deviceId]!.signalStrength < rssi) {
            trackers[deviceId] = PendingTracker(
              deviceId: deviceId,
              signalStrength: ((rssi + 100) * 2).clamp(0, 100).toInt(), // Convert RSSI to 0-100
              discovered: DateTime.now(),
              serialNumber: parsed.serialNumber,
              bleAddress: address,
              rssi: rssi,
            );
          }
        }
      });

      // Wait for scan to complete
      await Future.delayed(scanDuration);
      await FlutterBluePlus.stopScan();

      return trackers.values.toList();
    } catch (e) {
      print('[BleService] Error scanning: $e');
      return [];
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (e) {
      print('[BleService] Error stopping scan: $e');
    }
  }

  /// Check if Bluetooth is available
  Future<bool> isBluetoothAvailable() async {
    try {
      return await FlutterBluePlus.isSupported;
    } catch (e) {
      return false;
    }
  }

  /// Check if Bluetooth is on
  Future<bool> isBluetoothOn() async {
    try {
      return await FlutterBluePlus.isOn;
    } catch (e) {
      return false;
    }
  }

  /// Turn on Bluetooth (Android only)
  Future<void> turnOnBluetooth() async {
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      print('[BleService] Error turning on Bluetooth: $e');
    }
  }
}
