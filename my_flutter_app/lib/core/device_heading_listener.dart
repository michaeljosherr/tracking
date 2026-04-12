import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Normalizes degrees to [0, 360).
double normHeading360(double degrees) {
  var v = degrees % 360.0;
  if (v < 0) v += 360.0;
  return v;
}

/// Port of [android.hardware.SensorManager.getRotationMatrix] (3×3, R only).
bool getRotationMatrix9(List<double> R, List<double> gravity, List<double> geomagnetic) {
  var ax = gravity[0], ay = gravity[1], az = gravity[2];
  final normsqA = ax * ax + ay * ay + az * az;
  const g = 9.81;
  if (normsqA < 0.01 * g * g) return false;

  var ex = geomagnetic[0], ey = geomagnetic[1], ez = geomagnetic[2];
  var hx = ey * az - ez * ay;
  var hy = ez * ax - ex * az;
  var hz = ex * ay - ey * ax;
  final normH = math.sqrt(hx * hx + hy * hy + hz * hz);
  if (normH < 0.1) return false;

  final invH = 1.0 / normH;
  hx *= invH;
  hy *= invH;
  hz *= invH;
  final invA = 1.0 / math.sqrt(ax * ax + ay * ay + az * az);
  ax *= invA;
  ay *= invA;
  az *= invA;
  final mx = ay * hz - az * hy;
  final my = az * hx - ax * hz;
  final mz = ax * hy - ay * hx;

  R[0] = hx;
  R[1] = hy;
  R[2] = hz;
  R[3] = mx;
  R[4] = my;
  R[5] = mz;
  R[6] = ax;
  R[7] = ay;
  R[8] = az;
  return true;
}

/// Port of [android.hardware.SensorManager.getOrientation] for 3×3 R.
void getOrientation9(List<double> R, List<double> values) {
  values[0] = math.atan2(R[1], R[4]);
  values[1] = math.asin((-R[7]).clamp(-1.0, 1.0));
  values[2] = math.atan2(-R[6], R[8]);
}

/// Live device heading (0–360°, CW from magnetic north toward **top of phone**),
/// from accelerometer + magnetometer. Does not depend on CoreLocation heading APIs.
class DeviceHeadingListener {
  DeviceHeadingListener();

  static const _smooth = 0.18;

  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<MagnetometerEvent>? _magSub;

  final List<double> _g = [0, 0, 0];
  final List<double> _m = [0, 0, 0];
  bool _haveAccel = false;
  bool _haveMag = false;

  final List<double> _R = List<double>.filled(9, 0);
  final List<double> _orientation = List<double>.filled(3, 0);
  DateTime? _lastMatrixFailLog;

  void start(ValueChanged<double> onHeadingDeg) {
    if (kIsWeb) return;

    _accelSub = accelerometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(
      (e) {
        if (!_haveAccel) {
          _g[0] = e.x;
          _g[1] = e.y;
          _g[2] = e.z;
          _haveAccel = true;
        } else {
          _g[0] += _smooth * (e.x - _g[0]);
          _g[1] += _smooth * (e.y - _g[1]);
          _g[2] += _smooth * (e.z - _g[2]);
        }
        _emitIfReady(onHeadingDeg);
      },
      onError: (_) {},
    );

    _magSub = magnetometerEventStream(
      samplingPeriod: SensorInterval.uiInterval,
    ).listen(
      (e) {
        if (!_haveMag) {
          _m[0] = e.x;
          _m[1] = e.y;
          _m[2] = e.z;
          _haveMag = true;
        } else {
          _m[0] += _smooth * (e.x - _m[0]);
          _m[1] += _smooth * (e.y - _m[1]);
          _m[2] += _smooth * (e.z - _m[2]);
        }
        _emitIfReady(onHeadingDeg);
      },
      onError: (_) {},
    );
  }

  void _emitIfReady(ValueChanged<double> onHeadingDeg) {
    if (!_haveAccel || !_haveMag) return;
    if (!getRotationMatrix9(_R, _g, _m)) {
      if (kDebugMode) {
        final now = DateTime.now();
        if (_lastMatrixFailLog == null ||
            now.difference(_lastMatrixFailLog!) > const Duration(seconds: 4)) {
          _lastMatrixFailLog = now;
          // ignore: avoid_print
          print(
            '[DeviceHeadingListener] getRotationMatrix failed (not flat on table, free-fall, or weak/noisy field).',
          );
        }
      }
      return;
    }
    getOrientation9(_R, _orientation);
    final deg = normHeading360(_orientation[0] * 180.0 / math.pi);
    onHeadingDeg(deg);
  }

  void dispose() {
    _accelSub?.cancel();
    _magSub?.cancel();
    _accelSub = null;
    _magSub = null;
  }
}

/// Single fused heading feed for BLE logic and UI (one underlying [DeviceHeadingListener]).
class DeviceHeadingStore {
  DeviceHeadingStore._();

  static final ValueNotifier<double?> heading = ValueNotifier<double?>(null);
  static DeviceHeadingListener? _listener;

  static void ensureStarted() {
    if (kIsWeb || _listener != null) return;
    _listener = DeviceHeadingListener()
      ..start((deg) {
        heading.value = deg;
      });
  }

  /// Stops updates and clears [heading] (e.g. last tracker removed).
  static void stop() {
    _listener?.dispose();
    _listener = null;
    heading.value = null;
  }
}
