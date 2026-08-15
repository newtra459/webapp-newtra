import '../models/group_model.dart';

abstract class GroupRepository {
  Future<List<GroupModel>> getMyGroups();
  Future<List<GroupModel>> discoverGroups();
  Future<GroupModel> getGroupDetail(String groupId);
  Future<void> joinGroup(String groupId);
  Future<void> leaveGroup(String groupId);
  Future<void> deleteGroup(String groupId);
  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String category,
    String visibility = 'public',
    String? groupImage,
  });
  Future<List<GroupMemberModel>> getGroupMembers(String groupId);
  Future<GroupAggregateModel> getGroupAggregate(String groupId);
  Future<List<CommunityPostModel>> getCommunityPosts(String groupId, {int limit});
  Future<CommunityPostModel> createCommunityPost({required String body, required String groupId});
  Future<void> deleteCommunityPost(String postId);
}
