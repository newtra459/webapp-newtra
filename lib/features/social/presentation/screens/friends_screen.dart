import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mj_avatar.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../../groups/presentation/providers/groups_provider.dart';
import '../../data/models/social_models.dart';
import '../providers/social_provider.dart';

class FriendsScreen extends ConsumerStatefulWidget {
  const FriendsScreen({super.key});

  @override
  ConsumerState<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends ConsumerState<FriendsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tab;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static Map<String, dynamic> _friendToMap(FriendModel f) => {
        'id': f.id,
        'userId': f.id,
        'name': f.name,
        'type': f.type,
        'distance': f.totalDistance,
        'rides': f.rides,
        'following': f.isFollowing,
      };

  static const _typeColors = {
    'Student':  AppColors.info,
    'Employee': AppColors.primary,
    'General':  AppColors.elevation,
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> list) {
    if (_query.isEmpty) return list;
    return list
        .where((u) =>
            (u['name'] as String).toLowerCase().contains(_query.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final socialState = ref.watch(socialProvider);
    final suggested = socialState.suggested.map(_friendToMap).toList();
    final followers = socialState.followers.map(_friendToMap).toList();
    final following = socialState.following.map(_friendToMap).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            _buildSearch(isDark),
            _buildTabBar(isDark),
            Expanded(child: _buildTabBody(isDark, suggested, followers, following)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community',
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),
                Text(
                  'Connect with fellow riders',
                  style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
                ),
              ],
            ),
          ),
          _iconBtn(
            Icons.emoji_events_rounded,
            AppColors.warning,
            () => context.push('/leaderboard'),
            isDark,
          ),
          SizedBox(width: 10.w),
          _iconBtn(
            Icons.groups_rounded,
            AppColors.primary,
            () => context.push('/groups'),
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(
      IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12.r),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 20.w, color: color),
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Widget _buildSearch(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 14.h),
      child: Container(
        height: 44.h,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkElevated : AppColors.grey50,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ),
        child: Row(
          children: [
            SizedBox(width: 12.w),
            Icon(Icons.search_rounded, size: 18.w, color: AppColors.grey400),
            SizedBox(width: 8.w),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                style: TextStyle(
                    fontSize: 14.sp,
                    color: isDark ? AppColors.white : AppColors.grey900),
                decoration: InputDecoration(
                  hintText: 'Search riders…',
                  hintStyle:
                      TextStyle(fontSize: 14.sp, color: AppColors.grey400),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (_query.isNotEmpty)
              GestureDetector(
                onTap: () {
                  _searchCtrl.clear();
                  setState(() => _query = '');
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  child: Icon(Icons.close_rounded,
                      size: 16.w, color: AppColors.grey400),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 10.h),
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tab,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(13.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.grey500,
          labelStyle:
              TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
          padding: EdgeInsets.all(4.w),
          labelPadding: EdgeInsets.zero,
          tabs: [
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 6.w), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.explore_rounded, size: 15.w), SizedBox(width: 5.w), const Text('Discover')])))),
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 6.w), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.person_add_rounded, size: 15.w), SizedBox(width: 5.w), const Text('Followers')])))),
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 6.w), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.how_to_reg_rounded, size: 15.w), SizedBox(width: 5.w), const Text('Following')])))),
          ],
        ),
      ),
    );
  }

  // ── Tab body ───────────────────────────────────────────────────────────────

  Widget _buildTabBody(bool isDark, List<Map<String, dynamic>> suggested,
      List<Map<String, dynamic>> followers, List<Map<String, dynamic>> following) {
    return TabBarView(
      controller: _tab,
      children: [
        _buildDiscover(isDark, suggested),
        _buildList(_filter(followers), isDark, showFollow: false),
        _buildList(_filter(following), isDark,
            showFollow: true, isFollowing: true),
      ],
    );
  }

  // ── Discover ───────────────────────────────────────────────────────────────

  Widget _buildDiscover(bool isDark, List<Map<String, dynamic>> suggested) {
    final filtered = _filter(suggested);
    if (filtered.isEmpty) {
      return Column(
        children: [
          _buildStatsBar(isDark),
          SizedBox(height: 40.h),
          Icon(Icons.person_search_rounded, size: 64.w, color: isDark ? Colors.white30 : Colors.black26),
          SizedBox(height: 16.h),
          Text(
            'No more profiles',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 48.w),
            child: Text(
              'Check back later for new riders to connect with.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 32.h),
      itemCount: filtered.length + 1,
      itemBuilder: (_, i) {
        if (i == 0) return _buildStatsBar(isDark);
        final user = filtered[i - 1];
        final userId = user['id'] as String;
        final isFollowing = user['following'] as bool? ?? false;
        return _UserCard(
          user: user,
          isDark: isDark,
          typeColors: _typeColors,
          onTap: () => context.push('/user-profile', extra: user),
          onFollow: () {
            if (isFollowing) {
              ref.read(socialProvider.notifier).unfollow(userId);
            } else {
              ref.read(socialProvider.notifier).follow(userId);
            }
          },
        );
      },
    );
  }

  Widget _buildStatsBar(bool isDark) {
    final socialState = ref.watch(socialProvider);
    final groupsState = ref.watch(groupsProvider);

    // Unique riders across suggested + followers + following
    final allIds = <String>{};
    for (final f in socialState.suggested) allIds.add(f.id);
    for (final f in socialState.followers) allIds.add(f.id);
    for (final f in socialState.following) allIds.add(f.id);
    final ridersCount = allIds.length.toString();

    // Total distance from all known riders
    double totalKm = 0;
    final seen = <String>{};
    for (final list in [socialState.suggested, socialState.followers, socialState.following]) {
      for (final f in list) {
        if (seen.add(f.id)) {
          final num = double.tryParse(f.totalDistance.replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;
          totalKm += num;
        }
      }
    }
    final kmLabel = totalKm >= 1000
        ? '${(totalKm / 1000).toStringAsFixed(1)}k'
        : totalKm.toStringAsFixed(1);

    final groupsCount = (groupsState.myGroups.length + groupsState.discover.length).toString();

    final stats = [
      (Icons.people_rounded, ridersCount, 'Riders'),
      (Icons.route_rounded, kmLabel, 'km total'),
      (Icons.groups_rounded, groupsCount, 'Groups'),
    ];
    return Container(
      margin: EdgeInsets.only(bottom: 18.h),
      padding: EdgeInsets.symmetric(vertical: 16.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: List.generate(stats.length, (i) {
          final (icon, val, label) = stats[i];
          final isLast = i == stats.length - 1;
          return Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: isLast
                    ? null
                    : Border(
                        right: BorderSide(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                        )),
              ),
              child: Column(
                children: [
                  Icon(icon, size: 20.w, color: AppColors.primary),
                  SizedBox(height: 4.h),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(val,
                        style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppColors.white : AppColors.grey900)),
                  ),
                  Text(label,
                      style: TextStyle(
                          fontSize: 11.sp, color: AppColors.grey500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Followers / Following list ─────────────────────────────────────────────

  Widget _buildList(
    List<Map<String, dynamic>> users,
    bool isDark, {
    bool showFollow = false,
    bool isFollowing = false,
  }) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.people_outline_rounded,
                  size: 32.w, color: AppColors.primary.withValues(alpha: 0.5)),
            ),
            SizedBox(height: 14.h),
            Text(
              isFollowing ? 'Not following anyone yet' : 'No followers yet',
              style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.grey400 : AppColors.grey600),
            ),
            SizedBox(height: 4.h),
            Text(
              'Discover riders and start connecting!',
              style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 32.h),
      itemCount: users.length,
      itemBuilder: (_, i) {
        final user = users[i];
        return _UserCard(
          user: user,
          isDark: isDark,
          typeColors: _typeColors,
          onTap: () => context.push('/user-profile', extra: user),
          onFollow: showFollow
              ? () {
                  final userId = user['id'] as String;
                  ref.read(socialProvider.notifier).unfollow(userId);
                }
              : null,
        );
      },
    );
  }
}

// ── User card widget ──────────────────────────────────────────────────────────

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final bool isDark;
  final Map<String, Color?> typeColors;
  final VoidCallback onTap;
  final VoidCallback? onFollow;

  const _UserCard({
    required this.user,
    required this.isDark,
    required this.typeColors,
    required this.onTap,
    this.onFollow,
  });

  @override
  Widget build(BuildContext context) {
    final isFollowing = user['following'] as bool? ?? false;
    final typeColor = typeColors[user['type']] ?? AppColors.primary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar with colored ring
            GestureDetector(
              onTap: () => showPhotoViewer(
                context,
                name: user['name'] as String,
                imageUrl: user['imageUrl'] as String?,
              ),
              child: Container(
                padding: EdgeInsets.all(2.5.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: typeColor, width: 2),
                ),
                child: MjAvatar(name: user['name'] as String, size: 46),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user['name'] as String,
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.white : AppColors.grey900,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 7.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 7.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          user['type'] as String,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: typeColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 5.h),
                  Row(
                    children: [
                      Icon(Icons.route_rounded,
                          size: 13.w, color: AppColors.distance),
                      SizedBox(width: 4.w),
                      Flexible(
                        child: Text(
                          user['distance'] as String,
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.distance,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (user['rides'] != null) ...[
                        SizedBox(width: 12.w),
                        Icon(Icons.pedal_bike_rounded,
                            size: 13.w, color: AppColors.grey400),
                        SizedBox(width: 4.w),
                        Text(
                          '${user['rides']} rides',
                          style: TextStyle(
                              fontSize: 12.sp, color: AppColors.grey500),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (onFollow != null)
              GestureDetector(
                onTap: onFollow,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 9.h),
                  decoration: BoxDecoration(
                    color: isFollowing
                        ? (isDark
                            ? AppColors.darkElevated
                            : AppColors.grey100)
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: isFollowing
                        ? null
                        : [
                            BoxShadow(
                              color: AppColors.primary
                                  .withValues(alpha: 0.35),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                  ),
                  child: Text(
                    isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: isFollowing
                          ? (isDark
                              ? AppColors.grey400
                              : AppColors.grey600)
                          : Colors.white,
                    ),
                  ),
                ),
              )
            else
              Icon(Icons.chevron_right_rounded,
                  size: 20.w, color: AppColors.grey400),
          ],
        ),
      ),
    );
  }
}

