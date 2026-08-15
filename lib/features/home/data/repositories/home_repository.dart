import '../models/station_model.dart';

abstract class HomeRepository {
  Future<List<StationModel>> getNearbyStations(double lat, double lng);
}
