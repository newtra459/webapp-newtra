import 'dart:math';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/achievement_model.dart';
import 'achievements_repository.dart';

/// Client-side achievements computation matching the React Native implementation.
/// Achievements are NOT fetched from a backend endpoint — they are computed
/// from trip summary metrics and user profile data.
class AchievementsRepositoryImpl implements AchievementsRepository {
  final ApiClient _api;

  AchievementsRepositoryImpl(this._api);

  @override
  Future<List<AchievementModel>> getAchievements() async {
    // Fetch trip summary and user details in parallel
    final results = await Future.wait([
      _fetchTripSummary(),
      _fetchUserDetails(),
    ]);
    final tripSummary = results[0] as Map<String, dynamic>;
    final user = results[1] as Map<String, dynamic>;

    // Extract metrics matching RN's AchievementMetrics
    final tripsCount = _num(tripSummary['total_trips'] ?? user['trips']);
    final totalDistance = _num(tripSummary['distance_km'] ??
        tripSummary['total_distance'] ??
        user['distance']);
    final co2Saved = _num(tripSummary['carbon_footprint_kg'] ??
        (totalDistance * 0.21));
    final followersCount = _num(user['followers_count'] ?? user['followers']);
    final followingCount = _num(user['following_count']);
    final groupsCount = _num(user['group_count'] ?? user['groups_count'] ?? user['groups']);
    final highestSpeed = _num(tripSummary['highest_speed'] ??
        tripSummary['top_speed'] ??
        user['top_speed']);
    final morningRides = _num(tripSummary['morning_rides'] ?? user['morning_rides']);
    final longestStreakDays = _num(tripSummary['longest_streak'] ?? user['longest_streak']);
    final currentStreakDays = _num(tripSummary['current_streak'] ?? user['current_streak']);
    final streakDays = max(longestStreakDays, currentStreakDays).toDouble();

    // Build achievements with same logic as RN's buildAchievements
    return [
      _achievement(
        id: 'ach-01',
        title: 'First Ride',
        description: 'Complete your very first ride.',
        category: 'riding',
        icon: 'bike',
        colorHex: '#6C63FF',
        progress: _clamp(tripsCount, 1),
        thresholdLabel: 'Complete 1 ride',
      ),
      _achievement(
        id: 'ach-02',
        title: 'Century Rider',
        description: 'Ride a total of 100 km on campus.',
        category: 'riding',
        icon: 'medal',
        colorHex: '#FF6584',
        progress: _clamp(totalDistance, 100),
        thresholdLabel: 'Ride 100 km',
      ),
      _achievement(
        id: 'ach-03',
        title: 'Speed Demon',
        description: 'Reach a top speed of 25 km/h.',
        category: 'riding',
        icon: 'zap',
        colorHex: '#FFB300',
        progress: _clamp(highestSpeed, 25),
        thresholdLabel: 'Hit 25 km/h',
      ),
      _achievement(
        id: 'ach-04',
        title: 'Distance King',
        description: 'Ride 500 km in total.',
        category: 'riding',
        icon: 'crown',
        colorHex: '#43A047',
        progress: _clamp(totalDistance, 500),
        thresholdLabel: 'Ride 500 km',
      ),
      _achievement(
        id: 'ach-05',
        title: 'Green Commuter',
        description: 'Save 5 kg of CO2 emissions.',
        category: 'eco',
        icon: 'leaf',
        colorHex: '#26A69A',
        progress: _clamp(co2Saved, 5),
        thresholdLabel: 'Save 5 kg CO2',
      ),
      _achievement(
        id: 'ach-06',
        title: 'Planet Saver',
        description: 'Save 50 kg of CO2 emissions.',
        category: 'eco',
        icon: 'globe',
        colorHex: '#00897B',
        progress: _clamp(co2Saved, 50),
        thresholdLabel: 'Save 50 kg CO2',
      ),
      _achievement(
        id: 'ach-07',
        title: 'Connected',
        description: 'Follow 5 fellow riders.',
        category: 'social',
        icon: 'users',
        colorHex: '#039BE5',
        progress: _clamp(followingCount, 5),
        thresholdLabel: 'Follow 5 riders',
      ),
      _achievement(
        id: 'ach-08',
        title: 'Group Rider',
        description: 'Join your first group.',
        category: 'social',
        icon: 'users-round',
        colorHex: '#8E24AA',
        progress: _clamp(groupsCount, 1),
        thresholdLabel: 'Join 1 group',
      ),
      _achievement(
        id: 'ach-09',
        title: 'Influencer',
        description: 'Get 10 followers.',
        category: 'social',
        icon: 'sparkles',
        colorHex: '#FB8C00',
        progress: _clamp(followersCount, 10),
        thresholdLabel: 'Get 10 followers',
      ),
      _achievement(
        id: 'ach-10',
        title: 'Early Bird',
        description: 'Complete 5 rides before 8 AM.',
        category: 'streak',
        icon: 'sunrise',
        colorHex: '#F4511E',
        progress: _clamp(morningRides, 5),
        thresholdLabel: '5 rides before 8 AM',
      ),
      _achievement(
        id: 'ach-11',
        title: '7-Day Streak',
        description: 'Ride every day for a week.',
        category: 'streak',
        icon: 'flame',
        colorHex: '#E53935',
        progress: _clamp(streakDays, 7),
        thresholdLabel: '7 days in a row',
      ),
      _achievement(
        id: 'ach-12',
        title: '30-Day Streak',
        description: 'Ride every day for a full month.',
        category: 'streak',
        icon: 'trophy',
        colorHex: '#C62828',
        progress: _clamp(streakDays, 30),
        thresholdLabel: '30 days in a row',
      ),
    ];
  }

  @override
  Future<void> acknowledgeAchievement(String achievementId) async {
    // No-op for client-side achievements
  }

  // ── Helpers ──

  AchievementModel _achievement({
    required String id,
    required String title,
    required String description,
    required String category,
    required String icon,
    required String colorHex,
    required double progress,
    required String thresholdLabel,
  }) {
    return AchievementModel(
      id: id,
      title: title,
      description: description,
      category: category,
      icon: icon,
      colorHex: colorHex,
      progress: progress,
      unlocked: progress >= 1.0,
      thresholdLabel: thresholdLabel,
      active: true,
    );
  }

  double _clamp(double value, double target) {
    if (!value.isFinite || target <= 0) return 0.0;
    return (value / target).clamp(0.0, 1.0);
  }

  double _num(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  Future<Map<String, dynamic>> _fetchTripSummary() async {
    try {
      final res = await _api.get(ApiEndpoints.trips.summary);
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final data = root['data'];
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _fetchUserDetails() async {
    try {
      final res = await _api.get(ApiEndpoints.user.me);
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final data = root['data'];
      if (data is Map<String, dynamic>) return data;
      return <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
