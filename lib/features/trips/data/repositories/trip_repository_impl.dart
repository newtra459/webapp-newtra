import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/trip_model.dart';
import 'trip_repository.dart';

class TripRepositoryImpl implements TripRepository {
  final ApiClient _api;

  TripRepositoryImpl(this._api);

  TripModel _toTripModel(Map<String, dynamic> input) {
    // Backend Trip fields: id, user_id, bike_id, station_id,
    // start_timestamp, end_timestamp, distance (num), duration (num),
    // average_speed (num), path (list), max_elevation (num), kcal (num),
    // status, access_mode, subscription_id
    final mapped = <String, dynamic>{
      ...input,
      if (input['id'] == null && input['trip_id'] != null) 'id': input['trip_id'],
      // Map backend field names to TripModel expected names
      if (input['date'] == null)
        'date': input['start_timestamp'] as String? ??
            input['end_timestamp'] as String? ??
            input['created_at'] as String? ?? '',
      if (input['start_time'] == null)
        'start_time': input['start_timestamp'] as String? ??
            input['start_at'] as String? ?? '',
      if (input['end_time'] == null)
        'end_time': input['end_timestamp'] as String? ??
            input['end_at'] as String? ?? '',
      // Distance: backend returns number, TripModel expects string
      if (input['distance'] is num)
        'distance': '${(input['distance'] as num).toStringAsFixed(2)} km',
      // Duration: backend returns number (seconds? hours?), TripModel expects string
      if (input['duration'] is num)
        'duration': _formatDuration(input['duration'] as num),
      // Speed
      if (input['avg_speed'] == null && input['average_speed'] != null)
        'avg_speed': '${input['average_speed']}',
      // Calories
      if (input['calories'] == null && input['kcal'] != null)
        'calories': '${input['kcal']}',
      // Elevation
      if (input['elevation'] == null && input['max_elevation'] != null)
        'elevation': '${input['max_elevation']}',
      // CO2 saved estimate
      if (input['co2'] == null && input['distance'] is num)
        'co2': '${((input['distance'] as num) * 0.21).toStringAsFixed(1)}',
      // Station names for from/to
      if (input['from'] == null && input['start_station_name'] != null)
        'from': input['start_station_name'],
      if (input['to'] == null && input['end_station_name'] != null)
        'to': input['end_station_name'],
      // Type mapping
      if (input['type'] == null)
        'type': input['access_mode'] as String? ??
            input['mode'] as String? ?? 'cycle',
      // Payment type
      if (input['payment_type'] == null)
        'payment_type': input['subscription_id'] != null &&
                (input['subscription_id'] as String).isNotEmpty
            ? 'subscription'
            : (input['access_mode'] == 'personal' ? 'own_bike' : 'paid'),
    };
    return TripModel.fromJson(mapped);
  }

  String _formatDuration(num value) {
    // Backend returns duration as a number - could be hours or minutes
    if (value < 100) {
      // Likely hours
      final hours = value.toInt();
      final minutes = ((value - hours) * 60).toInt();
      if (hours > 0) return '${hours}h ${minutes}m';
      return '${minutes}m';
    }
    // Likely seconds
    final totalMinutes = (value / 60).round();
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  List<Map<String, dynamic>> _extractTripList(dynamic raw) {
    final root = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
    final data = root['data'];
    if (data is List) {
      return data.whereType<Map<String, dynamic>>().toList();
    }
    if (data is Map<String, dynamic>) {
      final list = data['items'] ?? data['trips'];
      if (list is List) {
        return list.whereType<Map<String, dynamic>>().toList();
      }
    }
    final list = root['items'] ?? root['trips'];
    if (list is List) {
      return list.whereType<Map<String, dynamic>>().toList();
    }
    return const [];
  }

  Map<String, dynamic> _extractTripDetail(dynamic raw) {
    final root = (raw is Map<String, dynamic>) ? raw : <String, dynamic>{};
    final data = root['data'];
    if (data is Map<String, dynamic>) return data;
    return root;
  }

  @override
  Future<List<TripModel>> getTrips({String? filter}) async {
    final params = <String, dynamic>{
      'limit': '100',
      'order': 'desc',
      'sort_by': 'start_timestamp',
    };
    if (filter != null) params['type'] = filter;
    final res = await _api.get(ApiEndpoints.trips.list, queryParameters: params);
    final list = _extractTripList(res.data);
    return list.map(_toTripModel).toList();
  }

  @override
  Future<TripModel> getTripDetail(String tripId) async {
    final res = await _api.get(ApiEndpoints.trips.detail(tripId));
    final detail = _extractTripDetail(res.data);
    return _toTripModel(detail);
  }
}
