import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/activity_model.dart';
import 'activity_repository.dart';

class ActivityRepositoryImpl implements ActivityRepository {
  final ApiClient _api;

  ActivityRepositoryImpl(this._api);

  @override
  Future<ActivitySummary> getSummary({String period = 'week'}) async {
    // Primary: use /user/profile/{uid} for comprehensive summary
    try {
      final userRes = await _api.get('/user/me');
      final userData = userRes.data['data'] as Map<String, dynamic>? ?? {};
      final uid = userData['uid'] as String? ?? '';

      if (uid.isNotEmpty) {
        final profileRes = await _api.get('/user/profile/$uid');
        final profileData = profileRes.data['data'] as Map<String, dynamic>? ?? {};
        final summary = profileData['summary'] as Map<String, dynamic>? ?? {};
        final social = profileData['social'] as Map<String, dynamic>? ?? {};

        // Fetch weekly distance data for the activity strip
        Map<String, List<double>>? weeklyData;
        try {
          final now = DateTime.now();
          final weekStart = now.subtract(Duration(days: now.weekday - 1));
          final startStr = _formatDate(weekStart);
          final endStr = _formatDate(now);
          final distData = await getDistanceGraph(startStr, endStr);
          weeklyData = _buildWeeklyMap(distData);
        } catch (_) {}

        return ActivitySummary.fromProfileOverview(
          summary,
          social: social,
          weeklyData: weeklyData,
        );
      }
    } catch (_) {}

    // Fallback: use /user/me for basic stats
    try {
      final userRes = await _api.get('/user/me');
      final userData = userRes.data['data'] as Map<String, dynamic>? ?? {};
      final trips = (userData['trips_count'] as num?)?.toInt() ?? 0;
      final distance = (userData['distance'] as num?)?.toDouble() ?? 0.0;
      return ActivitySummary(
        totalTrips: trips,
        totalDistance: distance,
        totalCo2: distance * 0.21,
      );
    } catch (_) {}

    return const ActivitySummary();
  }

  /// Build weekly distance map keyed by day name (Mon-Sun), 7 values
  Map<String, List<double>> _buildWeeklyMap(List<GraphDataPoint> points) {
    // Map day_of_week names to index 0=Mon .. 6=Sun
    const dayOrder = {
      'Monday': 0, 'Tuesday': 1, 'Wednesday': 2, 'Thursday': 3,
      'Friday': 4, 'Saturday': 5, 'Sunday': 6,
    };
    final values = List.filled(7, 0.0);
    for (final p in points) {
      final idx = dayOrder[p.dayOfWeek];
      if (idx != null) values[idx] = p.value;
    }
    return {'distance': values};
  }

  String _formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Future<List<ActivityFeedEvent>> getFeed({int page = 1}) async {
    final res = await _api.get(
      ApiEndpoints.activity.feed,
      queryParameters: {'page': page},
    );
    final list = res.data['data'] as List? ?? [];
    return list
        .map((e) => ActivityFeedEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getUserProfileOverview(String userId) async {
    final res = await _api.get('/user/profile/$userId');
    return res.data['data'] as Map<String, dynamic>? ?? {};
  }

  @override
  Future<List<GraphDataPoint>> getDistanceGraph(String startDate, String endDate) async {
    final res = await _api.get(ApiEndpoints.activity.distanceTravelled(startDate, endDate));
    final data = res.data['data'] as List? ?? [];
    return data.map((e) => GraphDataPoint.fromJson(e as Map<String, dynamic>, 'distance')).toList();
  }

  @override
  Future<List<GraphDataPoint>> getCaloriesGraph(String startDate, String endDate) async {
    final res = await _api.get(ApiEndpoints.activity.caloriesBurned(startDate, endDate));
    final data = res.data['data'] as List? ?? [];
    return data.map((e) => GraphDataPoint.fromJson(e as Map<String, dynamic>, 'calories')).toList();
  }

  @override
  Future<List<GraphDataPoint>> getTimeGraph(String startDate, String endDate) async {
    final res = await _api.get(ApiEndpoints.activity.timeTravelled(startDate, endDate));
    final data = res.data['data'] as List? ?? [];
    return data.map((e) => GraphDataPoint.fromJson(e as Map<String, dynamic>, 'time_travelled')).toList();
  }
}
