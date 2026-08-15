import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

// ─── Configuration ──────────────────────────────────────────────────────────────

/// Configuration for the route-snapping service.
class RouteSnappingConfig {
  /// OSRM server base URL (no trailing slash).
  /// For self-hosted: e.g. 'http://your-server:5000'
  /// For the EV backend proxy: e.g. 'https://ev-api.aks2.mellob.in/v1'
  final String osrmBaseUrl;

  /// OSRM profile: 'cycling', 'driving', 'walking'.
  final String profile;

  /// Maximum points per OSRM match request (API limit is 100).
  final int maxPointsPerRequest;

  /// GPS accuracy radius hint for OSRM (meters).
  /// Higher values make OSRM more lenient in matching.
  final double defaultRadiusMeters;

  /// Minimum number of raw points before attempting a snap request.
  final int minPointsForSnap;

  /// Timeout for OSRM requests.
  final Duration requestTimeout;

  /// Whether to include timestamps in the match request (improves accuracy).
  final bool includeTimestamps;

  const RouteSnappingConfig({
    this.osrmBaseUrl = 'https://ev-api.aks2.mellob.in/v1',
    this.profile = 'cycling',
    this.maxPointsPerRequest = 100,
    this.defaultRadiusMeters = 10.0,
    this.minPointsForSnap = 3,
    this.requestTimeout = const Duration(seconds: 12),
    this.includeTimestamps = true,
  });
}

// ─── Data Models ────────────────────────────────────────────────────────────────

/// A raw GPS point with metadata for OSRM matching.
class GpsTrackPoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final double accuracyMeters;
  final double? speedKmh;
  final double? elevation;

  const GpsTrackPoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    this.accuracyMeters = 10.0,
    this.speedKmh,
    this.elevation,
  });
}

/// Result of an OSRM map-match operation.
class SnapResult {
  /// Road-snapped polyline coordinates.
  final List<LatLng> snappedPolyline;

  /// Actual road distance in meters (follows road geometry).
  final double roadDistanceMeters;

  /// Average confidence (0.0–1.0) of the match.
  final double confidence;

  /// Number of raw input points.
  final int inputPointCount;

  /// Number of output snapped points.
  final int outputPointCount;

  /// Duration of the matched route in seconds (from OSRM).
  final double? durationSeconds;

  const SnapResult({
    required this.snappedPolyline,
    required this.roadDistanceMeters,
    required this.confidence,
    required this.inputPointCount,
    required this.outputPointCount,
    this.durationSeconds,
  });

  /// Empty result when snapping is unavailable.
  static const SnapResult empty = SnapResult(
    snappedPolyline: [],
    roadDistanceMeters: 0,
    confidence: 0,
    inputPointCount: 0,
    outputPointCount: 0,
  );

  bool get isEmpty => snappedPolyline.isEmpty;
  bool get isNotEmpty => snappedPolyline.isNotEmpty;
}

// ─── Route Snapping Service ─────────────────────────────────────────────────────

/// Service that snaps raw GPS traces to the road network via OSRM Match API.
///
/// Can be used in two modes:
/// 1. **Post-ride** (recommended): Feed all collected GPS points after the ride
///    ends to get a clean, road-snapped polyline for the trip summary.
/// 2. **Incremental** (optional): Feed batches of points during the ride for
///    progressive snapping while the user is riding.
///
/// Falls back gracefully to raw GPS polyline when OSRM is unreachable.
class RouteSnappingService {
  final RouteSnappingConfig config;
  final Dio _dio;

  RouteSnappingService({
    this.config = const RouteSnappingConfig(),
    Dio? dio,
  }) : _dio = dio ?? Dio();

  /// Snap a full GPS trace to the road network.
  ///
  /// This is the primary method — use it when the ride ends to get the
  /// definitive road-snapped polyline.
  ///
  /// If the trace has more than [config.maxPointsPerRequest] points, it
  /// is automatically split into overlapping batches and the results are
  /// stitched together.
  Future<SnapResult> snapTrace(List<GpsTrackPoint> trace) async {
    if (trace.length < config.minPointsForSnap) {
      return SnapResult.empty;
    }

    try {
      if (trace.length <= config.maxPointsPerRequest) {
        return await _matchBatch(trace);
      }

      // Split into overlapping batches of maxPointsPerRequest with 5-point overlap
      return await _matchMultiBatch(trace);
    } catch (e) {
      // Graceful degradation — return raw points as fallback
      return _fallbackFromRaw(trace);
    }
  }

  /// Snap a batch of recent GPS points (for incremental/real-time use).
  ///
  /// Returns [SnapResult.empty] if the batch is too small or OSRM is down.
  Future<SnapResult> snapBatch(List<GpsTrackPoint> batch) async {
    if (batch.length < config.minPointsForSnap) {
      return SnapResult.empty;
    }

    try {
      return await _matchBatch(batch);
    } catch (_) {
      return SnapResult.empty;
    }
  }

  /// Check if the OSRM service is reachable.
  Future<bool> isAvailable() async {
    try {
      // Simple health check — request a trivial match
      final response = await _dio.get(
        '${config.osrmBaseUrl}/match/v1/${config.profile}/0,0;0,0',
        options: Options(
          sendTimeout: const Duration(seconds: 3),
          receiveTimeout: const Duration(seconds: 3),
        ),
      );
      // OSRM returns 200 even for unroutable — we just check connectivity
      return response.statusCode != null && response.statusCode! < 500;
    } catch (_) {
      return false;
    }
  }

  // ── Private: OSRM Match API ────────────────────────────────────────────────

  /// Send a single batch to OSRM Match API and parse the response.
  Future<SnapResult> _matchBatch(List<GpsTrackPoint> points) async {
    // Build coordinate string: lng,lat;lng,lat;...
    final coords = points
        .map((p) => '${p.lng.toStringAsFixed(6)},${p.lat.toStringAsFixed(6)}')
        .join(';');

    // Build radiuses parameter (accuracy hint for each point)
    final radiuses = points
        .map((p) => math.max(p.accuracyMeters, 5.0).toStringAsFixed(0))
        .join(';');

    // Build query parameters
    final queryParams = <String, dynamic>{
      'overview': 'full',
      'geometries': 'geojson',
      'radiuses': radiuses,
      'gaps': 'ignore',
      'annotations': 'true',
    };

    // Add timestamps if configured and available
    if (config.includeTimestamps) {
      final timestamps = points
          .map((p) => (p.timestamp.millisecondsSinceEpoch / 1000).round())
          .join(';');
      queryParams['timestamps'] = timestamps;
    }

    final url =
        '${config.osrmBaseUrl}/match/v1/${config.profile}/$coords';

    final response = await _dio.get(
      url,
      queryParameters: queryParams,
      options: Options(
        sendTimeout: config.requestTimeout,
        receiveTimeout: config.requestTimeout,
      ),
    );

    if (response.statusCode != 200 || response.data is! Map<String, dynamic>) {
      throw Exception('OSRM returned ${response.statusCode}');
    }

    return _parseMatchResponse(response.data as Map<String, dynamic>, points.length);
  }

  /// Parse the OSRM Match API response into a [SnapResult].
  SnapResult _parseMatchResponse(Map<String, dynamic> data, int inputCount) {
    final code = data['code'] as String? ?? '';
    if (code != 'Ok') {
      return _emptyWithCount(inputCount);
    }

    final matchings = data['matchings'] as List<dynamic>?;
    if (matchings == null || matchings.isEmpty) {
      return _emptyWithCount(inputCount);
    }

    // Combine all matchings into a single polyline
    final allPoints = <LatLng>[];
    double totalDistance = 0;
    double totalDuration = 0;
    double confidenceSum = 0;

    for (final matching in matchings) {
      if (matching is! Map<String, dynamic>) continue;

      final geometry = matching['geometry'] as Map<String, dynamic>?;
      if (geometry == null) continue;

      final coordinates = geometry['coordinates'] as List<dynamic>?;
      if (coordinates == null) continue;

      for (final coord in coordinates) {
        if (coord is List && coord.length >= 2) {
          // GeoJSON is [lng, lat]
          allPoints.add(LatLng(
            (coord[1] as num).toDouble(),
            (coord[0] as num).toDouble(),
          ));
        }
      }

      totalDistance += (matching['distance'] as num?)?.toDouble() ?? 0;
      totalDuration += (matching['duration'] as num?)?.toDouble() ?? 0;
      confidenceSum += (matching['confidence'] as num?)?.toDouble() ?? 0;
    }

    if (allPoints.isEmpty) {
      return _emptyWithCount(inputCount);
    }

    return SnapResult(
      snappedPolyline: allPoints,
      roadDistanceMeters: totalDistance,
      confidence: matchings.isNotEmpty ? confidenceSum / matchings.length : 0,
      inputPointCount: inputCount,
      outputPointCount: allPoints.length,
      durationSeconds: totalDuration > 0 ? totalDuration : null,
    );
  }

  /// Split a large trace into overlapping batches and stitch results.
  Future<SnapResult> _matchMultiBatch(List<GpsTrackPoint> trace) async {
    const overlapCount = 5;
    final batchSize = config.maxPointsPerRequest;
    final batches = <List<GpsTrackPoint>>[];

    int start = 0;
    while (start < trace.length) {
      final end = math.min(start + batchSize, trace.length);
      batches.add(trace.sublist(start, end));
      start = end - overlapCount;
      if (start < 0) start = 0;
      if (end >= trace.length) break;
    }

    final results = <SnapResult>[];
    for (final batch in batches) {
      try {
        final result = await _matchBatch(batch);
        if (result.isNotEmpty) {
          results.add(result);
        }
      } catch (_) {
        // Skip failed batches, continue with next
      }
    }

    if (results.isEmpty) {
      return _fallbackFromRaw(trace);
    }

    // Stitch results: remove overlapping points between consecutive batches
    final stitched = <LatLng>[];
    double totalDistance = 0;
    double totalDuration = 0;
    double totalConfidence = 0;

    for (int i = 0; i < results.length; i++) {
      final result = results[i];
      totalDistance += result.roadDistanceMeters;
      totalDuration += result.durationSeconds ?? 0;
      totalConfidence += result.confidence;

      if (i == 0) {
        stitched.addAll(result.snappedPolyline);
      } else {
        // Find the best join point — skip first few points of this batch
        // that overlap with the previous batch
        final overlapPoints = math.min(10, result.snappedPolyline.length ~/ 3);
        if (result.snappedPolyline.length > overlapPoints) {
          stitched.addAll(result.snappedPolyline.sublist(overlapPoints));
        } else {
          stitched.addAll(result.snappedPolyline);
        }
      }
    }

    return SnapResult(
      snappedPolyline: stitched,
      roadDistanceMeters: totalDistance,
      confidence: results.isNotEmpty ? totalConfidence / results.length : 0,
      inputPointCount: trace.length,
      outputPointCount: stitched.length,
      durationSeconds: totalDuration > 0 ? totalDuration : null,
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  SnapResult _emptyWithCount(int inputCount) => SnapResult(
        snappedPolyline: const [],
        roadDistanceMeters: 0,
        confidence: 0,
        inputPointCount: inputCount,
        outputPointCount: 0,
      );

  /// Create a fallback result from raw GPS points (no road snapping).
  SnapResult _fallbackFromRaw(List<GpsTrackPoint> trace) {
    if (trace.isEmpty) return SnapResult.empty;

    const Distance distCalc = Distance();
    final points = trace.map((p) => LatLng(p.lat, p.lng)).toList();
    double totalDistance = 0;

    for (int i = 1; i < points.length; i++) {
      totalDistance += distCalc.as(LengthUnit.Meter, points[i - 1], points[i]);
    }

    return SnapResult(
      snappedPolyline: points,
      roadDistanceMeters: totalDistance,
      confidence: 0, // zero confidence = raw fallback
      inputPointCount: trace.length,
      outputPointCount: points.length,
    );
  }
}
