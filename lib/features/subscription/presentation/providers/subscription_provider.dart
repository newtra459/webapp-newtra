import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/subscription_model.dart';
import '../../data/repositories/subscription_repository.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../../../core/network/providers.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepositoryImpl(ref.watch(apiClientProvider));
});

class SubscriptionState {
  final List<SubscriptionPlan> plans;
  final List<UserSubscription> activeSubscriptions;
  final UserSubscription? active;
  final bool isLoading;
  final String? error;

  const SubscriptionState({
    this.plans = const [],
    this.activeSubscriptions = const [],
    this.active,
    this.isLoading = false,
    this.error,
  });

  SubscriptionState copyWith({
    List<SubscriptionPlan>? plans,
    List<UserSubscription>? activeSubscriptions,
    UserSubscription? active,
    bool clearActive = false,
    bool? isLoading,
    String? error,
  }) {
    return SubscriptionState(
      plans: plans ?? this.plans,
      activeSubscriptions: activeSubscriptions ?? this.activeSubscriptions,
      active: clearActive ? null : (active ?? this.active),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class SubscriptionNotifier extends StateNotifier<SubscriptionState> {
  final SubscriptionRepository _repository;

  SubscriptionNotifier(this._repository) : super(const SubscriptionState()) {
    loadSubscription();
  }

  Future<void> loadSubscription() async {
    state = state.copyWith(isLoading: true);
    try {
      final plans = await _repository.getPlans();
      final activeSubs = await _repository.getActiveSubscriptions();
      state = state.copyWith(
        plans: plans,
        activeSubscriptions: activeSubs,
        active: activeSubs.isNotEmpty ? activeSubs.first : null,
        clearActive: activeSubs.isEmpty,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> subscribe(String planId) async {
    try {
      final sub = await _repository.activateSubscription(planId);
      // Reload all active subscriptions after activation
      final activeSubs = await _repository.getActiveSubscriptions();
      state = state.copyWith(
        active: sub,
        activeSubscriptions: activeSubs,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancel() async {
    if (state.active == null) return false;
    try {
      await _repository.cancelSubscription(state.active!.id);
      final activeSubs = await _repository.getActiveSubscriptions();
      state = SubscriptionState(
        plans: state.plans,
        activeSubscriptions: activeSubs,
        active: activeSubs.isNotEmpty ? activeSubs.first : null,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<UserSubscription?> verifyInstitutionId({
    required String org,
    required String institutionId,
  }) async {
    try {
      final sub = await _repository.verifyInstitutionId(
        org: org,
        institutionId: institutionId,
      );
      if (sub != null) {
        final activeSubs = await _repository.getActiveSubscriptions();
        state = state.copyWith(
          active: sub,
          activeSubscriptions: activeSubs,
        );
      }
      return sub;
    } catch (_) {
      return null;
    }
  }
}

final subscriptionProvider = StateNotifierProvider<SubscriptionNotifier, SubscriptionState>((ref) {
  return SubscriptionNotifier(ref.watch(subscriptionRepositoryProvider));
});
