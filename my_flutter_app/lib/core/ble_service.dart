import 'dart:math' as math;
// import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:my_flutter_app/models/mock_data.dart';

/// BLE Service - Manages Bluetooth Low Energy device scanning
/// Note: flutter_blue_plus package not yet installed in pubspec.yaml
/// Using mock implementation for MVP development
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

  /// Scan for ESP32 tracker devices (Mock Implementation)
  /// Returns a list of discovered PendingTracker objects
  /// Note: Uses mock data - real BLE scanning requires flutter_blue_plus package
  Future<List<PendingTracker>> scanForTrackers({
    Duration scanDuration = const Duration(seconds: 5),
  }) async {
    try {
      // Simulate scanning delay
      await Future.delayed(scanDuration);
      
      // Return mock pending trackers from mock data
      final mockPending = <PendingTracker>[
        PendingTracker(
          deviceId: "esp32_indiv_03F2",
          signalStrength: 85,
          discovered: DateTime.now(),
          serialNumber: "03F2",
          bleAddress: "A1:B2:C3:D4:E5:F6",
          rssi: -45,
        ),
        PendingTracker(
          deviceId: "esp32_indiv_0A4B",
          signalStrength: 72,
          discovered: DateTime.now().subtract(const Duration(seconds: 2)),
          serialNumber: "0A4B",
          bleAddress: "A1:B2:C3:D4:E5:F7",
          rssi: -58,
        ),
        PendingTracker(
          deviceId: "esp32_indiv_1C7E",
          signalStrength: 60,
          discovered: DateTime.now().subtract(const Duration(seconds: 4)),
          serialNumber: "1C7E",
          bleAddress: "A1:B2:C3:D4:E5:F8",
          rssi: -70,
        ),
      ];
      
      return mockPending;
    } catch (e) {
      print('[BleService] Error scanning: $e');
      return [];
    }
  }

  /// Stop scanning (Mock Implementation)
  Future<void> stopScan() async {
    // No-op for mock implementation
  }

  /// Check if Bluetooth is available (Mock Implementation)
  /// Always returns true for development
  Future<bool> isBluetoothAvailable() async {
    return true;
  }

  /// Check if Bluetooth is on (Mock Implementation)
  /// Always returns true for development
  Future<bool> isBluetoothOn() async {
    return true;
  }

  /// Turn on Bluetooth (Mock Implementation - No-op)
  Future<void> turnOnBluetooth() async {
    // No-op for mock implementation
  }
}
