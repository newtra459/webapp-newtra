import 'package:latlong2/latlong.dart';

class RouteSanitizer {
  RouteSanitizer._();

  static const LatLng fallbackMapCenter = LatLng(17.4577, 78.2753);
  static const double fallbackToleranceMeters = 25.0;
  static const double minPointDeltaMeters = 0.5;
  static const double maxContiguousSegmentMeters = 250.0;

  static const Distance _distance = Distance();

  static bool isValidPoint(LatLng point) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180 &&
        !(point.latitude == 0 && point.longitude == 0);
  }

  static bool isFallbackPoint(LatLng point) {
    if (!isValidPoint(point)) return false;
    return _distance.as(LengthUnit.Meter, fallbackMapCenter, point) <=
        fallbackToleranceMeters;
  }

  static List<List<LatLng>> sanitizeSegments(
    List<List<LatLng>> segments, {
    double maxSegmentMeters = maxContiguousSegmentMeters,
  }) {
    final hasRealPoint = segments
        .expand((segment) => segment)
        .any((point) => isValidPoint(point) && !isFallbackPoint(point));
    final cleanedSegments = <List<LatLng>>[];

    for (final segment in segments) {
      var currentSegment = <LatLng>[];

      for (final point in segment) {
        if (!isValidPoint(point)) continue;
        if (hasRealPoint && isFallbackPoint(point)) continue;

        if (currentSegment.isEmpty) {
          currentSegment = [point];
          continue;
        }

        final gapMeters = _distance.as(
          LengthUnit.Meter,
          currentSegment.last,
          point,
        );
        if (gapMeters < minPointDeltaMeters) continue;

        if (gapMeters > maxSegmentMeters) {
          if (currentSegment.isNotEmpty) {
            cleanedSegments.add(currentSegment);
          }
          currentSegment = [point];
          continue;
        }

        currentSegment.add(point);
      }

      if (currentSegment.isNotEmpty) {
        cleanedSegments.add(currentSegment);
      }
    }

    return cleanedSegments;
  }

  static List<LatLng> flatten(List<List<LatLng>> segments) {
    return segments.expand((segment) => segment).toList(growable: false);
  }

  static double distanceKm(List<List<LatLng>> segments) {
    var meters = 0.0;
    for (final segment in sanitizeSegments(segments)) {
      for (var i = 1; i < segment.length; i++) {
        meters += _distance.as(LengthUnit.Meter, segment[i - 1], segment[i]);
      }
    }
    return meters / 1000.0;
  }
}
