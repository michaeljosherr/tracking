import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// App-wide Bluetooth adapter watcher.
///
/// Subscribes to [FlutterBluePlus.adapterState] and exposes a simple
/// [BluetoothGateStatus] that the UI can use to block/unblock the app.
class BluetoothStatusProvider extends ChangeNotifier {
  BluetoothStatusProvider() {
    _init();
  }

  bool _isSupported = true;
  bool _hasCheckedSupport = false;
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  StreamSubscription<BluetoothAdapterState>? _sub;
  bool _disposed = false;

  /// Whether the current platform/device supports Bluetooth LE.
  bool get isSupported => _isSupported;

  /// Raw adapter state from flutter_blue_plus.
  BluetoothAdapterState get adapterState => _adapterState;

  /// Derived state the UI layer consumes to decide whether to show the gate.
  BluetoothGateStatus get status {
    if (!_hasCheckedSupport) return BluetoothGateStatus.checking;
    if (!_isSupported) return BluetoothGateStatus.unsupported;
    switch (_adapterState) {
      case BluetoothAdapterState.on:
        return BluetoothGateStatus.on;
      case BluetoothAdapterState.turningOn:
        return BluetoothGateStatus.turningOn;
      case BluetoothAdapterState.turningOff:
      case BluetoothAdapterState.off:
        return BluetoothGateStatus.off;
      case BluetoothAdapterState.unauthorized:
        return BluetoothGateStatus.unauthorized;
      case BluetoothAdapterState.unavailable:
        return BluetoothGateStatus.unsupported;
      case BluetoothAdapterState.unknown:
        return BluetoothGateStatus.checking;
    }
  }

  /// Convenience flag: everything is good and the app can operate.
  bool get isReady => status == BluetoothGateStatus.on;

  Future<void> _init() async {
    try {
      _isSupported = await FlutterBluePlus.isSupported;
    } catch (_) {
      _isSupported = false;
    }
    _hasCheckedSupport = true;
    if (!_disposed) notifyListeners();

    if (!_isSupported) return;

    _sub = FlutterBluePlus.adapterState.listen(
      (state) {
        _adapterState = state;
        if (!_disposed) notifyListeners();
      },
      onError: (_) {
        _adapterState = BluetoothAdapterState.unknown;
        if (!_disposed) notifyListeners();
      },
    );
  }

  /// Ask the OS to turn Bluetooth on.
  ///
  /// - On Android this triggers a system dialog.
  /// - On iOS this is unsupported by flutter_blue_plus; users must open Settings.
  Future<void> requestTurnOn() async {
    if (!_isSupported) return;
    if (!Platform.isAndroid) return;
    try {
      await FlutterBluePlus.turnOn();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[BluetoothStatusProvider] turnOn error: $e');
      }
    }
  }

  /// Whether the runtime can programmatically enable Bluetooth.
  bool get canRequestTurnOn => _isSupported && Platform.isAndroid;

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    super.dispose();
  }
}

enum BluetoothGateStatus {
  checking,
  unsupported,
  unauthorized,
  off,
  turningOn,
  on,
}
