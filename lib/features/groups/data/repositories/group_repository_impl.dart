import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/group_model.dart';
import 'group_repository.dart';

class GroupRepositoryImpl implements GroupRepository {
  final ApiClient _api;

  GroupRepositoryImpl(this._api);

  List<GroupModel> _extractGroupList(dynamic responseData) {
    final root = (responseData is Map<String, dynamic>) ? responseData : <String, dynamic>{};
    // Backend returns groups under 'groups' key (GetGroups) or 'data' key (user groups)
    final list = root['data'] as List? ?? root['groups'] as List? ?? [];
    return list.map((e) => GroupModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<List<GroupModel>> getMyGroups() async {
    final res = await _api.get(
      ApiEndpoints.groups.list,
      queryParameters: {
        'only_member': 'true',
        'sort_by': 'activity',
        'order': 'desc',
      },
    );
    return _extractGroupList(res.data);
  }

  @override
  Future<List<GroupModel>> discoverGroups() async {
    final res = await _api.get(
      ApiEndpoints.groups.list,
      queryParameters: {
        'sort_by': 'activity',
        'order': 'desc',
      },
    );
    final all = _extractGroupList(res.data);
    // Filter out groups where user is already a member or creator
    return all.where((g) => !g.joined && !g.isCreator).toList();
  }

  @override
  Future<GroupModel> getGroupDetail(String groupId) async {
    final res = await _api.get(ApiEndpoints.groups.detail(groupId));
    final root = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final groupData = root['data'] as Map<String, dynamic>? ?? root['group'] as Map<String, dynamic>? ?? root;
    return GroupModel.fromJson(groupData);
  }

  @override
  Future<void> joinGroup(String groupId) async {
    await _api.get(ApiEndpoints.groups.join(groupId));
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    await _api.get(ApiEndpoints.groups.leave(groupId));
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await _api.delete(ApiEndpoints.groups.delete(groupId));
  }

  @override
  Future<GroupModel> createGroup({
    required String name,
    required String description,
    required String category,
    String visibility = 'public',
    String? groupImage,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'description': description,
      'category': category,
      'visibility': visibility,
    };
    if (groupImage != null) body['group_image'] = groupImage;

    final res = await _api.post(ApiEndpoints.groups.create, data: body);
    final root = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final groupData = root['data'] as Map<String, dynamic>? ?? root;
    return GroupModel.fromJson(groupData);
  }

  @override
  Future<List<GroupMemberModel>> getGroupMembers(String groupId) async {
    final res = await _api.get(ApiEndpoints.groups.membersData(groupId));
    final root = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final list = root['data'] as List? ?? [];
    return list.map((e) => GroupMemberModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<GroupAggregateModel> getGroupAggregate(String groupId) async {
    final res = await _api.get(ApiEndpoints.groups.aggregate(groupId));
    final root = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    return GroupAggregateModel.fromJson(root);
  }

  @override
  Future<List<CommunityPostModel>> getCommunityPosts(String groupId, {int limit = 20}) async {
    final res = await _api.get(
      ApiEndpoints.community.posts,
      queryParameters: {
        'group_id': groupId,
        'limit': limit.toString(),
      },
    );
    final root = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final list = root['data'] as List? ?? [];
    return list.map((e) => CommunityPostModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  @override
  Future<CommunityPostModel> createCommunityPost({required String body, required String groupId}) async {
    final res = await _api.post(
      ApiEndpoints.community.posts,
      data: {
        'body': body,
        'group_id': groupId,
        'image_url': '',
      },
    );
    final root = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final postData = root['data'] as Map<String, dynamic>? ?? root;
    return CommunityPostModel.fromJson(postData);
  }

  @override
  Future<void> deleteCommunityPost(String postId) async {
    await _api.delete(ApiEndpoints.community.deletePost(postId));
  }
}
