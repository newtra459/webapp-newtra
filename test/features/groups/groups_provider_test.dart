import 'package:flutter_test/flutter_test.dart';
import 'package:mjollnir_app/features/groups/presentation/providers/groups_provider.dart';
import 'package:mjollnir_app/features/groups/data/models/group_model.dart';
import 'package:mjollnir_app/features/groups/data/repositories/group_repository.dart';

class MockGroupRepository implements GroupRepository {
  bool shouldThrow = false;
  final List<GroupModel> _myGroups = [
    const GroupModel(id: 'g1', name: 'Campus Cyclists', description: 'Ride together!', category: 'Campus', members: 32, joined: true),
  ];
  final List<GroupModel> _discover = [
    const GroupModel(id: 'g2', name: 'IIT Riders', description: 'Official group', category: 'University', members: 45, joined: false),
  ];

  @override
  Future<List<GroupModel>> getMyGroups() async {
    if (shouldThrow) throw Exception('Error');
    return _myGroups;
  }

  @override
  Future<List<GroupModel>> discoverGroups() async {
    if (shouldThrow) throw Exception('Error');
    return _discover;
  }

  @override
  Future<GroupModel> getGroupDetail(String groupId) async {
    return _myGroups.first;
  }

  @override
  Future<void> joinGroup(String groupId) async {
    if (shouldThrow) throw Exception('Join failed');
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    if (shouldThrow) throw Exception('Leave failed');
  }

  @override
  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String category,
    String visibility = 'public',
    String? groupImage,
  }) async {
    return GroupModel(id: 'g3', name: name, description: description, category: category);
  }

  @override
  Future<List<GroupMemberModel>> getGroupMembers(String groupId) async => const [];

  @override
  Future<GroupAggregateModel> getGroupAggregate(String groupId) async {
    return const GroupAggregateModel();
  }

  @override
  Future<List<CommunityPostModel>> getCommunityPosts(
    String groupId, {
    int limit = 20,
  }) async {
    return const [];
  }

  @override
  Future<CommunityPostModel> createCommunityPost({
    required String body,
    required String groupId,
  }) async {
    return CommunityPostModel(
      id: 'post-1',
      userId: 'user-1',
      groupId: groupId,
      body: body,
    );
  }

  @override
  Future<void> deleteCommunityPost(String postId) async {}
}

void main() {
  late MockGroupRepository mockRepo;
  late GroupsNotifier notifier;

  setUp(() {
    mockRepo = MockGroupRepository();
    notifier = GroupsNotifier(mockRepo);
  });

  group('GroupsNotifier', () {
    test('loadGroups populates my groups and discover', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.myGroups.length, 1);
      expect(notifier.state.discover.length, 1);
      expect(notifier.state.myGroups.first.name, 'Campus Cyclists');
    });

    test('joinGroup returns true on success', () async {
      final success = await notifier.joinGroup('g2');
      expect(success, isTrue);
    });

    test('joinGroup returns false on failure', () async {
      mockRepo.shouldThrow = true;
      final success = await notifier.joinGroup('g2');
      expect(success, isFalse);
    });

    test('leaveGroup returns true on success', () async {
      final success = await notifier.leaveGroup('g1');
      expect(success, isTrue);
    });

    test('loadGroups handles errors', () async {
      mockRepo.shouldThrow = true;
      await notifier.loadGroups();
      expect(notifier.state.error, isNotNull);
    });
  });

  group('GroupModel', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'g1',
        'name': 'Test Group',
        'description': 'A test',
        'category': 'Campus',
        'members': 10,
        'total_distance': '100 km',
        'joined': true,
      };

      final group = GroupModel.fromJson(json);
      expect(group.name, 'Test Group');
      expect(group.joined, isTrue);
      expect(group.totalDistance, '100 km');
    });

    test('copyWith updates fields', () {
      const group = GroupModel(id: 'g1', name: 'A', description: 'B', category: 'C');
      final updated = group.copyWith(name: 'X');

      expect(updated.name, 'X');
      expect(updated.description, 'B');
    });
  });
}
