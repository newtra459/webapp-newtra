import '../models/social_models.dart';

abstract class SocialRepository {
  Future<List<FriendModel>> getSuggested();
  Future<List<FriendModel>> getFollowers();
  Future<List<FriendModel>> getFollowing();
  Future<void> follow(String userId);
  Future<void> unfollow(String userId);
  Future<List<LeaderboardEntry>> getRiderLeaderboard();
  Future<List<LeaderboardEntry>> getGroupLeaderboard();
}
