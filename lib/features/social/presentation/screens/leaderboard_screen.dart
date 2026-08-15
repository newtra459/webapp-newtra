import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mj_avatar.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../data/models/social_models.dart';
import '../providers/social_provider.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

enum _Metric { distance, points, co2 }

extension _MetricX on _Metric {
  String get label {
    switch (this) {
      case _Metric.distance: return 'Distance';
      case _Metric.points:   return 'Points';
      case _Metric.co2:      return 'CO2 Saved';
    }
  }

  IconData get icon {
    switch (this) {
      case _Metric.distance: return Icons.route_rounded;
      case _Metric.points:   return Icons.stars_rounded;
      case _Metric.co2:      return Icons.eco_rounded;
    }
  }
}

class _Rider {
  final String id;
  final String name;
  final Map<_Metric, String> values;
  final bool isMe;
  final String? badge;

  const _Rider({
    required this.id,
    required this.name,
    required this.values,
    this.isMe = false,
    this.badge,
  });
}

class _Group {
  final String id;
  final String name;
  final int members;
  final Map<_Metric, String> values;

  const _Group({
    required this.id,
    required this.name,
    required this.members,
    required this.values,
  });
}

const _riders = <_Rider>[];

const _groups = <_Group>[];

// ── Entry → UI model converters ───────────────────────────────────────────────────

_Rider _riderFromEntry(LeaderboardEntry e) => _Rider(
  id: e.id,
  name: e.name,
  isMe: e.isMe,
  badge: e.badge,
  values: {
    _Metric.distance: e.values['distance'] ?? '—',
    _Metric.points:   e.values['points']   ?? '—',
    _Metric.co2:      e.values['co2']      ?? '—',
  },
);

_Group _groupFromEntry(LeaderboardEntry e) => _Group(
  id: e.id,
  name: e.name,
  members: e.members,
  values: {
    _Metric.distance: e.values['distance'] ?? '—',
    _Metric.points:   e.values['points']   ?? '—',
    _Metric.co2:      e.values['co2']      ?? '—',
  },
);

// ── Screen ────────────────────────────────────────────────────────────────────

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  _Metric _metric = _Metric.distance;

  // rank medal colours
  static const _gold   = Color(0xFFFFB800);
  static const _silver = Color(0xFFB0B8C4);
  static const _bronze = Color(0xFFCD7F32);

  double _metricValue(Map<_Metric, String> values, _Metric metric) {
    final raw = values[metric] ?? '0';
    return double.tryParse(raw.replaceAll(RegExp(r'[^0-9.-]'), '')) ?? 0;
  }

  List<_Rider> _sortedRiders(List<_Rider> riders) {
    final sorted = List<_Rider>.of(riders);
    sorted.sort((a, b) => _metricValue(b.values, _metric)
        .compareTo(_metricValue(a.values, _metric)));
    return sorted;
  }

  List<_Group> _sortedGroups(List<_Group> groups) {
    final sorted = List<_Group>.of(groups);
    sorted.sort((a, b) => _metricValue(b.values, _metric)
        .compareTo(_metricValue(a.values, _metric)));
    return sorted;
  }

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final riderAsync = ref.watch(riderLeaderboardProvider);
    final groupAsync = ref.watch(groupLeaderboardProvider);

    final riders = riderAsync.maybeWhen(
      data: (l) => l.map(_riderFromEntry).toList(),
      orElse: () => const <_Rider>[],
    );
    final groups = groupAsync.maybeWhen(
      data: (l) => l.map(_groupFromEntry).toList(),
      orElse: () => const <_Group>[],
    );
    final sortedRiders = _sortedRiders(riders);
    final sortedGroups = _sortedGroups(groups);
    final myIdx = sortedRiders.indexWhere((r) => r.isMe);
    final myRankLabel = myIdx >= 0 ? 'Rank #${myIdx + 1}' : 'Rank —';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkSurface : const Color(0xFFF2F5F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark, myRankLabel),
            _buildMetricChips(isDark),
            _buildTabBar(isDark),
            Expanded(
              child: _buildBody(
                isDark, sortedRiders, sortedGroups,
                riderAsync.isLoading, groupAsync.isLoading,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark, String myRankLabel) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 16.h),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
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
                  color: isDark ? AppColors.white : AppColors.grey800),
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Leaderboard',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.white : AppColors.grey900,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'March 2026 · All time',
                  style: TextStyle(fontSize: 12.sp, color: AppColors.grey500),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.emoji_events_rounded,
                    size: 14.w, color: AppColors.primary),
                SizedBox(width: 5.w),
                Text(
                  myRankLabel,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Metric chips ───────────────────────────────────────────────────────────

  Widget _buildMetricChips(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
      child: Row(
        children: _Metric.values.map((m) {
          final sel = _metric == m;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _metric = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: EdgeInsets.only(
                    right: m != _Metric.values.last ? 8.w : 0),
                padding: EdgeInsets.symmetric(vertical: 10.h),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primary
                      : (isDark ? AppColors.darkCard : AppColors.white),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(m.icon,
                        size: 16.w,
                        color: sel
                            ? Colors.white
                            : (isDark
                                ? AppColors.grey400
                                : AppColors.grey600)),
                    SizedBox(height: 4.h),
                    Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: sel
                            ? Colors.white
                            : (isDark
                                ? AppColors.grey400
                                : AppColors.grey600),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 12.h),
      child: Container(
        height: 48.h,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(14.r),
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
            borderRadius: BorderRadius.circular(11.r),
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
              TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
          padding: EdgeInsets.all(4.w),
          labelPadding: EdgeInsets.zero,
          tabs: [
            Tab(
              child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 8.w), child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.person_rounded, size: 16.w),
                  SizedBox(width: 6.w),
                  const Text('Riders'),
                ],
              ))),
            ),
            Tab(
              child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 8.w), child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.group_rounded, size: 16.w),
                  SizedBox(width: 6.w),
                  const Text('Groups'),
                ],
              ))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(bool isDark, List<_Rider> riders, List<_Group> groups,
      bool riderLoading, bool groupLoading) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: TabBarView(
        key: ValueKey(_tab.index),
        controller: _tab,
        children: [
          _buildRiderList(isDark, riders, riderLoading),
          _buildGroupList(isDark, groups, groupLoading),
        ],
      ),
    );
  }

  // ── Rider list ─────────────────────────────────────────────────────────────

  Widget _buildRiderList(bool isDark, List<_Rider> riders, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final sorted = riders;

    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.emoji_events_outlined, size: 48.w, color: AppColors.grey300),
            SizedBox(height: 12.h),
            Text('No riders yet',
                style: TextStyle(fontSize: 15.sp, color: AppColors.grey500)),
            SizedBox(height: 4.h),
            Text('Complete rides to appear here',
                style: TextStyle(fontSize: 13.sp, color: AppColors.grey400)),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        // Podium (top 3) — only shown when there are enough riders
        SliverToBoxAdapter(
          child: sorted.length >= 3
              ? Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 20.h),
                  child: _Podium(
                    riders: sorted.take(3).toList(),
                    metric: _metric,
                    isDark: isDark,
                  ),
                )
              : const SizedBox.shrink(),
        ),
        // Rest
        SliverPadding(
          padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 32.h),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final startIdx = sorted.length >= 3 ? 3 : 0;
                final rider = sorted[startIdx + i];
                final rank  = startIdx + i + 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: 10.h),
                  child: _RiderRow(
                    rank: rank,
                    rider: rider,
                    metric: _metric,
                    isDark: isDark,
                  ),
                );
              },
              childCount: sorted.length >= 3 ? sorted.length - 3 : sorted.length,
            ),
          ),
        ),
      ],
    );
  }

  // ── Group list ─────────────────────────────────────────────────────────────

  Widget _buildGroupList(bool isDark, List<_Group> groups, bool isLoading) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final sorted = groups;
    if (sorted.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.group_outlined, size: 48.w, color: AppColors.grey300),
            SizedBox(height: 12.h),
            Text('No groups yet',
                style: TextStyle(fontSize: 15.sp, color: AppColors.grey500)),
            SizedBox(height: 4.h),
            Text('Join a group to see rankings here',
                style: TextStyle(fontSize: 13.sp, color: AppColors.grey400)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 32.h),
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final group = sorted[i];
        final rank  = i + 1;
        final medalColor = rank == 1
            ? _gold
            : rank == 2
                ? _silver
                : rank == 3
                    ? _bronze
                    : null;

        return Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: _GroupRow(
            rank: rank,
            group: group,
            metric: _metric,
            medalColor: medalColor,
            isDark: isDark,
          ),
        );
      },
    );
  }
}

// ── Podium ────────────────────────────────────────────────────────────────────

class _Podium extends StatelessWidget {
  final List<_Rider> riders;
  final _Metric metric;
  final bool isDark;

  static const _gold   = Color(0xFFFFB800);
  static const _silver = Color(0xFFB0B8C4);
  static const _bronze = Color(0xFFCD7F32);

  const _Podium(
      {required this.riders,
      required this.metric,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    // order: 2nd | 1st | 3rd
    final order = [riders[1], riders[0], riders[2]];
    final heights  = [100.h, 126.h, 84.h];
    final colors   = [_silver, _gold, _bronze];
    final ranks    = [2, 1, 3];
    final sizes    = [48.0, 60.0, 44.0];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        final rider = order[i];
        final color = colors[i];
        final rank  = ranks[i];
        final isFirst = rank == 1;

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Badge
              if (rider.badge != null)
                Text(rider.badge!, style: TextStyle(fontSize: 16.sp)),
              if (rider.badge == null) SizedBox(height: 24.h),

              // Avatar
              GestureDetector(
                onTap: rider.isMe
                    ? null
                    : () => context.push('/user-profile', extra: {
                          'name': rider.name,
                          'type': 'rider',
                          'distance': rider.values[_Metric.distance] ?? '',
                          'following': false,
                          'userId': rider.id,
                        }),
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: isFirst ? 3 : 2),
                    boxShadow: isFirst
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 12,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: MjAvatar(
                    name: rider.name,
                    size: sizes[i],
                    showBorder: false,
                    onTap: () => showPhotoViewer(context, name: rider.name),
                  ),
                ),
              ),
              SizedBox(height: 6.h),

              // Name
              Text(
                rider.isMe ? 'You' : rider.name.split(' ')[0],
                style: TextStyle(
                  fontSize: isFirst ? 13.sp : 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.white : AppColors.grey900,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 2.h),

              // Value
              Text(
                rider.values[metric] ?? '',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              SizedBox(height: 6.h),

              // Podium block
              Container(
                height: heights[i],
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.18 : 0.12),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(10.r),
                    topRight: Radius.circular(10.r),
                  ),
                  border: Border.all(
                      color: color.withValues(alpha: 0.35), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  '#$rank',
                  style: TextStyle(
                    fontSize: isFirst ? 22.sp : 18.sp,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ── Rider row ─────────────────────────────────────────────────────────────────

class _RiderRow extends StatelessWidget {
  final int rank;
  final _Rider rider;
  final _Metric metric;
  final bool isDark;

  const _RiderRow(
      {required this.rank,
      required this.rider,
      required this.metric,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final isMe = rider.isMe;

    return GestureDetector(
      onTap: isMe
          ? null
          : () => context.push('/user-profile', extra: {
                'name': rider.name,
                'type': 'rider',
                'distance': rider.values[_Metric.distance] ?? '',
                'following': false,
                'userId': rider.id,
              }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: isMe
              ? AppColors.primary.withValues(alpha: 0.10)
              : (isDark ? AppColors.darkCard : AppColors.white),
          borderRadius: BorderRadius.circular(16.r),
          border: isMe
              ? Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5)
              : Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.transparent),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32.w,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.grey400 : AppColors.grey500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(width: 10.w),

          // Avatar
          MjAvatar(
            name: rider.name,
            size: 42,
            showBorder: isMe,
            onTap: () => showPhotoViewer(context, name: rider.name),
          ),
          SizedBox(width: 12.w),

          // Name + label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rider.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isMe
                        ? AppColors.primary
                        : (isDark ? AppColors.white : AppColors.grey900),
                  ),
                ),
                if (isMe)
                  Text(
                    'That\'s you!',
                    style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.primary.withValues(alpha: 0.8)),
                  ),
              ],
            ),
          ),

          // Value pill
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 110.w),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppColors.grey100),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  rider.values[metric] ?? '',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: isMe
                        ? AppColors.primary
                        : (isDark ? AppColors.white : AppColors.grey800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Group row ─────────────────────────────────────────────────────────────────

class _GroupRow extends StatelessWidget {
  final int rank;
  final _Group group;
  final _Metric metric;
  final Color? medalColor;
  final bool isDark;

  const _GroupRow(
      {required this.rank,
      required this.group,
      required this.metric,
      required this.medalColor,
      required this.isDark});

  @override
  Widget build(BuildContext context) {
    final mc = medalColor;

    return GestureDetector(
      onTap: () => context.push('/groups/detail', extra: {
        'id': group.id,
        'name': group.name,
        'desc': 'Group leaderboard',
        'members': group.members,
        'joined': false,
        'createdByMe': false,
      }),
      child: Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
      decoration: BoxDecoration(
        color: mc != null
            ? mc.withValues(alpha: isDark ? 0.10 : 0.07)
            : (isDark ? AppColors.darkCard : AppColors.white),
        borderRadius: BorderRadius.circular(16.r),
        border: mc != null
            ? Border.all(color: mc.withValues(alpha: 0.30), width: 1.5)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.15 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Rank / medal
          SizedBox(
            width: 36.w,
            child: mc != null
                ? Icon(Icons.emoji_events_rounded, color: mc, size: 26.w)
                : Text(
                    '#$rank',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w800,
                      color: isDark ? AppColors.grey400 : AppColors.grey500,
                    ),
                    textAlign: TextAlign.center,
                  ),
          ),
          SizedBox(width: 10.w),

          // Group icon
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.group_rounded,
                size: 22.w, color: AppColors.primary),
          ),
          SizedBox(width: 12.w),

          // Name + members
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Icon(Icons.person_outline_rounded,
                        size: 12.w, color: AppColors.grey500),
                    SizedBox(width: 3.w),
                    Text(
                      '${group.members} members',
                      style: TextStyle(
                          fontSize: 11.sp, color: AppColors.grey500),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Value pill
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 110.w),
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: mc != null
                    ? mc.withValues(alpha: 0.15)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppColors.grey100),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  group.values[metric] ?? '',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: mc ??
                        (isDark ? AppColors.white : AppColors.grey800),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
