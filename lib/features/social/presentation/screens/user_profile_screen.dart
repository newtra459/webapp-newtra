import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../../activity/presentation/providers/activity_provider.dart';
import '../providers/social_provider.dart';
import '../../../profile/data/achievements.dart';

/// Provider that fetches user profile overview from /user/profile/{userId}
final userProfileProvider = FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final repo = ref.watch(activityRepositoryProvider);
  return repo.getUserProfileOverview(userId);
});

class UserProfileScreen extends ConsumerStatefulWidget {
  final String name;
  final String type;
  final String distance;
  final bool following;
  final String userId;
  final String? avatarUrl;

  const UserProfileScreen({
    super.key,
    required this.name,
    required this.type,
    required this.distance,
    this.following = false,
    this.userId = '',
    this.avatarUrl,
  });

  @override
  ConsumerState<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends ConsumerState<UserProfileScreen> {
  late bool _following;

  @override
  void initState() {
    super.initState();
    _following = widget.following;
  }

  String get _initials {
    final parts = widget.name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final localFollowStatus = widget.userId.isNotEmpty
        ? ref.watch(
            socialProvider.select((state) => state.followStatusFor(widget.userId)),
          )
        : null;
    final profileAsync = widget.userId.isNotEmpty
        ? ref.watch(userProfileProvider(widget.userId))
        : const AsyncValue<Map<String, dynamic>>.data({});

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _buildContent(isDark, null, localFollowStatus),
        data: (data) => _buildContent(isDark, data, localFollowStatus),
      ),
    );
  }

  Widget _buildContent(
    bool isDark,
    Map<String, dynamic>? profileData,
    bool? localFollowStatus,
  ) {
    final user = profileData?['user'] as Map<String, dynamic>? ?? {};
    final social = profileData?['social'] as Map<String, dynamic>? ?? {};
    final summary = profileData?['summary'] as Map<String, dynamic>? ?? {};
    final recentActivity = profileData?['recent_activity'] as List? ?? [];

    final name = user['first_name'] != null
        ? '${user['first_name']} ${user['last_name'] ?? ''}'.trim()
        : widget.name;
    final type = user['type'] as String? ?? widget.type;
    final avatarUrl = user['avatar'] as String? ?? widget.avatarUrl;
    final followersCount = (social['followers_count'] as num?)?.toInt() ?? 0;
    final followingCount = (social['following_count'] as num?)?.toInt() ?? 0;
    final isFollowing =
        localFollowStatus ?? (social['is_following'] as bool? ?? _following);
    final isSelf = social['is_self'] as bool? ?? false;

    // Summary stats
    final totalDistance = (summary['total_distance_km'] as num?)?.toDouble() ?? 0.0;
    final totalTrips = (summary['total_trips'] as num?)?.toInt() ?? 0;
    final co2Saved = (summary['co2_saved_kg'] as num?)?.toDouble() ?? 0.0;
    final streakDays = (summary['current_streak_days'] as num?)?.toInt() ?? 0;
    final avgSpeed = (summary['average_speed_kmh'] as num?)?.toDouble() ?? 0.0;
    final maxSpeed = (summary['max_speed_kmh'] as num?)?.toDouble() ?? 0.0;
    final totalCalories = (summary['total_calories'] as num?)?.toDouble() ?? 0.0;
    final totalElevation = (summary['total_elevation_m'] as num?)?.toDouble() ?? 0.0;
    final rideTimeHours = (summary['ride_time_hours'] as num?)?.toDouble() ?? 0.0;
    final groupsCount = (summary['groups_count'] as num?)?.toInt() ?? 0;
    final points = (user['points'] as num?)?.toInt() ?? 0;

    // Level
    final level = buildLevelProgress(points);

    // Achievements
    final metrics = AchievementMetrics(
      tripsCount: totalTrips,
      totalDistance: totalDistance,
      co2Saved: co2Saved,
      followingCount: followingCount,
      followersCount: followersCount,
      groupsCount: groupsCount,
      currentStreakDays: streakDays,
      highestSpeed: maxSpeed,
      rideHours: rideTimeHours,
      points: points > 0 ? points : null,
    );
    final achievements = buildAchievements(metrics);
    final unlocked = achievements.where((a) => a.unlocked).toList();

    // Format distance
    final distStr = totalDistance > 0
        ? '${totalDistance.toStringAsFixed(1)} km'
        : widget.distance;

    if (isFollowing != _following && profileData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _following = isFollowing);
      });
    }

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildHero(context, isDark,
          name: name,
          type: type,
          avatarUrl: avatarUrl,
          level: level.currentLevel,
          followersCount: followersCount,
          followingCount: followingCount,
          isSelf: isSelf,
        )),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 40.h),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              SizedBox(height: 20.h),
              _buildStatsRow(isDark,
                distance: distStr,
                trips: totalTrips,
                co2: co2Saved,
                streak: streakDays,
              ),
              SizedBox(height: 20.h),
              _buildBadgesCard(isDark, unlocked),
              SizedBox(height: 20.h),
              _buildActivityCard(isDark, recentActivity),
              SizedBox(height: 20.h),
              _buildRideStatsCard(isDark,
                distance: distStr,
                avgSpeed: avgSpeed,
                co2: co2Saved,
                calories: totalCalories,
                elevation: totalElevation,
                rideTimeHours: rideTimeHours,
              ),
            ]),
          ),
        ),
      ],
    );
  }

  String get _bio {
    final t = widget.type.isNotEmpty ? widget.type : 'Rider';
    return '$t • Campus Rider';
  }

  // ── Hero ──────────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context, bool isDark, {
    required String name,
    required String type,
    String? avatarUrl,
    required int level,
    required int followersCount,
    required int followingCount,
    required bool isSelf,
  }) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 24.h),
              child: Column(
                children: [
                  // Back button row
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkElevated : AppColors.grey100,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 16.w,
                          color: isDark ? AppColors.white : AppColors.grey800,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  // Avatar ring
                  GestureDetector(
                    onTap: () => showPhotoViewer(
                      context,
                      imageUrl: avatarUrl,
                      name: name,
                    ),
                    child: Container(
                    width: 90.w,
                    height: 90.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [AppColors.primaryDark, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: EdgeInsets.all(3.w),
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkElevated : AppColors.grey100,
                      ),
                      alignment: Alignment.center,
                      child: avatarUrl != null && avatarUrl.isNotEmpty
                          ? ClipOval(
                              child: Image.network(
                                avatarUrl,
                                width: 84.w,
                                height: 84.w,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Text(
                                  _initials,
                                  style: TextStyle(
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            )
                          : Text(
                        _initials,
                        style: TextStyle(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                  ),
                  SizedBox(height: 14.h),
                  // Name
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                      color: isDark ? AppColors.white : AppColors.grey900,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // Type + Level badges
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8.w,
                    runSpacing: 6.h,
                    children: [
                      _typeBadge(isDark, type),
                      _levelBadge(isDark, level),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  // Followers / Following
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _showFollowersSheet(
                              context, isDark,
                              showFollowers: true),
                          child: Text(
                            '$followersCount followers',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark
                                  ? AppColors.white
                                  : AppColors.grey900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          ' · ',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.grey500,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _showFollowersSheet(
                              context, isDark,
                              showFollowers: false),
                          child: Text(
                            '$followingCount following',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: isDark
                                  ? AppColors.white
                                  : AppColors.grey900,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  // Bio
                  Text(
                    '$type • Lv. $level Cyclist • Campus Rider',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isDark ? AppColors.grey400 : AppColors.grey600,
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 18.h),
                  // Follow button (hide if viewing self)
                  if (!isSelf) _buildFollowButton(isDark),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _typeBadge(bool isDark, String type) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.school_rounded, size: 11.w, color: AppColors.primary),
          SizedBox(width: 4.w),
          Text(
            type.isNotEmpty ? type : 'Rider',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _levelBadge(bool isDark, int level) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.bolt_rounded, size: 11.w, color: AppColors.warning),
          SizedBox(width: 3.w),
          Text(
            'Lv. $level',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  void _showFollowersSheet(BuildContext context, bool isDark,
      {required bool showFollowers}) {
    final title = showFollowers ? 'Followers' : 'Following';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _UserFollowersSheet(
        title: title,
        count: 0,
        people: const [],
        isDark: isDark,
      ),
    );
  }

  Widget _buildFollowButton(bool isDark) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        final newState = !_following;
        setState(() => _following = newState);
        if (widget.userId.isNotEmpty) {
          final socialNotifier = ref.read(socialProvider.notifier);
          final ok = newState
              ? await socialNotifier.follow(widget.userId)
              : await socialNotifier.unfollow(widget.userId);
          if (!mounted) return;
          if (!ok) {
            setState(() => _following = !newState);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  newState ? 'Failed to follow user' : 'Failed to unfollow user',
                ),
                backgroundColor: AppColors.error,
              ),
            );
            return;
          }
          ref.invalidate(userProfileProvider(widget.userId));
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 36.w, vertical: 11.h),
        decoration: BoxDecoration(
          color: _following
              ? (isDark ? AppColors.darkElevated : AppColors.grey100)
              : AppColors.primary,
          borderRadius: BorderRadius.circular(28.r),
          border: _following
              ? Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : AppColors.grey200)
              : null,
          boxShadow: _following
              ? null
              : [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _following
                  ? Icons.person_remove_rounded
                  : Icons.person_add_rounded,
              size: 15.w,
              color: _following
                  ? (isDark ? AppColors.grey300 : AppColors.grey600)
                  : AppColors.white,
            ),
            SizedBox(width: 7.w),
            Text(
              _following ? 'Following' : 'Follow',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: _following
                    ? (isDark ? AppColors.grey300 : AppColors.grey600)
                    : AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow(bool isDark, {
    required String distance,
    required int trips,
    required double co2,
    required int streak,
  }) {
    final stats = [
      (
        distance.isNotEmpty ? distance : '—',
        'Distance',
        Icons.straighten_rounded,
        AppColors.distance,
      ),
      ('$trips', 'Rides', Icons.pedal_bike_rounded, AppColors.primary),
      ('${co2.toStringAsFixed(1)} kg', 'CO2 Saved', Icons.eco_rounded, AppColors.success),
      ('$streak days', 'Streak', Icons.local_fire_department_rounded, AppColors.calories),
    ];
    return Row(
      children: stats.asMap().entries.map((e) {
        final (value, label, icon, color) = e.value;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: e.key < stats.length - 1 ? 8.w : 0),
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 6.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 16.w, color: color),
                ),
                SizedBox(height: 7.h),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.white : AppColors.grey900,
                    ),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  label,
                  style: TextStyle(fontSize: 9.sp, color: AppColors.grey500),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Badges card ───────────────────────────────────────────────────────────

  Widget _buildBadgesCard(bool isDark, List<AchievementItem> unlocked) {
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Achievements', Icons.emoji_events_rounded, AppColors.warning, isDark),
          SizedBox(height: 16.h),
          unlocked.isEmpty
              ? Text('No achievements yet', style: TextStyle(fontSize: 12.sp, color: AppColors.grey400))
              : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: unlocked.map((b) {
                return Padding(
                  padding: EdgeInsets.only(right: 14.w),
                  child: Column(
                    children: [
                      Container(
                        width: 46.w,
                        height: 46.w,
                        decoration: BoxDecoration(
                          color: b.color.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: b.color.withValues(alpha: 0.30),
                            width: 1.5,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          b.icon,
                          size: 20.w,
                          color: b.color,
                        ),
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        b.title,
                        style: TextStyle(
                          fontSize: 9.sp,
                          color: AppColors.grey500,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── Activity card ─────────────────────────────────────────────────────────

  Widget _buildActivityCard(bool isDark, List recentActivity) {
    // Use real recent_activity from API, fallback to placeholder
    final activities = recentActivity.isNotEmpty
        ? recentActivity.take(4).map((a) {
            final act = a as Map<String, dynamic>;
            final type = act['type'] as String? ?? 'ride';
            final distance = (act['distance'] as num?)?.toDouble();
            final distStr = distance != null ? '${distance.toStringAsFixed(1)} km' : '';
            final timestamp = act['timestamp'] as String? ?? '';
            final timeAgo = _formatTimeAgo(timestamp);
            IconData icon;
            Color color;
            String title;
            switch (type) {
              case 'ride':
              case 'trip':
                icon = Icons.pedal_bike_rounded;
                color = AppColors.primary;
                title = 'Completed a ride';
                break;
              case 'group_join':
                icon = Icons.groups_rounded;
                color = AppColors.success;
                title = 'Joined a group';
                break;
              case 'badge':
              case 'achievement':
                icon = Icons.emoji_events_rounded;
                color = AppColors.warning;
                title = 'Earned a badge';
                break;
              default:
                icon = Icons.history_rounded;
                color = AppColors.info;
                title = type;
            }
            return (icon, title, distStr, color, timeAgo);
          }).toList()
        : <(IconData, String, String, Color, String)>[
            (Icons.pedal_bike_rounded, 'No recent activity', '', AppColors.grey400, ''),
          ];

    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Recent Activity', Icons.history_rounded, AppColors.info, isDark),
          SizedBox(height: 12.h),
          ...activities.asMap().entries.map((e) {
            final (icon, title, sub, color, time) = e.value;
            final isLast = e.key == activities.length - 1;
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 10.h),
                  child: Row(
                    children: [
                      Container(
                        width: 38.w,
                        height: 38.w,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: color, size: 18.w),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.white : AppColors.grey900,
                              ),
                            ),
                            if (sub.isNotEmpty)
                              Text(
                                sub,
                                style: TextStyle(fontSize: 11.sp, color: AppColors.grey500),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(fontSize: 10.sp, color: AppColors.grey400),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 50.w,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  String _formatTimeAgo(String isoTimestamp) {
    if (isoTimestamp.isEmpty) return '';
    try {
      final dt = DateTime.parse(isoTimestamp);
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${diff.inDays ~/ 7}w ago';
    } catch (_) {
      return '';
    }
  }

  // ── Ride stats card ───────────────────────────────────────────────────────

  Widget _buildRideStatsCard(bool isDark, {
    required String distance,
    required double avgSpeed,
    required double co2,
    required double calories,
    required double elevation,
    required double rideTimeHours,
  }) {
    final rideH = rideTimeHours.toInt();
    final rideM = ((rideTimeHours - rideH) * 60).toInt();
    final metrics = [
      ('Total Distance', distance.isNotEmpty ? distance : '—', Icons.straighten_rounded, AppColors.distance),
      ('Avg Speed', '${avgSpeed.toStringAsFixed(1)} km/h', Icons.speed_rounded, AppColors.speed),
      ('CO2 Saved', '${co2.toStringAsFixed(1)} kg', Icons.eco_rounded, AppColors.success),
      ('Calories', '${calories.toInt()} kcal', Icons.local_fire_department_rounded, AppColors.calories),
      ('Elevation', '${elevation.toInt()} m', Icons.terrain_rounded, AppColors.elevation),
      ('Ride Time', '${rideH}h ${rideM}m', Icons.timer_rounded, AppColors.info),
    ];
    return _card(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Ride Stats', Icons.bar_chart_rounded, AppColors.primary, isDark),
          SizedBox(height: 16.h),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10.h,
            crossAxisSpacing: 10.w,
            childAspectRatio: 1.0,
            children: metrics.map((m) {
              final (label, value, icon, color) = m;
              return Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevated : AppColors.grey50,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18.w, color: color),
                    SizedBox(height: 6.h),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        value,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.white : AppColors.grey900,
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      label,
                      style: TextStyle(fontSize: 8.5.sp, color: AppColors.grey500),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _card(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardTitle(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15.w, color: color),
        ),
        SizedBox(width: 10.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.white : AppColors.grey900,
          ),
        ),
      ],
    );
  }
}

// ── Followers / Following bottom sheet ───────────────────────────────────────

class _UserFollowersSheet extends StatefulWidget {
  final String title;
  final int count;
  final List<(String, String)> people;
  final bool isDark;

  const _UserFollowersSheet({
    required this.title,
    required this.count,
    required this.people,
    required this.isDark,
  });

  @override
  State<_UserFollowersSheet> createState() => _UserFollowersSheetState();
}

class _UserFollowersSheetState extends State<_UserFollowersSheet> {
  late final List<bool> _following;

  @override
  void initState() {
    super.initState();
    _following = List.generate(widget.people.length, (i) => i % 2 == 0);
  }

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: EdgeInsets.only(top: 12.h),
            child: Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppColors.grey300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 12.h),
            child: Row(
              children: [
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${widget.count}',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32.w,
                    height: 32.w,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkElevated
                          : AppColors.grey100,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.close_rounded,
                      size: 16.w,
                      color: isDark ? AppColors.grey300 : AppColors.grey600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          // List
          if (widget.people.isEmpty)
            Padding(
              padding: EdgeInsets.all(32.w),
              child: Text(
                'No ${widget.title.toLowerCase()} yet',
                style: TextStyle(fontSize: 14.sp, color: AppColors.grey400),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                padding: EdgeInsets.fromLTRB(
                    20.w,
                    12.h,
                    20.w,
                    MediaQuery.of(context).padding.bottom + 20.h),
                itemCount: widget.people.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  indent: 60.w,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                itemBuilder: (_, i) {
                  final (name, type) = widget.people[i];
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    child: Row(
                      children: [
                        Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.primaryLight
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(name),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.white
                                      : AppColors.grey900,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                type,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.grey500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              setState(() => _following[i] = !_following[i]),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                                horizontal: 14.w, vertical: 7.h),
                            decoration: BoxDecoration(
                              color: _following[i]
                                  ? (isDark
                                      ? AppColors.darkElevated
                                      : AppColors.grey100)
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(20.r),
                              border: _following[i]
                                  ? Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.10)
                                          : AppColors.grey200)
                                  : null,
                            ),
                            child: Text(
                              _following[i] ? 'Following' : 'Follow',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: _following[i]
                                    ? (isDark
                                        ? AppColors.grey300
                                        : AppColors.grey600)
                                    : AppColors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
