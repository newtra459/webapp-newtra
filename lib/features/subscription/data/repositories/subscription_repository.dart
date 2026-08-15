import '../models/subscription_model.dart';

abstract class SubscriptionRepository {
  Future<List<SubscriptionPlan>> getPlans({String? location, String? userType, String? organizationId});
  Future<UserSubscription> activateSubscription(String planId);
  Future<List<UserSubscription>> getActiveSubscriptions();
  Future<void> cancelSubscription(String subscriptionId);

  /// Verify an institution / employee ID against the admin-uploaded list.
  /// Returns the auto-allocated [UserSubscription] if the ID is valid and
  /// the organisation has a paid fleet agreement.
  Future<UserSubscription?> verifyInstitutionId({
    required String org,
    required String institutionId,
  });
}
