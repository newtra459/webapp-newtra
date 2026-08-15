import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/group_model.dart';
import '../../data/repositories/group_repository.dart';
import '../../data/repositories/group_repository_impl.dart';
import '../../../../core/network/providers.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final groupRepositoryProvider = Provider<GroupRepository>((ref) {
  return GroupRepositoryImpl(ref.watch(apiClientProvider));
});

// ── State ────────────────────────────────────────────────────────────────────

class GroupsState {
  final List<GroupModel> myGroups;
  final List<GroupModel> discover;
  final bool isLoading;
  final String? error;

  const GroupsState({
    this.myGroups = const [],
    this.discover = const [],
    this.isLoading = false,
    this.error,
  });

  GroupsState copyWith({
    List<GroupModel>? myGroups,
    List<GroupModel>? discover,
    bool? isLoading,
    String? error,
  }) {
    return GroupsState(
      myGroups: myGroups ?? this.myGroups,
      discover: discover ?? this.discover,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class GroupsNotifier extends StateNotifier<GroupsState> {
  final GroupRepository _repository;

  GroupsNotifier(this._repository) : super(const GroupsState()) {
    loadGroups();
  }

  Future<void> loadGroups() async {
    state = state.copyWith(isLoading: true);
    try {
      final my = await _repository.getMyGroups();
      final disc = await _repository.discoverGroups();
      state = state.copyWith(myGroups: my, discover: disc, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> joinGroup(String groupId) async {
    try {
      await _repository.joinGroup(groupId);
      await loadGroups();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> leaveGroup(String groupId) async {
    try {
      await _repository.leaveGroup(groupId);
      await loadGroups();
      return true;
    } catch (_) {
      return false;
    }
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final groupsProvider = StateNotifierProvider<GroupsNotifier, GroupsState>((ref) {
  return GroupsNotifier(ref.watch(groupRepositoryProvider));
});
