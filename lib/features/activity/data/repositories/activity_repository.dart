import '../models/activity_model.dart';

abstract class ActivityRepository {
  /// GET /activity/summary — Riding stats for a given period.
  /// [period] — 'day' | 'week' | 'month' | 'year'
  Future<ActivitySummary> getSummary({String period = 'week'});

  /// GET /activity/feed — Paginated event log.
  /// [page] — 1-based page number (default 1)
  Future<List<ActivityFeedEvent>> getFeed({int page = 1});

  /// GET /user/profile/{userId} — Full profile overview with summary stats
  Future<Map<String, dynamic>> getUserProfileOverview(String userId);

  /// GET /user/distance_travelled/{start}/{end}
  Future<List<GraphDataPoint>> getDistanceGraph(String startDate, String endDate);

  /// GET /user/calories_burned/{start}/{end}
  Future<List<GraphDataPoint>> getCaloriesGraph(String startDate, String endDate);

  /// GET /user/time_travelled/{start}/{end}
  Future<List<GraphDataPoint>> getTimeGraph(String startDate, String endDate);
}
