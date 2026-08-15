import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/subscription_model.dart';
import 'subscription_repository.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  final ApiClient _api;

  SubscriptionRepositoryImpl(this._api);

  @override
  Future<List<SubscriptionPlan>> getPlans({String? location, String? userType, String? organizationId}) async {
    final params = <String, dynamic>{};
    if (location != null) params['location'] = location;
    if (userType != null) params['user_type'] = userType;
    if (organizationId != null) params['organization_id'] = organizationId;

    // Fetch plans and stations in parallel to resolve station names
    final plansFuture = _api.get(ApiEndpoints.subscriptions.plans, queryParameters: params);
    Map<String, String> stationMap = {};
    try {
      final stationsRes = await _api.get(ApiEndpoints.stations.list);
      final stRoot = stationsRes.data is Map<String, dynamic>
          ? stationsRes.data as Map<String, dynamic>
          : <String, dynamic>{};
      final stData = stRoot['data'];
      if (stData is List) {
        for (final s in stData) {
          if (s is Map<String, dynamic>) {
            final id = s['id'] as String? ?? '';
            final name = s['name'] as String? ?? '';
            if (id.isNotEmpty && name.isNotEmpty) stationMap[id] = name;
          }
        }
      }
    } catch (_) {}

    final res = await plansFuture;
    final root = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};
    final data = root['data'];
    List list;
    if (data is List) {
      list = data;
    } else {
      list = [];
    }

    return list.map((e) {
      final planJson = e as Map<String, dynamic>;
      // Resolve station_id to station name for location
      final loc = planJson['location'] as String? ?? '';
      final stationId = planJson['station_id'] as String? ?? '';
      if (loc.isEmpty && stationId.isNotEmpty && stationMap.containsKey(stationId)) {
        planJson['location'] = stationMap[stationId];
      }
      return SubscriptionPlan.fromJson(planJson);
    }).toList();
  }

  @override
  Future<UserSubscription> activateSubscription(String planId) async {
    final res = await _api.post(ApiEndpoints.subscriptions.activate(planId));
    final root = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};
    final data = root['data'];
    // Backend returns { user_subscription: {...}, subscription: {...}, charged_amount, auto_assigned }
    if (data is Map<String, dynamic>) {
      final userSub = data['user_subscription'] as Map<String, dynamic>?;
      final plan = data['subscription'] as Map<String, dynamic>?;
      if (userSub != null) {
        // Build a merged map for UserSubscription.fromJson
        final merged = <String, dynamic>{
          'user_subscription': userSub,
          if (plan != null) 'plan': plan,
        };
        return UserSubscription.fromJson(merged);
      }
      return UserSubscription.fromJson(data);
    }
    return UserSubscription.fromJson(root);
  }

  @override
  Future<List<UserSubscription>> getActiveSubscriptions() async {
    try {
      final res = await _api.get(ApiEndpoints.subscriptions.active);
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final data = root['data'];
      if (data == null) return [];

      // Backend GET /me/subscription returns UserSubscriptionWithPlan[]
      // Each item: { user_subscription: {...}, plan: {...}, vehicle_types: [...], days_remaining: N }
      if (data is List) {
        return data
            .map((e) => UserSubscription.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      if (data is Map<String, dynamic>) {
        return [UserSubscription.fromJson(data)];
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    await _api.delete(ApiEndpoints.subscriptions.cancel(subscriptionId));
  }

  @override
  Future<UserSubscription?> verifyInstitutionId({
    required String org,
    required String institutionId,
  }) async {
    final res = await _api.post(
      ApiEndpoints.subscriptions.verifyId,
      data: {'org': org, 'institution_id': institutionId},
    );
    final data = res.data['data'] as Map<String, dynamic>?;
    final verified = data?['verified'] as bool? ?? false;
    if (!verified) return null;
    final subJson = data?['subscription'] as Map<String, dynamic>?;
    if (subJson == null) return null;
    return UserSubscription.fromJson(subJson);
  }
}
