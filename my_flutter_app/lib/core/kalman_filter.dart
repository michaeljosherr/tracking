/// Kalman Filter for RSSI Signal Smoothing
/// 
/// 1D Kalman Filter implementation for smoothing noisy RSSI measurements.
/// Used to reduce measurement noise while tracking rapid signal changes.
class KalmanFilter {
  /// Process noise (Q) - how much we expect the signal to naturally vary
  /// Lower values assume smoother signals
  final double processNoise;

  /// Measurement noise (R) - measurement uncertainty in dBm
  /// Higher values mean we trust measurements less
  final double measurementNoise;

  /// Initial uncertainty (P) - how uncertain we are about the initial estimate
  final double initialUncertainty;

  /// Current estimated value
  double _x = 0.0;

  /// Current estimation uncertainty
  double _p = 0.0;

  /// Whether the filter has been initialized with a measurement
  bool _initialized = false;

  KalmanFilter({
    this.processNoise = 0.01,
    this.measurementNoise = 2.5,
    this.initialUncertainty = 10.0,
  }) {
    _p = initialUncertainty;
  }

  /// Update the filter with a new measurement and return the filtered value
  ///
  /// This implements the standard Kalman filter equations:
  /// 1. Predict: p_pred = p + q
  /// 2. Gain: k = p_pred / (p_pred + r)
  /// 3. Update: x = x + k * (measurement - x)
  /// 4. Correct: p = (1 - k) * p_pred
  double update(double measurement) {
    if (!_initialized) {
      _x = measurement;
      _initialized = true;
      return _x;
    }

    // Prediction step
    final pPred = _p + processNoise;

    // Kalman gain
    final k = pPred / (pPred + measurementNoise);

    // Update estimate
    _x = _x + k * (measurement - _x);

    // Update uncertainty
    _p = (1 - k) * pPred;

    return _x;
  }

  /// Get the current filtered value
  double get value => _x;

  /// Get the current estimation uncertainty
  double get uncertainty => _p;

  /// Reset the filter to uninitialized state
  void reset() {
    _x = 0.0;
    _p = initialUncertainty;
    _initialized = false;
  }

  /// Check if filter has been initialized
  bool get isInitialized => _initialized;
}
