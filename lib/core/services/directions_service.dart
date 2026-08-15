import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart';

/// Fetches a road-following route between two points for the map directions
/// preview line.
///
/// Uses the public OSRM routing server and degrades gracefully — it returns an
/// empty list when routing is unavailable, so callers can fall back to drawing
/// a straight line between the two points.
class DirectionsService {
  DirectionsService({Dio? dio, String? baseUrl})
      : _dio = dio ?? Dio(),
        _baseUrl = baseUrl ?? 'https://router.project-osrm.org';

  final Dio _dio;
  final String _baseUrl;

  /// Returns the ordered road-following coordinates from [from] to [to], or an
  /// empty list when no route could be resolved.
  Future<List<LatLng>> getRoute(
    LatLng from,
    LatLng to, {
    String profile = 'driving',
  }) async {
    try {
      // OSRM expects lng,lat;lng,lat
      final coords =
          '${from.longitude},${from.latitude};${to.longitude},${to.latitude}';
      final res = await _dio.get(
        '$_baseUrl/route/v1/$profile/$coords',
        queryParameters: const {
          'overview': 'full',
          'geometries': 'geojson',
        },
        options: Options(
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      final data = res.data;
      if (data is! Map || data['code'] != 'Ok') return const [];

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return const [];

      final geometry = (routes.first as Map)['geometry'] as Map?;
      final coordinates = geometry?['coordinates'] as List?;
      if (coordinates == null || coordinates.isEmpty) return const [];

      final points = <LatLng>[];
      for (final c in coordinates) {
        if (c is List && c.length >= 2) {
          // GeoJSON is [lng, lat]
          points.add(LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()));
        }
      }
      return points;
    } catch (_) {
      return const [];
    }
  }
}
