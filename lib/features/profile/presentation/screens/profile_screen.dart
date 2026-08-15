import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../auth/presentation/providers/auth_state_provider.dart';
import '../../../activity/presentation/providers/activity_provider.dart';
import '../../data/models/achievement_model.dart';
import '../../../social/presentation/providers/social_provider.dart';
import '../../../social/data/models/social_models.dart';
import '../../../../core/widgets/mj_avatar.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../providers/achievements_provider.dart';
import '../providers/profile_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _showXpCard = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    // Refresh lifetime stats when Profile opens. The activity provider is
    // created once at app start and can load before auth is ready, leaving the
    // header showing "0 Rides / 0.0 km" even though the user has trips (My Trips
    // and Leaderboard, which fetch on open, show the real totals). Re-fetch here
    // so Profile shows the correct lifetime totals too.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(activityProvider.notifier).loadSummary();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              children: [
                _buildHero(context),
                _buildStatsCard(isDark),
                SizedBox(height: 20.h),
                _buildActivityStrip(isDark),
                SizedBox(height: 20.h),
                _buildMenuGroup(
                  context,
                  isDark,
                  label: 'Account',
                  items: [
                    _MenuItem(
                      Icons.route_rounded,
                      'My Trips',
                      AppColors.info,
                      () => context.push('/trips'),
                    ),
                    _MenuItem(
                      Icons.account_balance_wallet_rounded,
                      'Wallet',
                      AppColors.success,
                      () => context.push('/wallet'),
                    ),
                    _MenuItem(
                      Icons.card_membership_rounded,
                      'Subscriptions',
                      AppColors.warning,
                      () => context.push('/subscriptions'),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                _buildMenuGroup(
                  context,
                  isDark,
                  label: 'Explore',
                  items: [
                    _MenuItem(
                      Icons.bar_chart_rounded,
                      'Activity Dashboard',
                      AppColors.primary,
                      () => context.push('/activity'),
                    ),
                    _MenuItem(
                      Icons.leaderboard_rounded,
                      'Leaderboard',
                      AppColors.elevation,
                      () => context.push('/leaderboard'),
                    ),
                    _MenuItem(
                      Icons.groups_rounded,
                      'Groups',
                      AppColors.speed,
                      () => context.push('/groups'),
                    ),
                  ],
                ),
                SizedBox(height: 14.h),
                _buildMenuGroup(
                  context,
                  isDark,
                  label: 'More',
                  items: [
                    _MenuItem(
                      Icons.person_add_rounded,
                      'Invite Friends',
                      AppColors.distance,
                      _showInviteFriends,
                    ),
                    _MenuItem(
                      Icons.help_rounded,
                      'Help & Support',
                      AppColors.grey500,
                      () => context.push('/support'),
                    ),
                  ],
                ),
                SizedBox(height: 20.h),
                _buildSignOutRow(context, isDark),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 72.h),
              ],
            ),
          ),
          // ── XP overlay ────────────────────────────────────────────────
          if (_showXpCard) ...[
            // Scrim
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showXpCard = false),
                child: Container(color: Colors.black.withValues(alpha: 0.45)),
              ),
            ),
            // Sheet — capped so it never grows above the screen
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.85,
                ),
                child: _buildXpCard(context, isDark),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Hero ───────────────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profile =
        ref.watch(profileProvider).valueOrNull ?? const ProfileData();
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
              child: Column(
                children: [
                  // Top row: avatar left + info right + settings
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avatar with glow ring
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          GestureDetector(
                            onTap: () => showPhotoViewer(
                              context,
                              imagePath: profile.profileImagePath,
                              imageUrl: profile.profileImageUrl,
                              name: profile.fullName.isNotEmpty
                                  ? profile.fullName
                                  : profile.firstName,
                            ),
                            child: Container(
                              width: 80.w,
                              height: 80.w,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryDark,
                                    AppColors.primaryLight,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              padding: EdgeInsets.all(2.5.w),
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isDark
                                      ? AppColors.darkElevated
                                      : AppColors.grey100,
                                ),
                                child: profile.profileImagePath != null
                                    ? ClipOval(
                                        child: Image.file(
                                          File(profile.profileImagePath!),
                                          width: 75.w,
                                          height: 75.w,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : MjAvatar(
                                        name: profile.firstName,
                                        size: 72,
                                        showBorder: false,
                                      ),
                              ),
                            ),
                          ),
                          // Camera badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: _pickProfileImage,
                              child: Container(
                                width: 26.w,
                                height: 26.w,
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.darkCard
                                        : AppColors.white,
                                    width: 2,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.camera_alt_rounded,
                                  size: 12.w,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(width: 16.w),
                      // Name + info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 4.h),
                            Text(
                              profile.fullName.isNotEmpty
                                  ? profile.fullName
                                  : 'Rider',
                              style: TextStyle(
                                fontSize: 24.sp,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                color: isDark
                                    ? AppColors.white
                                    : AppColors.grey900,
                              ),
                            ),
                            if (profile.userNumber.isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              Row(
                                children: [
                                  Icon(
                                    Icons.tag_rounded,
                                    size: 11.w,
                                    color: isDark
                                        ? AppColors.grey400
                                        : AppColors.grey500,
                                  ),
                                  SizedBox(width: 2.w),
                                  Text(
                                    profile.userNumber,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.grey400
                                          : AppColors.grey500,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            SizedBox(height: 5.h),
                            Wrap(
                              spacing: 8.w,
                              runSpacing: 6.h,
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10.w,
                                    vertical: 4.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.school_rounded,
                                        size: 11.w,
                                        color: AppColors.primary,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        'Student',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Builder(
                                  builder: (_) {
                                    final pts = profile.points;
                                    const thresholds = [
                                      0,
                                      200,
                                      500,
                                      1000,
                                      2000,
                                      4000,
                                    ];
                                    int lv = 1;
                                    for (
                                      int i = thresholds.length - 1;
                                      i >= 0;
                                      i--
                                    ) {
                                      if (pts >= thresholds[i]) {
                                        lv = i + 1;
                                        break;
                                      }
                                    }
                                    return Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10.w,
                                        vertical: 4.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.warning.withValues(
                                          alpha: 0.10,
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          8.r,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.bolt_rounded,
                                            size: 11.w,
                                            color: AppColors.warning,
                                          ),
                                          SizedBox(width: 3.w),
                                          Text(
                                            'Lv. $lv',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.warning,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            SizedBox(height: 7.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12.w,
                                  color: AppColors.grey400,
                                ),
                                SizedBox(width: 3.w),
                                Expanded(
                                  child: Text(
                                    profile.city.isNotEmpty
                                        ? profile.city
                                        : 'Campus · Joined Mar 2025',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: AppColors.grey500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            if (profile.bio.isNotEmpty) ...[
                              SizedBox(height: 6.h),
                              Text(
                                profile.bio,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: isDark
                                      ? AppColors.grey400
                                      : AppColors.grey600,
                                  fontStyle: FontStyle.italic,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),

                  // XP progress bar
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final pts = profile.points;
                          // Level thresholds: Lv1=0, Lv2=200, Lv3=500, Lv4=1000, Lv5=2000, Lv6=4000
                          const thresholds = [0, 200, 500, 1000, 2000, 4000];
                          int level = 1;
                          int currentThreshold = 0;
                          int nextThreshold = 200;
                          for (int i = thresholds.length - 1; i >= 0; i--) {
                            if (pts >= thresholds[i]) {
                              level = i + 1;
                              currentThreshold = thresholds[i];
                              nextThreshold = (i + 1 < thresholds.length)
                                  ? thresholds[i + 1]
                                  : thresholds[i];
                              break;
                            }
                          }
                          final progress = level >= thresholds.length
                              ? 1.0
                              : (pts - currentThreshold) /
                                    (nextThreshold - currentThreshold).clamp(
                                      1,
                                      999999,
                                    );
                          final xpInLevel = pts - currentThreshold;
                          final xpNeeded = nextThreshold - currentThreshold;
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Level $level Progress',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.grey500,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _showXpCard = true),
                                    child: Icon(
                                      Icons.info_outline_rounded,
                                      size: 14.w,
                                      color: AppColors.grey400,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '$xpInLevel / ${_fmtNum(xpNeeded)} XP',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6.r),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  minHeight: 7.h,
                                  backgroundColor: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                  valueColor: const AlwaysStoppedAnimation(
                                    AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                  SizedBox(height: 18.h),

                  // Stats strip
                  Row(
                    children: [
                      _headerStat(
                        '${ref.watch(activityProvider).summary.totalTrips}',
                        'Rides',
                        AppColors.info,
                        isDark,
                      ),
                      _headerDivider(isDark),
                      _headerStat(
                        '${ref.watch(socialProvider).following.length}',
                        'Following',
                        AppColors.primary,
                        isDark,
                        onTap: () => _showFollowersSheet(
                          context,
                          isDark,
                          showFollowers: false,
                        ),
                      ),
                      _headerDivider(isDark),
                      _headerStat(
                        '${ref.watch(socialProvider).followers.length}',
                        'Followers',
                        AppColors.elevation,
                        isDark,
                        onTap: () => _showFollowersSheet(
                          context,
                          isDark,
                          showFollowers: true,
                        ),
                      ),
                      _headerDivider(isDark),
                      _headerStat(
                        '${ref.watch(activityProvider).summary.totalDistance.toStringAsFixed(1)} km',
                        'Distance',
                        AppColors.distance,
                        isDark,
                      ),
                    ],
                  ),
                  SizedBox(height: 16.h),

                  // Action buttons row
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.push('/profile/edit'),
                          child: Container(
                            padding: EdgeInsets.symmetric(vertical: 11.h),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(14.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.30,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 15.w,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  'Edit Profile',
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      GestureDetector(
                        onTap: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final profile =
                                ref.read(profileProvider).valueOrNull ??
                                const ProfileData();
                            final displayName = profile.fullName.isNotEmpty
                                ? profile.fullName
                                : profile.firstName;
                            final handle = displayName
                                .toLowerCase()
                                .replaceAll(' ', '.')
                                .replaceAll(RegExp(r'[^a-z0-9.]'), '');

                            final shareText =
                                'Join me on Newtra - the smart campus mobility app!\n'
                                'I\'m $displayName and I\'m riding smarter every day.\n\n'
                                'Follow my profile:\nhttps://newtra.app/u/$handle\n\n'
                                'Download Newtra and start your sustainable journey!';

                            await Share.share(
                              shareText,
                              subject: 'Follow $displayName on Newtra',
                            );
                          } catch (e) {
                            if (mounted) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Sharing not available: ${e.toString().contains('PlatformException') ? 'Please try on a real device' : e}',
                                  ),
                                  backgroundColor: AppColors.error,
                                  duration: const Duration(seconds: 3),
                                ),
                              );
                            }
                          }
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 11.h,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkElevated
                                : AppColors.grey100,
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          child: Icon(
                            Icons.share_rounded,
                            size: 18.w,
                            color: isDark
                                ? AppColors.grey300
                                : AppColors.grey700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerStat(
    String val,
    String label,
    Color color,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    final content = Column(
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            val,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w900,
              color: isDark ? AppColors.white : AppColors.grey900,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.sp,
            color: onTap != null ? AppColors.primary : AppColors.grey500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
    return Expanded(
      child: onTap != null
          ? GestureDetector(onTap: onTap, child: content)
          : content,
    );
  }

  void _showFollowersSheet(
    BuildContext context,
    bool isDark, {
    required bool showFollowers,
  }) {
    final social = ref.read(socialProvider);
    final list = showFollowers ? social.followers : social.following;
    final title = showFollowers ? 'Followers' : 'Following';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          _FollowersSheet(title: title, people: list, isDark: isDark),
    );
  }

  Widget _buildXpCard(BuildContext context, bool isDark) {
    final profile =
        ref.watch(profileProvider).valueOrNull ?? const ProfileData();
    final pts = profile.points;
    const thresholds = [0, 200, 500, 1000, 2000, 4000];
    int userLevel = 1;
    for (int i = thresholds.length - 1; i >= 0; i--) {
      if (pts >= thresholds[i]) {
        userLevel = i + 1;
        break;
      }
    }

    final xpSources = [
      (Icons.pedal_bike_rounded, '1 km ridden', '+10 XP', AppColors.distance),
      (Icons.eco_rounded, '1 kg CO2 saved', '+5 XP', AppColors.success),
      (Icons.timer_rounded, '10 min ride time', '+8 XP', AppColors.elevation),
      (
        Icons.local_fire_department_rounded,
        'Daily streak',
        '+20 XP',
        AppColors.calories,
      ),
      (Icons.groups_rounded, 'Join a group', '+15 XP', AppColors.info),
      (Icons.emoji_events_rounded, 'Earn a badge', '+50 XP', AppColors.warning),
    ];
    final levels = [
      ('Lv. 1', 'Beginner', '0 XP', AppColors.grey400),
      ('Lv. 2', 'Commuter', '200 XP', AppColors.info),
      ('Lv. 3', 'Cyclist', '500 XP', AppColors.success),
      ('Lv. 4', 'Explorer', '1,000 XP', AppColors.primary),
      ('Lv. 5', 'Rider', '2,000 XP', AppColors.warning),
      ('Lv. 6', 'Champion', '4,000 XP', AppColors.calories),
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          20.w,
          16.h,
          20.w,
          MediaQuery.of(context).padding.bottom + 16.h,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.bolt_rounded,
                    size: 20.w,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How XP is Earned',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.white : AppColors.grey900,
                        ),
                      ),
                      Text(
                        'Complete actions to level up',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _showXpCard = false),
                  child: Container(
                    width: 34.w,
                    height: 34.w,
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
            SizedBox(height: 20.h),
            ...xpSources.map((s) {
              final (icon, action, xp, color) = s;
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Row(
                  children: [
                    Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      alignment: Alignment.center,
                      child: Icon(icon, size: 17.w, color: color),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        action,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.white : AppColors.grey800,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        xp,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: 6.h),
            Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            SizedBox(height: 14.h),
            Text(
              'Level Milestones',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.white : AppColors.grey900,
              ),
            ),
            SizedBox(height: 12.h),
            ...levels.map((l) {
              final (lv, title, threshold, color) = l;
              final isCurrent = lv == 'Lv. $userLevel';
              return Container(
                margin: EdgeInsets.only(bottom: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: isCurrent
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : (isDark ? AppColors.darkElevated : AppColors.grey50),
                  borderRadius: BorderRadius.circular(12.r),
                  border: isCurrent
                      ? Border.all(
                          color: AppColors.primary.withValues(alpha: 0.30),
                          width: 1.5,
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32.w,
                      height: 32.w,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        lv.split(' ')[1],
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: isCurrent
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isCurrent
                              ? AppColors.primary
                              : (isDark
                                    ? AppColors.grey300
                                    : AppColors.grey700),
                        ),
                      ),
                    ),
                    Text(
                      threshold,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
                    ),
                    if (isCurrent) ...[
                      SizedBox(width: 6.w),
                      Icon(
                        Icons.my_location_rounded,
                        size: 13.w,
                        color: AppColors.primary,
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _headerDivider(bool isDark) {
    return Container(
      width: 1,
      height: 28.h,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.07),
    );
  }

  // ── Stats card ─────────────────────────────────────────────────────────────

  Widget _buildStatsCard(bool isDark) {
    final achievementsAsync = ref.watch(profileAchievementsProvider);
    final unlockedAchievements = achievementsAsync.maybeWhen(
      data: (items) =>
          items.where((achievement) => achievement.unlocked).toList(),
      orElse: () => const <AchievementModel>[],
    );
    final achievements = unlockedAchievements;
    final achievementsLabel = achievementsAsync.maybeWhen(
      data: (_) => '${unlockedAchievements.length} unlocked',
      loading: () => 'Loading...',
      orElse: () => '0 unlocked',
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 0),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Eco impact row ─────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.success.withValues(alpha: 0.15),
                          AppColors.primary.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42.w,
                          height: 42.w,
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.eco_rounded,
                            size: 22.w,
                            color: AppColors.success,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ref.watch(activityProvider).summary.totalCo2.toStringAsFixed(1)} kg',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.success,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                              ),
                              Text(
                                'CO2 saved',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.grey500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(14.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.warning.withValues(alpha: 0.15),
                          AppColors.calories.withValues(alpha: 0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42.w,
                          height: 42.w,
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.local_fire_department_rounded,
                            size: 22.w,
                            color: AppColors.warning,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${ref.watch(activityProvider).summary.totalCalories.toInt()}',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.warning,
                                  height: 1.1,
                                ),
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.fade,
                              ),
                              Text(
                                'cal burned',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.grey500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            SizedBox(height: 14.h),

            // ── Achievements ───────────────────────────────────────────
            GestureDetector(
              onTap: () => context.push('/achievements'),
              child: Row(
                children: [
                  Text(
                    'Achievements',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.white : AppColors.grey900,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    achievementsLabel,
                    style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18.w,
                    color: AppColors.grey400,
                  ),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            achievementsAsync.isLoading
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: SizedBox(
                      width: 18.w,
                      height: 18.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : achievements.isEmpty
                ? Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.h),
                    child: Text(
                      'Complete rides to earn achievements!',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.grey400,
                      ),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: achievements.map((a) {
                        final color = _achievementColorFromHex(a.colorHex);
                        final icon = _achievementIconFromString(a.icon);
                        return Padding(
                          padding: EdgeInsets.only(right: 14.w),
                          child: Column(
                            children: [
                              Container(
                                width: 46.w,
                                height: 46.w,
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: color.withValues(alpha: 0.30),
                                    width: 1.5,
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Icon(icon, size: 22.w, color: color),
                              ),
                              SizedBox(height: 5.h),
                              Text(
                                a.title,
                                style: TextStyle(
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.grey500,
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
      ),
    );
  }

  Color _achievementColorFromHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final value = int.parse(
        clean.length == 6 ? 'FF$clean' : clean,
        radix: 16,
      );
      return Color(value);
    } catch (_) {
      return AppColors.primary;
    }
  }

  IconData _achievementIconFromString(String name) {
    const map = <String, IconData>{
      'emoji_events': Icons.emoji_events_rounded,
      'bolt': Icons.bolt_rounded,
      'eco': Icons.eco_rounded,
      'groups': Icons.groups_rounded,
      'local_fire_department': Icons.local_fire_department_rounded,
      'terrain': Icons.terrain_rounded,
      'public': Icons.public_rounded,
      'people': Icons.people_rounded,
      'workspace_premium': Icons.workspace_premium_rounded,
      'energy_savings_leaf': Icons.energy_savings_leaf_rounded,
      'stars': Icons.stars_rounded,
      'pedal_bike': Icons.pedal_bike_rounded,
      'directions_bike': Icons.directions_bike_rounded,
      'speed': Icons.speed_rounded,
      'bike': Icons.pedal_bike_rounded,
      'medal': Icons.workspace_premium_rounded,
      'zap': Icons.bolt_rounded,
      'crown': Icons.emoji_events_rounded,
      'leaf': Icons.eco_rounded,
      'globe': Icons.public_rounded,
      'users': Icons.people_rounded,
      'users-round': Icons.groups_rounded,
      'sparkles': Icons.stars_rounded,
      'sunrise': Icons.wb_sunny_rounded,
      'flame': Icons.local_fire_department_rounded,
      'trophy': Icons.emoji_events_rounded,
    };
    return map[name] ?? Icons.emoji_events_rounded;
  }

  // ── Activity strip ─────────────────────────────────────────────────────────

  Widget _buildActivityStrip(bool isDark) {
    final activityState = ref.watch(activityProvider);
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final rawKm = activityState.summary.weeklyData['distance'];
    final kmValues = (rawKm != null && rawKm.length == 7)
        ? rawKm
        : [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
    final weekTotal = kmValues.fold(0.0, (a, b) => a + b);
    final hasWeeklyData = weekTotal > 0;
    final showLoading = activityState.isLoading && rawKm == null;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Weekly Activity',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.white : AppColors.grey900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${weekTotal.toStringAsFixed(1)} km this week',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10.w),
                GestureDetector(
                  onTap: () => context.push('/activity'),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      'View all',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            SizedBox(
              height: 90.h,
              child: showLoading
                  ? Center(
                      child: SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : hasWeeklyData
                  ? _LineChart(values: kmValues, isDark: isDark)
                  : _WeeklyActivityEmptyState(isDark: isDark),
            ),
            SizedBox(height: 10.h),
            if (hasWeeklyData)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: days
                    .map(
                      (d) => Text(
                        d,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.grey400,
                        ),
                      ),
                    )
                    .toList(),
              )
            else
              Text(
                'Your weekly distance will appear here after your next ride.',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.grey500,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Menu groups ────────────────────────────────────────────────────────────

  Widget _buildMenuGroup(
    BuildContext context,
    bool isDark, {
    required String label,
    required List<_MenuItem> items,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 4.w, bottom: 10.h),
            child: Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: AppColors.grey500,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: List.generate(items.length, (i) {
                final item = items[i];
                final isLast = i == items.length - 1;
                return Column(
                  children: [
                    GestureDetector(
                      onTap: item.onTap,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 13.h,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 38.w,
                              height: 38.w,
                              decoration: BoxDecoration(
                                color: item.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                item.icon,
                                size: 18.w,
                                color: item.color,
                              ),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? AppColors.white
                                      : AppColors.grey900,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18.w,
                              color: AppColors.grey400,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast)
                      Divider(
                        height: 1,
                        indent: 68.w,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.05)
                            : Colors.black.withValues(alpha: 0.04),
                      ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sign out ───────────────────────────────────────────────────────────────

  Widget _buildSignOutRow(BuildContext context, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Sign Out'),
              content: const Text('Are you sure you want to sign out?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(authStateProvider.notifier).logout();
                    if (!context.mounted) return;
                    context.go('/auth/login');
                  },
                  style: TextButton.styleFrom(foregroundColor: AppColors.error),
                  child: const Text('Sign Out'),
                ),
              ],
            ),
          );
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 15.h),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(
              color: AppColors.error.withValues(alpha: 0.18),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38.w,
                height: 38.w,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.logout_rounded,
                  size: 18.w,
                  color: AppColors.error,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  'Sign Out',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper methods ─────────────────────────────────────────────────────────

  Future<void> _pickProfileImage() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: AppColors.grey300,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'Change Profile Picture',
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.white : AppColors.grey900,
                    ),
                  ),
                  SizedBox(height: 20.h),
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.primary,
                        size: 24.w,
                      ),
                    ),
                    title: Text(
                      'Take Photo',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? photo = await _picker.pickImage(
                        source: ImageSource.camera,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (photo != null && mounted) {
                        ref
                            .read(profileProvider.notifier)
                            .update(
                              ref
                                      .read(profileProvider)
                                      .valueOrNull
                                      ?.copyWith(
                                        profileImagePath: photo.path,
                                      ) ??
                                  const ProfileData(),
                            );
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Profile picture updated!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(
                        Icons.photo_library_rounded,
                        color: AppColors.success,
                        size: 24.w,
                      ),
                    ),
                    title: Text(
                      'Choose from Gallery',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(context);
                      final XFile? image = await _picker.pickImage(
                        source: ImageSource.gallery,
                        maxWidth: 1024,
                        maxHeight: 1024,
                        imageQuality: 85,
                      );
                      if (image != null && mounted) {
                        ref
                            .read(profileProvider.notifier)
                            .update(
                              ref
                                      .read(profileProvider)
                                      .valueOrNull
                                      ?.copyWith(
                                        profileImagePath: image.path,
                                      ) ??
                                  const ProfileData(),
                            );
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Profile picture updated!'),
                            backgroundColor: AppColors.success,
                          ),
                        );
                      }
                    },
                  ),
                  if (ref.read(profileProvider).valueOrNull?.profileImagePath !=
                      null)
                    ListTile(
                      leading: Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                          size: 24.w,
                        ),
                      ),
                      title: Text(
                        'Remove Photo',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ref
                            .read(profileProvider.notifier)
                            .update(
                              ref
                                      .read(profileProvider)
                                      .valueOrNull
                                      ?.copyWith(profileImagePath: null) ??
                                  const ProfileData(),
                            );
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Profile picture removed'),
                            backgroundColor: AppColors.info,
                          ),
                        );
                      },
                    ),
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Failed to pick image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showInviteFriends() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile =
          ref.read(profileProvider).valueOrNull ?? const ProfileData();

      // Generate referral code safely
      final namePrefix = profile.firstName.length >= 3
          ? profile.firstName.substring(0, 3).toUpperCase()
          : profile.firstName.toUpperCase().padRight(3, 'X');
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final referralCode =
          namePrefix + timestamp.substring(timestamp.length - 4);
      final displayName = profile.fullName.isNotEmpty
          ? profile.fullName
          : profile.firstName;

      final shareText =
          'Join me on Newtra - The Smart Mobility App!\n\n'
          '$displayName invited you to experience sustainable campus transportation.\n\n'
          'Use my referral code: $referralCode\n'
          'Get 100 bonus points on signup!\n\n'
          'Features:\n'
          '- Real-time transit tracking\n'
          '- Ride-sharing with friends\n'
          '- Earn rewards for eco-friendly travel\n'
          '- Join campus groups & challenges\n\n'
          'Download now: https://newtra.app/invite/$referralCode';

      await Share.share(
        shareText,
        subject: '$displayName invited you to Newtra',
      );
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              'Sharing not available: ${e.toString().contains('PlatformException') ? 'Please try on a real device' : e}',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  String _fmtNum(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    final sb = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) sb.write(',');
      sb.write(s[i]);
    }
    return sb.toString();
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.color, this.onTap);
}

// ── Line chart ────────────────────────────────────────────────────────────────

class _LineChart extends StatelessWidget {
  final List<double> values;
  final bool isDark;
  const _LineChart({required this.values, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _LineChartPainter(values: values, isDark: isDark),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final bool isDark;
  _LineChartPainter({required this.values, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return;

    final pts = List.generate(values.length, (i) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - (values[i] / maxVal) * size.height * 0.82 - 6;
      return Offset(x, y);
    });

    // Smooth bezier line
    final linePath = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 0; i < pts.length - 1; i++) {
      final cpX = (pts[i].dx + pts[i + 1].dx) / 2;
      linePath.cubicTo(
        cpX,
        pts[i].dy,
        cpX,
        pts[i + 1].dy,
        pts[i + 1].dx,
        pts[i + 1].dy,
      );
    }

    // Gradient fill
    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.28),
            AppColors.primary.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Line stroke
    canvas.drawPath(
      linePath,
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Dots
    for (final pt in pts) {
      canvas.drawCircle(
        pt,
        5,
        Paint()..color = isDark ? AppColors.darkCard : Colors.white,
      );
      canvas.drawCircle(pt, 3.5, Paint()..color = AppColors.primary);
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => false;
}

class _WeeklyActivityEmptyState extends StatelessWidget {
  final bool isDark;
  const _WeeklyActivityEmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : AppColors.grey50,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : AppColors.grey200,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.route_rounded, size: 22.w, color: AppColors.grey400),
            SizedBox(height: 6.h),
            Text(
              'No weekly activity yet',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.grey300 : AppColors.grey700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Followers / Following bottom sheet ───────────────────────────────────────

class _FollowersSheet extends ConsumerStatefulWidget {
  final String title;
  final List<FriendModel> people;
  final bool isDark;

  const _FollowersSheet({
    required this.title,
    required this.people,
    required this.isDark,
  });

  @override
  ConsumerState<_FollowersSheet> createState() => _FollowersSheetState();
}

class _FollowersSheetState extends ConsumerState<_FollowersSheet> {
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
                  padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    '${widget.people.length}',
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
          Flexible(
            child: ListView.separated(
              padding: EdgeInsets.fromLTRB(
                20.w,
                12.h,
                20.w,
                MediaQuery.of(context).padding.bottom + 20.h,
              ),
              itemCount: widget.people.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 60.w,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              itemBuilder: (_, i) {
                final friend = widget.people[i];
                final isFollowing =
                    ref.watch(
                      socialProvider.select(
                        (state) => state.followStatusFor(friend.id),
                      ),
                    ) ??
                    friend.isFollowing;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    context.push(
                      '/user-profile',
                      extra: {
                        'name': friend.name,
                        'type': friend.type,
                        'distance': friend.totalDistance,
                        'following': isFollowing,
                        'userId': friend.id,
                      },
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10.h),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [
                                AppColors.primaryDark,
                                AppColors.primaryLight,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            _initials(friend.name),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        // Name + type
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                friend.name,
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
                                '${friend.totalDistance} · ${friend.rides} rides',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.grey500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Follow button
                        GestureDetector(
                          onTap: () {
                            final socialNotifier = ref.read(
                              socialProvider.notifier,
                            );
                            if (isFollowing) {
                              socialNotifier.unfollow(friend.id);
                            } else {
                              socialNotifier.follow(friend.id);
                            }
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(
                              horizontal: 14.w,
                              vertical: 7.h,
                            ),
                            decoration: BoxDecoration(
                              color: isFollowing
                                  ? (isDark
                                        ? AppColors.darkElevated
                                        : AppColors.grey100)
                                  : AppColors.primary,
                              borderRadius: BorderRadius.circular(20.r),
                              border: isFollowing
                                  ? Border.all(
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.10)
                                          : AppColors.grey200,
                                    )
                                  : null,
                            ),
                            child: Text(
                              isFollowing ? 'Following' : 'Follow',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: isFollowing
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
