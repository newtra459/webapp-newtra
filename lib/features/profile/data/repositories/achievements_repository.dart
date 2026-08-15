import '../models/achievement_model.dart';

abstract class AchievementsRepository {
  /// GET /profile/achievements
  /// Returns all admin-defined achievements merged with the current user's
  /// progress. Only achievements with [active] == true are included.
  Future<List<AchievementModel>> getAchievements();

  /// POST /profile/achievements/:id/acknowledge
  /// Marks a newly unlocked achievement as seen so the badge dot clears.
  Future<void> acknowledgeAchievement(String achievementId);
}
