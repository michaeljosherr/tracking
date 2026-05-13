import 'dart:collection';
import 'dart:math' as math;

/// Multi-stage distance filtering pipeline for BLE tracker distance readings.
///
/// Combines three complementary strategies to handle the noisy, spike-prone
/// nature of BLE RSSI-derived distances:
///
/// 1. **Sliding-window median**: Maintains a rolling window of the last N raw
///    measurements and outputs the median. This is inherently resistant to
///    outliers — a single spike to 20 m when the object is at 5 m gets
///    swallowed by the majority of sane readings.
///
/// 2. **Spike dampening (heuristic filter)**: When a new reading deviates from
///    the current estimate by more than [spikeThresholdM] metres, only a
///    fraction ([spikeDampeningFactor]) of the jump is accepted. This means a
///    spike from 5 m to 20 m (a 15 m jump) is treated as +3 m (= 15 × 0.20),
///    producing 8 m. If the object really did move, subsequent consistent
///    readings will gradually pull the estimate towards the true value.
///
/// 3. **Exponential moving average (EMA)**: After median + spike dampening,
///    the result is fed through an EMA to smooth frame-to-frame jitter. The
///    [emaSmoothingAlpha] controls responsiveness vs. smoothness (lower values
///    → smoother but laggier).
///
/// All three stages run in sequence on every [update] call. The pipeline is
/// stateful per-tracker (one instance per serial number).
class DistanceFilterPipeline {
  DistanceFilterPipeline({
    this.medianWindowSize = 7,
    this.spikeThresholdM = 3.0,
    this.spikeDampeningFactor = 0.20,
    this.emaSmoothingAlpha = 0.30,
    this.minDistance = 0.1,
    this.maxDistance = 500.0,
    double? initialDistance,
  }) : _emaValue = initialDistance {
    if (initialDistance != null) {
      // Seed the median window so we don't have a cold-start artifact.
      _medianWindow.add(initialDistance.clamp(minDistance, maxDistance));
    }
  }

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Number of recent raw readings kept for median calculation.
  /// Odd numbers work best (clean median without averaging two middle values).
  final int medianWindowSize;

  /// If the incoming reading differs from the current EMA estimate by more
  /// than this many metres, spike dampening kicks in.
  final double spikeThresholdM;

  /// Fraction of a spike that is accepted. 0.20 means only 20 % of the sudden
  /// jump is applied (e.g. 15 m spike → +3 m adjustment).
  final double spikeDampeningFactor;

  /// EMA blending factor. 0.0 = ignore new data (frozen), 1.0 = no smoothing.
  /// Typical range: 0.15–0.40.
  final double emaSmoothingAlpha;

  /// Floor and ceiling for clamped distances.
  final double minDistance;
  final double maxDistance;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  /// Rolling buffer for median. Newest element at the end.
  final ListQueue<double> _medianWindow = ListQueue<double>();

  /// Current exponential moving average output.
  double? _emaValue;

  /// Number of raw readings ingested so far.
  int _sampleCount = 0;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Feed a new raw distance measurement (in metres) and receive the filtered
  /// distance estimate.
  double update(double rawDistance) {
    final clamped = rawDistance.clamp(minDistance, maxDistance).toDouble();
    _sampleCount++;

    // ---- Stage 1: Sliding-window median ------------------------------------
    _medianWindow.addLast(clamped);
    while (_medianWindow.length > medianWindowSize) {
      _medianWindow.removeFirst();
    }
    final median = _computeMedian();

    // ---- Stage 2: Spike dampening ------------------------------------------
    final dampened = _dampenSpike(median);

    // ---- Stage 3: Exponential moving average --------------------------------
    if (_emaValue == null) {
      _emaValue = dampened;
    } else {
      _emaValue = _emaValue! * (1.0 - emaSmoothingAlpha) +
          dampened * emaSmoothingAlpha;
    }

    return _emaValue!;
  }

  /// Current filtered estimate without ingesting a new reading.
  double get currentEstimate => _emaValue ?? 0.0;

  /// How many raw samples have been processed.
  int get sampleCount => _sampleCount;

  /// Reset the pipeline to its initial state.
  void reset() {
    _medianWindow.clear();
    _emaValue = null;
    _sampleCount = 0;
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Compute the median of [_medianWindow].
  double _computeMedian() {
    if (_medianWindow.isEmpty) return 0.0;
    final sorted = _medianWindow.toList()..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid];
    }
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  /// If [incoming] deviates from the current estimate by more than
  /// [spikeThresholdM], only accept [spikeDampeningFactor] of the delta.
  double _dampenSpike(double incoming) {
    if (_emaValue == null) return incoming;
    final delta = incoming - _emaValue!;
    if (delta.abs() <= spikeThresholdM) {
      // Normal movement — accept as-is.
      return incoming;
    }
    // Spike detected: only apply a fraction of the jump.
    return _emaValue! + delta * spikeDampeningFactor;
  }
}
