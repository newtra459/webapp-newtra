import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class AchievementMetrics {
  final int tripsCount;
  final double totalDistance;
  final double co2Saved;
  final int followingCount;
  final int followersCount;
  final int groupsCount;
  final int currentStreakDays;
  final double highestSpeed;
  final int morningRides;
  final double rideHours;
  final int? points;

  const AchievementMetrics({
    this.tripsCount = 0,
    this.totalDistance = 0,
    this.co2Saved = 0,
    this.followingCount = 0,
    this.followersCount = 0,
    this.groupsCount = 0,
    this.currentStreakDays = 0,
    this.highestSpeed = 0,
    this.morningRides = 0,
    this.rideHours = 0,
    this.points,
  });
}

class AchievementItem {
  final String id;
  final String title;
  final String description;
  final String category;
  final IconData icon;
  final Color color;
  final double progress;
  final bool unlocked;
  final String thresholdLabel;

  const AchievementItem({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
    required this.progress,
    required this.unlocked,
    required this.thresholdLabel,
  });
}

class LevelProgress {
  final int currentLevel;
  final String currentTitle;
  final int totalXp;
  final int progressXp;
  final int progressTargetXp;
  final double progressRatio;
  final int? nextLevel;
  final String? nextTitle;
  final bool isMaxLevel;

  const LevelProgress({
    required this.currentLevel,
    required this.currentTitle,
    required this.totalXp,
    required this.progressXp,
    required this.progressTargetXp,
    required this.progressRatio,
    this.nextLevel,
    this.nextTitle,
    this.isMaxLevel = false,
  });
}

const _levelDefinitions = [
  (level: 1, minXp: 0, title: 'Beginner'),
  (level: 2, minXp: 200, title: 'Commuter'),
  (level: 3, minXp: 500, title: 'Cyclist'),
  (level: 4, minXp: 1000, title: 'Explorer'),
  (level: 5, minXp: 2000, title: 'Rider'),
  (level: 6, minXp: 4000, title: 'Champion'),
];

double _clamp(double value, double target) {
  if (!value.isFinite || target <= 0) return 0;
  return (value / target).clamp(0.0, 1.0);
}

List<AchievementItem> buildAchievements(AchievementMetrics m) {
  final longestStreak = max(m.currentStreakDays, 0);

  final raw = <(String, String, String, String, IconData, Color, double, String)>[
    ('ach-01', 'First Ride', 'Complete your very first ride.', 'riding',
        Icons.emoji_events_rounded, const Color(0xFF6C63FF),
        _clamp(m.tripsCount.toDouble(), 1), 'Complete 1 ride'),
    ('ach-02', 'Century Rider', 'Ride a total of 100 km on campus.', 'riding',
        Icons.military_tech_rounded, const Color(0xFFFF6584),
        _clamp(m.totalDistance, 100), 'Ride 100 km'),
    ('ach-03', 'Speed Demon', 'Reach a top speed of 25 km/h.', 'riding',
        Icons.bolt_rounded, const Color(0xFFFFB300),
        _clamp(m.highestSpeed, 25), 'Hit 25 km/h'),
    ('ach-04', 'Distance King', 'Ride 500 km in total.', 'riding',
        Icons.workspace_premium_rounded, const Color(0xFF43A047),
        _clamp(m.totalDistance, 500), 'Ride 500 km'),
    ('ach-05', 'Green Commuter', 'Save 5 kg of CO2 emissions.', 'eco',
        Icons.eco_rounded, const Color(0xFF26A69A),
        _clamp(m.co2Saved, 5), 'Save 5 kg CO2'),
    ('ach-06', 'Planet Saver', 'Save 50 kg of CO2 emissions.', 'eco',
        Icons.public_rounded, const Color(0xFF00897B),
        _clamp(m.co2Saved, 50), 'Save 50 kg CO2'),
    ('ach-07', 'Connected', 'Follow 5 fellow riders.', 'social',
        Icons.people_rounded, const Color(0xFF039BE5),
        _clamp(m.followingCount.toDouble(), 5), 'Follow 5 riders'),
    ('ach-08', 'Group Rider', 'Join your first group.', 'social',
        Icons.groups_rounded, const Color(0xFF8E24AA),
        _clamp(m.groupsCount.toDouble(), 1), 'Join 1 group'),
    ('ach-09', 'Influencer', 'Get 10 followers.', 'social',
        Icons.auto_awesome_rounded, const Color(0xFFFB8C00),
        _clamp(m.followersCount.toDouble(), 10), 'Get 10 followers'),
    ('ach-10', 'Early Bird', 'Complete 5 rides before 8 AM.', 'streak',
        Icons.wb_sunny_rounded, const Color(0xFFF4511E),
        _clamp(m.morningRides.toDouble(), 5), '5 rides before 8 AM'),
    ('ach-11', '7-Day Streak', 'Ride every day for a week.', 'streak',
        Icons.local_fire_department_rounded, const Color(0xFFE53935),
        _clamp(longestStreak.toDouble(), 7), '7 days in a row'),
    ('ach-12', '30-Day Streak', 'Ride every day for a full month.', 'streak',
        Icons.emoji_events_rounded, const Color(0xFFC62828),
        _clamp(longestStreak.toDouble(), 30), '30 days in a row'),
  ];

  return raw.map((a) => AchievementItem(
    id: a.$1,
    title: a.$2,
    description: a.$3,
    category: a.$4,
    icon: a.$5,
    color: a.$6,
    progress: a.$7,
    unlocked: a.$7 >= 1.0,
    thresholdLabel: a.$8,
  )).toList();
}

int estimateXp(AchievementMetrics m, {int unlockedCount = 0}) {
  if (m.points != null) return max(0, m.points!);

  final distanceXp = m.totalDistance.floor() * 10;
  final ecoXp = m.co2Saved.floor() * 5;
  final rideTimeXp = ((m.rideHours * 60) / 10).floor() * 8;
  final streakXp = m.currentStreakDays * 20;
  final groupXp = m.groupsCount * 15;
  final badgeXp = unlockedCount * 50;

  return max(0, distanceXp + ecoXp + rideTimeXp + streakXp + groupXp + badgeXp);
}

LevelProgress buildLevelProgress(int totalXp) {
  final xp = max(0, totalXp);

  var current = _levelDefinitions[0];
  for (int i = _levelDefinitions.length - 1; i >= 0; i--) {
    if (xp >= _levelDefinitions[i].minXp) {
      current = _levelDefinitions[i];
      break;
    }
  }

  final nextIdx = _levelDefinitions.indexWhere((d) => d.level == current.level + 1);
  if (nextIdx < 0) {
    return LevelProgress(
      currentLevel: current.level,
      currentTitle: current.title,
      totalXp: xp,
      progressXp: xp - current.minXp,
      progressTargetXp: 0,
      progressRatio: 1.0,
      isMaxLevel: true,
    );
  }

  final next = _levelDefinitions[nextIdx];
  final progressXp = max(0, xp - current.minXp);
  final progressTarget = next.minXp - current.minXp;

  return LevelProgress(
    currentLevel: current.level,
    currentTitle: current.title,
    totalXp: xp,
    progressXp: progressXp,
    progressTargetXp: progressTarget,
    progressRatio: progressTarget > 0 ? progressXp / progressTarget : 0,
    nextLevel: next.level,
    nextTitle: next.title,
  );
}
