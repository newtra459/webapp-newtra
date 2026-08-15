import '../models/transit_model.dart';

abstract class TransitRepository {
  /// GET /transit/stops — Stops near the user.
  /// [type]   — 'bus' | 'buggy' (omit for both)
  /// [search] — optional stop/route name filter
  Future<List<TransitStopModel>> getNearbyStops({String? type, String? search});

  /// POST /transit/trips/board — QR-board a vehicle; starts a trip.
  /// [vehicleId] — scanned vehicle identifier
  /// [stopId]    — stop the user is boarding from
  Future<TransitTripModel> boardVehicle({
    required String vehicleId,
    required String stopId,
  });

  /// GET /transit/trips/active — Currently active trip (null if none).
  Future<TransitTripModel?> getActiveTrip();

  /// POST /transit/trips/:tripId/end — End an active trip.
  Future<TransitTripModel> endTrip(String tripId);
}
