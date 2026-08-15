import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mj_avatar.dart';
import '../../data/models/group_model.dart';
import '../providers/groups_provider.dart';

// ── Data ──────────────────────────────────────────────────────────────────────

class _GroupData {
  final String id;
  final String name;
  final String desc;
  final String category;
  final int members;
  final String distance;
  bool joined;
  final bool createdByMe;

  _GroupData({
    required this.id,
    required this.name,
    required this.desc,
    required this.category,
    required this.members,
    required this.distance,
    required this.joined,
    this.createdByMe = false,
  });
}

// ── Screen ────────────────────────────────────────────────────────────────────

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _searchCtrl = TextEditingController();
  String _query = '';

  static _GroupData _groupToData(GroupModel m) => _GroupData(
        id: m.id,
        name: m.name,
        desc: m.description,
        category: m.category,
        members: m.members,
        distance: m.totalDistance,
        joined: m.joined,
        createdByMe: m.isCreator,
      );

  static const _categoryColors = {
    'Campus':     AppColors.primary,
    'Eco':        AppColors.success,
    'University': AppColors.info,
    'Racing':     AppColors.calories,
    'Leisure':    AppColors.elevation,
    'E-Bike':     AppColors.speed,
  };

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this)
      ..addListener(() => setState(() {}));
    // Refresh on open. The groups provider loads once at app start and may run
    // before auth is ready, leaving "My Groups" empty on first visit (it only
    // populated after switching to Discover and back). Re-fetch here so both
    // lists are correct as soon as the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(groupsProvider.notifier).loadGroups();
      }
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_GroupData> _filtered(List<_GroupData> src) {
    if (_query.isEmpty) return src;
    final q = _query.toLowerCase();
    return src.where((g) =>
        g.name.toLowerCase().contains(q) ||
        g.desc.toLowerCase().contains(q)).toList();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final groupsState = ref.watch(groupsProvider);
    final myGroups = groupsState.myGroups.map(_groupToData).toList();
    final discover = groupsState.discover.map(_groupToData).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkSurface : const Color(0xFFF2F5F9),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => context.push('/groups/create'),
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark, myGroups, discover),
            _buildSearch(isDark),
            _buildTabBar(isDark),
            Expanded(child: _buildBody(isDark, myGroups, discover)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark,
      List<_GroupData> myGroups, List<_GroupData> discover) {
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
                  'Groups',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),
                Text(
                  '${myGroups.length} joined · ${discover.length} to explore',
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
                Icon(Icons.group_rounded, size: 14.w, color: AppColors.primary),
                SizedBox(width: 5.w),
                Text(
                  '${myGroups.length} groups',
                  style: TextStyle(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Widget _buildSearch(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
      child: Container(
        height: 46.h,
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
        child: TextField(
          controller: _searchCtrl,
          onChanged: (v) => setState(() => _query = v),
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: 'Search groups…',
            hintStyle:
                TextStyle(fontSize: 14.sp, color: AppColors.grey500),
            prefixIcon: Icon(Icons.search_rounded,
                size: 20.w, color: AppColors.grey400),
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
                    },
                    child: Icon(Icons.close_rounded,
                        size: 18.w, color: AppColors.grey400),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 13.h),
          ),
        ),
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 10.h),
      child: Container(
        height: 50.h,
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
                blurRadius: 10,
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
              child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 8.w), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.group_rounded, size: 16.w),
                SizedBox(width: 6.w),
                const Text('My Groups'),
              ]))),
            ),
            Tab(
              child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 8.w), child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.explore_rounded, size: 16.w),
                SizedBox(width: 6.w),
                const Text('Discover'),
              ]))),
            ),
          ],
        ),
      ),
    );
  }

  // ── Body ───────────────────────────────────────────────────────────────────

  Widget _buildBody(bool isDark, List<_GroupData> myGroups,
      List<_GroupData> discover) {
    return TabBarView(
      controller: _tab,
      children: [
        _buildList(_filtered(myGroups), isMyGroups: true, isDark: isDark),
        _buildList(_filtered(discover), isMyGroups: false, isDark: isDark),
      ],
    );
  }

  Widget _buildList(List<_GroupData> groups,
      {required bool isMyGroups, required bool isDark}) {
    if (groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48.w, color: AppColors.grey300),
            SizedBox(height: 12.h),
            Text('No groups found',
                style:
                    TextStyle(fontSize: 15.sp, color: AppColors.grey500)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 2.h, 20.w, 100.h),
      itemCount: groups.length,
      itemBuilder: (_, i) => Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: _GroupCard(
          data: groups[i],
          isDark: isDark,
          showJoin: !isMyGroups,
          accentColor:
              _categoryColors[groups[i].category] ?? AppColors.primary,
          onJoinToggle: () async {
            if (groups[i].joined) {
              await ref.read(groupsProvider.notifier).leaveGroup(groups[i].id);
            } else {
              await ref.read(groupsProvider.notifier).joinGroup(groups[i].id);
            }
          },
          onTap: () => context.push('/groups/detail', extra: {
            'id': groups[i].id,
            'name': groups[i].name,
            'desc': groups[i].desc,
            'members': groups[i].members,
            'joined': groups[i].joined,
            'createdByMe': groups[i].createdByMe,
          }),
        ),
      ),
    );
  }
}

// ── Group Card ────────────────────────────────────────────────────────────────

class _GroupCard extends StatelessWidget {
  final _GroupData data;
  final bool isDark;
  final bool showJoin;
  final Color accentColor;
  final Future<void> Function() onJoinToggle;
  final VoidCallback onTap;

  const _GroupCard({
    required this.data,
    required this.isDark,
    required this.showJoin,
    required this.accentColor,
    required this.onJoinToggle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // ── Top section ──────────────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
              child: Row(
                children: [
                  // Avatar with accent ring
                  Container(
                    padding: EdgeInsets.all(2.5.w),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: accentColor, width: 2),
                    ),
                    child: MjAvatar(name: data.name, size: 50),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                data.name,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.white
                                      : AppColors.grey900,
                                ),
                              ),
                            ),
                            // Category chip
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                data.category,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          data.desc,
                          style: TextStyle(
                              fontSize: 12.sp, color: AppColors.grey500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Divider ──────────────────────────────────────────────
            Divider(
              height: 1,
              thickness: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
            ),

            // ── Bottom stats + join ───────────────────────────────────
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 12.w, 12.h),
              child: Row(
                children: [
                  // Members
                  Icon(Icons.people_alt_rounded,
                      size: 14.w, color: AppColors.grey400),
                  SizedBox(width: 4.w),
                  Text(
                    '${data.members} members',
                    style: TextStyle(
                        fontSize: 12.sp, color: AppColors.grey500),
                  ),
                  SizedBox(width: 14.w),
                  // Distance
                  Icon(Icons.route_rounded,
                      size: 14.w, color: AppColors.grey400),
                  SizedBox(width: 4.w),
                  Text(
                    data.distance,
                    style: TextStyle(
                        fontSize: 12.sp, color: AppColors.grey500),
                  ),
                  const Spacer(),
                  if (showJoin)
                    _JoinButton(
                      joined: data.joined,
                      isDark: isDark,
                      accentColor: accentColor,
                      onToggle: onJoinToggle,
                    )
                  else
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 12.w, vertical: 7.h),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Text(
                        'View',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Join / Joined button with inline loader ───────────────────────────────────

class _JoinButton extends StatefulWidget {
  final bool joined;
  final bool isDark;
  final Color accentColor;
  final Future<void> Function() onToggle;

  const _JoinButton({
    required this.joined,
    required this.isDark,
    required this.accentColor,
    required this.onToggle,
  });

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onToggle();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final joined = widget.joined;
    final isDark = widget.isDark;
    final accentColor = widget.accentColor;
    final mutedColor = isDark ? AppColors.grey400 : AppColors.grey600;

    return GestureDetector(
      onTap: _loading ? null : _handleTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: joined
              ? (isDark ? AppColors.darkElevated : AppColors.grey100)
              : accentColor,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: joined
              ? null
              : [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.30),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ],
        ),
        child: _loading
            ? SizedBox(
                width: 16.sp,
                height: 16.sp,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    joined ? mutedColor : Colors.white,
                  ),
                ),
              )
            : joined
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_rounded, size: 14.sp, color: mutedColor),
                      SizedBox(width: 4.w),
                      Text(
                        'Joined',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: mutedColor,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Join',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
      ),
    );
  }
}

