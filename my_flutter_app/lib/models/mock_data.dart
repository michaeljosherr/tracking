enum TrackerStatus { connected, disconnected, outOfRange }

class Tracker {
  final String id;
  final String deviceId;
  final String name;
  final TrackerStatus status;
  final int signalStrength; // 0-100
  final DateTime lastSeen;
  final int? batteryLevel; // 0-100
  
  // BLE-specific fields
  final int? rssi; // Raw RSSI in dBm
  final double? rssiFiltered; // Kalman-filtered RSSI
  final double? distance; // Estimated distance in meters
  final String? serialNumber; // From device name parsing
  final String? bleAddress; // MAC address

  Tracker({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.status,
    required this.signalStrength,
    required this.lastSeen,
    this.batteryLevel,
    this.rssi,
    this.rssiFiltered,
    this.distance,
    this.serialNumber,
    this.bleAddress,
  });

  Tracker copyWith({
    String? id,
    String? deviceId,
    String? name,
    TrackerStatus? status,
    int? signalStrength,
    DateTime? lastSeen,
    int? batteryLevel,
    int? rssi,
    double? rssiFiltered,
    double? distance,
    String? serialNumber,
    String? bleAddress,
  }) {
    return Tracker(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      name: name ?? this.name,
      status: status ?? this.status,
      signalStrength: signalStrength ?? this.signalStrength,
      lastSeen: lastSeen ?? this.lastSeen,
      batteryLevel: batteryLevel ?? this.batteryLevel,
      rssi: rssi ?? this.rssi,
      rssiFiltered: rssiFiltered ?? this.rssiFiltered,
      distance: distance ?? this.distance,
      serialNumber: serialNumber ?? this.serialNumber,
      bleAddress: bleAddress ?? this.bleAddress,
    );
  }

  /// Convert Tracker to JSON for persistent storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'deviceId': deviceId,
      'name': name,
      'status': status.toString().split('.').last,
      'signalStrength': signalStrength,
      'lastSeen': lastSeen.toIso8601String(),
      'batteryLevel': batteryLevel,
      'rssi': rssi,
      'rssiFiltered': rssiFiltered,
      'distance': distance,
      'serialNumber': serialNumber,
      'bleAddress': bleAddress,
    };
  }

  /// Create Tracker from JSON
  factory Tracker.fromJson(Map<String, dynamic> json) {
    return Tracker(
      id: json['id'] as String,
      deviceId: json['deviceId'] as String,
      name: json['name'] as String,
      status: TrackerStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => TrackerStatus.disconnected,
      ),
      signalStrength: json['signalStrength'] as int? ?? 0,
      lastSeen: DateTime.parse(json['lastSeen'] as String),
      batteryLevel: json['batteryLevel'] as int?,
      rssi: json['rssi'] as int?,
      rssiFiltered: json['rssiFiltered'] as double?,
      distance: json['distance'] as double?,
      serialNumber: json['serialNumber'] as String?,
      bleAddress: json['bleAddress'] as String?,
    );
  }
}

class Alert {
  final String id;
  final String trackerId;
  final String trackerName;
  final String type; // "disconnected" | "out-of-range" | "reconnected"
  final String message;
  final DateTime timestamp;
  final bool acknowledged;

  Alert({
    required this.id,
    required this.trackerId,
    required this.trackerName,
    required this.type,
    required this.message,
    required this.timestamp,
    required this.acknowledged,
  });

  Alert copyWith({
    String? id,
    String? trackerId,
    String? trackerName,
    String? type,
    String? message,
    DateTime? timestamp,
    bool? acknowledged,
  }) {
    return Alert(
      id: id ?? this.id,
      trackerId: trackerId ?? this.trackerId,
      trackerName: trackerName ?? this.trackerName,
      type: type ?? this.type,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      acknowledged: acknowledged ?? this.acknowledged,
    );
  }
}

class PendingTracker {
  final String deviceId;
  final int signalStrength;
  final DateTime discovered;
  final String? serialNumber; // From device name parsing
  final String? bleAddress; // MAC address
  final int? rssi; // Raw RSSI in dBm
  final double? rssiFiltered; // Kalman-filtered RSSI
  final double? distance; // Estimated distance in meters
  final List<double>? rssiHistory; // Historical filtered RSSI values

  PendingTracker({
    required this.deviceId,
    required this.signalStrength,
    required this.discovered,
    this.serialNumber,
    this.bleAddress,
    this.rssi,
    this.rssiFiltered,
    this.distance,
    this.rssiHistory,
  });
}

final List<Tracker> mockTrackers = [
  Tracker(
    id: "1",
    deviceId: "A1B3",
    name: "John",
    status: TrackerStatus.connected,
    signalStrength: 85,
    lastSeen: DateTime.now().subtract(const Duration(seconds: 2)),
    batteryLevel: 78,
  ),
  Tracker(
    id: "2",
    deviceId: "F7D9",
    name: "Maria",
    status: TrackerStatus.connected,
    signalStrength: 92,
    lastSeen: DateTime.now().subtract(const Duration(seconds: 1)),
    batteryLevel: 95,
  ),
  Tracker(
    id: "3",
    deviceId: "C4E8",
    name: "Sarah",
    status: TrackerStatus.outOfRange,
    signalStrength: 15,
    lastSeen: DateTime.now().subtract(const Duration(seconds: 45)),
    batteryLevel: 62,
  ),
  Tracker(
    id: "4",
    deviceId: "B2F5",
    name: "Michael",
    status: TrackerStatus.connected,
    signalStrength: 68,
    lastSeen: DateTime.now().subtract(const Duration(seconds: 3)),
    batteryLevel: 84,
  ),
  Tracker(
    id: "5",
    deviceId: "D9A7",
    name: "Emma",
    status: TrackerStatus.disconnected,
    signalStrength: 0,
    lastSeen: DateTime.now().subtract(const Duration(seconds: 120)),
    batteryLevel: 23,
  ),
  Tracker(
    id: "6",
    deviceId: "E3C1",
    name: "Tracker_E3C1",
    status: TrackerStatus.connected,
    signalStrength: 75,
    lastSeen: DateTime.now().subtract(const Duration(seconds: 5)),
    batteryLevel: 91,
  ),
];

final List<Alert> mockAlerts = [
  Alert(
    id: "alert-1",
    trackerId: "5",
    trackerName: "Emma",
    type: "disconnected",
    message: "Tracker Emma has disconnected.",
    timestamp: DateTime.now().subtract(const Duration(seconds: 120)),
    acknowledged: false,
  ),
  Alert(
    id: "alert-2",
    trackerId: "3",
    trackerName: "Sarah",
    type: "out-of-range",
    message: "Tracker Sarah is out of range.",
    timestamp: DateTime.now().subtract(const Duration(seconds: 45)),
    acknowledged: false,
  ),
  Alert(
    id: "alert-3",
    trackerId: "2",
    trackerName: "Maria",
    type: "reconnected",
    message: "Tracker Maria has reconnected.",
    timestamp: DateTime.now().subtract(const Duration(seconds: 180)),
    acknowledged: true,
  ),
  Alert(
    id: "alert-4",
    trackerId: "4",
    trackerName: "Michael",
    type: "out-of-range",
    message: "Tracker Michael is out of range.",
    timestamp: DateTime.now().subtract(const Duration(seconds: 300)),
    acknowledged: true,
  ),
];

final List<PendingTracker> mockPendingTrackers = [
  PendingTracker(
    deviceId: "G8H2",
    signalStrength: 88,
    discovered: DateTime.now().subtract(const Duration(seconds: 5)),
  ),
  PendingTracker(
    deviceId: "K5L9",
    signalStrength: 72,
    discovered: DateTime.now().subtract(const Duration(seconds: 3)),
  ),
  PendingTracker(
    deviceId: "M3N7",
    signalStrength: 95,
    discovered: DateTime.now().subtract(const Duration(seconds: 8)),
  ),
];
