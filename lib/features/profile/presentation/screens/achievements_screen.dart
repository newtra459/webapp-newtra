import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/achievement_model.dart';
import '../providers/achievements_provider.dart';

// ── Category ──────────────────────────────────────────────────────────────────

enum _Category { all, riding, social, eco, streak }

extension _CategoryX on _Category {
  String get label {
    switch (this) {
      case _Category.all:
        return 'All';
      case _Category.riding:
        return 'Riding';
      case _Category.social:
        return 'Social';
      case _Category.eco:
        return 'Eco';
      case _Category.streak:
        return 'Streaks';
    }
  }

  IconData get icon {
    switch (this) {
      case _Category.all:
        return Icons.emoji_events_rounded;
      case _Category.riding:
        return Icons.pedal_bike_rounded;
      case _Category.social:
        return Icons.group_rounded;
      case _Category.eco:
        return Icons.eco_rounded;
      case _Category.streak:
        return Icons.local_fire_department_rounded;
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────

class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  _Category _selected = _Category.all;

  List<AchievementModel> _filtered(List<AchievementModel> all) {
    if (_selected == _Category.all) return all;
    return all.where((a) => a.category == _selected.name).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final async = ref.watch(profileAchievementsProvider);

    final achievements = async.maybeWhen(
      data: (list) => list,
      orElse: () => const <AchievementModel>[],
    );
    final unlocked = achievements.where((a) => a.unlocked).length;
    final total = achievements.length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
      body: Column(
        children: [
          // Header always visible — shows placeholder counts while loading
          _buildHeader(context, isDark, unlocked, total),
          _buildCategoryChips(isDark),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 48.w, color: AppColors.grey300),
                    SizedBox(height: 12.h),
                    Text('Could not load achievements',
                        style: TextStyle(
                            color: AppColors.grey500, fontSize: 14.sp)),
                    SizedBox(height: 16.h),
                    TextButton.icon(
                      onPressed: () => ref.invalidate(profileAchievementsProvider),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary),
                    ),
                  ],
                ),
              ),
              data: (all) {
                final filtered = _filtered(all);
                if (filtered.isEmpty) {
                  return Center(
                    child: Text(
                      'No achievements in this category yet.',
                      style: TextStyle(
                          color: AppColors.grey500, fontSize: 13.sp),
                    ),
                  );
                }
                return ListView.builder(
                  padding: EdgeInsets.fromLTRB(
                      20.w,
                      12.h,
                      20.w,
                      MediaQuery.of(context).padding.bottom + 20.h),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) =>
                      _buildAchievementCard(filtered[i], isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(
      BuildContext context, bool isDark, int unlocked, int total) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
          child: Column(
            children: [
              // ── Top bar ──
              Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkElevated : AppColors.grey100,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16.w,
                          color: isDark ? AppColors.white : AppColors.grey900),
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Achievements',
                        style: TextStyle(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.white : AppColors.grey900,
                        ),
                      ),
                      Text(
                        '$unlocked of $total unlocked',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: AppColors.grey500,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Trophy badge
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      color: AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events_rounded,
                            size: 16.w, color: AppColors.warning),
                        SizedBox(width: 4.w),
                        Text(
                          '$unlocked',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 18.h),

              // ── Progress summary ──
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.10),
                      AppColors.warning.withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16.r),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Overall Progress',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.white : AppColors.grey900,
                          ),
                        ),
                        Text(
                          '${(total > 0 ? unlocked / total * 100 : 0).round()}%',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10.h),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6.r),
                      child: LinearProgressIndicator(
                        value: total > 0 ? unlocked / total : 0,
                        minHeight: 7.h,
                        backgroundColor: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : AppColors.grey200,
                        valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Category chips ─────────────────────────────────────────────────────────

  Widget _buildCategoryChips(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      padding: EdgeInsets.only(bottom: 14.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Row(
          children: _Category.values.map((cat) {
            final active = cat == _selected;
            return Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: GestureDetector(
                onTap: () => setState(() => _selected = cat),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primary
                        : isDark
                            ? AppColors.darkElevated
                            : AppColors.grey100,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        cat.icon,
                        size: 14.w,
                        color: active
                            ? Colors.white
                            : isDark
                                ? AppColors.grey400
                                : AppColors.grey600,
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        cat.label,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: active
                              ? Colors.white
                              : isDark
                                  ? AppColors.grey400
                                  : AppColors.grey600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ── Achievement card ───────────────────────────────────────────────────────

  Widget _buildAchievementCard(AchievementModel a, bool isDark) {
    final isUnlocked = a.unlocked;
    final color = _colorFromHex(a.colorHex);
    final icon = _iconFromString(a.icon);

    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: isUnlocked
            ? Border.all(color: color.withValues(alpha: 0.30), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // ── Icon badge ──
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isUnlocked ? 0.14 : 0.07),
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: isUnlocked ? 0.35 : 0.12),
                width: 1.5,
              ),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 26.w,
              color: isUnlocked ? color : AppColors.grey400,
            ),
          ),
          SizedBox(width: 14.w),

          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        a.title,
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w800,
                          color: isUnlocked
                              ? (isDark ? AppColors.white : AppColors.grey900)
                              : AppColors.grey500,
                        ),
                      ),
                    ),
                    if (isUnlocked)
                      Icon(Icons.check_circle_rounded,
                          size: 18.w, color: color),
                  ],
                ),
                SizedBox(height: 3.h),
                Text(
                  a.description,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.grey500,
                  ),
                ),
                if (isUnlocked && a.unlockedDate != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'Unlocked ${a.unlockedDate}',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
                if (!isUnlocked && a.progress > 0) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4.r),
                          child: LinearProgressIndicator(
                            value: a.progress,
                            minHeight: 5.h,
                            backgroundColor: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : AppColors.grey200,
                            valueColor:
                                AlwaysStoppedAnimation(color.withValues(alpha: 0.7)),
                          ),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        '${(a.progress * 100).round()}%',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Converts a hex string like "#FFB300" or "FFB300" to a Flutter [Color].
  /// Falls back to [AppColors.primary] on any parse error.
  Color _colorFromHex(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      final value = int.parse(clean.length == 6 ? 'FF$clean' : clean, radix: 16);
      return Color(value);
    } catch (_) {
      return AppColors.primary;
    }
  }

  /// Maps the admin-defined icon string to a Flutter [IconData].
  /// The admin can use any of the keys in the map below, or pass a
  /// Material symbol name as-is. Unmapped values fall back to a star.
  IconData _iconFromString(String name) {
    const map = <String, IconData>{
      'emoji_events':            Icons.emoji_events_rounded,
      'bolt':                    Icons.bolt_rounded,
      'eco':                     Icons.eco_rounded,
      'groups':                  Icons.groups_rounded,
      'local_fire_department':   Icons.local_fire_department_rounded,
      'terrain':                 Icons.terrain_rounded,
      'public':                  Icons.public_rounded,
      'people':                  Icons.people_rounded,
      'workspace_premium':       Icons.workspace_premium_rounded,
      'energy_savings_leaf':     Icons.energy_savings_leaf_rounded,
      'stars':                   Icons.stars_rounded,
      'pedal_bike':              Icons.pedal_bike_rounded,
      'directions_bike':         Icons.directions_bike_rounded,
      'speed':                   Icons.speed_rounded,
      // Client-side achievement icon names (matching RN)
      'bike':                    Icons.pedal_bike_rounded,
      'medal':                   Icons.workspace_premium_rounded,
      'zap':                     Icons.bolt_rounded,
      'crown':                   Icons.emoji_events_rounded,
      'leaf':                    Icons.eco_rounded,
      'globe':                   Icons.public_rounded,
      'users':                   Icons.people_rounded,
      'users-round':             Icons.groups_rounded,
      'sparkles':                Icons.stars_rounded,
      'sunrise':                 Icons.wb_sunny_rounded,
      'flame':                   Icons.local_fire_department_rounded,
      'trophy':                  Icons.emoji_events_rounded,
    };
    return map[name] ?? Icons.emoji_events_rounded;
  }
}
