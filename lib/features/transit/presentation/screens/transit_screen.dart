import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/local_storage.dart';
import '../../data/models/transit_model.dart';
import '../providers/transit_provider.dart';


// ── Screen ────────────────────────────────────────────────────────────────────

class TransitScreen extends ConsumerStatefulWidget {
  const TransitScreen({super.key});

  @override
  ConsumerState<TransitScreen> createState() => _TransitScreenState();
}

class _TransitScreenState extends ConsumerState<TransitScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tab;
  String _search = '';

  static const _busColor   = Color(0xFFFF8F00);
  static const _buggyColor = AppColors.primary;

  GoRouter? _goRouter;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
    WidgetsBinding.instance.addObserver(this);
    // Load stops from backend
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(transitProvider.notifier).loadStops();
      ref.read(transitProvider.notifier).checkActiveTrip();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Register once — refreshes active trip on every in-app navigation event
    // (e.g. returning from active trip screen after starting or ending a trip).
    if (_goRouter == null) {
      _goRouter = GoRouter.of(context);
      _goRouter!.routerDelegate.addListener(_onRouteChanged);
    }
  }

  void _onRouteChanged() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(transitProvider.notifier).checkActiveTrip();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(transitProvider.notifier).checkActiveTrip();
    }
  }

  @override
  void dispose() {
    _goRouter?.routerDelegate.removeListener(_onRouteChanged);
    WidgetsBinding.instance.removeObserver(this);
    _tab.dispose();
    super.dispose();
  }

  Color get _accent => _tab.index == 0 ? _buggyColor : _busColor;

  List<TransitStopModel> get _filtered {
    final transitState = ref.read(transitProvider);
    final base = _tab.index == 0 ? transitState.buggyStops : transitState.busStops;
    List<TransitStopModel> result;
    if (_search.isEmpty) {
      result = base;
    } else {
      final q = _search.toLowerCase();
      result = base
          .where((s) =>
              s.name.toLowerCase().contains(q) ||
              s.route.toLowerCase().contains(q))
          .toList();
    }
    // Show at most 7 nearest stops
    return result.length > 7 ? result.sublist(0, 7) : result;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkSurface : const Color(0xFFF2F5F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, isDark),
            _buildSearch(isDark),
            _buildTabBar(isDark),
            Expanded(child: _buildList(isDark)),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, bool isDark) {
    final isBus = _tab.index == 1;
    final transitState = ref.watch(transitProvider);
    final count = isBus ? transitState.busStops.length : transitState.buggyStops.length;
    final subtitle = isBus
        ? 'City & campus bus network'
        : 'On-demand golf buggy service';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 18.h),
      child: Row(
        children: [
          // Back
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
                  'Bus & Buggy',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.white : AppColors.grey900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2.h),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    subtitle,
                    key: ValueKey(isBus),
                    style:
                        TextStyle(fontSize: 12.sp, color: AppColors.grey500),
                  ),
                ),
              ],
            ),
          ),
          // Stops badge
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding:
                EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6.w,
                  height: 6.w,
                  decoration: BoxDecoration(
                      color: _accent, shape: BoxShape.circle),
                ),
                SizedBox(width: 5.w),
                Text(
                  '$count stops',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: _accent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Search bar ─────────────────────────────────────────────────────────────

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
          onChanged: (v) {
            setState(() => _search = v);
            ref.read(transitProvider.notifier).loadStops(search: v.isEmpty ? null : v);
          },
          style: TextStyle(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: 'Search stops or routes…',
            hintStyle:
                TextStyle(fontSize: 14.sp, color: AppColors.grey500),
            prefixIcon: Icon(Icons.search_rounded,
                size: 20.w, color: AppColors.grey400),
            suffixIcon: _search.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      setState(() => _search = '');
                      ref.read(transitProvider.notifier).loadStops();
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
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 10.h),
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
            color: _accent,
            borderRadius: BorderRadius.circular(13.r),
            boxShadow: [
              BoxShadow(
                color: _accent.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.grey500,
          labelStyle: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w500),
          padding: EdgeInsets.all(4.w),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.airport_shuttle_rounded, size: 16.w),
                  SizedBox(width: 7.w),
                  const Text('Buggy'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.directions_bus_rounded, size: 16.w),
                  SizedBox(width: 7.w),
                  const Text('Bus'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Stop list ─────────────────────────────────────────────────────────────

  Widget _buildList(bool isDark) {
    final stops = _filtered;
    final transitState = ref.watch(transitProvider);
    final activeTrip = transitState.activeTrip;

    if (transitState.isLoading) {
      return Center(
        child: CircularProgressIndicator(color: _accent),
      );
    }

    if (stops.isEmpty && activeTrip == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded,
                size: 48.w, color: AppColors.grey300),
            SizedBox(height: 12.h),
            Text('No stops found',
                style:
                    TextStyle(fontSize: 15.sp, color: AppColors.grey500)),
          ],
        ),
      );
    }

    final hasActive = activeTrip != null;
    final itemCount = stops.length + (hasActive ? 1 : 0);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: ListView.builder(
        key: ValueKey(_tab.index),
        padding: EdgeInsets.fromLTRB(20.w, 2.h, 20.w, 32.h),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          // First item: active trip card (if any)
          if (hasActive && i == 0) {
            return Padding(
              padding: EdgeInsets.only(bottom: 14.h),
              child: _ActiveTripCard(
                  trip: activeTrip!,
                  isDark: isDark,
                  onReturn: () {
                    ref.read(transitProvider.notifier).checkActiveTrip();
                  }),
            );
          }
          final stopIdx = hasActive ? i - 1 : i;
          if (stopIdx >= stops.length) return const SizedBox.shrink();
          return Padding(
            padding: EdgeInsets.only(bottom: 14.h),
            child: _StopCard(
              stop: stops[stopIdx],
              isDark: isDark,
              accentColor: _accent,
              activeTrip: activeTrip,
              onReturn: () {
                ref.read(transitProvider.notifier).checkActiveTrip();
              },
            ),
          );
        },
      ),
    );
  }
}

// ── Insufficient balance dialog (transit) ─────────────────────────────────────

void _showTransitInsufficientBalance(BuildContext context, double balance) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bottomPad = MediaQuery.of(context).padding.bottom;
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomPad + 16.h),
      padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 8.h),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A2030) : Colors.white,
        borderRadius: BorderRadius.circular(28.r),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36.w, height: 4.h,
            decoration: BoxDecoration(
              color: isDark ? AppColors.grey700 : AppColors.grey300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 20.h),
          Container(
            width: 62.w, height: 62.w,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(Icons.account_balance_wallet_rounded,
                size: 28.w, color: AppColors.error),
          ),
          SizedBox(height: 14.h),
          Text(
            'Insufficient Balance',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.grey900,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'You need an active subscription or at least ₹300 to board a bus or buggy.\nCurrent balance: ₹${balance.toStringAsFixed(0)}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.sp, color: AppColors.grey500, height: 1.5),
          ),
          SizedBox(height: 22.h),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.push('/wallet');
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primaryDark, AppColors.primary],
                ),
                borderRadius: BorderRadius.circular(16.r),
              ),
              alignment: Alignment.center,
              child: Text(
                'Top Up Wallet',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: AppColors.grey500),
            child: Text('Cancel', style: TextStyle(fontSize: 13.sp)),
          ),
          SizedBox(height: 4.h),
        ],
      ),
    ),
  );
}

// ── Active Trip Card ──────────────────────────────────────────────────────────

class _ActiveTripCard extends StatelessWidget {
  final TransitTripModel trip;
  final bool isDark;
  final VoidCallback onReturn;
  const _ActiveTripCard({required this.trip, required this.isDark, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final isBuggy = trip.type == 'buggy';
    final color =
        isBuggy ? AppColors.primary : const Color(0xFFFF8F00);
    final icon = isBuggy
        ? Icons.airport_shuttle_rounded
        : Icons.directions_bus_rounded;
    final label = isBuggy ? 'Buggy' : 'Bus';

    return GestureDetector(
      onTap: () => context.push(
          '/transit/active',
          extra: {
            'tripId': trip.id,
            'stopName': trip.stopName,
            'type': trip.type,
            'route': trip.route,
            'vehicleName': trip.vehicleName,
            'vehicleNumber': trip.vehicleNumber,
            'vehicleImageUrl': trip.vehicleImageUrl ?? '',
            'startTime': trip.startTime,
          }).then((_) => onReturn()),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
              color: color.withValues(alpha: 0.35), width: 1.5),
        ),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
        child: Row(
          children: [
            Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 22.w),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'ACTIVE TRIP',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    trip.stopName,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.white : AppColors.grey900,
                    ),
                  ),
                  if (trip.route.isNotEmpty) ...[
                    SizedBox(height: 2.h),
                    Text(
                      trip.route,
                      style: TextStyle(
                          fontSize: 11.sp, color: AppColors.grey500),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 16.w, color: color),
          ],
        ),
      ),
    );
  }
}

// ── Stop Card ─────────────────────────────────────────────────────────────────

class _StopCard extends StatelessWidget {
  final TransitStopModel stop;
  final bool isDark;
  final Color accentColor;
  final TransitTripModel? activeTrip;
  final VoidCallback onReturn;
  const _StopCard(
      {required this.stop,
      required this.isDark,
      required this.accentColor,
      this.activeTrip,
      required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final freeSeats  = stop.capacityTotal - stop.capacityOccupied;
    final occupancy  = stop.capacityTotal > 0 ? stop.capacityOccupied / stop.capacityTotal : 0.0;
    final occColor   = occupancy > 0.8
        ? AppColors.error
        : occupancy > 0.5
            ? AppColors.warning
            : AppColors.success;

    final isReady  = stop.eta == 'Ready';
    final etaColor = isReady ? AppColors.success : accentColor;
    final etaNum   = isReady ? '' : stop.eta.replaceAll(' min', '');

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Top row ────────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 14.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Route-type circle badge
                Container(
                  width: 50.w,
                  height: 50.w,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        stop.type == 'bus'
                            ? Icons.directions_bus_rounded
                            : Icons.airport_shuttle_rounded,
                        color: accentColor,
                        size: 20.w,
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        stop.routeShort,
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w900,
                          color: accentColor,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 12.w),

                // Name + route + distance
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        stop.name,
                        style: TextStyle(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.w800,
                          color: isDark ? AppColors.white : AppColors.grey900,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        stop.route,
                        style: TextStyle(
                            fontSize: 12.sp, color: AppColors.grey500),
                      ),
                      SizedBox(height: 7.h),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded,
                              size: 12.w, color: AppColors.grey400),
                          SizedBox(width: 3.w),
                          Text(
                            stop.distance,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.grey400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // ETA pill
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: etaColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isReady ? 'GO' : etaNum,
                        style: TextStyle(
                          fontSize: isReady ? 16.sp : 22.sp,
                          fontWeight: FontWeight.w900,
                          color: etaColor,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        isReady ? 'Now' : 'min',
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: etaColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Divider ────────────────────────────────────────────────
          Divider(
            height: 1,
            thickness: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),

          // ── Capacity row ───────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.event_seat_rounded,
                        size: 13.w, color: occColor),
                    SizedBox(width: 5.w),
                    Text(
                      '$freeSeats of ${stop.capacityTotal} seats free',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: occColor,
                      ),
                    ),
                    const Spacer(),
                  ],
                ),
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: occupancy,
                    minHeight: 6.h,
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    valueColor: AlwaysStoppedAnimation(occColor),
                  ),
                ),
              ],
            ),
          ),

          // ── Board button ────────────────────────────────────────────
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            child: GestureDetector(
              onTap: () {
                // If there's an active transit trip, notify user — do NOT restart
                if (activeTrip != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                          'You already have an active trip in progress.'),
                      action: SnackBarAction(
                        label: 'View Trip',
                        onPressed: () => context.push(
                          '/transit/active',
                          extra: {
                            'tripId': activeTrip!.id,
                            'stopName': activeTrip!.stopName,
                            'type': activeTrip!.type,
                            'route': activeTrip!.route,
                            'vehicleName': activeTrip!.vehicleName,
                            'vehicleNumber': activeTrip!.vehicleNumber,
                            'vehicleImageUrl': activeTrip!.vehicleImageUrl ?? '',
                            'startTime': activeTrip!.startTime,
                          },
                        ),
                      ),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  return;
                }
                // Allow boarding if:
                //  • user has an active subscription (sub coins remaining > 0), OR
                //  • wallet balance ≥ ₹300
                final hasSubscription = LocalStorage.getSubCoinsRemaining() > 0;
                final balance = LocalStorage.getWalletBalance();
                if (!hasSubscription && balance < 300) {
                  _showTransitInsufficientBalance(context, balance);
                  return;
                }
                context.push(
                  '/transit/board',
                  extra: {
                    'stopId': stop.id,
                    'vehicleId': stop.vehicleId,
                    'stopName': stop.name,
                    'type': stop.type,
                    'route': stop.route,
                    'vehicleName': stop.vehicleName,
                    'vehicleNumber': stop.vehicleNumber,
                    'vehicleImageUrl': stop.vehicleImageUrl ?? '',
                  },
                ).then((_) => onReturn());
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(14.r),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.qr_code_scanner_rounded,
                        color: Colors.white, size: 18.w),
                    SizedBox(width: 8.w),
                    Text(
                      'Scan to Board',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
