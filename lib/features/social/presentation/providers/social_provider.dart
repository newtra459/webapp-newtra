import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/social_models.dart';
import '../../data/repositories/social_repository.dart';
import '../../data/repositories/social_repository_impl.dart';
import '../../../../core/network/providers.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  return SocialRepositoryImpl(ref.watch(apiClientProvider));
});

// ── State ────────────────────────────────────────────────────────────────────

class SocialState {
  final List<FriendModel> suggested;
  final List<FriendModel> followers;
  final List<FriendModel> following;
  final Map<String, bool> followOverrides;
  final bool isLoading;
  final String? error;

  const SocialState({
    this.suggested = const [],
    this.followers = const [],
    this.following = const [],
    this.followOverrides = const {},
    this.isLoading = false,
    this.error,
  });

  SocialState copyWith({
    List<FriendModel>? suggested,
    List<FriendModel>? followers,
    List<FriendModel>? following,
    Map<String, bool>? followOverrides,
    bool? isLoading,
    String? error,
  }) {
    return SocialState(
      suggested: suggested ?? this.suggested,
      followers: followers ?? this.followers,
      following: following ?? this.following,
      followOverrides: followOverrides ?? this.followOverrides,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool? followStatusFor(String userId) {
    if (userId.isEmpty) return null;

    final override = followOverrides[userId];
    if (override != null) return override;

    for (final friend in suggested) {
      if (friend.id == userId) return friend.isFollowing;
    }
    for (final friend in followers) {
      if (friend.id == userId) return friend.isFollowing;
    }
    for (final friend in following) {
      if (friend.id == userId) return friend.isFollowing;
    }

    return null;
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class SocialNotifier extends StateNotifier<SocialState> {
  final SocialRepository _repository;

  SocialNotifier(this._repository) : super(const SocialState()) {
    loadSocial();
  }

  Future<void> loadSocial() async {
    state = state.copyWith(isLoading: true);
    try {
      // Load each independently so one failure doesn't block others
      List<FriendModel> suggested = [];
      List<FriendModel> followers = [];
      List<FriendModel> following = [];
      try { suggested = await _repository.getSuggested(); } catch (_) {}
      try { followers = await _repository.getFollowers(); } catch (_) {}
      try { following = await _repository.getFollowing(); } catch (_) {}
      final followOverrides = <String, bool>{
        ...state.followOverrides,
      };
      for (final friend in [...suggested, ...followers, ...following]) {
        if (friend.id.isNotEmpty) {
          followOverrides[friend.id] = friend.isFollowing;
        }
      }
      state = state.copyWith(
        suggested: suggested,
        followers: followers,
        following: following,
        followOverrides: followOverrides,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  SocialState _setFollowState(String userId, bool isFollowing) {
    FriendModel? target;

    List<FriendModel> updateList(List<FriendModel> list) {
      return list.map((friend) {
        if (friend.id != userId) return friend;
        target = friend.copyWith(isFollowing: isFollowing);
        return target!;
      }).toList();
    }

    final updatedSuggested = updateList(state.suggested);
    final updatedFollowers = updateList(state.followers);

    var updatedFollowing = state.following
        .where((friend) => friend.id != userId)
        .map((friend) => friend.copyWith(
              isFollowing: friend.id == userId ? isFollowing : friend.isFollowing,
            ))
        .toList();

    if (isFollowing) {
      final candidate = target ??
          state.following.firstWhere(
            (friend) => friend.id == userId,
            orElse: () => const FriendModel(id: '', name: '', type: ''),
          );
      if (candidate.id.isNotEmpty &&
          !updatedFollowing.any((friend) => friend.id == userId)) {
        updatedFollowing = [
          candidate.copyWith(isFollowing: true),
          ...updatedFollowing,
        ];
      }
    }

    return state.copyWith(
      suggested: updatedSuggested,
      followers: updatedFollowers,
      following: updatedFollowing,
      followOverrides: {
        ...state.followOverrides,
        userId: isFollowing,
      },
    );
  }

  Future<bool> follow(String userId) async {
    try {
      await _repository.follow(userId);
      state = _setFollowState(userId, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> unfollow(String userId) async {
    try {
      await _repository.unfollow(userId);
      state = _setFollowState(userId, false);
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final socialProvider = StateNotifierProvider<SocialNotifier, SocialState>((ref) {
  return SocialNotifier(ref.watch(socialRepositoryProvider));
});

// ── Leaderboard providers ─────────────────────────────────────────────────────

final riderLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(socialRepositoryProvider).getRiderLeaderboard();
});

final groupLeaderboardProvider = FutureProvider<List<LeaderboardEntry>>((ref) {
  return ref.watch(socialRepositoryProvider).getGroupLeaderboard();
});
