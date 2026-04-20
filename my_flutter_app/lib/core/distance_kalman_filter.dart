import 'dart:math' as math;

/// 1D distance Kalman filter with outlier rejection (aligned with Python GUI).
class DistanceKalmanFilter {
  DistanceKalmanFilter({
    required double initialDistance,
    this.processNoise = 0.15,
    this.measurementNoise = 20.0,
    this.outlierThreshold = 3.0,
    this.minDistance = 0.1,
    this.maxDistance = 500.0,
  })  : _x = initialDistance.clamp(0.1, 500.0).toDouble(),
        _p = measurementNoise;

  final double processNoise;
  final double measurementNoise;
  final double outlierThreshold;
  final double minDistance;
  final double maxDistance;

  double _x;
  double _p;

  double update(double measuredDistance) {
    final z = measuredDistance.clamp(minDistance, maxDistance).toDouble();

    _p = _p + processNoise;
    final predictionError = (z - _x).abs();
    final stdDev = math.sqrt(_p + measurementNoise);
    if (predictionError > outlierThreshold * stdDev) {
      return _x;
    }

    final k = _p / (_p + measurementNoise);
    _x = _x + k * (z - _x);
    _p = (1.0 - k) * _p;
    return _x;
  }
}
