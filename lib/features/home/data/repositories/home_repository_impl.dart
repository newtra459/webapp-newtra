import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/station_model.dart';
import 'home_repository.dart';

class HomeRepositoryImpl implements HomeRepository {
  final ApiClient _api;

  HomeRepositoryImpl(this._api);

  @override
  Future<List<StationModel>> getNearbyStations(double lat, double lng) async {
    try {
      final res = await _api.get(ApiEndpoints.stations.nearby, queryParameters: {
        'latitude': lat.toString(),
        'longitude': lng.toString(),
      });
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final list = root['data'] as List? ?? [];
      return list.map((e) => StationModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      // Fallback: try getting all stations
      try {
        final res = await _api.get(ApiEndpoints.stations.list);
        final root = (res.data is Map<String, dynamic>)
            ? (res.data as Map<String, dynamic>)
            : <String, dynamic>{};
        final list = root['data'] as List? ?? [];
        return list.map((e) => StationModel.fromJson(e as Map<String, dynamic>)).toList();
      } catch (_) {
        return [];
      }
    }
  }
}
