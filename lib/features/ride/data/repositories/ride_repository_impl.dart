import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/ride_model.dart';
import 'ride_repository.dart';

class RideRepositoryImpl implements RideRepository {
  final ApiClient _api;

  RideRepositoryImpl(this._api);

  @override
  Future<void> validateBike(String bikeId) async {
    await _api.get(ApiEndpoints.bikes.detail(bikeId));
  }

  RideModel _toRideModel(
    dynamic raw, {
    int? fallbackRideMode,
    bool? fallbackIsEBike,
  }) {
    final root = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
    final data = (root['data'] is Map<String, dynamic>)
        ? (root['data'] as Map<String, dynamic>)
        : root;

    final merged = <String, dynamic>{
      ...data,
      if (data['id'] == null && data['trip_id'] != null) 'id': data['trip_id'],
      if (data['id'] == null && root['trip_id'] != null) 'id': root['trip_id'],
      if (fallbackRideMode != null && data['ride_mode'] == null)
        'ride_mode': fallbackRideMode,
      if (fallbackIsEBike != null && data['is_ebike'] == null)
        'is_ebike': fallbackIsEBike,
    };

    return RideModel.fromJson(merged);
  }

  @override
  Future<RideModel?> getActiveRide() async {
    try {
      final res = await _api.get(ApiEndpoints.trips.active);
      return _toRideModel(res.data);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<RideModel> startRide({
    required String bikeId,
    required int rideMode,
    bool isEBike = true,
  }) async {
    // Backend expects: station_id, bike_id, personal
    // rideMode 0 = station bike, rideMode 1 = personal bike
    final res = await _api.post(
      ApiEndpoints.ride.start,
      data: {'bike_id': bikeId, 'station_id': '', 'personal': rideMode == 1},
    );
    return _toRideModel(
      res.data,
      fallbackRideMode: rideMode,
      fallbackIsEBike: isEBike,
    );
  }

  @override
  Future<RideModel> endRide(
    String rideId, {
    bool personal = false,
    double distance = 0,
    double duration = 0,
    double averageSpeed = 0,
    double kcal = 0,
    double maxElevation = 0,
  }) async {
    // Backend expects metrics in the POST body for trips/end/{tripId}
    final res = await _api.post(
      ApiEndpoints.ride.end(rideId),
      data: {
        'personal': personal,
        'distance': distance,
        'duration': duration,
        'average_speed': averageSpeed,
        'kcal': kcal.round(),
        'max_elevation': maxElevation,
      },
    );
    // The backend returns HTTP 200 with {success:false} when it can't finalize
    // the trip; treat that as a failure so the caller doesn't clear the active
    // ride while it is still 'active' on the server.
    final root = res.data;
    if (root is Map && root['success'] == false) {
      throw Exception(
        (root['message'] ?? 'Failed to end ride').toString(),
      );
    }
    return _toRideModel(res.data);
  }

  @override
  Future<void> updateRideLocation(
    String rideId,
    double lat,
    double lng, {
    double elevation = 0,
  }) async {
    // Backend expects TripLocationPath struct via PUT: lat, long, elevation
    await _api.put(
      ApiEndpoints.ride.updateLocation(rideId),
      data: {'lat': lat, 'long': lng, 'elevation': elevation},
    );
  }

  @override
  Future<void> batchUpdateLocations(
    String rideId,
    List<LocationBatchPoint> points,
  ) async {
    if (points.isEmpty) return;

    // Send all points in a single request to the batch endpoint.
    // Falls back to sequential single-point updates if batch endpoint
    // is not available.
    try {
      await _api.put(
        ApiEndpoints.ride.batchUpdateLocations(rideId),
        data: {'points': points.map((p) => p.toJson()).toList()},
      );
    } catch (_) {
      // Fallback: send points one by one (existing endpoint)
      for (final point in points) {
        try {
          await updateRideLocation(
            rideId,
            point.lat,
            point.lng,
            elevation: point.elevation,
          );
        } catch (_) {
          // Continue even if individual points fail
        }
      }
    }
  }

  @override
  Future<List<List<double>>?> getSnappedRoute(String tripId) async {
    try {
      final res = await _api.get(ApiEndpoints.trips.snappedRoute(tripId));
      final root = res.data is Map<String, dynamic>
          ? res.data as Map<String, dynamic>
          : <String, dynamic>{};
      final data = root['data'];

      if (data is List && data.isNotEmpty) {
        final route = <List<double>>[];
        for (final point in data) {
          if (point is Map<String, dynamic>) {
            final lat = (point['lat'] as num?)?.toDouble();
            final lng =
                (point['long'] as num?)?.toDouble() ??
                (point['lng'] as num?)?.toDouble();
            if (lat != null && lng != null) {
              route.add([lat, lng]);
            }
          }
        }
        return route.isNotEmpty ? route : null;
      }
    } catch (_) {
      // Snapped route not available yet — not an error
    }
    return null;
  }
}
