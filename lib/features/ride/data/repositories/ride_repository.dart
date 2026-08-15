import '../models/ride_model.dart';

/// Data class for a batch location point.
class LocationBatchPoint {
  final double lat;
  final double lng;
  final double elevation;
  final DateTime timestamp;

  const LocationBatchPoint({
    required this.lat,
    required this.lng,
    this.elevation = 0,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'lat': lat,
    'long': lng,
    'elevation': elevation,
    'timestamp': timestamp.toIso8601String(),
  };
}

abstract class RideRepository {
  Future<void> validateBike(String bikeId);
  Future<RideModel?> getActiveRide();
  Future<RideModel> startRide({
    required String bikeId,
    required int rideMode,
    bool isEBike = true,
  });
  Future<RideModel> endRide(
    String rideId, {
    bool personal = false,
    double distance = 0,
    double duration = 0,
    double averageSpeed = 0,
    double kcal = 0,
    double maxElevation = 0,
  });
  Future<void> updateRideLocation(
    String rideId,
    double lat,
    double lng, {
    double elevation = 0,
  });

  /// Send a batch of location points to the server in a single request.
  /// More efficient than individual updateRideLocation calls.
  Future<void> batchUpdateLocations(
    String rideId,
    List<LocationBatchPoint> points,
  );

  /// Retrieve the road-snapped route for a completed trip.
  /// Returns null if snapped route is not yet available.
  Future<List<List<double>>?> getSnappedRoute(String tripId);
}
