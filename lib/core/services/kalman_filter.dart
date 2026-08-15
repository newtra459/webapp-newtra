/// A simple 1-D Kalman filter for smoothing GPS signals.
///
/// Used independently for latitude, longitude, speed, and altitude channels.
/// Each channel has its own noise characteristics, so they get separate
/// instances with different [processNoise] / [measurementNoise] values.
class KalmanFilter1D {
  /// How fast the true value is expected to change between updates.
  /// Higher = more responsive to changes, lower = smoother.
  final double processNoise;

  /// How noisy the raw measurements are.
  /// Higher = less trust in individual readings, lower = more trust.
  final double measurementNoise;

  double _estimate = 0;
  double _errorCovariance = 1;
  bool _initialized = false;

  KalmanFilter1D({
    this.processNoise = 0.012,
    this.measurementNoise = 2.5,
  });

  /// Whether the filter has received at least one measurement.
  bool get isInitialized => _initialized;

  /// Current best estimate.
  double get estimate => _estimate;

  /// Current uncertainty.
  double get errorCovariance => _errorCovariance;

  /// Feed a new raw [measurement] and return the smoothed estimate.
  ///
  /// Optionally provide [measurementAccuracy] to dynamically adjust
  /// measurement noise based on reported GPS accuracy.
  double update(double measurement, {double? measurementAccuracy}) {
    if (!_initialized) {
      _estimate = measurement;
      _errorCovariance = measurementAccuracy ?? measurementNoise;
      _initialized = true;
      return _estimate;
    }

    // Prediction step — estimate doesn't change (constant-velocity assumed
    // to be zero for the 1-D case; motion is captured by the process noise).
    final predictedCovariance = _errorCovariance + processNoise;

    // Effective measurement noise — use reported accuracy when available.
    final effectiveNoise = measurementAccuracy ?? measurementNoise;

    // Kalman gain
    final gain = predictedCovariance / (predictedCovariance + effectiveNoise);

    // Update step
    _estimate = _estimate + gain * (measurement - _estimate);
    _errorCovariance = (1 - gain) * predictedCovariance;

    return _estimate;
  }

  /// Reset the filter to uninitialized state.
  void reset() {
    _estimate = 0;
    _errorCovariance = 1;
    _initialized = false;
  }

  /// Seed the filter with a known value (e.g. from restored state).
  void seed(double value, {double covariance = 1.0}) {
    _estimate = value;
    _errorCovariance = covariance;
    _initialized = true;
  }
}

/// A 2-D Kalman filter that smooths latitude/longitude pairs together.
///
/// Wraps two [KalmanFilter1D] instances with correlated tuning so the
/// filtered position is consistent.
class KalmanFilter2D {
  final KalmanFilter1D _latFilter;
  final KalmanFilter1D _lngFilter;

  KalmanFilter2D({
    double processNoise = 0.000035,
    double measurementNoise = 2.5,
  })  : _latFilter = KalmanFilter1D(
          processNoise: processNoise,
          measurementNoise: measurementNoise,
        ),
        _lngFilter = KalmanFilter1D(
          processNoise: processNoise,
          measurementNoise: measurementNoise,
        );

  bool get isInitialized => _latFilter.isInitialized;

  ({double lat, double lng}) get estimate =>
      (lat: _latFilter.estimate, lng: _lngFilter.estimate);

  /// Feed raw lat/lng and return smoothed pair.
  ({double lat, double lng}) update(
    double lat,
    double lng, {
    double? accuracyMeters,
  }) {
    // Convert accuracy in meters to rough degree-equivalent for the filter.
    // 1° latitude ≈ 111,320 m. This is an approximation but works well
    // enough for Kalman noise scaling.
    final accuracyDeg =
        accuracyMeters != null ? accuracyMeters / 111320.0 : null;

    final filteredLat =
        _latFilter.update(lat, measurementAccuracy: accuracyDeg);
    final filteredLng =
        _lngFilter.update(lng, measurementAccuracy: accuracyDeg);

    return (lat: filteredLat, lng: filteredLng);
  }

  /// Reset both channels.
  void reset() {
    _latFilter.reset();
    _lngFilter.reset();
  }

  /// Seed both channels from restored state.
  void seed(double lat, double lng) {
    _latFilter.seed(lat);
    _lngFilter.seed(lng);
  }
}
