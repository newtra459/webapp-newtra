// Dummy data mock — swap back to ActivityRepositoryImpl in activity_provider.dart
// when the backend /activity endpoints are live.

import '../models/activity_model.dart';
import 'activity_repository.dart';

class ActivityRepositoryMock implements ActivityRepository {
  static final ActivitySummary _weekSummary = ActivitySummary(
    totalTrips: 14,
    totalDistance: 38.4,
    totalDurationMin: 210,
    totalCalories: 920.5,
    totalCo2: 7.2,
    avgSpeed: 11.0,
    weeklyData: {
      'trips':    [2, 3, 0, 2, 3, 2, 2],
      'distance': [4.2, 6.1, 0.0, 5.8, 7.3, 8.1, 6.9],
      'calories': [98.0, 142.0, 0.0, 135.0, 172.0, 189.0, 184.5],
      'duration': [24.0, 34.0, 0.0, 31.0, 39.0, 43.0, 39.0],
      'co2':      [0.8, 1.2, 0.0, 1.1, 1.4, 1.5, 1.2],
      'speed':    [10.5, 10.8, 0.0, 11.2, 11.2, 11.3, 10.6],
    },
    monthlyData: {
      'trips':    [12, 16, 10, 14],
      'distance': [32.0, 41.5, 29.8, 38.4],
      'calories': [745.0, 960.0, 690.0, 920.5],
      'duration': [178.0, 228.0, 163.0, 210.0],
      'co2':      [6.1, 7.9, 5.7, 7.2],
      'speed':    [10.8, 10.9, 11.0, 11.0],
    },
  );

  static final ActivitySummary _monthSummary = ActivitySummary(
    totalTrips: 52,
    totalDistance: 141.7,
    totalDurationMin: 779,
    totalCalories: 3316.0,
    totalCo2: 26.8,
    avgSpeed: 10.9,
    weeklyData: {
      'trips':    [12, 16, 10, 14],
      'distance': [32.0, 41.5, 29.8, 38.4],
      'calories': [745.0, 960.0, 690.0, 920.5],
      'duration': [178.0, 228.0, 163.0, 210.0],
      'co2':      [6.1, 7.9, 5.7, 7.2],
      'speed':    [10.8, 10.9, 11.0, 11.0],
    },
    monthlyData: {
      'trips':    [12, 16, 10, 14],
      'distance': [32.0, 41.5, 29.8, 38.4],
      'calories': [745.0, 960.0, 690.0, 920.5],
      'duration': [178.0, 228.0, 163.0, 210.0],
      'co2':      [6.1, 7.9, 5.7, 7.2],
      'speed':    [10.8, 10.9, 11.0, 11.0],
    },
  );

  static final ActivitySummary _threeMonthSummary = ActivitySummary(
    totalTrips: 148,
    totalDistance: 412.3,
    totalDurationMin: 2263,
    totalCalories: 9640.0,
    totalCo2: 78.1,
    avgSpeed: 10.9,
    weeklyData: {
      'trips':    [14, 16, 12, 10, 15, 16, 13, 16, 13, 14, 9, 0],
      'distance': [38.4, 42.1, 35.8, 29.3, 41.7, 43.8, 37.2, 44.1, 36.9, 40.2, 22.8, 0.0],
      'calories': [920.5, 980.0, 836.0, 680.0, 988.0, 1020.0, 856.0, 1040.0, 862.0, 932.0, 525.0, 0.0],
      'duration': [210.0, 230.0, 196.0, 160.0, 228.0, 240.0, 204.0, 242.0, 202.0, 220.0, 131.0, 0.0],
      'co2':      [7.2, 8.0, 6.8, 5.6, 7.9, 8.3, 7.1, 8.4, 7.0, 7.6, 4.2, 0.0],
      'speed':    [11.0, 11.0, 11.0, 11.0, 11.0, 10.9, 10.9, 10.9, 11.0, 11.0, 10.4, 0.0],
    },
    monthlyData: {
      'trips':    [52, 54, 42],
      'distance': [141.7, 148.2, 122.4],
      'calories': [3316.0, 3480.0, 2844.0],
      'duration': [779.0, 812.0, 672.0],
      'co2':      [26.8, 28.1, 23.2],
      'speed':    [10.9, 10.9, 10.9],
    },
  );

  static final ActivitySummary _yearSummary = ActivitySummary(
    totalTrips: 589,
    totalDistance: 1647.0,
    totalDurationMin: 9042,
    totalCalories: 38512.0,
    totalCo2: 312.5,
    avgSpeed: 10.9,
    weeklyData: {
      'trips':    [42, 34, 40, 52, 48, 42, 38, 47, 52, 44, 37, 64],
      'distance': [120.0, 98.0, 115.0, 141.7, 138.2, 122.4, 109.8, 135.0, 148.5, 127.3, 106.2, 184.9],
      'calories': [2800.0, 2280.0, 2688.0, 3316.0, 3226.0, 2844.0, 2552.0, 3150.0, 3462.0, 2970.0, 2472.0, 4312.0],
      'duration': [660.0, 538.0, 632.0, 779.0, 758.0, 672.0, 604.0, 742.0, 816.0, 700.0, 584.0, 1016.0],
      'co2':      [22.8, 18.6, 21.9, 26.8, 26.2, 23.2, 20.9, 25.6, 28.2, 24.2, 20.2, 35.1],
      'speed':    [10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9],
    },
    monthlyData: {
      'trips':    [42, 34, 40, 52, 48, 42, 38, 47, 52, 44, 37, 64],
      'distance': [120.0, 98.0, 115.0, 141.7, 138.2, 122.4, 109.8, 135.0, 148.5, 127.3, 106.2, 184.9],
      'calories': [2800.0, 2280.0, 2688.0, 3316.0, 3226.0, 2844.0, 2552.0, 3150.0, 3462.0, 2970.0, 2472.0, 4312.0],
      'duration': [660.0, 538.0, 632.0, 779.0, 758.0, 672.0, 604.0, 742.0, 816.0, 700.0, 584.0, 1016.0],
      'co2':      [22.8, 18.6, 21.9, 26.8, 26.2, 23.2, 20.9, 25.6, 28.2, 24.2, 20.2, 35.1],
      'speed':    [10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9, 10.9],
    },
  );

  static final List<ActivityFeedEvent> _feedPage1 = [
    const ActivityFeedEvent(
      id: 'af-01',
      type: 'ride',
      title: 'Morning Ride',
      description: 'Main Gate → Library Hub',
      timestamp: '2026-03-19T07:32:00Z',
      distance: 0.5,
      durationMin: 4,
      calories: 18.0,
      coinsEarned: 5,
    ),
    const ActivityFeedEvent(
      id: 'af-02',
      type: 'badge',
      title: '🏅 Early Bird unlocked!',
      description: 'Completed 5 rides before 8 AM',
      timestamp: '2026-03-19T07:36:00Z',
      coinsEarned: 50,
    ),
    const ActivityFeedEvent(
      id: 'af-03',
      type: 'bus',
      title: 'Campus Bus',
      description: 'Route R2 · Hostel Block C → Admin Block',
      timestamp: '2026-03-18T09:10:00Z',
      durationMin: 12,
      coinsEarned: 3,
    ),
    const ActivityFeedEvent(
      id: 'af-04',
      type: 'ride',
      title: 'Evening Ride',
      description: 'Sports Complex → Hostel Block C',
      timestamp: '2026-03-18T18:45:00Z',
      distance: 1.3,
      durationMin: 11,
      calories: 43.0,
      coinsEarned: 12,
    ),
    const ActivityFeedEvent(
      id: 'af-05',
      type: 'streak',
      title: '🔥 7-Day Streak!',
      description: 'You rode every day this week',
      timestamp: '2026-03-17T20:00:00Z',
      coinsEarned: 100,
    ),
    const ActivityFeedEvent(
      id: 'af-06',
      type: 'buggy',
      title: 'Campus Buggy',
      description: 'Route B1 · Library → Research Park',
      timestamp: '2026-03-17T14:22:00Z',
      durationMin: 8,
      coinsEarned: 3,
    ),
    const ActivityFeedEvent(
      id: 'af-07',
      type: 'ride',
      title: 'Lunch Ride',
      description: 'Research Park → Admin Block',
      timestamp: '2026-03-17T12:55:00Z',
      distance: 0.8,
      durationMin: 7,
      calories: 27.0,
      coinsEarned: 8,
    ),
    const ActivityFeedEvent(
      id: 'af-08',
      type: 'ride',
      title: 'Campus Loop',
      description: 'Main Gate → Sports Complex → Library Hub',
      timestamp: '2026-03-16T16:10:00Z',
      distance: 2.1,
      durationMin: 18,
      calories: 68.5,
      coinsEarned: 21,
    ),
  ];

  static final List<ActivityFeedEvent> _feedPage2 = [
    const ActivityFeedEvent(
      id: 'af-09',
      type: 'ride',
      title: 'Morning Commute',
      description: 'Hostel Block C → Library Hub',
      timestamp: '2026-03-15T08:05:00Z',
      distance: 0.7,
      durationMin: 6,
      calories: 23.0,
      coinsEarned: 7,
    ),
    const ActivityFeedEvent(
      id: 'af-10',
      type: 'bus',
      title: 'Campus Bus',
      description: 'Route R1 · Main Gate → Research Park',
      timestamp: '2026-03-14T10:20:00Z',
      durationMin: 15,
      coinsEarned: 3,
    ),
    const ActivityFeedEvent(
      id: 'af-11',
      type: 'ride',
      title: 'Afternoon Ride',
      description: 'Library Hub → Sports Complex',
      timestamp: '2026-03-13T17:30:00Z',
      distance: 1.6,
      durationMin: 14,
      calories: 52.0,
      coinsEarned: 15,
    ),
    const ActivityFeedEvent(
      id: 'af-12',
      type: 'badge',
      title: '🌟 Connected unlocked!',
      description: 'Followed 5 fellow riders',
      timestamp: '2026-03-12T19:45:00Z',
      coinsEarned: 75,
    ),
    const ActivityFeedEvent(
      id: 'af-13',
      type: 'buggy',
      title: 'Campus Buggy',
      description: 'Route B1 · Admin Block → Hostel Block C',
      timestamp: '2026-03-12T20:05:00Z',
      durationMin: 10,
      coinsEarned: 5,
    ),
    const ActivityFeedEvent(
      id: 'af-14',
      type: 'ride',
      title: 'Morning Ride',
      description: 'Main Gate → Hostel Block A',
      timestamp: '2026-03-11T07:15:00Z',
      distance: 1.8,
      durationMin: 16,
      calories: 58.0,
      coinsEarned: 18,
    ),
    const ActivityFeedEvent(
      id: 'af-15',
      type: 'ride',
      title: 'Quick Commute',
      description: 'Sports Complex → Library Hub',
      timestamp: '2026-03-10T18:20:00Z',
      distance: 1.1,
      durationMin: 10,
      calories: 36.0,
      coinsEarned: 11,
    ),
    const ActivityFeedEvent(
      id: 'af-16',
      type: 'bus',
      title: 'Campus Bus',
      description: 'Route R2 · Library Hub → Admin Block',
      timestamp: '2026-03-09T13:45:00Z',
      durationMin: 14,
      coinsEarned: 3,
    ),
    const ActivityFeedEvent(
      id: 'af-17',
      type: 'streak',
      title: '🔥 3-Day Streak Active!',
      description: 'Keep it up - 7 more days to go!',
      timestamp: '2026-03-08T10:00:00Z',
      coinsEarned: 25,
    ),
    const ActivityFeedEvent(
      id: 'af-18',
      type: 'ride',
      title: 'Evening Commute',
      description: 'Hostel Block B → Main Gate',
      timestamp: '2026-03-08T09:00:00Z',
      distance: 1.9,
      durationMin: 17,
      calories: 62.0,
      coinsEarned: 19,
    ),
  ];

  static List<GraphDataPoint> _graphFrom(List<double> values) {
    return List.generate(
      values.length,
      (index) => GraphDataPoint(
        date: '2026-03-${(index + 1).toString().padLeft(2, '0')}',
        dayOfWeek: 'Day ${index + 1}',
        value: values[index],
      ),
    );
  }

  @override
  Future<ActivitySummary> getSummary({String period = 'week'}) async {
    await Future.delayed(const Duration(milliseconds: 500));
    return switch (period) {
      'month' => _monthSummary,
      '3m'    => _threeMonthSummary,
      'year'  => _yearSummary,
      _       => _weekSummary,
    };
  }

  @override
  Future<List<ActivityFeedEvent>> getFeed({int page = 1}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return page == 1 ? _feedPage1 : _feedPage2;
  }

  @override
  Future<Map<String, dynamic>> getUserProfileOverview(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return {
      'summary': {
        'total_trips': _weekSummary.totalTrips,
        'total_distance_km': _weekSummary.totalDistance,
        'total_calories': _weekSummary.totalCalories,
        'co2_saved_kg': _weekSummary.totalCo2,
        'average_speed_kmh': _weekSummary.avgSpeed,
        'ride_time_hours': _weekSummary.totalDurationMin / 60,
      },
      'social': {
        'followers_count': 0,
        'following_count': 0,
      },
    };
  }

  @override
  Future<List<GraphDataPoint>> getDistanceGraph(
    String startDate,
    String endDate,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _graphFrom(_weekSummary.weeklyData['distance'] ?? const []);
  }

  @override
  Future<List<GraphDataPoint>> getCaloriesGraph(
    String startDate,
    String endDate,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _graphFrom(_weekSummary.weeklyData['calories'] ?? const []);
  }

  @override
  Future<List<GraphDataPoint>> getTimeGraph(
    String startDate,
    String endDate,
  ) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _graphFrom(_weekSummary.weeklyData['duration'] ?? const []);
  }
}
