import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/group_model.dart';
import '../../data/repositories/group_repository.dart';
import '../providers/groups_provider.dart';

// ── State ────────────────────────────────────────────────────────────────────

class GroupDetailState {
  final GroupModel? group;
  final List<GroupMemberModel> members;
  final GroupAggregateModel? aggregate;
  final List<CommunityPostModel> posts;
  final bool isLoading;
  final String? error;

  const GroupDetailState({
    this.group,
    this.members = const [],
    this.aggregate,
    this.posts = const [],
    this.isLoading = false,
    this.error,
  });

  GroupDetailState copyWith({
    GroupModel? group,
    List<GroupMemberModel>? members,
    GroupAggregateModel? aggregate,
    List<CommunityPostModel>? posts,
    bool? isLoading,
    String? error,
  }) {
    return GroupDetailState(
      group: group ?? this.group,
      members: members ?? this.members,
      aggregate: aggregate ?? this.aggregate,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class GroupDetailNotifier extends StateNotifier<GroupDetailState> {
  final GroupRepository _repository;
  final String groupId;

  GroupDetailNotifier(this._repository, this.groupId) : super(const GroupDetailState()) {
    loadGroupDetail();
  }

  Future<void> loadGroupDetail() async {
    state = state.copyWith(isLoading: true);
    try {
      // Fetch group, members, aggregate, and posts in parallel.
      final results = await Future.wait([
        _repository.getGroupDetail(groupId),
        _repository.getGroupMembers(groupId),
        _repository.getGroupAggregate(groupId),
        _repository.getCommunityPosts(groupId),
      ]);
      state = state.copyWith(
        group: results[0] as GroupModel,
        members: results[1] as List<GroupMemberModel>,
        aggregate: results[2] as GroupAggregateModel,
        posts: results[3] as List<CommunityPostModel>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> joinGroup() async {
    try {
      await _repository.joinGroup(groupId);
      await loadGroupDetail();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> leaveGroup() async {
    try {
      await _repository.leaveGroup(groupId);
      await loadGroupDetail();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteGroup() async {
    try {
      await _repository.deleteGroup(groupId);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> createPost(String body) async {
    try {
      final post = await _repository.createCommunityPost(body: body, groupId: groupId);
      state = state.copyWith(posts: [post, ...state.posts]);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deletePost(String postId) async {
    try {
      await _repository.deleteCommunityPost(postId);
      state = state.copyWith(
        posts: state.posts.where((post) => post.id != postId).toList(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Provider (family by groupId) ─────────────────────────────────────────────

final groupDetailProvider = StateNotifierProvider.family<GroupDetailNotifier, GroupDetailState, String>(
  (ref, groupId) {
    return GroupDetailNotifier(ref.watch(groupRepositoryProvider), groupId);
  },
);
