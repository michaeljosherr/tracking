import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/mock_data.dart';
import 'package:uuid/uuid.dart';

class TrackerProvider with ChangeNotifier {
  final List<Tracker> _trackers = List.from(mockTrackers);
  final List<Alert> _alerts = List.from(mockAlerts);
  final List<PendingTracker> _pendingTrackers = List.from(mockPendingTrackers);
  final _uuid = const Uuid();

  List<Tracker> get trackers => _trackers;
  List<Alert> get alerts => _alerts;
  List<PendingTracker> get pendingTrackers => _pendingTrackers;

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

  void registerDevice(PendingTracker pendingTracker, String name) {
    // Generate a unique ID
    final newId = _uuid.v4();
    final newTracker = Tracker(
      id: newId,
      deviceId: pendingTracker.deviceId,
      name: name,
      status: TrackerStatus.connected,
      signalStrength: pendingTracker.signalStrength,
      lastSeen: DateTime.now(),
      batteryLevel: 100, // Default for new registration
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
