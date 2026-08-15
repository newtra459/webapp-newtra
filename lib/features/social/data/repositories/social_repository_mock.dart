// Dummy data mock — swap back to SocialRepositoryImpl in social_provider.dart
// when the backend /social endpoints are live.

import '../models/social_models.dart';
import 'social_repository.dart';

class SocialRepositoryMock implements SocialRepository {
  final List<FriendModel> _suggested = [
    const FriendModel(
      id: 'u-01',
      name: 'Arjun Sharma',
      type: 'Student',
      totalDistance: '142.3 km',
      rides: 68,
      isFollowing: false,
    ),
    const FriendModel(
      id: 'u-02',
      name: 'Priya Nair',
      type: 'Student',
      totalDistance: '98.7 km',
      rides: 44,
      isFollowing: true,
    ),
    const FriendModel(
      id: 'u-03',
      name: 'Ravi Kumar',
      type: 'Employee',
      totalDistance: '210.5 km',
      rides: 95,
      isFollowing: false,
    ),
    const FriendModel(
      id: 'u-04',
      name: 'Meera Iyer',
      type: 'Student',
      totalDistance: '67.2 km',
      rides: 31,
      isFollowing: false,
    ),
    const FriendModel(
      id: 'u-05',
      name: 'Kiran Rao',
      type: 'Student',
      totalDistance: '185.0 km',
      rides: 82,
      isFollowing: true,
    ),
    const FriendModel(
      id: 'u-06',
      name: 'Anjali Singh',
      type: 'Employee',
      totalDistance: '310.8 km',
      rides: 140,
      isFollowing: false,
    ),
    const FriendModel(
      id: 'u-07',
      name: 'Deepak Verma',
      type: 'Student',
      totalDistance: '55.4 km',
      rides: 25,
      isFollowing: false,
    ),
    const FriendModel(
      id: 'u-08',
      name: 'Lakshmi Prasad',
      type: 'Student',
      totalDistance: '128.9 km',
      rides: 57,
      isFollowing: false,
    ),
  ];

  static const List<FriendModel> _followers = [
    FriendModel(
      id: 'u-02',
      name: 'Priya Nair',
      type: 'Student',
      totalDistance: '98.7 km',
      rides: 44,
      isFollowing: true,
    ),
    FriendModel(
      id: 'u-05',
      name: 'Kiran Rao',
      type: 'Student',
      totalDistance: '185.0 km',
      rides: 82,
      isFollowing: true,
    ),
    FriendModel(
      id: 'u-09',
      name: 'Suresh Pillai',
      type: 'Employee',
      totalDistance: '243.1 km',
      rides: 108,
      isFollowing: false,
    ),
    FriendModel(
      id: 'u-10',
      name: 'Nandini Bose',
      type: 'Student',
      totalDistance: '41.0 km',
      rides: 19,
      isFollowing: false,
    ),
  ];

  static const List<FriendModel> _following = [
    FriendModel(
      id: 'u-02',
      name: 'Priya Nair',
      type: 'Student',
      totalDistance: '98.7 km',
      rides: 44,
      isFollowing: true,
    ),
    FriendModel(
      id: 'u-05',
      name: 'Kiran Rao',
      type: 'Student',
      totalDistance: '185.0 km',
      rides: 82,
      isFollowing: true,
    ),
    FriendModel(
      id: 'u-03',
      name: 'Ravi Kumar',
      type: 'Employee',
      totalDistance: '210.5 km',
      rides: 95,
      isFollowing: true,
    ),
  ];

  static const List<LeaderboardEntry> _riderLeaderboard = [
    LeaderboardEntry(
      id: 'u-03',
      name: 'Ravi Kumar',
      values: {'distance': '210.5 km', 'rides': '95', 'co2': '39.9 kg'},
      badge: '🥇',
    ),
    LeaderboardEntry(
      id: 'u-06',
      name: 'Anjali Singh',
      values: {'distance': '310.8 km', 'rides': '140', 'co2': '59.1 kg'},
      badge: '🥈',
    ),
    LeaderboardEntry(
      id: 'u-05',
      name: 'Kiran Rao',
      values: {'distance': '185.0 km', 'rides': '82', 'co2': '35.2 kg'},
      badge: '🥉',
    ),
    LeaderboardEntry(
      id: 'u-01',
      name: 'Arjun Sharma',
      values: {'distance': '142.3 km', 'rides': '68', 'co2': '27.0 kg'},
    ),
    LeaderboardEntry(
      id: 'mock-user-001',
      name: 'Rishwak',
      values: {'distance': '38.4 km', 'rides': '14', 'co2': '7.2 kg'},
      isMe: true,
    ),
    LeaderboardEntry(
      id: 'u-02',
      name: 'Priya Nair',
      values: {'distance': '98.7 km', 'rides': '44', 'co2': '18.8 kg'},
    ),
    LeaderboardEntry(
      id: 'u-08',
      name: 'Lakshmi Prasad',
      values: {'distance': '128.9 km', 'rides': '57', 'co2': '24.5 kg'},
    ),
    LeaderboardEntry(
      id: 'u-04',
      name: 'Meera Iyer',
      values: {'distance': '67.2 km', 'rides': '31', 'co2': '12.8 kg'},
    ),
  ];

  static const List<LeaderboardEntry> _groupLeaderboard = [
    LeaderboardEntry(
      id: 'g-01',
      name: 'Morning Pedallers',
      values: {'distance': '1847.2 km', 'rides': '412', 'members': '24'},
      badge: '🥇',
      members: 24,
    ),
    LeaderboardEntry(
      id: 'g-02',
      name: 'Campus Eco Riders',
      values: {'distance': '1621.5 km', 'rides': '368', 'members': '31'},
      badge: '🥈',
      members: 31,
    ),
    LeaderboardEntry(
      id: 'g-03',
      name: 'Night Owls Cycling',
      values: {'distance': '1204.8 km', 'rides': '289', 'members': '18'},
      badge: '🥉',
      members: 18,
    ),
    LeaderboardEntry(
      id: 'g-04',
      name: 'Research Park Riders',
      values: {'distance': '980.3 km', 'rides': '225', 'members': '15'},
      members: 15,
    ),
    LeaderboardEntry(
      id: 'g-05',
      name: 'Weekend Warriors',
      values: {'distance': '743.6 km', 'rides': '170', 'members': '22'},
      members: 22,
    ),
  ];

  @override
  Future<List<FriendModel>> getSuggested() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_suggested);
  }

  @override
  Future<List<FriendModel>> getFollowers() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _followers;
  }

  @override
  Future<List<FriendModel>> getFollowing() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _following;
  }

  @override
  Future<void> follow(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<void> unfollow(String userId) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }

  @override
  Future<List<LeaderboardEntry>> getRiderLeaderboard() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _riderLeaderboard;
  }

  @override
  Future<List<LeaderboardEntry>> getGroupLeaderboard() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _groupLeaderboard;
  }
}
