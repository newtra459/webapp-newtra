// ── Graph data point from /user/distance_travelled, /user/calories_burned, etc.
class GraphDataPoint {
  final String date;
  final String dayOfWeek;
  final double value;

  const GraphDataPoint({
    required this.date,
    required this.dayOfWeek,
    required this.value,
  });

  factory GraphDataPoint.fromJson(Map<String, dynamic> json, String valueKey) {
    return GraphDataPoint(
      date: json['date'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? '',
      value: (json[valueKey] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ActivitySummary {
  final int totalTrips;
  final double totalDistance;
  final int totalDurationMin;
  final double totalCalories;
  final double totalCo2;
  final double avgSpeed;
  final double maxSpeed;
  final double totalElevation;
  final double rideTimeHours;
  final int currentStreakDays;
  final int groupsCount;
  final int followersCount;
  final int followingCount;
  final Map<String, List<double>> weeklyData;
  final Map<String, List<double>> monthlyData;

  const ActivitySummary({
    this.totalTrips = 0,
    this.totalDistance = 0.0,
    this.totalDurationMin = 0,
    this.totalCalories = 0.0,
    this.totalCo2 = 0.0,
    this.avgSpeed = 0.0,
    this.maxSpeed = 0.0,
    this.totalElevation = 0.0,
    this.rideTimeHours = 0.0,
    this.currentStreakDays = 0,
    this.groupsCount = 0,
    this.followersCount = 0,
    this.followingCount = 0,
    this.weeklyData = const {},
    this.monthlyData = const {},
  });

  static Map<String, List<double>> _parseChartMap(dynamic raw) {
    if (raw is! Map) return {};
    return raw.map((k, v) {
      final List<double> list = v is List
          ? v.map((e) => (e as num).toDouble()).toList()
          : <double>[];
      return MapEntry(k.toString(), list);
    });
  }

  factory ActivitySummary.fromJson(Map<String, dynamic> json) {
    final averages = (json['averages'] is Map<String, dynamic>)
        ? (json['averages'] as Map<String, dynamic>)
        : <String, dynamic>{};
    final totalTrips = (json['total_trips'] as num?)?.toInt() ?? 0;
    final avgDistKm = (averages['distance_km'] as num?)?.toDouble() ?? 0.0;

    return ActivitySummary(
      totalTrips: totalTrips,
      totalDistance: json['total_distance'] != null
          ? (json['total_distance'] as num).toDouble()
          : avgDistKm * totalTrips,
      totalDurationMin: json['total_duration_min'] != null
          ? (json['total_duration_min'] as num).toInt()
          : ((json['total_time_hours'] as num?)?.toDouble() ?? 0.0) * 60 ~/ 1,
      totalCalories: (json['total_calories'] as num?)?.toDouble() ?? 0.0,
      totalCo2: json['total_co2'] != null
          ? (json['total_co2'] as num).toDouble()
          : (json['carbon_footprint_kg'] as num?)?.toDouble() ?? 0.0,
      avgSpeed: json['avg_speed'] != null
          ? (json['avg_speed'] as num).toDouble()
          : (averages['speed_kmh'] as num?)?.toDouble() ?? 0.0,
      weeklyData: _parseChartMap(json['weekly_data']),
      monthlyData: _parseChartMap(json['monthly_data']),
    );
  }

  /// Build from /user/profile/{id} summary response
  factory ActivitySummary.fromProfileOverview(Map<String, dynamic> summary, {
    Map<String, dynamic>? social,
    Map<String, List<double>>? weeklyData,
  }) {
    final rideHours = (summary['ride_time_hours'] as num?)?.toDouble() ?? 0.0;
    return ActivitySummary(
      totalTrips: (summary['total_trips'] as num?)?.toInt() ?? 0,
      totalDistance: (summary['total_distance_km'] as num?)?.toDouble() ?? 0.0,
      totalDurationMin: (rideHours * 60).toInt(),
      totalCalories: (summary['total_calories'] as num?)?.toDouble() ?? 0.0,
      totalCo2: (summary['co2_saved_kg'] as num?)?.toDouble() ?? 0.0,
      avgSpeed: (summary['average_speed_kmh'] as num?)?.toDouble() ?? 0.0,
      maxSpeed: (summary['max_speed_kmh'] as num?)?.toDouble() ?? 0.0,
      totalElevation: (summary['total_elevation_m'] as num?)?.toDouble() ?? 0.0,
      rideTimeHours: rideHours,
      currentStreakDays: (summary['current_streak_days'] as num?)?.toInt() ?? 0,
      groupsCount: (summary['groups_count'] as num?)?.toInt() ?? 0,
      followersCount: (social?['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (social?['following_count'] as num?)?.toInt() ?? 0,
      weeklyData: weeklyData ?? const {},
    );
  }
}

// ── Activity Feed Event ───────────────────────────────────────────────────────

class ActivityFeedEvent {
  final String id;
  final String type;        // 'ride' | 'bus' | 'buggy' | 'badge' | 'streak'
  final String title;
  final String description;
  final String timestamp;   // ISO-8601
  final double? distance;
  final int? durationMin;
  final double? calories;
  final int? coinsEarned;
  final String? iconUrl;

  const ActivityFeedEvent({
    this.id = '',
    this.type = '',
    this.title = '',
    this.description = '',
    this.timestamp = '',
    this.distance,
    this.durationMin,
    this.calories,
    this.coinsEarned,
    this.iconUrl,
  });

  factory ActivityFeedEvent.fromJson(Map<String, dynamic> json) {
    return ActivityFeedEvent(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] as String? ?? '',
      distance: (json['distance'] as num?)?.toDouble(),
      durationMin: (json['duration_min'] as num?)?.toInt(),
      calories: (json['calories'] as num?)?.toDouble(),
      coinsEarned: (json['coins_earned'] as num?)?.toInt(),
      iconUrl: json['icon_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'description': description,
        'timestamp': timestamp,
        'distance': distance,
        'duration_min': durationMin,
        'calories': calories,
        'coins_earned': coinsEarned,
        'icon_url': iconUrl,
      };
}
