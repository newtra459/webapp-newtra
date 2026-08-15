import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/transit_model.dart';
import 'transit_repository.dart';

class TransitRepositoryImpl implements TransitRepository {
  final ApiClient _api;

  TransitRepositoryImpl(this._api);

  @override
  Future<List<TransitStopModel>> getNearbyStops({
    String? type,
    String? search,
  }) async {
    final params = <String, dynamic>{};
    if (type != null) params['type'] = type;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final res = await _api.get(ApiEndpoints.transit.stops, queryParameters: params);
    final list = res.data['data'] as List? ?? [];
    return list
        .map((e) => TransitStopModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<TransitTripModel> boardVehicle({
    required String vehicleId,
    required String stopId,
  }) async {
    final res = await _api.post(
      ApiEndpoints.transit.board,
      data: {'vehicle_id': vehicleId, 'stop_id': stopId},
    );
    return TransitTripModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }

  @override
  Future<TransitTripModel?> getActiveTrip() async {
    final res = await _api.get(ApiEndpoints.transit.activeTrip);
    final data = res.data['data'];
    if (data == null) return null;
    return TransitTripModel.fromJson(data as Map<String, dynamic>);
  }

  @override
  Future<TransitTripModel> endTrip(String tripId) async {
    final res = await _api.post(ApiEndpoints.transit.endTrip(tripId));
    return TransitTripModel.fromJson(res.data['data'] as Map<String, dynamic>);
  }
}
