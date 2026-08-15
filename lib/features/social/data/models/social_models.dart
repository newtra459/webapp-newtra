class FriendModel {
  final String id;
  final String name;
  final String type; // Student, Employee, General
  final String totalDistance;
  final int rides;
  final bool isFollowing;

  const FriendModel({
    required this.id,
    required this.name,
    required this.type,
    this.totalDistance = '0 km',
    this.rides = 0,
    this.isFollowing = false,
  });

  factory FriendModel.fromJson(Map<String, dynamic> json) {
    // Backend returns User structs with uid, first_name, last_name, type, etc.
    final id = json['id'] as String? ?? json['uid'] as String? ?? '';
    final firstName = json['first_name'] as String? ?? '';
    final lastName = json['last_name'] as String? ?? '';
    final name = json['name'] as String? ?? '$firstName $lastName'.trim();

    // Backend returns `distance` (float) — convert to "X.XX km" string
    // Also check `total_distance` for backward compat
    String totalDistance = json['total_distance'] as String? ?? '';
    if (totalDistance.isEmpty) {
      final dist = json['distance'];
      if (dist is num) {
        totalDistance = '${dist.toStringAsFixed(2)} km';
      } else {
        totalDistance = '0 km';
      }
    }

    // Backend returns `trips` (int) — map to `rides`
    final rides = (json['rides'] as num?)?.toInt() ??
        (json['trips'] as num?)?.toInt() ??
        0;

    return FriendModel(
      id: id,
      name: name.isEmpty ? firstName : name,
      type: json['type'] as String? ?? 'General',
      totalDistance: totalDistance,
      rides: rides,
      isFollowing: json['is_following'] as bool? ?? json['following'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'total_distance': totalDistance,
        'rides': rides,
        'is_following': isFollowing,
      };

  FriendModel copyWith({bool? isFollowing}) {
    return FriendModel(
      id: id,
      name: name,
      type: type,
      totalDistance: totalDistance,
      rides: rides,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }
}

class LeaderboardEntry {
  final String id;
  final String name;
  final Map<String, String> values; // metric → formatted value
  final bool isMe;
  final String? badge;
  final int members; // relevant for group leaderboard

  const LeaderboardEntry({
    required this.id,
    required this.name,
    required this.values,
    this.isMe = false,
    this.badge,
    this.members = 0,
  });

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      values: (json['values'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v.toString())) ?? {},
      isMe: json['is_me'] as bool? ?? false,
      badge: json['badge'] as String?,
      members: (json['members'] as num?)?.toInt() ?? 0,
    );
  }
}
