import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mj_avatar.dart';
import '../../../../core/widgets/photo_viewer.dart';
import '../../data/models/group_model.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../providers/group_detail_provider.dart';
import '../providers/groups_provider.dart';

enum _PostAction { share, delete }

class GroupDetailScreen extends ConsumerStatefulWidget {
  final String groupId;
  final String name;
  final String desc;
  final int members;
  final bool joined;
  final bool createdByMe;

  const GroupDetailScreen({
    super.key,
    this.groupId = '',
    this.name = 'Campus Cyclists',
    this.desc = 'Ride together across campus!',
    this.members = 32,
    this.joined = false,
    this.createdByMe = false,
  });

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen>
    with SingleTickerProviderStateMixin {
  late bool _joined;
  late bool _isAdmin;
  bool _isPrivate = false;
  bool _isJoinToggling = false;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _isAdmin = widget.createdByMe;
    _joined = _isAdmin ? true : widget.joined;
    _tab = TabController(length: 3, vsync: this)
      ..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final detailState = widget.groupId.isNotEmpty
        ? ref.watch(groupDetailProvider(widget.groupId))
        : null;
    final effectiveJoined = detailState?.group?.joined ?? _joined;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkSurface : AppColors.grey50,
      floatingActionButton: _tab.index == 0 && effectiveJoined
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => _showCreatePostSheet(context),
              child: const Icon(Icons.edit_rounded, color: Colors.white),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            _buildStats(isDark),
            _buildTabBar(isDark),
            Expanded(child: _buildTabBody(isDark)),
          ],
        ),
      ),
    );
  }

  // ── Hero header ────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    final detailState = widget.groupId.isNotEmpty
        ? ref.watch(groupDetailProvider(widget.groupId))
        : null;
    final group = detailState?.group;
    final groupName =
        (group?.name.isNotEmpty ?? false) ? group!.name : widget.name;
    final groupDesc =
        (group?.description.isNotEmpty ?? false) ? group!.description : widget.desc;
    final membersCount = group?.members ?? widget.members;
    final effectiveJoined = group?.joined ?? _joined;
    final effectiveIsAdmin = group?.isCreator ?? _isAdmin;
    final effectivePrivate =
        _isPrivate || (group?.visibility.toLowerCase() == 'private');

    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 20.h),
      child: Column(
        children: [
          // Top bar
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).maybePop(),
                child: Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color:
                        isDark ? AppColors.darkElevated : AppColors.grey100,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.arrow_back_ios_new_rounded,
                      size: 16.w,
                      color:
                          isDark ? AppColors.white : AppColors.grey800),
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _shareGroup(
                  name: groupName,
                  description: groupDesc,
                  members: membersCount,
                ),
                child: Container(
                  width: 38.w,
                  height: 38.w,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(Icons.share_rounded,
                      size: 18.w, color: AppColors.primary),
                ),
              ),
              if (effectiveIsAdmin) ...[
                SizedBox(width: 10.w),
                GestureDetector(
                  onTap: () => setState(() => _isPrivate = !_isPrivate),
                  child: Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: effectivePrivate
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : AppColors.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      effectivePrivate ? Icons.lock_rounded : Icons.public_rounded,
                      size: 18.w,
                      color: effectivePrivate ? AppColors.warning : AppColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 10.w),
                GestureDetector(
                  onTap: () => _showDeleteDialog(context),
                  child: Container(
                    width: 38.w,
                    height: 38.w,
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    alignment: Alignment.center,
                    child: Icon(Icons.delete_outline_rounded,
                        size: 18.w, color: AppColors.error),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 18.h),

          // Group info row
          Row(
            children: [
              // Large avatar
              GestureDetector(
                onTap: () => showPhotoViewer(context, name: groupName),
                child: Container(
                  padding: EdgeInsets.all(3.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: AppColors.primary, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: MjAvatar(name: groupName, size: 64),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      groupName,
                      style: TextStyle(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      groupDesc,
                      style: TextStyle(
                          fontSize: 13.sp, color: AppColors.grey500),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Icon(Icons.people_alt_rounded,
                            size: 14.w, color: AppColors.primary),
                        SizedBox(width: 4.w),
                        Text(
                          '$membersCount members',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(width: 12.w),
              // Join / Joined button
              if (effectiveJoined || !effectivePrivate)
                GestureDetector(
                  onTap: _isJoinToggling
                      ? null
                      : () async {
                    if (widget.groupId.isNotEmpty) {
                      setState(() => _isJoinToggling = true);
                      try {
                        if (effectiveJoined) {
                          final ok = await ref.read(groupDetailProvider(widget.groupId).notifier).leaveGroup();
                          if (ok) {
                            setState(() => _joined = false);
                            ref.read(groupsProvider.notifier).loadGroups();
                          }
                        } else {
                          final ok = await ref.read(groupDetailProvider(widget.groupId).notifier).joinGroup();
                          if (ok) {
                            setState(() => _joined = true);
                            ref.read(groupsProvider.notifier).loadGroups();
                          }
                        }
                      } finally {
                        if (mounted) setState(() => _isJoinToggling = false);
                      }
                    } else {
                      setState(() => _joined = !_joined);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: EdgeInsets.symmetric(
                        horizontal: 18.w, vertical: 11.h),
                    decoration: BoxDecoration(
                      color: effectiveJoined
                          ? (isDark
                              ? AppColors.darkElevated
                              : AppColors.grey100)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: effectiveJoined
                          ? null
                          : [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ],
                    ),
                    child: _isJoinToggling
                        ? SizedBox(
                            width: 16.sp,
                            height: 16.sp,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                effectiveJoined
                                    ? (isDark
                                        ? AppColors.grey400
                                        : AppColors.grey600)
                                    : Colors.white,
                              ),
                            ),
                          )
                        : effectiveJoined
                        ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_rounded,
                                  size: 14.sp,
                                  color: isDark
                                      ? AppColors.grey400
                                      : AppColors.grey600),
                              SizedBox(width: 4.w),
                              Text(
                                'Joined',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isDark
                                      ? AppColors.grey400
                                      : AppColors.grey600,
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
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 14.w, vertical: 11.h),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock_rounded,
                          size: 13.w, color: AppColors.warning),
                      SizedBox(width: 5.w),
                      Text(
                        'Private',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Stats row ──────────────────────────────────────────────────────────────

  Widget _buildStats(bool isDark) {
    final detailState = widget.groupId.isNotEmpty
        ? ref.watch(groupDetailProvider(widget.groupId))
        : null;
    final agg = detailState?.aggregate;
    final distStr = agg != null ? agg.distanceFormatted : '0';
    final carbonStr = agg != null ? agg.carbonFormatted : '0';
    final ridesStr = agg != null ? '${agg.totalTrips}' : '0';
    final stats = [
      (distStr, 'km', AppColors.distance),
      (carbonStr, 'kg CO2', AppColors.success),
      (ridesStr, 'rides', AppColors.speed),
    ];
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.white,
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 16.h),
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.darkElevated
              : AppColors.grey50,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
          ),
        ),
        child: Row(
          children: List.generate(stats.length, (i) {
            final (val, label, color) = stats[i];
            final isLast = i == stats.length - 1;
            return Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  border: isLast
                      ? null
                      : Border(
                          right: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.black.withValues(alpha: 0.05),
                          ),
                        ),
                ),
                child: Column(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        val,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w900,
                          color: color,
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      label,
                      style: TextStyle(
                          fontSize: 11.sp, color: AppColors.grey500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ── Tab bar ────────────────────────────────────────────────────────────────

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
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 6.w), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.dynamic_feed_rounded, size: 15.w), SizedBox(width: 5.w), const Text('Feed')])))),
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 6.w), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.people_rounded, size: 15.w), SizedBox(width: 5.w), const Text('Members')])))),
            Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Padding(padding: EdgeInsets.symmetric(horizontal: 6.w), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.bar_chart_rounded, size: 15.w), SizedBox(width: 5.w), const Text('Stats')])))),
          ],
        ),
      ),
    );
  }

  // ── Tab body ───────────────────────────────────────────────────────────────

  Widget _buildTabBody(bool isDark) {
    return TabBarView(
      controller: _tab,
      children: [
        _buildFeed(isDark),
        _buildMembers(isDark),
        _buildStatsTab(isDark),
      ],
    );
  }

  // ── Feed ────────────────────────────────────────────────────────────────────

  Widget _buildFeed(bool isDark) {
    final detailState = widget.groupId.isNotEmpty
        ? ref.watch(groupDetailProvider(widget.groupId))
        : null;
    final group = detailState?.group;
    final effectiveIsAdmin = group?.isCreator ?? _isAdmin;
    final currentGroupName =
        (group?.name.isNotEmpty ?? false) ? group!.name : widget.name;
    final posts = detailState?.posts ?? [];
    final currentUserId = ref.watch(profileProvider).valueOrNull?.id ?? '';

    if (detailState?.isLoading == true && posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 56.w, color: isDark ? Colors.white30 : Colors.black26),
            SizedBox(height: 14.h),
            Text(
              'No posts yet',
              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w600, color: isDark ? Colors.white54 : Colors.black45),
            ),
            SizedBox(height: 6.h),
            Text(
              'Be the first to share something!',
              style: TextStyle(fontSize: 13.sp, color: isDark ? Colors.white38 : Colors.black38),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 100.h),
      itemCount: posts.length,
      itemBuilder: (_, i) {
        final post = posts[i];
        final isMe = post.userId == currentUserId;
        final canDelete = isMe || effectiveIsAdmin;
        final authorLabel = isMe ? 'You' : post.authorName;
        return Padding(
          padding: EdgeInsets.only(bottom: 14.h),
          child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Author row
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
                  child: Row(
                    children: [
                      MjAvatar(
                          name: authorLabel,
                          imageUrl: post.authorAvatar,
                          size: 38,
                          showBorder: isMe,
                          onTap: isMe
                              ? null
                              : () => showPhotoViewer(context,
                                  name: authorLabel)),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              authorLabel,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.white
                                    : AppColors.grey900,
                              ),
                            ),
                            Text(
                              post.relativeTime,
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.grey500),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<_PostAction>(
                        onSelected: (action) async {
                          switch (action) {
                            case _PostAction.share:
                              await _sharePost(
                                post,
                                groupName: post.groupName.isNotEmpty
                                    ? post.groupName
                                    : currentGroupName,
                              );
                              break;
                            case _PostAction.delete:
                              if (canDelete) {
                                await _deletePost(post);
                              }
                              break;
                          }
                        },
                        icon: Icon(Icons.more_horiz_rounded,
                            size: 20.w, color: AppColors.grey500),
                        itemBuilder: (_) => [
                          const PopupMenuItem<_PostAction>(
                            value: _PostAction.share,
                            child: Text('Share'),
                          ),
                          if (canDelete)
                            PopupMenuItem<_PostAction>(
                              value: _PostAction.delete,
                              child: Text(
                                'Delete',
                                style: TextStyle(color: AppColors.error),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Post text
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
                  child: Text(
                    post.body,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: isDark ? AppColors.grey200 : AppColors.grey800,
                      height: 1.4,
                    ),
                  ),
                ),
                // Post image
                if (post.imageUrl.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12.r),
                      child: Image.network(
                        post.imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _shareGroup({
    required String name,
    required String description,
    required int members,
  }) async {
    final summary = description.trim().isEmpty
        ? 'Ride together with $members members on Newtra.'
        : description.trim();
    await Share.share(
      'Join "$name" on Newtra.\n\n$summary\n\nMembers: $members',
      subject: name,
    );
  }

  Future<void> _sharePost(
    CommunityPostModel post, {
    required String groupName,
  }) async {
    final body = post.body.trim().isEmpty ? 'Check out this update.' : post.body.trim();
    await Share.share(
      'From $groupName on Newtra\n\n$body',
      subject: groupName,
    );
  }

  Future<void> _deletePost(CommunityPostModel post) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: const Text('Delete Post'),
            content: const Text('This post will be removed from the group feed.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(
                  'Delete',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted || widget.groupId.isEmpty) {
      return;
    }

    final ok = await ref
        .read(groupDetailProvider(widget.groupId).notifier)
        .deletePost(post.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Post deleted' : 'Failed to delete post'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
      ),
    );
  }

  // ── Members ─────────────────────────────────────────────────────────────────

  Widget _buildMembers(bool isDark) {
    final detailState = widget.groupId.isNotEmpty
        ? ref.watch(groupDetailProvider(widget.groupId))
        : null;
    final apiMembers = detailState?.members ?? [];
    final currentUserId = ref.watch(profileProvider).valueOrNull?.id ?? '';

    // Convert API members to the map format the UI expects
    final members = apiMembers.isEmpty
        ? <Map<String, dynamic>>[]
        : apiMembers.map((m) => <String, dynamic>{
              'name': (currentUserId.isNotEmpty && m.uid == currentUserId) ? 'You' : (m.fullName.isEmpty ? 'Unknown' : m.fullName),
              'role': m.role,
              'distance': m.distanceFormatted,
              'rides': '${m.totalTrips}',
              'uid': m.uid,
            }).toList();

    if (detailState?.isLoading == true && members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (members.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Text('No members yet', style: TextStyle(fontSize: 14.sp, color: AppColors.grey500)),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 32.h),
      itemCount: members.length,
      itemBuilder: (_, i) {
        final m = members[i];
        final isAdmin = m['role'] == 'Admin';
        final isMe = m['name'] == 'You';
        return GestureDetector(
          onTap: isMe
              ? null
              : () => context.push('/user-profile', extra: {
                    'name': m['name'] as String,
                    'type': 'rider',
                    'distance': m['distance'] as String,
                    'following': false,
                    'userId': m['uid'] as String? ?? '',
                  }),
          child: Padding(
          padding: EdgeInsets.only(bottom: 10.h),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: 14.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: isMe
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : (isDark ? AppColors.darkCard : AppColors.white),
              borderRadius: BorderRadius.circular(16.r),
              border: isMe
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black
                      .withValues(alpha: isDark ? 0.15 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                MjAvatar(
                  name: m['name'] as String,
                  size: 44,
                  showBorder: isMe,
                  onTap: isMe
                      ? null
                      : () => showPhotoViewer(context,
                          name: m['name'] as String),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            m['name'] as String,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                              color: isMe
                                  ? AppColors.primary
                                  : (isDark
                                      ? AppColors.white
                                      : AppColors.grey900),
                            ),
                          ),
                          SizedBox(width: 6.w),
                          if (isAdmin)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 7.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'Admin',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          if (isMe)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 7.w, vertical: 2.h),
                              decoration: BoxDecoration(
                                color: AppColors.primary
                                    .withValues(alpha: 0.12),
                                borderRadius:
                                    BorderRadius.circular(6.r),
                              ),
                              child: Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        '${m['distance']}  ·  ${m['rides']} rides',
                        style: TextStyle(
                            fontSize: 12.sp, color: AppColors.grey500),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 20.w, color: AppColors.grey400),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  // ── Stats tab ───────────────────────────────────────────────────────────────

  Widget _buildStatsTab(bool isDark) {
    final detailState = widget.groupId.isNotEmpty
        ? ref.watch(groupDetailProvider(widget.groupId))
        : null;
    final apiMembers = detailState?.members ?? [];
    final currentUserId = ref.watch(profileProvider).valueOrNull?.id ?? '';

    // Sort members by km traveled descending, take top 10
    final sorted = List<GroupMemberModel>.from(apiMembers)
      ..sort((a, b) => b.kmTraveled.compareTo(a.kmTraveled));
    final topMembers = sorted.take(10).toList();

    // Calculate max distance for progress bar ratio
    final maxDist = topMembers.isNotEmpty ? topMembers.first.kmTraveled : 1.0;

    final topRiders = topMembers.map((m) {
      final ratio = maxDist > 0 ? m.kmTraveled / maxDist : 0.0;
      final name = (currentUserId.isNotEmpty && m.uid == currentUserId) ? 'You' : (m.fullName.isEmpty ? 'Unknown' : m.fullName);
      return (name, m.distanceFormatted, ratio, m.uid);
    }).toList();

    return ListView(
      padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 32.h),
      children: [
        // Section title
        Text('Top Contributors',
            style: TextStyle(
                fontSize: 15.sp, fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.grey900)),
        SizedBox(height: 12.h),
        ...topRiders.asMap().entries.map((e) {
          final i = e.key;
          final (name, dist, ratio, uid) = e.value;
          final isMe = name == 'You';
          return GestureDetector(
            onTap: isMe
                ? null
                : () => context.push('/user-profile', extra: {
                      'name': name,
                      'type': 'rider',
                      'distance': dist,
                      'following': false,
                      'userId': uid,
                    }),
            child: Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Container(
              padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
              decoration: BoxDecoration(
                color: isMe
                    ? AppColors.primary.withValues(alpha: 0.08)
                    : (isDark ? AppColors.darkCard : AppColors.white),
                borderRadius: BorderRadius.circular(14.r),
                border: isMe
                    ? Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1.5)
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black
                        .withValues(alpha: isDark ? 0.12 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        '#${i + 1}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? AppColors.grey400
                              : AppColors.grey500,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      MjAvatar(
                        name: name,
                        size: 34,
                        onTap: isMe
                            ? null
                            : () => showPhotoViewer(context, name: name),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: isMe
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.white
                                    : AppColors.grey800),
                          ),
                        ),
                      ),
                      Text(
                        dist,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4.r),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 5.h,
                      backgroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.07)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation(
                          isMe ? AppColors.primary : AppColors.distance),
                    ),
                  ),
                ],
              ),
            ),
          ),
          );
        }),
      ],
    );
  }

  // ── Dialogs / sheets ───────────────────────────────────────────────────────

  // ── Inline replies display ─────────────────────────────────────────────────

  List<Widget> _buildInlineReplies(
      List<Map<String, String>> replies, bool isDark) {
    const maxShown = 2;
    final shown = replies.take(maxShown).toList();
    return [
      Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
        child: Divider(
          height: 1,
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      Padding(
        padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
        child: Column(
          children: shown
              .map((reply) => Padding(
                    padding: EdgeInsets.only(bottom: 7.h),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MjAvatar(
                          name: reply['author']!,
                          size: 26,
                          showBorder: reply['author'] == 'You',
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 10.w, vertical: 7.h),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppColors.darkElevated
                                  : AppColors.grey50,
                              borderRadius: BorderRadius.circular(10.r),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reply['author']!,
                                  style: TextStyle(
                                    fontSize: 11.5.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? AppColors.white
                                        : AppColors.grey900,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  reply['text']!,
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: isDark
                                        ? AppColors.grey300
                                        : AppColors.grey700,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      if (replies.length > maxShown)
        Padding(
          padding: EdgeInsets.fromLTRB(60.w, 0, 16.w, 4.h),
          child: Text(
            'View ${replies.length - maxShown} more '
            '${replies.length - maxShown == 1 ? 'reply' : 'replies'}',
            style: TextStyle(
              fontSize: 11.5.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
    ];
  }

  // ── Create post sheet ──────────────────────────────────────────────────────

  void _showCreatePostSheet(BuildContext context) {
    final ctrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 16.h,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              SizedBox(height: 18.h),
              Text('New Post',
                  style: TextStyle(
                      fontSize: 18.sp, fontWeight: FontWeight.w800)),
              SizedBox(height: 14.h),
              Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkElevated
                      : AppColors.grey50,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: TextField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 4,
                  style: TextStyle(fontSize: 14.sp),
                  decoration: InputDecoration(
                    hintText: "What's on your mind?",
                    hintStyle: TextStyle(
                        fontSize: 14.sp, color: AppColors.grey400),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14.w),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: GestureDetector(
                  onTap: () {
                    final text = ctrl.text.trim();
                    if (text.isEmpty) return;
                    if (widget.groupId.isNotEmpty) {
                      ref.read(groupDetailProvider(widget.groupId).notifier).createPost(text);
                    }
                    Navigator.pop(ctx);
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 15.h),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(14.r),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AppColors.primary.withValues(alpha: 0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r)),
        title: const Text('Delete Group'),
        content: Text(
            'Are you sure you want to delete "${widget.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _deleteGroup();
            },
            child: Text('Delete',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup() async {
    if (widget.groupId.isEmpty) {
      Navigator.pop(context);
      return;
    }
    final ok = await ref
        .read(groupDetailProvider(widget.groupId).notifier)
        .deleteGroup();
    if (!mounted) return;
    if (ok) {
      ref.read(groupsProvider.notifier).loadGroups();
      Navigator.pop(context);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Group deleted' : 'Failed to delete group'),
        backgroundColor: ok ? AppColors.success : AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
