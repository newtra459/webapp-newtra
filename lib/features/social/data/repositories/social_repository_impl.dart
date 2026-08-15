import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../groups/data/models/group_model.dart';
import '../models/social_models.dart';
import 'social_repository.dart';

class SocialRepositoryImpl implements SocialRepository {
  final ApiClient _api;

  SocialRepositoryImpl(this._api);

  String _wholeNumberString(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0.0;
    return number.round().toString();
  }

  List<FriendModel> _extractUserList(dynamic responseData) {
    final root = (responseData is Map<String, dynamic>) ? responseData : <String, dynamic>{};
    final data = root['data'];
    if (data is List) return data.map((e) => FriendModel.fromJson(e as Map<String, dynamic>)).toList();
    if (data is Map<String, dynamic>) {
      // Backend wraps followers/following inside data object
      final inner = data['followers'] ?? data['following'] ?? data['users'];
      if (inner is List) return inner.map((e) => FriendModel.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  @override
  Future<List<FriendModel>> getSuggested() async {
    final res = await _api.get(ApiEndpoints.social.suggested);
    return _extractUserList(res.data);
  }

  @override
  Future<List<FriendModel>> getFollowers() async {
    final res = await _api.get(ApiEndpoints.social.followers);
    return _extractUserList(res.data);
  }

  @override
  Future<List<FriendModel>> getFollowing() async {
    final res = await _api.get(ApiEndpoints.social.following);
    return _extractUserList(res.data);
  }

  @override
  Future<void> follow(String userId) async {
    await _api.post(ApiEndpoints.social.follow(userId));
  }

  @override
  Future<void> unfollow(String userId) async {
    await _api.post(ApiEndpoints.social.unfollow(userId));
  }

  @override
  Future<List<LeaderboardEntry>> getRiderLeaderboard() async {
    final res = await _api.get(ApiEndpoints.social.leaderboardRiders);
    dynamic meData;
    try {
      final meRes = await _api.get(ApiEndpoints.user.me);
      meData = meRes.data;
    } catch (_) {
      meData = const <String, dynamic>{};
    }

    // Backend returns all users via /user/getAll — convert to leaderboard format
    final root = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final list = root['data'] as List? ?? [];
    final meRoot = meData is Map<String, dynamic>
        ? meData as Map<String, dynamic>
        : <String, dynamic>{};
    final me = meRoot['data'] is Map<String, dynamic>
        ? meRoot['data'] as Map<String, dynamic>
        : meRoot;
    final myUid = me['uid'] as String? ?? me['id'] as String? ?? '';

    final entries = list.map((e) {
      final user = e as Map<String, dynamic>;
      final firstName = user['first_name'] as String? ?? user['FirstName'] as String? ?? '';
      final lastName = user['last_name'] as String? ?? user['LastName'] as String? ?? '';
      final name = '$firstName $lastName'.trim();
      final points = user['points'] ?? user['Points'] ?? 0;
      final distance = user['distance'] ?? user['Distance'] ?? 0;
      final distNum = (distance is num) ? distance.toDouble() : (double.tryParse('$distance') ?? 0.0);
      final co2 = distNum * 0.21;
      final id = user['uid'] as String? ?? user['Uid'] as String? ?? user['id'] as String? ?? '';
      return LeaderboardEntry(
        id: id,
        name: name.isEmpty ? 'User' : name,
        values: {
          'points': _wholeNumberString(points),
          'distance': _wholeNumberString(distNum),
          'co2': _wholeNumberString(co2),
        },
        isMe: id.isNotEmpty && id == myUid,
      );
    }).toList();

    if (myUid.isNotEmpty && !entries.any((entry) => entry.id == myUid)) {
      final firstName = me['first_name'] as String? ?? '';
      final lastName = me['last_name'] as String? ?? '';
      final name = ('$firstName $lastName').trim();
      final distance = me['distance'] ?? me['total_distance'] ?? 0;
      final distNum = (distance is num)
          ? distance.toDouble()
          : double.tryParse('$distance') ?? 0.0;
      entries.add(
        LeaderboardEntry(
          id: myUid,
          name: name.isEmpty ? 'You' : name,
          values: {
            'points': _wholeNumberString(me['points'] ?? 0),
            'distance': _wholeNumberString(distNum),
            'co2': _wholeNumberString(distNum * 0.21),
          },
          isMe: true,
        ),
      );
    }

    // Sort by points descending
    entries.sort((a, b) {
      final aPoints = int.tryParse(a.values['points'] ?? '0') ?? 0;
      final bPoints = int.tryParse(b.values['points'] ?? '0') ?? 0;
      return bPoints.compareTo(aPoints);
    });
    return entries;
  }

  @override
  Future<List<LeaderboardEntry>> getGroupLeaderboard() async {
    // Fetch all groups
    final res = await _api.get(
      ApiEndpoints.groups.list,
      queryParameters: {'sort_by': 'activity', 'order': 'desc'},
    );
    final root = (res.data is Map<String, dynamic>) ? res.data as Map<String, dynamic> : <String, dynamic>{};
    final list = root['groups'] as List? ?? root['data'] as List? ?? [];
    final groups = list.map((e) => e as Map<String, dynamic>).toList();

    if (groups.isEmpty) return [];

    // Fetch aggregate data for each group in parallel
    final futures = groups.map((group) async {
      final groupId = group['id'] as String? ?? '';
      if (groupId.isEmpty) return null;
      try {
        final aggRes = await _api.get(ApiEndpoints.groups.aggregate(groupId));
        final aggRoot = (aggRes.data is Map<String, dynamic>) ? aggRes.data as Map<String, dynamic> : <String, dynamic>{};
        return GroupAggregateModel.fromJson(aggRoot);
      } catch (_) {
        return null;
      }
    });
    final aggregates = await Future.wait(futures);

    final entries = <LeaderboardEntry>[];
    for (var i = 0; i < groups.length; i++) {
      final group = groups[i];
      final agg = aggregates[i];
      final distance = agg?.totalDistance ?? (group['total_distance'] as num?)?.toDouble() ?? 0;
      final co2 = agg?.carbonFootprintKg ?? (distance * 0.21);
      final points = agg?.totalPoints ?? 0;
      entries.add(LeaderboardEntry(
        id: group['id'] as String? ?? '',
        name: group['name'] as String? ?? '',
        values: {
          'distance': _wholeNumberString(distance),
          'points': _wholeNumberString(points),
          'co2': _wholeNumberString(co2),
        },
        members: (group['member_count'] as num?)?.toInt() ?? 0,
      ));
    }

    // Sort by distance descending
    entries.sort((a, b) {
      final aVal = double.tryParse(a.values['distance']?.replaceAll('k', '') ?? '0') ?? 0;
      final bVal = double.tryParse(b.values['distance']?.replaceAll('k', '') ?? '0') ?? 0;
      return bVal.compareTo(aVal);
    });
    return entries;
  }
}
