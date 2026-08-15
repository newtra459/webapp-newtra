class GroupModel {
  final String id;
  final String name;
  final String description;
  final String category;
  final int members;
  final String totalDistance;
  final bool joined;
  final bool isCreator;
  final String visibility;
  final String? createdBy;
  final String? imageUrl;

  const GroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    this.members = 0,
    this.totalDistance = '0 km',
    this.joined = false,
    this.isCreator = false,
    this.visibility = 'public',
    this.createdBy,
    this.imageUrl,
  });

  factory GroupModel.fromJson(Map<String, dynamic> json) {
    // Backend returns total_distance as a number, format it as string
    final rawDistance = json['total_distance'];
    String distanceStr;
    if (rawDistance is num) {
      distanceStr = '${rawDistance >= 100 ? rawDistance.toStringAsFixed(0) : rawDistance.toStringAsFixed(1)} km';
    } else if (rawDistance is String) {
      distanceStr = rawDistance;
    } else {
      distanceStr = '0 km';
    }

    return GroupModel(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      category: json['category'] as String? ?? 'Campus',
      members: (json['members'] as num?)?.toInt() ?? (json['member_count'] as num?)?.toInt() ?? 0,
      totalDistance: distanceStr,
      joined: json['is_member'] as bool? ?? json['joined'] as bool? ?? false,
      isCreator: json['is_creator'] as bool? ?? false,
      visibility: json['visibility'] as String? ?? 'public',
      createdBy: json['created_by'] as String?,
      imageUrl: json['avatar_url'] as String? ?? json['image_url'] as String? ?? json['group_image'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'category': category,
        'members': members,
        'total_distance': totalDistance,
        'joined': joined,
        'is_creator': isCreator,
        'visibility': visibility,
        'created_by': createdBy,
        'image_url': imageUrl,
      };

  GroupModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    int? members,
    String? totalDistance,
    bool? joined,
    bool? isCreator,
    String? visibility,
    String? createdBy,
    String? imageUrl,
  }) {
    return GroupModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      members: members ?? this.members,
      totalDistance: totalDistance ?? this.totalDistance,
      joined: joined ?? this.joined,
      isCreator: isCreator ?? this.isCreator,
      visibility: visibility ?? this.visibility,
      createdBy: createdBy ?? this.createdBy,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}

// ── Group Member Model ──────────────────────────────────────────────────────

class GroupMemberModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String? avatar;
  final double kmTraveled;
  final int totalTrips;
  final double carbonFootprint;
  final int points;
  final bool isAdmin;
  final String role;

  const GroupMemberModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    this.avatar,
    this.kmTraveled = 0,
    this.totalTrips = 0,
    this.carbonFootprint = 0,
    this.points = 0,
    this.isAdmin = false,
    this.role = 'Member',
  });

  String get fullName => '$firstName $lastName'.trim();

  String get distanceFormatted =>
      '${kmTraveled >= 100 ? kmTraveled.toStringAsFixed(0) : kmTraveled.toStringAsFixed(1)} km';

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    final km = (json['km_traveled'] as num?)?.toDouble() ??
        (json['Km_traveled'] as num?)?.toDouble() ??
        (json['total_distance'] as num?)?.toDouble() ??
        0;
    return GroupMemberModel(
      uid: json['uid'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      kmTraveled: km,
      totalTrips: (json['total_trips'] as num?)?.toInt() ?? 0,
      carbonFootprint: (json['carbon_footprint'] as num?)?.toDouble() ?? 0,
      points: (json['points'] as num?)?.toInt() ?? 0,
      isAdmin: json['is_admin'] as bool? ?? false,
      role: json['role'] as String? ?? (json['is_admin'] == true ? 'Admin' : 'Member'),
    );
  }
}

// ── Group Aggregate Model ───────────────────────────────────────────────────

class GroupAggregateModel {
  final double totalDistance;
  final int totalTrips;
  final int totalCalories;
  final double totalTime;
  final double averageSpeed;
  final double highestElevation;
  final double carbonFootprintKg;
  final int totalPoints;
  final int noOfUsers;

  const GroupAggregateModel({
    this.totalDistance = 0,
    this.totalTrips = 0,
    this.totalCalories = 0,
    this.totalTime = 0,
    this.averageSpeed = 0,
    this.highestElevation = 0,
    this.carbonFootprintKg = 0,
    this.totalPoints = 0,
    this.noOfUsers = 0,
  });

  String get distanceFormatted =>
      totalDistance >= 1000
          ? '${(totalDistance / 1000).toStringAsFixed(1)}k'
          : totalDistance >= 100
              ? totalDistance.toStringAsFixed(0)
              : totalDistance.toStringAsFixed(1);

  String get carbonFormatted =>
      carbonFootprintKg >= 1000
          ? '${(carbonFootprintKg / 1000).toStringAsFixed(1)}k'
          : carbonFootprintKg.toStringAsFixed(0);

  factory GroupAggregateModel.fromJson(Map<String, dynamic> json) {
    final raw = json['aggregate_data'] as Map<String, dynamic>? ?? json;
    return GroupAggregateModel(
      totalDistance: (raw['total_distance'] as num?)?.toDouble() ?? (raw['total_km'] as num?)?.toDouble() ?? 0,
      totalTrips: (raw['total_trips'] as num?)?.toInt() ?? 0,
      totalCalories: (raw['total_calories'] as num?)?.toInt() ?? 0,
      totalTime: (raw['total_time'] as num?)?.toDouble() ?? 0,
      averageSpeed: (raw['average_speed'] as num?)?.toDouble() ?? 0,
      highestElevation: (raw['highest_elevation'] as num?)?.toDouble() ?? 0,
      carbonFootprintKg: (raw['carbon_footprint_kg'] as num?)?.toDouble() ?? (raw['total_carbon'] as num?)?.toDouble() ?? 0,
      totalPoints: (raw['total_points'] as num?)?.toInt() ?? 0,
      noOfUsers: (raw['no_of_users'] as num?)?.toInt() ?? 0,
    );
  }
}

// ── Community Post Model ─────────────────────────────────────────────────────

class CommunityPostModel {
  final String id;
  final String userId;
  final String groupId;
  final String body;
  final String imageUrl;
  final String createdAt;
  final String groupName;
  final String authorName;
  final String? authorAvatar;

  const CommunityPostModel({
    required this.id,
    required this.userId,
    this.groupId = '',
    this.body = '',
    this.imageUrl = '',
    this.createdAt = '',
    this.groupName = '',
    this.authorName = '',
    this.authorAvatar,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>? ?? {};
    final firstName = user['first_name'] as String? ?? '';
    final lastName = user['last_name'] as String? ?? '';
    return CommunityPostModel(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      groupId: json['group_id'] as String? ?? '',
      body: json['body'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      createdAt: json['created_at'] as String? ?? '',
      groupName: json['group_name'] as String? ?? '',
      authorName: '$firstName $lastName'.trim(),
      authorAvatar: user['avatar'] as String?,
    );
  }

  String get relativeTime {
    final dt = DateTime.tryParse(createdAt);
    if (dt == null) return 'Just now';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }
}
