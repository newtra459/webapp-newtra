// Dummy data mock — swap back to GroupRepositoryImpl in groups_provider.dart
// when the backend /groups endpoint is live.

import '../models/group_model.dart';
import 'group_repository.dart';

class GroupRepositoryMock implements GroupRepository {
  final List<GroupModel> _myGroups = [
    const GroupModel(
      id: 'g-01',
      name: 'Morning Pedallers',
      description: 'Early risers who ride before 8 AM every day.',
      category: 'Fitness',
      members: 24,
      totalDistance: '1847.2 km',
      joined: true,
    ),
  ];

  static const List<GroupModel> _discover = [
    GroupModel(
      id: 'g-02',
      name: 'Campus Eco Riders',
      description: 'Dedicated to zero-emission campus travel.',
      category: 'Eco',
      members: 31,
      totalDistance: '1621.5 km',
      joined: false,
    ),
  ];

  @override
  Future<List<GroupModel>> getMyGroups() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return List.from(_myGroups);
  }

  @override
  Future<List<GroupModel>> discoverGroups() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _discover;
  }

  @override
  Future<GroupModel> getGroupDetail(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final all = [..._myGroups, ..._discover];
    return all.firstWhere((g) => g.id == groupId, orElse: () => _myGroups.first);
  }

  @override
  Future<void> joinGroup(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String category,
    String visibility = 'public',
    String? groupImage,
  }) async {
    await Future.delayed(const Duration(milliseconds: 700));
    final newGroup = GroupModel(
      id: 'g-new-${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      description: description,
      category: category,
      members: 1,
      totalDistance: '0 km',
      joined: true,
      isCreator: true,
      visibility: visibility,
    );
    _myGroups.add(newGroup);
    return newGroup;
  }

  @override
  Future<List<GroupMemberModel>> getGroupMembers(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return [];
  }

  @override
  Future<GroupAggregateModel> getGroupAggregate(String groupId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const GroupAggregateModel();
  }

  @override
  Future<List<CommunityPostModel>> getCommunityPosts(String groupId, {int limit = 20}) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const [];
  }

  @override
  Future<CommunityPostModel> createCommunityPost({
    required String body,
    required String groupId,
  }) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return CommunityPostModel(
      id: 'post-${DateTime.now().millisecondsSinceEpoch}',
      userId: 'mock-user',
      groupId: groupId,
      body: body,
      createdAt: DateTime.now().toIso8601String(),
      groupName: _myGroups.first.name,
      authorName: 'You',
    );
  }

  @override
  Future<void> deleteCommunityPost(String postId) async {
    await Future.delayed(const Duration(milliseconds: 300));
  }
}
