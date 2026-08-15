import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/location_tracking_service.dart';
import '../../../../core/services/route_sanitizer.dart';
import '../../../../core/storage/local_storage.dart';
import '../../data/repositories/ride_repository.dart';
import '../../data/repositories/ride_repository_impl.dart';
import '../../data/ride_pricing.dart';

class RideScreen extends StatefulWidget {
  /// 0 = Scan Bike (shared), 1 = Record Ride (own bike)
  final int rideMode;
  final bool isEBike;
  final bool paidWithCoin;
  final String bikeId;

  /// True only when continuing an in-progress ride (home/scanner "Continue").
  /// A fresh ride (scan / record) is [resume] = false and must NOT inherit any
  /// previously saved session state.
  final bool resume;
  const RideScreen({
    super.key,
    this.rideMode = 0,
    this.isEBike = true,
    this.paidWithCoin = false,
    this.bikeId = '',
    this.resume = false,
  });

  @override
  State<RideScreen> createState() => _RideScreenState();
}

class _RideScreenState extends State<RideScreen> with TickerProviderStateMixin {
  static const Distance _distanceCalculator = Distance();
  static const double _maxDirectPolylineSegmentMeters = 120.0;
  static const double _maxRestoreGpsDriftMeters = 100.0;
  static const double _minRoutePointDistanceMeters = 3.0;
  // Below this covered distance a session isn't treated as a real ride, so
  // GPS-noise speed spikes and time-based calories can't be reported while the
  // rider is effectively stationary.
  static const double _minRealRideDistanceKm = 0.05;
  static const int _speedResetAfterMs = 9000;
  static const int _polylineSimplifyInterval = 24;

  bool _isPaused = false;
  int _seconds = 0;
  int _rideStartMs = 0;
  int _pausedAtMs = 0;
  Timer? _timer;
  double _distance = 0.0;
  double _currentSpeed = 0.0;
  double _maxSpeed = 0.0;
  double _movingSeconds = 0.0;
  double _calories = 0.0;
  double _elevation = 0.0;
  double? _lastFilteredAltitude;
  DateTime? _lastReferenceAt;
  int _lastMotionAtMs = 0;
  double _riderWeightKg = 70.0;
  int _syncedRoutePointCount = 0;
  bool _isSyncingRoute = false;
  Future<String?>? _serverRideStartFuture;
  int _rawTrackPointCount = 0;

  final MapController _mapCtrl = MapController();
  LatLng _currentPosition = RouteSanitizer.fallbackMapCenter;
  LatLng _displayPosition = RouteSanitizer.fallbackMapCenter;
  double _displayHeading = 0;
  final List<List<LatLng>> _routeSegments = [];
  final List<List<LatLng>> _smoothedRouteSegments = [];
  final List<DateTime> _routePointTimestamps = [];
  double _heading = 0;

  StreamSubscription<FilteredLocation>? _locationSub;
  late LocationTrackingService _trackingService;
  bool _gpsAvailable = false;

  late AnimationController _pulseCtrl;
  late AnimationController _mapMoveCtrl;
  late AnimationController _markerCtrl;
  Tween<double>? _mapLatTween;
  Tween<double>? _mapLngTween;
  Tween<double>? _markerLatTween;
  Tween<double>? _markerLngTween;
  Tween<double>? _headingTween;

  bool get _isSharedBike => widget.rideMode == 0;
  bool get _isEBike => widget.isEBike;
  final int _batteryPct = 78;
  late final String _bikeId;

  @override
  void initState() {
    super.initState();
    _bikeId = _resolveBikeId();
    _loadRiderWeight();

    // Setup tracking service with vehicle-specific config
    _trackingService = LocationTrackingService(
      config: _isEBike ? TrackingConfig.eBike() : TrackingConfig.regularBike(),
    );

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);

    // Smooth map camera animation controller
    _mapMoveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(_onMapMoveAnimation);

    // Smooth marker position + heading animation controller
    _markerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..addListener(_onMarkerAnimation);

    _startRide();
    unawaited(_initGps());
  }

  void _onMapMoveAnimation() {
    if (_mapLatTween == null || _mapLngTween == null) return;
    final t = Curves.easeOutCubic.transform(_mapMoveCtrl.value);
    try {
      _mapCtrl.move(
        LatLng(_mapLatTween!.transform(t), _mapLngTween!.transform(t)),
        _mapCtrl.camera.zoom,
      );
    } catch (_) {}
  }

  void _onMarkerAnimation() {
    if (_markerLatTween == null || _markerLngTween == null) return;
    final t = Curves.easeOutCubic.transform(_markerCtrl.value);
    setState(() {
      _displayPosition = LatLng(
        _markerLatTween!.transform(t),
        _markerLngTween!.transform(t),
      );
      if (_headingTween != null) {
        _displayHeading = _headingTween!.transform(t);
      }
    });
  }

  Future<void> _initGps() async {
    final started = await _trackingService.start();
    if (!mounted) return;

    if (!started) return;

    setState(() => _gpsAvailable = true);

    // Restore the previous position into the service only when resuming an
    // existing ride; a fresh ride must bootstrap from live GPS, never inherit
    // an old session's location.
    if (widget.resume) {
      final existing = LocalStorage.getActiveRideParams();
      final savedLat = _asNullableDouble(existing['currentLat']);
      final savedLng = _asNullableDouble(existing['currentLng']);
      final freshInitialPos = _trackingService.lastPosition;
      if (savedLat != null && savedLng != null) {
        final savedPosition = LatLng(savedLat, savedLng);
        final savedPositionLooksCurrent =
            freshInitialPos == null ||
            _distanceCalculator.as(
                  LengthUnit.Meter,
                  savedPosition,
                  freshInitialPos,
                ) <=
                _maxRestoreGpsDriftMeters;
        if (savedPositionLooksCurrent) {
          _trackingService.restore(
            lat: savedLat,
            lng: savedLng,
            bearing: _heading,
            speedKmh: _currentSpeed,
            elevationGainM: _elevation,
            lastMotionAtMs: _lastMotionAtMs,
            lastAltitude: _lastFilteredAltitude,
          );
        } else {
          _resetRouteToGps(freshInitialPos);
        }
      }
    }

    // If we have the initial position from the service, use it
    final initialPos = _trackingService.lastPosition;
    if (initialPos != null && _routeSegments.isEmpty) {
      setState(() {
        _currentPosition = initialPos;
        _displayPosition = initialPos;
        _heading = _trackingService.lastBearing;
        _displayHeading = _heading;
      });
      _animateMapTo(initialPos);
    }

    // Subscribe to filtered location updates
    _locationSub = _trackingService.locations.listen(_onFilteredLocation);
  }

  void _onFilteredLocation(FilteredLocation loc) {
    if (!mounted || _isPaused) return;

    if (!_gpsAvailable) {
      setState(() => _gpsAvailable = true);
    }

    // Outlier — don't update route but maybe update GPS availability
    if (loc.isOutlier && !loc.isTeleport) return;

    // Teleport / re-anchor — start a new route segment
    if (loc.isTeleport && !loc.isOutlier) {
      setState(() {
        _startNewRouteSegment(loc.position);
        _currentPosition = loc.position;
        _heading = loc.headingDegrees;
        _currentSpeed = 0;
        _lastReferenceAt = loc.timestamp;
        _lastMotionAtMs = loc.timestamp.millisecondsSinceEpoch;
        _elevation = _trackingService.elevationGain;
        _lastFilteredAltitude = loc.altitudeMeters > 0
            ? loc.altitudeMeters
            : _lastFilteredAltitude;
        _recalculateDerivedMetrics();
      });
      _animateMarkerTo(loc.position, loc.headingDegrees);
      _animateMapTo(loc.position);
      _persistRideState();
      _scheduleRouteSync();
      return;
    }

    // Normal movement
    if (!loc.isMoving) {
      _maybeBootstrapFromGps(loc);
      // Idle update — possibly reset speed
      final now = loc.timestamp;
      final shouldResetSpeed =
          _currentSpeed > 0 &&
          (_lastMotionAtMs == 0 ||
              now.millisecondsSinceEpoch - _lastMotionAtMs >=
                  _speedResetAfterMs);
      if (shouldResetSpeed) {
        setState(() {
          _currentSpeed = 0;
          _recalculateDerivedMetrics();
        });
        _persistRideState();
      }
      return;
    }

    // Good movement point — accept it
    final filteredDistance = loc.distanceDeltaMeters;

    // If segment gap is too big, re-anchor
    if (filteredDistance > _maxDirectPolylineSegmentMeters) {
      setState(() {
        _startNewRouteSegment(loc.position);
        _currentPosition = loc.position;
        _heading = loc.headingDegrees;
        _currentSpeed = 0;
        _lastReferenceAt = loc.timestamp;
        _lastMotionAtMs = loc.timestamp.millisecondsSinceEpoch;
        _elevation = _trackingService.elevationGain;
        _lastFilteredAltitude = loc.altitudeMeters > 0
            ? loc.altitudeMeters
            : _lastFilteredAltitude;
        _recalculateDerivedMetrics();
      });
    } else {
      setState(() {
        _currentPosition = loc.position;
        _heading = loc.headingDegrees;
        _distance += filteredDistance / 1000.0;
        _movingSeconds += loc.elapsedSeconds;
        _currentSpeed = loc.speedKmh;
        // Only record a max speed once the ride has covered real distance, so a
        // stationary device's GPS-noise speed spikes can't set a phantom max.
        if (_distance >= _minRealRideDistanceKm && _currentSpeed > _maxSpeed) {
          _maxSpeed = _currentSpeed;
        }
        _lastReferenceAt = loc.timestamp;
        _lastMotionAtMs = loc.timestamp.millisecondsSinceEpoch;
        _appendRoutePoint(loc.position);
        _elevation = _trackingService.elevationGain;
        _lastFilteredAltitude = loc.altitudeMeters > 0
            ? loc.altitudeMeters
            : _lastFilteredAltitude;
        _recalculateDerivedMetrics();
      });
    }

    // Update raw count and simplify polyline periodically
    _rawTrackPointCount++;
    if (_rawTrackPointCount % _polylineSimplifyInterval == 0) {
      _simplifyPolyline();
    }

    _animateMarkerTo(loc.position, loc.headingDegrees);
    _animateMapTo(loc.position);
    _persistRideState();
    _scheduleRouteSync();
  }

  void _resetRouteToGps(LatLng point) {
    setState(() {
      _routeSegments
        ..clear()
        ..add([point]);
      _smoothedRouteSegments.clear();
      _routePointTimestamps
        ..clear()
        ..add(DateTime.now());
      _currentPosition = point;
      _displayPosition = point;
      _distance = 0;
      _currentSpeed = 0;
      _movingSeconds = 0;
      _rawTrackPointCount = 0;
      _syncedRoutePointCount = 0;
      _lastReferenceAt = DateTime.now();
      _recalculateDerivedMetrics();
    });
    _animateMapTo(point);
    _persistRideState();
    _scheduleRouteSync();
  }

  void _maybeBootstrapFromGps(FilteredLocation loc) {
    final hasNoRoute = _routeSegments.isEmpty;
    if (!hasNoRoute) return;
    if (loc.accuracyMeters > 20) return;

    setState(() {
      _currentPosition = loc.position;
      _displayPosition = loc.position;
      _heading = loc.headingDegrees;
      _displayHeading = loc.headingDegrees;
      _lastReferenceAt = loc.timestamp;
    });
    _animateMarkerTo(loc.position, loc.headingDegrees);
    _animateMapTo(loc.position);
    _persistRideState();
  }

  /// Animate map camera smoothly to a target position.
  void _animateMapTo(LatLng target) {
    try {
      final currentCenter = _mapCtrl.camera.center;
      _mapLatTween = Tween(begin: currentCenter.latitude, end: target.latitude);
      _mapLngTween = Tween(
        begin: currentCenter.longitude,
        end: target.longitude,
      );
      _mapMoveCtrl.forward(from: 0);
    } catch (_) {
      // Map controller not ready yet, fall back to direct move
      try {
        _mapCtrl.move(target, 16);
      } catch (_) {}
    }
  }

  /// Animate marker position and heading smoothly.
  void _animateMarkerTo(LatLng target, double targetHeading) {
    _markerLatTween = Tween(
      begin: _displayPosition.latitude,
      end: target.latitude,
    );
    _markerLngTween = Tween(
      begin: _displayPosition.longitude,
      end: target.longitude,
    );

    // Smooth heading rotation — take shortest path
    var headingDelta = targetHeading - _displayHeading;
    if (headingDelta > 180) headingDelta -= 360;
    if (headingDelta < -180) headingDelta += 360;
    _headingTween = Tween(
      begin: _displayHeading,
      end: _displayHeading + headingDelta,
    );

    _markerCtrl.forward(from: 0);
  }

  /// Douglas-Peucker polyline simplification to keep rendering fast.
  void _simplifyPolyline() {
    _rebuildSmoothedRouteSegments();
  }

  void _rebuildSmoothedRouteSegments() {
    _smoothedRouteSegments.clear();
    for (final segment in _routeSegments) {
      if (segment.length <= 2) {
        _smoothedRouteSegments.add(List.of(segment));
        continue;
      }
      final smoothed = _smoothRouteSegment(segment);
      _smoothedRouteSegments.add(_douglasPeucker(smoothed, 0.7));
    }
  }

  List<LatLng> _smoothRouteSegment(List<LatLng> points) {
    if (points.length <= 2) return List.of(points);

    final smoothed = <LatLng>[points.first];
    for (var i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final current = points[i];
      final next = points[i + 1];
      smoothed.add(
        LatLng(
          (prev.latitude * 0.25) +
              (current.latitude * 0.50) +
              (next.latitude * 0.25),
          (prev.longitude * 0.25) +
              (current.longitude * 0.50) +
              (next.longitude * 0.25),
        ),
      );
    }
    smoothed.add(points.last);
    return smoothed;
  }

  List<LatLng> _douglasPeucker(List<LatLng> points, double epsilonMeters) {
    if (points.length <= 2) return List.of(points);

    double maxDist = 0;
    int maxIdx = 0;
    final first = points.first;
    final last = points.last;

    for (int i = 1; i < points.length - 1; i++) {
      final d = _perpendicularDistanceMeters(points[i], first, last);
      if (d > maxDist) {
        maxDist = d;
        maxIdx = i;
      }
    }

    if (maxDist > epsilonMeters) {
      final left = _douglasPeucker(
        points.sublist(0, maxIdx + 1),
        epsilonMeters,
      );
      final right = _douglasPeucker(points.sublist(maxIdx), epsilonMeters);
      return [...left.sublist(0, left.length - 1), ...right];
    }

    return [first, last];
  }

  double _perpendicularDistanceMeters(
    LatLng point,
    LatLng lineStart,
    LatLng lineEnd,
  ) {
    final a = _distanceCalculator.as(LengthUnit.Meter, lineStart, point);
    final b = _distanceCalculator.as(LengthUnit.Meter, point, lineEnd);
    final c = _distanceCalculator.as(LengthUnit.Meter, lineStart, lineEnd);
    if (c == 0) return a;
    final s = (a + b + c) / 2;
    final area = math.sqrt(math.max(0, s * (s - a) * (s - b) * (s - c)));
    return (2 * area) / c;
  }

  void _persistRideState() {
    final cleanSegments = RouteSanitizer.sanitizeSegments(_routeSegments);
    final cleanPoints = RouteSanitizer.flatten(cleanSegments);
    final hasUsableCurrentPoint =
        RouteSanitizer.isValidPoint(_currentPosition) &&
        !RouteSanitizer.isFallbackPoint(_currentPosition) &&
        (_gpsAvailable || cleanPoints.isNotEmpty);

    unawaited(
      LocalStorage.saveActiveRide({
        'rideMode': widget.rideMode,
        'isEBike': widget.isEBike,
        'paidWithCoin': widget.paidWithCoin,
        'bikeId': _bikeId,
        'startTime': _rideStartMs,
        'isPaused': _isPaused,
        if (_isPaused) 'pausedAtMs': _pausedAtMs,
        'distanceKm': _effectiveDistance,
        'currentSpeedKmh': _currentSpeed,
        'maxSpeedKmh': _maxSpeed,
        'movingSeconds': _movingSeconds,
        'calories': _calories,
        'elevationGainM': _elevation,
        'heading': _heading,
        if (hasUsableCurrentPoint) 'currentLat': _currentPosition.latitude,
        if (hasUsableCurrentPoint) 'currentLng': _currentPosition.longitude,
        'routeSegments': cleanSegments
            .map(
              (segment) => segment
                  .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                  .toList(),
            )
            .toList(),
        'routePoints': cleanPoints
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
        if (_lastReferenceAt != null)
          'lastReferenceAtMs': _lastReferenceAt!.millisecondsSinceEpoch,
        if (_lastFilteredAltitude != null)
          'lastFilteredAltitudeM': _lastFilteredAltitude,
        'lastMotionAtMs': _lastMotionAtMs,
        'syncedRoutePointCount': _syncedRoutePointCount,
      }),
    );
  }

  String _resolveBikeId() {
    final existing = LocalStorage.getActiveRideParams();
    final stored = existing['bikeId']?.toString().trim() ?? '';
    if (stored.isNotEmpty) return stored;
    final incoming = widget.bikeId.trim();
    if (incoming.isNotEmpty) return incoming;
    if (widget.rideMode == 1) return '';
    return 'MJ-042';
  }

  void _loadRiderWeight() {
    final cachedProfile = LocalStorage.getString('cached_profile');
    if (cachedProfile == null || cachedProfile.isEmpty) return;

    final parts = cachedProfile.split('|');
    if (parts.length < 10) return;
    final parsedWeight = double.tryParse(
      parts[9].replaceAll(RegExp(r'[^0-9.]'), ''),
    );
    if (parsedWeight != null && parsedWeight > 0) {
      _riderWeightKg = parsedWeight;
    }
  }

  void _startRide() {
    if (!widget.resume) {
      // Fresh ride: discard any abandoned/killed session so its distance,
      // moving time, route, calories and server id aren't inherited here.
      unawaited(LocalStorage.clearActiveRide());
    }
    final existing =
        widget.resume ? LocalStorage.getActiveRideParams() : <String, dynamic>{};
    final now = DateTime.now().millisecondsSinceEpoch;

    _rideStartMs = existing['startTime'] as int? ?? now;
    final wasPaused = existing['isPaused'] as bool? ?? false;
    _isPaused = wasPaused;
    _distance = _asDouble(existing['distanceKm']);
    _currentSpeed = _asDouble(existing['currentSpeedKmh']);
    _maxSpeed = _asDouble(existing['maxSpeedKmh']);
    _movingSeconds = _asDouble(existing['movingSeconds']);
    _calories = _asDouble(existing['calories']);
    _elevation = _asDouble(existing['elevationGainM']);
    _heading = _resolveHeading(
      _asDouble(existing['heading']),
      fallback: _heading,
    );
    _lastFilteredAltitude = _asNullableDouble(
      existing['lastFilteredAltitudeM'],
    );
    _lastMotionAtMs = (existing['lastMotionAtMs'] as num?)?.round() ?? 0;
    _syncedRoutePointCount =
        (existing['syncedRoutePointCount'] as num?)?.toInt() ?? 0;

    final restoredRouteSegments = _restoreRouteSegments(
      existing['routeSegments'],
      fallbackPoints: existing['routePoints'],
    );
    if (restoredRouteSegments.isNotEmpty) {
      _routeSegments
        ..clear()
        ..addAll(restoredRouteSegments);
      _currentPosition = _routeSegments.last.last;
      _sanitizeRouteState();
      if (_routeSegments.isNotEmpty) {
        _currentPosition = _routeSegments.last.last;
        _displayPosition = _currentPosition;
      }
      _rebuildSmoothedRouteSegments();
    } else {
      final savedLat = _asNullableDouble(existing['currentLat']);
      final savedLng = _asNullableDouble(existing['currentLng']);
      if (savedLat != null && savedLng != null) {
        final savedPoint = LatLng(savedLat, savedLng);
        if (!RouteSanitizer.isFallbackPoint(savedPoint)) {
          _currentPosition = savedPoint;
        }
      }
    }

    final lastReferenceMs = (existing['lastReferenceAtMs'] as num?)?.round();
    if (lastReferenceMs != null && lastReferenceMs > 0) {
      _lastReferenceAt = DateTime.fromMillisecondsSinceEpoch(lastReferenceMs);
    }

    if (wasPaused) {
      _pausedAtMs = existing['pausedAtMs'] as int? ?? now;
      _seconds = ((_pausedAtMs - _rideStartMs) / 1000).floor().clamp(0, 86400);
    } else {
      _seconds = ((now - _rideStartMs) / 1000).floor().clamp(0, 86400);
    }

    _recalculateDerivedMetrics();
    _persistRideState();
    _ensureServerRideStarted();
    _scheduleRouteSync();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isPaused) return;
      final currentMs = DateTime.now().millisecondsSinceEpoch;
      final recalculatedSeconds = ((currentMs - _rideStartMs) / 1000)
          .floor()
          .clamp(0, 86400);
      final shouldResetSpeed =
          _currentSpeed > 0 &&
          _lastMotionAtMs > 0 &&
          currentMs - _lastMotionAtMs >= _speedResetAfterMs;
      if (_seconds == recalculatedSeconds && !shouldResetSpeed) return;

      setState(() {
        _seconds = recalculatedSeconds;
        if (shouldResetSpeed) {
          _currentSpeed = 0;
        }
        _recalculateDerivedMetrics();
      });
    });
  }

  Future<String?> _ensureServerRideStarted() async {
    final existingServerId = LocalStorage.getActiveRideServerId();
    if (existingServerId != null && existingServerId.isNotEmpty) {
      return existingServerId;
    }
    final inflight = _serverRideStartFuture;
    if (inflight != null) return inflight;

    final future = () async {
      final repo = RideRepositoryImpl(ApiClient());
      try {
        final activeRide = await repo.getActiveRide();
        final activeRideId = activeRide?.id.trim() ?? '';
        if (activeRideId.isNotEmpty) {
          await LocalStorage.saveActiveRideServerId(activeRideId);
          return activeRideId;
        }
      } catch (_) {}

      try {
        final ride = await repo.startRide(
          bikeId: _bikeId,
          rideMode: widget.rideMode,
          isEBike: widget.isEBike,
        );
        final rideId = ride.id.trim();
        if (rideId.isNotEmpty) {
          await LocalStorage.saveActiveRideServerId(rideId);
          return rideId;
        }
      } catch (_) {
        return null;
      }
      return null;
    }();

    _serverRideStartFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_serverRideStartFuture, future)) {
        _serverRideStartFuture = null;
      }
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _locationSub?.cancel();
    _trackingService.dispose();
    _mapMoveCtrl.dispose();
    _markerCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  String _fmtCompactDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  double get _effectiveDistance => _resolveEffectiveDistance();

  // Moving time can never exceed the wall-clock ride time; clamp it so restored
  // or over-accumulated moving-seconds can't inflate avg speed and calories.
  double get _movingSecondsCapped =>
      math.min(_movingSeconds, _seconds.toDouble());

  double get _avg => _movingSecondsCapped <= 0
      ? 0
      : _effectiveDistance / (_movingSecondsCapped / 3600.0);

  void _showEndRideSheet() {
    _sanitizeRouteState();
    final endDistance = _effectiveDistance;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _EndRideSheet(
        distanceKm: endDistance,
        durationText: _fmtCompactDuration(_seconds),
        calories: _calories,
        onConfirmed: () async {
          Navigator.pop(ctx);
          final serverId = await _ensureServerRideStarted();
          if (serverId == null || serverId.isEmpty) {
            _showRidePersistenceError(
              'Could not save this ride yet. Check your connection and try ending it again.',
            );
            return;
          }

          await _syncRouteToServer();
          try {
            await RideRepositoryImpl(ApiClient()).endRide(
              serverId,
              personal: widget.rideMode == 1,
              distance: _effectiveDistance,
              duration: _seconds.toDouble(),
              averageSpeed: _avg,
              kcal: _calories,
              maxElevation: _elevation,
            );
          } catch (_) {
            _showRidePersistenceError(
              'Could not finish syncing this ride. Please try ending it again.',
            );
            return;
          }

          _timer?.cancel();
          await LocalStorage.clearActiveRide();
          final bill = RidePricing.calculate(_seconds);
          final cleanSegments = RouteSanitizer.sanitizeSegments(_routeSegments);
          final cleanPoints = RouteSanitizer.flatten(cleanSegments);
          final rideData = <String, dynamic>{
            'rideMode': widget.rideMode,
            'durationSeconds': _seconds,
            'distanceKm': _effectiveDistance,
            'avgSpeed': _avg,
            'maxSpeed': _maxSpeed,
            'calories': _calories.round(),
            'elevation': _elevation.round(),
            'billTotal': bill.total,
            'billSubtotal': bill.subtotal,
            'billBaseFare': bill.baseFare,
            'billExtra': bill.extraCharge,
            'billCancelFee': bill.cancelFee,
            'billGst': bill.gst,
            'billLabel': bill.label,
            'paidWithCoin': widget.paidWithCoin,
            'bikeId': _bikeId,
            'isEBike': widget.isEBike,
            'routeSegments': cleanSegments
                .map(
                  (segment) => segment
                      .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                      .toList(),
                )
                .toList(),
            'routePoints': cleanPoints
                .map((p) => {'lat': p.latitude, 'lng': p.longitude})
                .toList(),
            'startTimeMs': _rideStartMs,
            'endTimeMs': DateTime.now().millisecondsSinceEpoch,
            if (serverId.isNotEmpty) 'tripId': serverId,
          };

          // Shared bike: deduct from wallet & track loyalty (skip if coin ride)
          if (widget.rideMode == 0 && !widget.paidWithCoin) {
            final current = LocalStorage.getWalletBalance();
            await LocalStorage.saveWalletBalance(
              (current - bill.total).clamp(0, double.infinity),
            );
            final coinAwarded = await LocalStorage.recordWalletRide();
            rideData['loyaltyCoinAwarded'] = coinAwarded;
          }

          if (mounted) {
            context.go('/ride/summary', extra: rideData);
          }
        },
      ),
    );
  }

  double _asDouble(dynamic value) => (value as num?)?.toDouble() ?? 0.0;

  double? _asNullableDouble(dynamic value) => (value as num?)?.toDouble();

  List<LatLng> get _routePoints =>
      RouteSanitizer.flatten(RouteSanitizer.sanitizeSegments(_routeSegments));

  double _resolveEffectiveDistance() {
    final routeDistance = RouteSanitizer.distanceKm(_routeSegments);
    if (routeDistance <= 0) return _distance;

    final inflatedByOutlier =
        _distance > routeDistance + 1.0 && _distance > routeDistance * 2.0;
    if (inflatedByOutlier) {
      return routeDistance;
    }
    return _distance;
  }

  void _sanitizeRouteState() {
    final cleaned = RouteSanitizer.sanitizeSegments(_routeSegments);
    final originalPointCount = _routeSegments
        .expand((segment) => segment)
        .length;
    final cleanedPointCount = cleaned.expand((segment) => segment).length;
    final routeDistance = RouteSanitizer.distanceKm(cleaned);

    if (cleanedPointCount != originalPointCount) {
      _routeSegments
        ..clear()
        ..addAll(cleaned);
      _routePointTimestamps
        ..clear()
        ..addAll(List.generate(cleanedPointCount, (_) => DateTime.now()));
      _syncedRoutePointCount = math.min(
        _syncedRoutePointCount,
        cleanedPointCount,
      );
      _rebuildSmoothedRouteSegments();
    }

    if (routeDistance > 0 &&
        _distance > routeDistance + 1.0 &&
        _distance > routeDistance * 2.0) {
      _distance = routeDistance;
      _recalculateDerivedMetrics();
    }
  }

  List<List<LatLng>> _restoreRouteSegments(
    dynamic rawSegments, {
    dynamic fallbackPoints,
  }) {
    final segments = <List<LatLng>>[];
    if (rawSegments is List) {
      for (final segment in rawSegments) {
        final restored = _restorePointList(segment);
        if (restored.isNotEmpty) {
          segments.add(restored);
        }
      }
    }
    if (segments.isNotEmpty) {
      return RouteSanitizer.sanitizeSegments(segments);
    }

    final fallback = _restorePointList(fallbackPoints);
    if (fallback.isEmpty) return const [];
    return RouteSanitizer.sanitizeSegments([fallback]);
  }

  List<LatLng> _restorePointList(dynamic raw) {
    if (raw is! List) return const [];
    final points = <LatLng>[];
    for (final entry in raw) {
      if (entry is! Map) continue;
      final lat = (entry['lat'] as num?)?.toDouble();
      final lng = (entry['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final point = LatLng(lat, lng);
      if (RouteSanitizer.isValidPoint(point)) {
        points.add(point);
      }
    }
    return points;
  }

  void _appendRoutePoint(LatLng point) {
    if (_routeSegments.isEmpty) {
      final seed = _currentPosition;
      final shouldSeedStart =
          RouteSanitizer.isValidPoint(seed) &&
          !RouteSanitizer.isFallbackPoint(seed);
      if (shouldSeedStart) {
        final seedGap = _distanceCalculator.as(LengthUnit.Meter, seed, point);
        if (seedGap >= _minRoutePointDistanceMeters &&
            seedGap <= _maxDirectPolylineSegmentMeters) {
          _routeSegments.add([seed, point]);
          _routePointTimestamps
            ..add(DateTime.now())
            ..add(DateTime.now());
        } else {
          _routeSegments.add([point]);
          _routePointTimestamps.add(DateTime.now());
        }
      } else {
        _routeSegments.add([point]);
        _routePointTimestamps.add(DateTime.now());
      }
      _rebuildSmoothedRouteSegments();
      return;
    }
    final lastPoint = _routeSegments.last.last;
    final delta = _distanceCalculator.as(LengthUnit.Meter, lastPoint, point);
    if (delta < _minRoutePointDistanceMeters) {
      return;
    }
    if (delta > _maxDirectPolylineSegmentMeters) {
      _startNewRouteSegment(point);
      return;
    }
    _routeSegments.last.add(point);
    _routePointTimestamps.add(DateTime.now());
    _rebuildSmoothedRouteSegments();
  }

  void _startNewRouteSegment(LatLng point) {
    _routeSegments.add([point]);
    _routePointTimestamps.add(DateTime.now());
    _rebuildSmoothedRouteSegments();
  }

  void _scheduleRouteSync() {
    unawaited(_syncRouteToServer());
  }

  Future<void> _syncRouteToServer() async {
    if (_isSyncingRoute) return;
    _isSyncingRoute = true;
    try {
      var serverId = LocalStorage.getActiveRideServerId();
      if (serverId == null || serverId.isEmpty) {
        serverId = await _ensureServerRideStarted();
      }
      if (serverId == null || serverId.isEmpty) return;

      final points = _routePoints;
      if (_syncedRoutePointCount > points.length) {
        _syncedRoutePointCount = 0;
      }

      // Batch sync: collect all unsynced points and send in one request
      if (_syncedRoutePointCount < points.length) {
        final unsyncedPoints = <LocationBatchPoint>[];
        for (int i = _syncedRoutePointCount; i < points.length; i++) {
          final point = points[i];
          final ts = i < _routePointTimestamps.length
              ? _routePointTimestamps[i]
              : DateTime.now();
          unsyncedPoints.add(
            LocationBatchPoint(
              lat: point.latitude,
              lng: point.longitude,
              timestamp: ts,
            ),
          );
        }

        final repo = RideRepositoryImpl(ApiClient());
        try {
          await repo.batchUpdateLocations(serverId, unsyncedPoints);
          _syncedRoutePointCount = points.length;
        } catch (_) {
          // Batch failed — fall back to single-point sync for remaining
          while (_syncedRoutePointCount < points.length) {
            final point = points[_syncedRoutePointCount];
            try {
              await repo.updateRideLocation(
                serverId,
                point.latitude,
                point.longitude,
              );
            } catch (_) {
              break; // Stop on first failure, will retry next sync
            }
            _syncedRoutePointCount += 1;
          }
        }
        _persistRideState();
      }
    } catch (_) {
      // Keep local tracking active even if the network drops temporarily.
    } finally {
      _isSyncingRoute = false;
    }
  }

  double _resolveHeading(double rawHeading, {double? fallback}) {
    if (rawHeading.isFinite && rawHeading >= 0) {
      return rawHeading % 360;
    }
    return fallback ?? 0;
  }

  void _recalculateDerivedMetrics() {
    _calories = _estimateCalories(
      averageSpeedKmh: _avg,
      movingSeconds: _movingSecondsCapped,
      weightKg: _riderWeightKg,
    );
  }

  double _estimateCalories({
    required double averageSpeedKmh,
    required double movingSeconds,
    required double weightKg,
  }) {
    // Require a real ride distance so GPS-jitter / restored moving-time can't
    // produce phantom calories while the rider is effectively stationary.
    if (averageSpeedKmh <= 0 ||
        movingSeconds <= 0 ||
        _effectiveDistance < _minRealRideDistanceKm) {
      return 0.0;
    }

    final hours = movingSeconds / 3600.0;
    double met;
    if (averageSpeedKmh < 16) {
      met = 4.0;
    } else if (averageSpeedKmh < 19) {
      met = 6.8;
    } else if (averageSpeedKmh < 22) {
      met = 8.0;
    } else {
      met = 10.0;
    }
    return met * weightKg * hours;
  }

  void _showRidePersistenceError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
      body: Column(
        children: [
          // ── Map (top 45%) ──────────────────────────────────────────────
          Expanded(
            flex: 45,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: _currentPosition,
                    initialZoom: 16,
                    interactionOptions: const InteractionOptions(
                      flags:
                          InteractiveFlag.pinchZoom |
                          InteractiveFlag.drag |
                          InteractiveFlag.doubleTapZoom,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: isDark
                          ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                          : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
                      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.newtra.app',
                    ),
                    if (_routeSegments.any((segment) => segment.length > 1))
                      PolylineLayer(
                        polylines: [
                          // Shadow / glow layer for depth
                          ...(_smoothedRouteSegments.isNotEmpty
                                  ? _smoothedRouteSegments
                                  : _routeSegments)
                              .where((segment) => segment.length > 1)
                              .map(
                                (segment) => Polyline(
                                  points: segment,
                                  color: AppColors.primary.withValues(
                                    alpha: 0.18,
                                  ),
                                  strokeWidth: 8,
                                ),
                              ),
                          // Main route line
                          ...(_smoothedRouteSegments.isNotEmpty
                                  ? _smoothedRouteSegments
                                  : _routeSegments)
                              .where((segment) => segment.length > 1)
                              .map(
                                (segment) => Polyline(
                                  points: segment,
                                  color: AppColors.primary,
                                  strokeWidth: 4.5,
                                  strokeCap: StrokeCap.round,
                                  strokeJoin: StrokeJoin.round,
                                ),
                              ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _displayPosition,
                          width: 46,
                          height: 46,
                          child: Transform.rotate(
                            angle: _displayHeading * math.pi / 180,
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.primary,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.35,
                                    ),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.18),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.navigation_rounded,
                                size: 18.w,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const RichAttributionWidget(
                      attributions: [
                        TextSourceAttribution('OpenStreetMap contributors'),
                        TextSourceAttribution('CARTO'),
                      ],
                    ),
                  ],
                ),
                // ── Newtra logo overlay (covers Google Maps watermark) ──
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1A1A1A).withValues(alpha: 0.95)
                          : Colors.white.withValues(alpha: 0.95),
                    ),
                    child: SvgPicture.asset(
                      AppAssets.fullLogoForTheme(isDark),
                      height: 16.h,
                    ),
                  ),
                ),
                // Back button top-left
                SafeArea(
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: GestureDetector(
                      onTap: () => context.go('/home'),
                      child: Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.darkCard.withValues(alpha: 0.9)
                              : AppColors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 15.w,
                          color: isDark ? AppColors.white : AppColors.grey800,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Dashboard (bottom 55%) ─────────────────────────────────────
          Expanded(
            flex: 55,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.grey50,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                child: Column(
                  children: [
                    SizedBox(height: 8.h),
                    Center(
                      child: Container(
                        width: 36.w,
                        height: 4.h,
                        decoration: BoxDecoration(
                          color: AppColors.grey300,
                          borderRadius: BorderRadius.circular(2.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),

                    // ── Shared bike card ────────────────────────────────
                    if (_isSharedBike) ...[
                      _buildBikeCard(isDark),
                      SizedBox(height: 12.h),
                    ],

                    // ── Timer + speed ───────────────────────────────────
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        vertical: 16.h,
                        horizontal: 16.w,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkCard : AppColors.white,
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: isDark ? 0.20 : 0.05,
                            ),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Duration',
                                  style: TextStyle(
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.grey500,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  _fmt(_seconds),
                                  style: TextStyle(
                                    fontSize: 38.sp,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1,
                                    color: isDark
                                        ? AppColors.white
                                        : AppColors.grey900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 72.w,
                            height: 72.w,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.09),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.22,
                                ),
                                width: 1.5,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    _currentSpeed.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 18.sp,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                Text(
                                  'km/h',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: AppColors.grey500,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // ── Stats row 1 ─────────────────────────────────────
                    Row(
                      children: [
                        _statCard(
                          icon: Icons.straighten_rounded,
                          label: 'Distance',
                          value: _effectiveDistance.toStringAsFixed(2),
                          unit: 'km',
                          color: AppColors.distance,
                          isDark: isDark,
                        ),
                        SizedBox(width: 8.w),
                        _statCard(
                          icon: Icons.speed_rounded,
                          label: 'Avg Speed',
                          value: _avg.toStringAsFixed(1),
                          unit: 'km/h',
                          color: AppColors.speed,
                          isDark: isDark,
                        ),
                        SizedBox(width: 8.w),
                        _statCard(
                          icon: Icons.local_fire_department_rounded,
                          label: 'Calories',
                          value: _calories.toStringAsFixed(0),
                          unit: 'cal',
                          color: AppColors.calories,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    SizedBox(height: 8.h),

                    // ── Stats row 2 ─────────────────────────────────────
                    Row(
                      children: [
                        _statCard(
                          icon: Icons.terrain_rounded,
                          label: 'Elevation',
                          value: _elevation.toStringAsFixed(1),
                          unit: 'm',
                          color: AppColors.elevation,
                          isDark: isDark,
                        ),
                        SizedBox(width: 8.w),
                        _statCard(
                          icon: Icons.eco_rounded,
                          label: 'CO2 Saved',
                          value: (_effectiveDistance * 0.21).toStringAsFixed(2),
                          unit: 'kg',
                          color: AppColors.success,
                          isDark: isDark,
                        ),
                        SizedBox(width: 8.w),
                        _statCard(
                          icon: Icons.bolt_rounded,
                          label: 'XP Earned',
                          value:
                              '${(_effectiveDistance * (_isSharedBike ? 10 : 7)).toInt()}',
                          unit: 'XP',
                          color: AppColors.warning,
                          isDark: isDark,
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),

                    // ── Controls ────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              final nowMs =
                                  DateTime.now().millisecondsSinceEpoch;
                              setState(() {
                                _isPaused = !_isPaused;
                                if (_isPaused) {
                                  _trackingService.pause();
                                  _pausedAtMs = nowMs;
                                  _currentSpeed = 0;
                                } else {
                                  _trackingService.resume();
                                  final pauseDuration = nowMs - _pausedAtMs;
                                  _rideStartMs += pauseDuration;
                                  _lastReferenceAt =
                                      DateTime.fromMillisecondsSinceEpoch(
                                        nowMs,
                                      );
                                }
                              });
                              _persistRideState();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkCard
                                    : AppColors.white,
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: _isPaused
                                      ? AppColors.primary
                                      : AppColors.warning,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    _isPaused
                                        ? Icons.play_arrow_rounded
                                        : Icons.pause_rounded,
                                    size: 20.w,
                                    color: _isPaused
                                        ? AppColors.primary
                                        : AppColors.warning,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    _isPaused ? 'Resume' : 'Pause',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _isPaused
                                          ? AppColors.primary
                                          : AppColors.warning,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              _showEndRideSheet();
                            },
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(16.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.error.withValues(
                                      alpha: 0.28,
                                    ),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.stop_rounded,
                                    size: 20.w,
                                    color: AppColors.white,
                                  ),
                                  SizedBox(width: 6.w),
                                  Text(
                                    'End Ride',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Shared bike card ─────────────────────────────────────────────────────

  Widget _buildBikeCard(bool isDark) {
    final batteryColor = _batteryPct > 50
        ? AppColors.success
        : _batteryPct > 20
        ? AppColors.warning
        : AppColors.error;
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 86.w,
            height: 70.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.primary.withValues(alpha: 0.04),
                ],
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.directions_bike_rounded,
                  size: 40.w,
                  color: AppColors.primary,
                ),
                if (_isEBike)
                  Positioned(
                    right: 8.w,
                    top: 8.h,
                    child: Container(
                      padding: EdgeInsets.all(3.w),
                      decoration: BoxDecoration(
                        color: batteryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.electric_bolt_rounded,
                        size: 10.w,
                        color: batteryColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Bike $_bikeId',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 7.w,
                        vertical: 3.h,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        _isEBike ? 'E-Bike' : 'Regular Bike',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                if (_isEBike) ...[
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Icon(
                              Icons.battery_charging_full_rounded,
                              size: 13.w,
                              color: batteryColor,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              'Battery',
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.grey500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '$_batteryPct%',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: batteryColor,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3.r),
                    child: LinearProgressIndicator(
                      value: _batteryPct / 100,
                      minHeight: 6.h,
                      backgroundColor: isDark
                          ? AppColors.darkElevated
                          : AppColors.grey200,
                      valueColor: AlwaysStoppedAnimation<Color>(batteryColor),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    '~${(_batteryPct * 0.5).toStringAsFixed(0)} km remaining',
                    style: TextStyle(fontSize: 10.sp, color: AppColors.grey500),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Stat card ────────────────────────────────────────────────────────────

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 10.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28.w,
              height: 28.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8.r),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 14.w, color: color),
            ),
            SizedBox(height: 8.h),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: value,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                    TextSpan(
                      text: ' $unit',
                      style: TextStyle(
                        fontSize: 9.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.grey400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 9.5.sp,
                color: AppColors.grey500,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── End Ride Confirmation Sheet ───────────────────────────────────────────────

class _EndRideSheet extends StatefulWidget {
  final double distanceKm;
  final String durationText;
  final double calories;
  final VoidCallback onConfirmed;
  const _EndRideSheet({
    required this.distanceKm,
    required this.durationText,
    required this.calories,
    required this.onConfirmed,
  });

  @override
  State<_EndRideSheet> createState() => _EndRideSheetState();
}

class _EndRideSheetState extends State<_EndRideSheet> {
  double _drag = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxDrag = MediaQuery.of(context).size.width - 160.w;
    final progress = (_drag / maxDrag).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 32.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Top accent bar ─────────────────────────────────────────
          Container(
            height: 5.h,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFE53935), Color(0xFFFF7043)],
              ),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32.r)),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : AppColors.grey200,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 22.h),

                // ── Icon + title ────────────────────────────────────
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 60.w,
                      height: 60.w,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.flag_rounded,
                        size: 28.w,
                        color: AppColors.white,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                Text(
                  'End Your Ride?',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.white : AppColors.grey900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Your stats will be saved and you\'ll\nsee a full summary of your ride.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.grey500,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 28.h),

                // ── Quick stats strip ───────────────────────────────
                Container(
                  padding: EdgeInsets.symmetric(
                    vertical: 14.h,
                    horizontal: 16.w,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : AppColors.grey50,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.grey200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _quickStat(
                        Icons.straighten_rounded,
                        '${widget.distanceKm.toStringAsFixed(2)} km',
                        'Distance',
                        AppColors.distance,
                        isDark,
                      ),
                      _vertDivider(isDark),
                      _quickStat(
                        Icons.timer_rounded,
                        widget.durationText,
                        'Duration',
                        AppColors.speed,
                        isDark,
                      ),
                      _vertDivider(isDark),
                      _quickStat(
                        Icons.local_fire_department_rounded,
                        widget.calories.toStringAsFixed(0),
                        'Calories',
                        AppColors.calories,
                        isDark,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // ── Slide to end ────────────────────────────────────
                Container(
                  height: 60.h,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Progress fill
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30.r),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppColors.error.withValues(alpha: 0.20),
                                      AppColors.error.withValues(alpha: 0.05),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Label
                      Center(
                        child: AnimatedOpacity(
                          opacity: progress > 0.3 ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            'Slide to end ride',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error.withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                      // Thumb
                      Positioned(
                        left: 4 + _drag,
                        top: 5,
                        bottom: 5,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (d) {
                            setState(() {
                              _drag = (_drag + d.delta.dx).clamp(0.0, maxDrag);
                            });
                          },
                          onHorizontalDragEnd: (_) {
                            if (_drag >= maxDrag * 0.75) {
                              widget.onConfirmed();
                            } else {
                              setState(() => _drag = 0);
                            }
                          },
                          child: Container(
                            width: 50.w,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE53935), Color(0xFFFF7043)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(25.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error.withValues(
                                    alpha: 0.45,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.double_arrow_rounded,
                              size: 22.w,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 14.h),

                // ── Keep riding button ──────────────────────────────
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 13.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkElevated
                          : AppColors.grey100,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Keep Riding',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.grey300 : AppColors.grey700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStat(
    IconData icon,
    String value,
    String label,
    Color color,
    bool isDark,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16.w, color: color),
        SizedBox(height: 5.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.white : AppColors.grey900,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: AppColors.grey500),
        ),
      ],
    );
  }

  Widget _vertDivider(bool isDark) {
    return Container(
      width: 1,
      height: 36.h,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.07),
    );
  }
}
