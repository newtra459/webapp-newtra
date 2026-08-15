import '../models/trip_model.dart';

abstract class TripRepository {
  Future<List<TripModel>> getTrips({String? filter});
  Future<TripModel> getTripDetail(String tripId);
}
