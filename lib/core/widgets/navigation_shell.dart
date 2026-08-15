import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../constants/app_assets.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';
import '../../features/auth/presentation/providers/auth_state_provider.dart';
import '../storage/local_storage.dart';
import '../theme/theme_provider.dart';
import '../../features/profile/presentation/providers/profile_provider.dart';
import '../../features/subscription/presentation/providers/subscription_provider.dart';
import '../../features/wallet/presentation/providers/wallet_provider.dart';

class NavigationShell extends ConsumerWidget {
  final Widget child;

  const NavigationShell({super.key, required this.child});

  int _currentIndex(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/home')) return 0;
    if (location.startsWith('/bikes')) return 1;
    if (location.startsWith('/community')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(walletProvider.select((state) => state.balance));
    ref.watch(subscriptionProvider.select((state) => state.active?.planName));

    final index = _currentIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final useRail = AppBreakpoints.useRailNav(context);
    final useWideRail = AppBreakpoints.useWideRailNav(context);
    final foldRect = AppBreakpoints.foldBounds(context);

    void navigate(int i) {
      switch (i) {
        case 0:
          context.go('/home');
        case 1:
          context.go('/bikes');
        case 2:
          context.go('/community');
        case 3:
          context.go('/profile');
      }
    }

    // ── Tablet / unfolded foldable: side navigation rail ─────────────────
    if (useRail) {
      return Scaffold(
        drawer: _AppDrawer(shellContext: context),
        body: Builder(
          builder: (innerCtx) => Row(
            children: [
              _GlassNavRail(
                currentIndex: index,
                isDark: isDark,
                extended: useWideRail,
                onTap: navigate,
                onMenuTap: () => Scaffold.of(innerCtx).openDrawer(),
              ),
              // Gap equal to the physical hinge / fold crease width so that
              // no content is rendered over the crease on foldable devices.
              if (foldRect != null && foldRect.width > 0)
                SizedBox(width: foldRect.width),
              Expanded(child: child),
            ],
          ),
        ),
      );
    }

    // ── Phone / half-opened foldable: bottom navigation bar ─────────────
    return Scaffold(
      drawer: _AppDrawer(shellContext: context),
      extendBody: true,
      body: child,
      bottomNavigationBar: _GlassBottomNav(
        currentIndex: index,
        isDark: isDark,
        onTap: navigate,
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  final BuildContext shellContext;
  const _AppDrawer({required this.shellContext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Palette: true charcoal dark / clean white light — no green tints in bg
    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF);
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : const Color(0xFFEEEEEE);
    final sectionColor = isDark
        ? Colors.white.withValues(alpha: 0.30)
        : AppColors.grey400;

    return Drawer(
      width: 0.78.sw,
      backgroundColor: bg,
      child: Column(
        children: [
          // ── Profile card ──────────────────────────────────────────
          _DrawerProfileCard(isDark: isDark),

          // ── Menu items ────────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(top: 8.h, bottom: 8.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel(label: 'MOBILITY', subColor: sectionColor),
                  _DrawerItem(
                    icon: Icons.directions_bus_outlined,
                    label: 'Bus & Buggy',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/transit');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.route_outlined,
                    label: 'My Trips',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/trips');
                    },
                  ),

                  Divider(
                    height: 16.h,
                    thickness: 1,
                    color: divider,
                    indent: 20.w,
                    endIndent: 20.w,
                  ),
                  _SectionLabel(label: 'ACCOUNT', subColor: sectionColor),
                  _DrawerItem(
                    icon: Icons.subscriptions_outlined,
                    label: 'Subscriptions',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/subscriptions');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Wallet',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/wallet');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.bar_chart_outlined,
                    label: 'Activity',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/activity');
                    },
                  ),

                  Divider(
                    height: 16.h,
                    thickness: 1,
                    color: divider,
                    indent: 20.w,
                    endIndent: 20.w,
                  ),
                  _SectionLabel(label: 'SOCIAL', subColor: sectionColor),
                  _DrawerItem(
                    icon: Icons.leaderboard_outlined,
                    label: 'Leaderboard',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/leaderboard');
                    },
                  ),
                  _DrawerItem(
                    icon: Icons.groups_outlined,
                    label: 'Groups',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/groups');
                    },
                  ),

                  Divider(
                    height: 16.h,
                    thickness: 1,
                    color: divider,
                    indent: 20.w,
                    endIndent: 20.w,
                  ),
                  _SectionLabel(label: 'PREFERENCES', subColor: sectionColor),
                  _DrawerItem(
                    icon: isDark
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                    label: isDark ? 'Light Mode' : 'Dark Mode',
                    isDark: isDark,
                    onTap: () => ref.read(themeProvider.notifier).toggleTheme(),
                  ),
                  _DrawerItem(
                    icon: Icons.help_outline,
                    label: 'FAQ & Support',
                    isDark: isDark,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/support');
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Footer ────────────────────────────────────────────────
          Divider(height: 1, thickness: 1, color: divider),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4.h),
            child: Column(
              children: [
                _DrawerItem(
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  isDark: isDark,
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutDialog(shellContext, ref);
                  },
                ),
                _DrawerItem(
                  icon: Icons.delete_forever_outlined,
                  label: 'Delete Account',
                  isDark: isDark,
                  isDestructive: true,
                  onTap: () {
                    Navigator.pop(context);
                    _showDeleteDialog(shellContext, ref);
                  },
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom + 8.h),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    final authNotifier = ref.read(authStateProvider.notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await authNotifier.logout();
              if (!context.mounted) return;
              context.go('/auth/login');
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This action is irreversible. All your data will be permanently deleted. You will need to verify with OTP.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.push('/account/delete-verify');
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

class _DrawerProfileCard extends ConsumerWidget {
  final bool isDark;
  const _DrawerProfileCard({required this.isDark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardBg = isDark ? const Color(0xFF161B22) : const Color(0xFFF5F5F5);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final nameColor = isDark ? Colors.white : AppColors.grey900;
    final subTextColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.grey500;
    final activePlanName = ref.watch(
      subscriptionProvider.select((state) {
        final raw = state.active?.planName.trim() ?? '';
        return raw.isEmpty ? null : raw;
      }),
    );

    return Container(
      width: double.infinity,
      // Respect status bar height
      padding: EdgeInsets.fromLTRB(
        16.w,
        MediaQuery.of(context).padding.top + 16.h,
        16.w,
        16.h,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: logo left, close right
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SvgPicture.asset(
                AppAssets.fullLogoForTheme(isDark),
                height: 28.h,
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 28.w,
                  height: 28.w,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14.w,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.70)
                        : AppColors.grey600,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 18.h),

          // Avatar + name row — tappable → profile
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.push('/profile');
            },
            behavior: HitTestBehavior.opaque,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar with glassmorphism ring
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 0, sigmaY: 0),
                    child: Stack(
                      children: [
                        Container(
                          width: 52.w,
                          height: 52.w,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [Color(0xFF00A877), Color(0xFF007A56)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              ref
                                          .watch(profileProvider)
                                          .valueOrNull
                                          ?.initials
                                          .isNotEmpty ==
                                      true
                                  ? ref
                                        .watch(profileProvider)
                                        .valueOrNull!
                                        .initials
                                  : 'MU',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                        // Glass sheen overlay
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 26.w,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.rectangle,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.white.withValues(alpha: 0.18),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(width: 12.w),

                // Name + phone
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        (ref.watch(profileProvider).valueOrNull?.fullName ?? '')
                                .isNotEmpty
                            ? ref.watch(profileProvider).valueOrNull!.fullName
                            : 'Newtra User',
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w700,
                          color: nameColor,
                          letterSpacing: 0.1,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        (ref.watch(profileProvider).valueOrNull?.phone ?? '')
                                .isNotEmpty
                            ? ref.watch(profileProvider).valueOrNull!.phone
                            : '+91 98765 43210',
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          color: subTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),

                // Edit profile arrow
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20.w,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.grey400,
                ),
              ],
            ), // Row
          ), // GestureDetector

          SizedBox(height: 14.h),

          // Plan badge + stats row
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: [
              // Plan pill
              if (activePlanName != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A877).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: const Color(0xFF00A877).withValues(alpha: 0.30),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bolt_rounded,
                        size: 11.w,
                        color: const Color(0xFF00A877),
                      ),
                      SizedBox(width: 3.w),
                      Text(
                        activePlanName,
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF00A877),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),

              // Coins chip
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      size: 11.w,
                      color: const Color(0xFFFFB300),
                    ),
                    SizedBox(width: 3.w),
                    Text(
                      '${LocalStorage.getTotalDisplayCoins()} MJ',
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w600,
                        color: nameColor,
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
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Color subColor;
  const _SectionLabel({required this.label, required this.subColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 2.h),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: subColor,
          letterSpacing: 1.4,
        ),
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool isDark;

  const _DrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = isDestructive
        ? AppColors.error
        : (isDark ? Colors.white.withValues(alpha: 0.75) : AppColors.grey700);
    final labelColor = isDestructive
        ? AppColors.error
        : (isDark ? Colors.white : AppColors.grey900);
    final splashColor = isDestructive
        ? AppColors.error.withValues(alpha: 0.08)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.grey100);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor,
        highlightColor: splashColor,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 20.w),
              SizedBox(width: 16.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: labelColor,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 16.w,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : AppColors.grey300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Frosted-glass navigation rail (tablets & foldables) ────────────────────

class _GlassNavRail extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final VoidCallback onMenuTap;
  final bool isDark;
  final bool extended;

  // Fixed logical-pixel widths — intentionally NOT using .w so the rail stays
  // a sensible fixed size regardless of screen width.
  static const double _compactWidth = 72;
  static const double _extendedWidth = 184;

  const _GlassNavRail({
    required this.currentIndex,
    required this.onTap,
    required this.onMenuTap,
    required this.isDark,
    required this.extended,
  });

  @override
  Widget build(BuildContext context) {
    final railWidth = extended ? _extendedWidth : _compactWidth;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          width: railWidth,
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.52)
                : Colors.white.withValues(alpha: 0.88),
            border: Border(
              right: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
                width: 0.8,
              ),
            ),
          ),
          child: SafeArea(
            right: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // App icon-mark logo
                  SvgPicture.asset(
                    AppAssets.iconLogoForTheme(isDark),
                    width: 36,
                    height: 36,
                  ),
                  const SizedBox(height: 10),
                  // Drawer menu toggle
                  _RailIconButton(
                    icon: Icons.menu_rounded,
                    isDark: isDark,
                    onTap: onMenuTap,
                  ),
                  Divider(
                    height: 20,
                    thickness: 0.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                  _RailItem(
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map,
                    label: 'Home',
                    isActive: currentIndex == 0,
                    isDark: isDark,
                    extended: extended,
                    onTap: () => onTap(0),
                  ),
                  _RailItem(
                    icon: Icons.qr_code_scanner_outlined,
                    activeIcon: Icons.qr_code_scanner,
                    label: 'Bikes',
                    isActive: currentIndex == 1,
                    isDark: isDark,
                    extended: extended,
                    onTap: () => onTap(1),
                  ),
                  _RailItem(
                    icon: Icons.people_outline,
                    activeIcon: Icons.people,
                    label: 'Community',
                    isActive: currentIndex == 2,
                    isDark: isDark,
                    extended: extended,
                    onTap: () => onTap(2),
                  ),
                  _RailItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profile',
                    isActive: currentIndex == 3,
                    isDark: isDark,
                    extended: extended,
                    onTap: () => onTap(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RailIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;

  const _RailIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Center(
          child: Icon(
            icon,
            size: 22,
            color: isDark ? AppColors.grey400 : AppColors.grey600,
          ),
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isDark;
  final bool extended;
  final VoidCallback onTap;

  const _RailItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.extended,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.primary
        : (isDark ? AppColors.grey500 : AppColors.grey600);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: isActive
            ? BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.20),
                  width: 1,
                ),
              )
            : null,
        child: extended
            ? Row(
                children: [
                  Icon(isActive ? activeIcon : icon, color: color, size: 22),
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                ],
              )
            : Center(
                child: Icon(
                  isActive ? activeIcon : icon,
                  color: color,
                  size: 22,
                ),
              ),
      ),
    );
  }
}

// ─── Frosted-glass bottom navigation bar ─────────────────────────────────────

class _GlassBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isDark;

  const _GlassBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
        child: Container(
          decoration: BoxDecoration(
            color: isDark
                ? Colors.black.withValues(alpha: 0.52)
                : Colors.white.withValues(alpha: 0.78),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.90),
                width: 0.8,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 6.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _NavItem(
                    icon: Icons.map_outlined,
                    activeIcon: Icons.map,
                    label: 'Home',
                    isActive: currentIndex == 0,
                    isDark: isDark,
                    onTap: () => onTap(0),
                  ),
                  _NavItem(
                    icon: Icons.qr_code_scanner_outlined,
                    activeIcon: Icons.qr_code_scanner,
                    label: 'Bikes',
                    isActive: currentIndex == 1,
                    isDark: isDark,
                    onTap: () => onTap(1),
                  ),
                  _NavItem(
                    icon: Icons.people_outline,
                    activeIcon: Icons.people,
                    label: 'Community',
                    isActive: currentIndex == 2,
                    isDark: isDark,
                    onTap: () => onTap(2),
                  ),
                  _NavItem(
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: 'Profile',
                    isActive: currentIndex == 3,
                    isDark: isDark,
                    onTap: () => onTap(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? AppColors.primary
        : (isDark ? AppColors.grey500 : AppColors.grey600);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: Icon(
                isActive ? activeIcon : icon,
                key: ValueKey(isActive),
                color: color,
                size: 24.w,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
