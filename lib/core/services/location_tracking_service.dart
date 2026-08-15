import 'dart:async';
import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import 'kalman_filter.dart';

// ─── Filtered location output ─────────────────────────────────────────────────

/// The processed result emitted by [LocationTrackingService] after Kalman
/// filtering, outlier rejection, and motion analysis.
class FilteredLocation {
  final LatLng position;
  final double speedKmh;
  final double headingDegrees;
  final double altitudeMeters;
  final double accuracyMeters;
  final double distanceDeltaMeters;
  final double elapsedSeconds;
  final bool isMoving;
  final bool isTeleport;
  final bool isOutlier;
  final DateTime timestamp;

  const FilteredLocation({
    required this.position,
    required this.speedKmh,
    required this.headingDegrees,
    required this.altitudeMeters,
    required this.accuracyMeters,
    required this.distanceDeltaMeters,
    required this.elapsedSeconds,
    required this.isMoving,
    required this.isTeleport,
    required this.isOutlier,
    required this.timestamp,
  });
}

// ─── Tuning parameters ──────────────────────────────────────────────────────────

class TrackingConfig {
  /// Maximum accepted horizontal accuracy (meters).
  final double maxAccuracyMeters;

  /// Maximum accepted altitude accuracy (meters).
  final double maxAltitudeAccuracyMeters;

  /// Minimum displacement for track-point recording (meters).
  final double minTrackPointDistanceMeters;

  /// Maximum accuracy accepted for initial map seeding (meters).
  final double maxBootstrapAccuracyMeters;

  /// Maximum age accepted for initial map seeding.
  final int maxBootstrapAgeSeconds;

  /// Below this speed the rider is considered stationary (km/h).
  final double stationarySpeedThresholdKmh;

  /// Teleport: distance beyond which a single jump is rejected (meters).
  final double maxTeleportDistanceMeters;

  /// Maximum reasonable riding speed for the vehicle type (km/h).
  final double maxReasonableSpeedKmh;

  /// How many consecutive confirmations are needed to re-anchor after a teleport.
  final int reanchorConfirmationHits;

  /// Radius within which re-anchor hits are confirmed (meters).
  final double reanchorConfirmationRadiusMeters;

  /// Speed resets to 0 after this many ms of no movement.
  final int speedResetAfterMs;

  /// Minimum device-reported speed to trust (km/h).
  final double minReliableDeviceSpeedKmh;

  /// Maximum accepted speed-accuracy from the device (m/s).
  final double maxSpeedAccuracyMps;

  /// Max bearing change (degrees) allowed in <2s of movement at speed.
  /// Exceeding this means the point is likely GPS bounce.
  final double maxBearingChangeDegrees;

  /// Minimum elapsed time (ms) before bearing rejection applies.
  final int bearingRejectionMinElapsedMs;

  /// EMA alpha for speed smoothing (0–1). Higher = more responsive.
  final double speedSmoothingAlpha;

  /// Kalman process noise for position (lower = smoother, slower to respond).
  final double positionProcessNoise;

  /// Kalman process noise for altitude.
  final double altitudeProcessNoise;

  /// Number of consecutive moving samples required after being stationary.
  final int movingConfirmationHits;

  /// Minimum distance from the stationary anchor before movement can resume.
  final double stationaryExitDistanceMeters;

  const TrackingConfig({
    this.maxAccuracyMeters = 20.0,
    this.maxAltitudeAccuracyMeters = 15.0,
    this.minTrackPointDistanceMeters = 8.0,
    this.maxBootstrapAccuracyMeters = 25.0,
    this.maxBootstrapAgeSeconds = 30,
    this.stationarySpeedThresholdKmh = 2.2,
    this.maxTeleportDistanceMeters = 90.0,
    this.maxReasonableSpeedKmh = 45.0,
    this.reanchorConfirmationHits = 3,
    this.reanchorConfirmationRadiusMeters = 18.0,
    this.speedResetAfterMs = 6000,
    this.minReliableDeviceSpeedKmh = 2.2,
    this.maxSpeedAccuracyMps = 1.5,
    this.maxBearingChangeDegrees = 120.0,
    this.bearingRejectionMinElapsedMs = 1500,
    this.speedSmoothingAlpha = 0.30,
    this.positionProcessNoise = 0.000035,
    this.altitudeProcessNoise = 0.5,
    this.movingConfirmationHits = 4,
    this.stationaryExitDistanceMeters = 18.0,
  });

  /// Factory for e-bike (higher max speed).
  factory TrackingConfig.eBike() =>
      const TrackingConfig(maxReasonableSpeedKmh: 48.0);

  /// Factory for regular bike.
  factory TrackingConfig.regularBike() =>
      const TrackingConfig(maxReasonableSpeedKmh: 36.0);
}

// ─── Location Tracking Service ────────────────────────────────────────────────

/// Encapsulates GPS processing: Kalman filtering, outlier rejection,
/// motion detection, bearing analysis, and smooth speed estimation.
///
/// Subscribes to Geolocator and emits [FilteredLocation] events through
/// the [locations] stream.
class LocationTrackingService {
  final TrackingConfig config;

  // Kalman filters
  late final KalmanFilter2D _positionFilter;
  late final KalmanFilter1D _altitudeFilter;

  // State
  LatLng? _lastAcceptedPosition;
  DateTime? _lastAcceptedAt;
  double _lastAcceptedBearing = 0;
  double _smoothedSpeed = 0;
  int _lastMotionAtMs = 0;
  double? _lastFilteredAltitude;
  double _elevationGain = 0;
  LatLng? _stationaryAnchor;
  LatLng? _pendingMovementPoint;
  double _pendingMovementDistanceMeters = 0;
  int _pendingMovementHits = 0;

  // Re-anchor state
  LatLng? _pendingReanchorPoint;
  int _pendingReanchorHits = 0;

  // Geolocator subscription
  StreamSubscription<Position>? _positionSub;
  bool _isPaused = false;

  // Output stream
  final _controller = StreamController<FilteredLocation>.broadcast();

  static const Distance _distCalc = Distance();

  LocationTrackingService({this.config = const TrackingConfig()}) {
    _positionFilter = KalmanFilter2D(
      processNoise: config.positionProcessNoise,
      measurementNoise: 3.0,
    );
    _altitudeFilter = KalmanFilter1D(
      processNoise: config.altitudeProcessNoise,
      measurementNoise: 10.0,
    );
  }

  /// Stream of processed location updates.
  Stream<FilteredLocation> get locations => _controller.stream;

  /// Current smoothed speed in km/h.
  double get currentSpeedKmh => _smoothedSpeed;

  /// Total elevation gain accumulated so far (meters).
  double get elevationGain => _elevationGain;

  /// Last accepted filtered position.
  LatLng? get lastPosition => _lastAcceptedPosition;

  /// Last accepted bearing in degrees.
  double get lastBearing => _lastAcceptedBearing;

  /// Millisecond epoch of last detected motion.
  int get lastMotionAtMs => _lastMotionAtMs;

  /// Start listening to GPS updates.
  Future<bool> start() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return false;
      }

      // Seed with initial position
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (_isUsableBootstrapPosition(pos, DateTime.now())) {
        _seedFromPosition(pos);
      }

      // Subscribe with distanceFilter: 0 — we handle our own filtering
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen(_onRawGpsUpdate);

      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pause processing (e.g. ride paused).
  void pause() => _isPaused = true;

  /// Resume processing.
  void resume() {
    _isPaused = false;
    // Reset time reference so we don't accumulate paused time as distance.
    _lastAcceptedAt = DateTime.now();
  }

  /// Restore state from a persisted ride.
  void restore({
    required double lat,
    required double lng,
    required double bearing,
    required double speedKmh,
    required double elevationGainM,
    required int lastMotionAtMs,
    double? lastAltitude,
  }) {
    _positionFilter.seed(lat, lng);
    _lastAcceptedPosition = LatLng(lat, lng);
    _lastAcceptedBearing = bearing;
    _smoothedSpeed = speedKmh;
    _elevationGain = elevationGainM;
    _lastMotionAtMs = lastMotionAtMs;
    _lastFilteredAltitude = lastAltitude;
    _lastAcceptedAt = DateTime.now();
    if (lastAltitude != null) {
      _altitudeFilter.seed(lastAltitude);
    }
  }

  /// Stop all GPS processing.
  void dispose() {
    _positionSub?.cancel();
    _controller.close();
  }

  // ─── Private processing pipeline ────────────────────────────────────────

  void _seedFromPosition(Position pos) {
    final accuracy = _normalizedAccuracy(pos.accuracy);
    final filtered = _positionFilter.update(
      pos.latitude,
      pos.longitude,
      accuracyMeters: accuracy,
    );
    _lastAcceptedPosition = LatLng(filtered.lat, filtered.lng);
    _lastAcceptedAt = DateTime.now();
    _lastAcceptedBearing = _resolveHeading(pos.heading);

    if (pos.altitude.isFinite) {
      _altitudeFilter.update(pos.altitude);
      _lastFilteredAltitude = pos.altitude;
    }
  }

  void _onRawGpsUpdate(Position pos) {
    if (_isPaused) return;

    final now = DateTime.now();
    final newLat = pos.latitude;
    final newLng = pos.longitude;
    final accuracy = _normalizedAccuracy(pos.accuracy);
    final deviceSpeedKmh = _readDeviceSpeedKmh(pos);
    final speedAccuracy = _readSpeedAccuracy(pos);
    final reliableDeviceSpeed =
        deviceSpeedKmh != null &&
        deviceSpeedKmh >= config.minReliableDeviceSpeedKmh &&
        (speedAccuracy != null
            ? speedAccuracy <= config.maxSpeedAccuracyMps
            : true);
    final trustedDeviceSpeedKmh = reliableDeviceSpeed ? deviceSpeedKmh : 0.0;

    // ── Hard rejection: poor accuracy ──────────────────────────────────
    if (accuracy > config.maxAccuracyMeters) {
      _emitOutlier(pos, now, reason: 'accuracy');
      return;
    }

    final previousPosition = _lastAcceptedPosition;
    final previousAt = _lastAcceptedAt;

    // ── Bootstrap: no previous position yet ────────────────────────────
    if (previousPosition == null || previousAt == null) {
      _acceptPosition(pos, now, distanceDelta: 0, elapsed: 0);
      return;
    }

    final elapsed = math.max(
      0.5,
      now.difference(previousAt).inMilliseconds / 1000.0,
    );
    final rawDistance = _distCalc.as(
      LengthUnit.Meter,
      previousPosition,
      LatLng(newLat, newLng),
    );
    final rawSpeed = (rawDistance / elapsed) * 3.6;

    final strongRawMotion = _hasStrongRawMotion(
      distance: rawDistance,
      accuracy: accuracy,
      rawSpeed: rawSpeed,
      deviceSpeed: trustedDeviceSpeedKmh,
    );

    if (!strongRawMotion) {
      _holdStationary(now, previousPosition);
      return;
    }

    // ── Teleport detection ─────────────────────────────────────────────
    if (_isTeleport(rawDistance, elapsed, rawSpeed)) {
      _queueReanchor(LatLng(newLat, newLng), pos, now, accuracy);
      _emitOutlier(pos, now, reason: 'teleport');
      return;
    }

    // ── Bearing-based outlier rejection ────────────────────────────────
    if (_isBearingOutlier(previousPosition, LatLng(newLat, newLng), elapsed)) {
      _emitOutlier(pos, now, reason: 'bearing');
      return;
    }

    // ── Kalman filter the position ─────────────────────────────────────
    final filtered = _positionFilter.update(
      newLat,
      newLng,
      accuracyMeters: accuracy,
    );
    final filteredPos = LatLng(filtered.lat, filtered.lng);
    final filteredDistance = _distCalc.as(
      LengthUnit.Meter,
      previousPosition,
      filteredPos,
    );

    // ── Stationary detection ───────────────────────────────────────────
    final derivedFilteredSpeed = _derivedSpeed(filteredDistance, elapsed);
    final deviceIndicatesMotion =
        trustedDeviceSpeedKmh >= config.minReliableDeviceSpeedKmh;
    final isStationary =
        !deviceIndicatesMotion &&
        (filteredDistance <
                _movementThreshold(accuracy, trustedDeviceSpeedKmh) ||
            derivedFilteredSpeed < config.stationarySpeedThresholdKmh);

    if (isStationary) {
      _holdStationary(now, previousPosition);
      return;
    }

    // ── Segment threshold ──────────────────────────────────────────────
    if (!deviceIndicatesMotion &&
        filteredDistance < _segmentThreshold(accuracy, trustedDeviceSpeedKmh)) {
      _holdStationary(now, previousPosition);
      return;
    }

    if (!_movementConfirmed(
      candidate: filteredPos,
      anchor: previousPosition,
      accuracy: accuracy,
      strongMotion: deviceIndicatesMotion,
    )) {
      return;
    }

    // ── Speed calculation ──────────────────────────────────────────────
    final derivedSpeed = _derivedSpeed(filteredDistance, elapsed);
    final acceptedSpeed = _resolveSpeed(derivedSpeed, trustedDeviceSpeedKmh);

    if (acceptedSpeed > config.maxReasonableSpeedKmh * 1.35) {
      _emitOutlier(pos, now, reason: 'speed');
      return;
    }

    // ── Accept the position ────────────────────────────────────────────
    _clearReanchor();
    _clearStationary();
    _smoothedSpeed = _emaSpeed(acceptedSpeed);
    _lastAcceptedBearing = _resolveHeading(
      pos.heading,
      fallback: _bearingBetween(previousPosition, filteredPos),
    );
    _lastMotionAtMs = now.millisecondsSinceEpoch;
    _lastAcceptedPosition = filteredPos;
    _lastAcceptedAt = now;

    // Altitude
    _processAltitude(pos);

    _controller.add(
      FilteredLocation(
        position: filteredPos,
        speedKmh: _smoothedSpeed,
        headingDegrees: _lastAcceptedBearing,
        altitudeMeters: _lastFilteredAltitude ?? 0,
        accuracyMeters: accuracy,
        distanceDeltaMeters: filteredDistance,
        elapsedSeconds: elapsed,
        isMoving: true,
        isTeleport: false,
        isOutlier: false,
        timestamp: now,
      ),
    );
  }

  void _acceptPosition(
    Position pos,
    DateTime now, {
    required double distanceDelta,
    required double elapsed,
  }) {
    final accuracy = _normalizedAccuracy(pos.accuracy);
    final filtered = _positionFilter.update(
      pos.latitude,
      pos.longitude,
      accuracyMeters: accuracy,
    );
    _lastAcceptedPosition = LatLng(filtered.lat, filtered.lng);
    _lastAcceptedAt = now;
    _lastAcceptedBearing = _resolveHeading(pos.heading);
    _processAltitude(pos);

    _controller.add(
      FilteredLocation(
        position: _lastAcceptedPosition!,
        speedKmh: 0,
        headingDegrees: _lastAcceptedBearing,
        altitudeMeters: _lastFilteredAltitude ?? 0,
        accuracyMeters: accuracy,
        distanceDeltaMeters: distanceDelta,
        elapsedSeconds: elapsed,
        isMoving: false,
        isTeleport: false,
        isOutlier: false,
        timestamp: now,
      ),
    );
  }

  void _emitOutlier(Position pos, DateTime now, {required String reason}) {
    _controller.add(
      FilteredLocation(
        position: LatLng(pos.latitude, pos.longitude),
        speedKmh: _smoothedSpeed,
        headingDegrees: _lastAcceptedBearing,
        altitudeMeters: _lastFilteredAltitude ?? 0,
        accuracyMeters: _normalizedAccuracy(pos.accuracy),
        distanceDeltaMeters: 0,
        elapsedSeconds: 0,
        isMoving: false,
        isTeleport: reason == 'teleport',
        isOutlier: true,
        timestamp: now,
      ),
    );
  }

  // ── Re-anchor logic ─────────────────────────────────────────────────────

  void _queueReanchor(
    LatLng candidate,
    Position pos,
    DateTime now,
    double accuracy,
  ) {
    final confirmationRadius = math.max(
      config.reanchorConfirmationRadiusMeters,
      accuracy * 1.2,
    );
    final pending = _pendingReanchorPoint;
    if (pending != null) {
      final dist = _distCalc.as(LengthUnit.Meter, pending, candidate);
      if (dist <= confirmationRadius) {
        _pendingReanchorHits += 1;
        if (_pendingReanchorHits >= config.reanchorConfirmationHits) {
          _confirmReanchor(candidate, pos, now);
        }
        return;
      }
    }
    _pendingReanchorPoint = candidate;
    _pendingReanchorHits = 1;
  }

  void _confirmReanchor(LatLng anchor, Position pos, DateTime now) {
    _positionFilter.seed(anchor.latitude, anchor.longitude);
    _lastAcceptedPosition = anchor;
    _lastAcceptedAt = now;
    _lastAcceptedBearing = _resolveHeading(pos.heading);
    _smoothedSpeed = 0;
    _lastMotionAtMs = now.millisecondsSinceEpoch;
    _clearReanchor();
    _processAltitude(pos);

    _controller.add(
      FilteredLocation(
        position: anchor,
        speedKmh: 0,
        headingDegrees: _lastAcceptedBearing,
        altitudeMeters: _lastFilteredAltitude ?? 0,
        accuracyMeters: _normalizedAccuracy(pos.accuracy),
        distanceDeltaMeters: 0,
        elapsedSeconds: 0,
        isMoving: false,
        isTeleport: true,
        isOutlier: false,
        timestamp: now,
      ),
    );
  }

  void _clearReanchor() {
    _pendingReanchorPoint = null;
    _pendingReanchorHits = 0;
  }

  void _holdStationary(DateTime now, LatLng? anchor) {
    _stationaryAnchor ??= anchor;
    _pendingMovementPoint = null;
    _pendingMovementDistanceMeters = 0;
    _pendingMovementHits = 0;

    final shouldResetSpeed =
        _smoothedSpeed > 0 &&
        (_lastMotionAtMs == 0 ||
            now.millisecondsSinceEpoch - _lastMotionAtMs >=
                config.speedResetAfterMs);
    if (shouldResetSpeed) {
      _smoothedSpeed = 0;
    }
  }

  void _clearStationary() {
    _stationaryAnchor = null;
    _pendingMovementPoint = null;
    _pendingMovementDistanceMeters = 0;
    _pendingMovementHits = 0;
  }

  // ── Altitude processing ─────────────────────────────────────────────────

  void _processAltitude(Position pos) {
    if (!pos.altitude.isFinite) return;

    double? altAccuracy;
    try {
      final dynamic raw = pos;
      final value = raw.altitudeAccuracy;
      if (value is num && value.isFinite && value >= 0) {
        altAccuracy = value.toDouble();
      }
    } catch (_) {}

    if (altAccuracy != null && altAccuracy > config.maxAltitudeAccuracyMeters) {
      return;
    }

    final filtered = _altitudeFilter.update(
      pos.altitude,
      measurementAccuracy: altAccuracy,
    );

    if (_lastFilteredAltitude != null) {
      final climb = filtered - _lastFilteredAltitude!;
      if (climb > 1.5) {
        _elevationGain += climb;
      }
    }
    _lastFilteredAltitude = filtered;
  }

  // ── Bearing outlier detection ─────────────────────────────────────────

  bool _isBearingOutlier(LatLng from, LatLng to, double elapsedSeconds) {
    // Only apply when moving at speed and the time gap is short
    if (_smoothedSpeed < config.stationarySpeedThresholdKmh * 1.5) {
      return false;
    }
    if (elapsedSeconds * 1000 > config.bearingRejectionMinElapsedMs) {
      return false;
    }

    final newBearing = _bearingBetween(from, to);
    var bearingDelta = (newBearing - _lastAcceptedBearing).abs();
    if (bearingDelta > 180) bearingDelta = 360 - bearingDelta;

    return bearingDelta > config.maxBearingChangeDegrees;
  }

  // ── Helpers ─────────────────────────────────────────────────────────────

  double _normalizedAccuracy(double accuracy) {
    if (!accuracy.isFinite || accuracy <= 0) return 10.0;
    return accuracy;
  }

  bool _isUsableBootstrapPosition(Position pos, DateTime now) {
    final accuracy = _normalizedAccuracy(pos.accuracy);
    if (accuracy > config.maxBootstrapAccuracyMeters) return false;
    final ageSeconds = now.difference(pos.timestamp).inSeconds.abs();
    return ageSeconds <= config.maxBootstrapAgeSeconds;
  }

  bool _isTeleport(double distance, double elapsed, double speed) {
    if (distance > config.maxTeleportDistanceMeters && elapsed < 6) return true;
    return speed > config.maxReasonableSpeedKmh * 1.35;
  }

  double _movementThreshold(double accuracy, double deviceSpeed) {
    final effectiveAccuracy = _effectiveMotionAccuracy(accuracy);
    final minMovement = config.minTrackPointDistanceMeters;
    if (deviceSpeed >= config.minReliableDeviceSpeedKmh) {
      return math.max(
        1.5,
        math.max(minMovement * 0.65, effectiveAccuracy * 0.2),
      );
    }
    return math.max(minMovement, math.max(effectiveAccuracy * 0.45, 3.5));
  }

  double _segmentThreshold(double accuracy, double deviceSpeed) {
    final effectiveAccuracy = _effectiveMotionAccuracy(accuracy);
    final base = math.max(
      config.minTrackPointDistanceMeters,
      effectiveAccuracy * 0.35,
    );
    if (deviceSpeed >= config.minReliableDeviceSpeedKmh) return base;
    return math.max(base, 4.0);
  }

  double _stationaryExitDistance(double accuracy) => math.max(
    config.stationaryExitDistanceMeters,
    _effectiveMotionAccuracy(accuracy) * 0.45,
  );

  double _effectiveMotionAccuracy(double accuracy) =>
      math.min(math.max(_normalizedAccuracy(accuracy), 5.0), 14.0);

  bool _hasStrongRawMotion({
    required double distance,
    required double accuracy,
    required double rawSpeed,
    required double deviceSpeed,
  }) {
    final anchor = _stationaryAnchor ?? _lastAcceptedPosition;
    var distanceFromAnchor = distance;
    if (anchor != null && _lastAcceptedPosition != null) {
      distanceFromAnchor = _distCalc.as(
        LengthUnit.Meter,
        anchor,
        _lastAcceptedPosition!,
      );
      distanceFromAnchor = math.max(distanceFromAnchor, distance);
    }

    final exitDistance = _stationaryExitDistance(accuracy);
    if (deviceSpeed >= config.minReliableDeviceSpeedKmh) {
      return distance >=
              math.max(1.5, config.minTrackPointDistanceMeters * 0.5) ||
          rawSpeed >= config.stationarySpeedThresholdKmh;
    }

    final speedLooksMoving =
        rawSpeed >= config.stationarySpeedThresholdKmh ||
        distanceFromAnchor >= exitDistance * 1.5;
    return distance >= _movementThreshold(accuracy, deviceSpeed) &&
        distanceFromAnchor >= exitDistance &&
        speedLooksMoving;
  }

  bool _movementConfirmed({
    required LatLng candidate,
    required LatLng anchor,
    required double accuracy,
    required bool strongMotion,
  }) {
    if (_stationaryAnchor == null || strongMotion) return true;

    final pending = _pendingMovementPoint;
    final distanceFromAnchor = _distCalc.as(
      LengthUnit.Meter,
      _stationaryAnchor ?? anchor,
      candidate,
    );

    final confirmationRadius = math.max(accuracy * 1.25, 10.0);
    if (pending != null &&
        _distCalc.as(LengthUnit.Meter, pending, candidate) <=
            confirmationRadius) {
      final requiredProgress = math.max(4.0, accuracy * 0.35);
      final progress = distanceFromAnchor - _pendingMovementDistanceMeters;
      if (progress >= requiredProgress) {
        _pendingMovementHits += 1;
        _pendingMovementPoint = candidate;
        _pendingMovementDistanceMeters = distanceFromAnchor;
      }
    } else {
      _pendingMovementPoint = candidate;
      _pendingMovementDistanceMeters = distanceFromAnchor;
      _pendingMovementHits = 1;
    }

    return _pendingMovementHits >= config.movingConfirmationHits &&
        distanceFromAnchor >= _stationaryExitDistance(accuracy);
  }

  double _derivedSpeed(double distanceM, double elapsedS) =>
      (distanceM / math.max(elapsedS, 0.5)) * 3.6;

  double _resolveSpeed(double derived, double device) {
    if (device > 0) {
      if (derived <= 0) return device;
      return (device * 0.75) + (derived * 0.25);
    }
    return derived * 0.82;
  }

  double _emaSpeed(double newSpeed) {
    if (_smoothedSpeed <= 0) return newSpeed;
    return _smoothedSpeed * (1 - config.speedSmoothingAlpha) +
        newSpeed * config.speedSmoothingAlpha;
  }

  double? _readDeviceSpeedKmh(Position pos) {
    final mps = pos.speed;
    if (!mps.isFinite || mps <= 0) return null;
    return mps * 3.6;
  }

  double? _readSpeedAccuracy(Position pos) {
    try {
      final dynamic raw = pos;
      final value = raw.speedAccuracy;
      if (value is num && value.isFinite && value >= 0) return value.toDouble();
    } catch (_) {}
    return null;
  }

  double _resolveHeading(double raw, {double? fallback}) {
    if (raw.isFinite && raw >= 0) return raw % 360;
    return fallback ?? 0;
  }

  double _bearingBetween(LatLng from, LatLng to) {
    final lat1 = from.latitude * math.pi / 180.0;
    final lat2 = to.latitude * math.pi / 180.0;
    final dLon = (to.longitude - from.longitude) * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(lat2);
    final x =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return ((math.atan2(y, x) * 180.0 / math.pi) + 360.0) % 360.0;
  }
}
