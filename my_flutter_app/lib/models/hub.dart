/// Represents a connected hub instance
class Hub {
  final String bleId; // MAC address / BLE identifier
  final String displayName; // User-friendly name (Hub_1, Hub_2, etc.)
  final List<String> trackerIds; // IDs of trackers registered to this hub
  final DateTime connectedAt;

  Hub({
    required this.bleId,
    required this.displayName,
    required this.trackerIds,
    required this.connectedAt,
  });

  /// Get a user-friendly identifier if displayName is auto-generated
  String get label {
    // If it looks auto-generated (Hub_N), keep it; otherwise return custom name
    if (displayName.startsWith('Hub_') || displayName.startsWith('ESP32')) {
      return displayName;
    }
    return displayName;
  }

  /// Number of trackers associated with this hub
  int get trackerCount => trackerIds.length;

  Hub copyWith({
    String? bleId,
    String? displayName,
    List<String>? trackerIds,
    DateTime? connectedAt,
  }) {
    return Hub(
      bleId: bleId ?? this.bleId,
      displayName: displayName ?? this.displayName,
      trackerIds: trackerIds ?? this.trackerIds,
      connectedAt: connectedAt ?? this.connectedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bleId': bleId,
      'displayName': displayName,
      'trackerIds': trackerIds,
      'connectedAt': connectedAt.toIso8601String(),
    };
  }

  factory Hub.fromJson(Map<String, dynamic> json) {
    return Hub(
      bleId: json['bleId'] as String,
      displayName: json['displayName'] as String,
      trackerIds: List<String>.from(json['trackerIds'] as List? ?? []),
      connectedAt: DateTime.parse(json['connectedAt'] as String),
    );
  }
}
