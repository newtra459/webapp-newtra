import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../trips/data/models/trip_model.dart';
import '../../../trips/presentation/providers/trips_provider.dart';
import '../providers/transit_provider.dart';

// ── Active Trip Screen ────────────────────────────────────────────────────────

class TransitActiveTripScreen extends ConsumerStatefulWidget {
  final String tripId;
  final String stopName;
  final String transitType; // 'bus' | 'buggy'
  final String route;
  final String vehicleName;
  final String vehicleNumber;
  final String vehicleImageUrl;
  final String startTime;

  const TransitActiveTripScreen({
    super.key,
    this.tripId = '',
    required this.stopName,
    required this.transitType,
    required this.route,
    this.vehicleName = '',
    this.vehicleNumber = '',
    this.vehicleImageUrl = '',
    this.startTime = '',
  });

  @override
  ConsumerState<TransitActiveTripScreen> createState() =>
      _TransitActiveTripScreenState();
}

class _TransitActiveTripScreenState extends ConsumerState<TransitActiveTripScreen>
    with TickerProviderStateMixin {
  late final Timer _timer;
  int _elapsedSeconds = 0;
  String _tripId = '';

  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  Color get _typeColor => widget.transitType == 'buggy'
      ? AppColors.primary
      : const Color(0xFFFF8F00);

  IconData get _typeIcon => widget.transitType == 'buggy'
      ? Icons.airport_shuttle_rounded
      : Icons.directions_bus_rounded;

  String get _vehicleLabel =>
      widget.transitType == 'buggy' ? 'Buggy' : 'Bus';

  int get _xpEarned => 5 + (_elapsedSeconds ~/ 60);

  String get _elapsed {
    final m = _elapsedSeconds ~/ 60;
    final s = _elapsedSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatTripDate() {
    final parsed = DateTime.tryParse(widget.startTime);
    final dt = parsed?.toLocal() ?? DateTime.now();
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String _formatClockTime(String raw, {String fallback = '—'}) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return fallback;
    final dt = parsed.toLocal();
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $ampm';
  }

  Future<String> _resolveDropOffStopName() async {
    final state = ref.read(transitProvider);
    final stops = widget.transitType == 'buggy' ? state.buggyStops : state.busStops;
    if (stops.isEmpty) return widget.stopName;

    try {
      final position = await Geolocator.getCurrentPosition();
      double nearestDistance = double.infinity;
      String nearestName = widget.stopName;

      for (final stop in stops) {
        if (stop.lat == 0 && stop.lng == 0) continue;
        final distance = Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          stop.lat,
          stop.lng,
        );
        if (distance < nearestDistance) {
          nearestDistance = distance;
          nearestName = stop.name;
        }
      }

      return nearestName;
    } catch (_) {
      return widget.stopName;
    }
  }

  void _upsertCompletedTrip({
    required String destinationStop,
    required double fare,
    required int xpEarned,
  }) {
    ref.read(tripsProvider.notifier).upsertLocalTrip(
          TripModel(
            id: _tripId.isEmpty
                ? 'transit-${DateTime.now().millisecondsSinceEpoch}'
                : _tripId,
            date: _formatTripDate(),
            type: widget.transitType,
            from: widget.stopName,
            to: destinationStop,
            distance: '—',
            duration: _elapsed,
            startTime: _formatClockTime(widget.startTime),
            endTime: _formatClockTime(DateTime.now().toIso8601String()),
            co2: '0 kg',
            paymentType: fare > 0 ? 'paid' : 'subscription',
            price: '₹${fare.toStringAsFixed(2)}',
            coins: xpEarned,
            vehicle: widget.vehicleName.isEmpty ? _vehicleLabel : widget.vehicleName,
            routeNumber: widget.transitType == 'bus'
                ? (widget.route.isEmpty ? widget.vehicleNumber : widget.route)
                : null,
            buggyNumber: widget.transitType == 'buggy' ? widget.vehicleNumber : null,
          ),
        );
  }

  @override
  void initState() {
    super.initState();
    _tripId = widget.tripId;
    final activeTrip = ref.read(transitProvider).activeTrip;
    if (_tripId.isEmpty && activeTrip != null) {
      _tripId = activeTrip.id;
    }
    final startTimeRaw =
        widget.startTime.isNotEmpty ? widget.startTime : (activeTrip?.startTime ?? '');
    final parsedStartTime = DateTime.tryParse(startTimeRaw);
    if (parsedStartTime != null) {
      _elapsedSeconds = DateTime.now()
          .difference(parsedStartTime.toLocal())
          .inSeconds
          .clamp(0, 86400);
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsedSeconds++);
    });
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _timer.cancel();
    _pulseCtrl.dispose();
    super.dispose();
  }

  void _endTrip() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _EndTripConfirmSheet(
        vehicleLabel: _vehicleLabel,
        vehicleName: widget.vehicleName,
        vehicleNumber: widget.vehicleNumber,
        vehicleImageUrl: widget.vehicleImageUrl,
        typeColor: _typeColor,
        typeIcon: _typeIcon,
        elapsedSeconds: _elapsedSeconds,
        stopName: widget.stopName,
        onConfirmed: () async {
          Navigator.pop(context); // close confirm sheet
          _timer.cancel();

          // Call backend to end trip
          double fare = 0;
          int xp = _xpEarned;
          final destinationStop = await _resolveDropOffStopName();
          if (_tripId.isNotEmpty) {
            final trip = await ref.read(transitProvider.notifier).endTrip(_tripId);
            if (trip != null) {
              fare = trip.fare ?? 0;
              xp = trip.xpEarned;
            }
          }

          _upsertCompletedTrip(
            destinationStop: destinationStop,
            fare: fare,
            xpEarned: xp,
          );
          // Refresh trips so the completed transit trip appears in My Trips
          ref.read(tripsProvider.notifier).refresh();
          _showTripSummary(fare: fare, xpEarned: xp);
        },
      ),
    );
  }

  void _showTripSummary({double fare = 0, int xpEarned = 0}) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TripSummarySheet(
        vehicleLabel: _vehicleLabel,
        vehicleName: widget.vehicleName,
        vehicleNumber: widget.vehicleNumber,
        vehicleImageUrl: widget.vehicleImageUrl,
        stopName: widget.stopName,
        route: widget.route,
        typeColor: _typeColor,
        typeIcon: _typeIcon,
        durationSeconds: _elapsedSeconds,
        xpEarned: xpEarned,
        fare: fare,
        onDone: () {
          Navigator.pop(context);
          context.pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkSurface : AppColors.grey100;
    final cardBg = isDark ? AppColors.darkCard : AppColors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (!didPop) context.pop();
        },
        child: Scaffold(
          backgroundColor: bg,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────────
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 16.w,
                            color: isDark ? Colors.white : AppColors.grey900,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Trip in Progress',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : AppColors.grey900,
                              ),
                            ),
                            Text(
                              '$_vehicleLabel · ${widget.route}',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: AppColors.grey500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Live pulse badge
                      AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (context, _) => Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 5.h),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(
                                alpha: 0.10 + _pulseAnim.value * 0.08),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                                color: AppColors.success.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6.w,
                                height: 6.w,
                                decoration: BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                'LIVE',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  // ── Timer card ──────────────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 28.h),
                    decoration: BoxDecoration(
                      color: _typeColor,
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: _typeColor.withValues(alpha: 0.35),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Duration',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.75),
                            letterSpacing: 0.8,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          _elapsed,
                          style: TextStyle(
                            fontSize: 52.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'mm : ss',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.white.withValues(alpha: 0.50),
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 16.h),

                  // ── Stats row ───────────────────────────────────────────
                  Row(
                    children: [
                      _statCard(
                        icon: Icons.location_on_rounded,
                        label: 'Boarded At',
                        value: widget.stopName,
                        isDark: isDark,
                        cardBg: cardBg,
                        iconColor: _typeColor,
                      ),
                      SizedBox(width: 12.w),
                      _statCard(
                        icon: Icons.star_rounded,
                        label: 'XP Earned',
                        value: '+$_xpEarned XP',
                        isDark: isDark,
                        cardBg: cardBg,
                        iconColor: const Color(0xFFFFB300),
                      ),
                    ],
                  ),

                  SizedBox(height: 12.h),

                  // ── Vehicle info card ───────────────────────────────────
                  if (widget.vehicleName.isNotEmpty || widget.vehicleNumber.isNotEmpty)
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(14.w),
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: _typeColor.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Vehicle image or icon
                          Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              color: _typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: widget.vehicleImageUrl.isNotEmpty
                                ? Image.network(
                                    widget.vehicleImageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      _typeIcon,
                                      size: 24.w,
                                      color: _typeColor,
                                    ),
                                  )
                                : Icon(_typeIcon, size: 24.w, color: _typeColor),
                          ),
                          SizedBox(width: 14.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (widget.vehicleName.isNotEmpty)
                                  Text(
                                    widget.vehicleName,
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppColors.grey900,
                                    ),
                                  ),
                                if (widget.vehicleNumber.isNotEmpty)
                                  Text(
                                    widget.vehicleNumber,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: _typeColor,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: EdgeInsets.symmetric(
                                horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              'On Board',
                              style: TextStyle(
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w700,
                                color: AppColors.success,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // ── Payment info card ───────────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16.r),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.w),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Icon(Icons.card_membership_rounded,
                              color: AppColors.success, size: 20.w),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subscription Plan',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.grey900,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                'This ride is covered by your active plan',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: AppColors.grey500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '₹0',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // ── End Trip button ─────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54.h,
                    child: ElevatedButton(
                      onPressed: _endTrip,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.stop_circle_outlined, size: 22.w),
                          SizedBox(width: 10.w),
                          Text(
                            'End Trip',
                            style: TextStyle(
                                fontSize: 16.sp, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
    required Color cardBg,
    required Color iconColor,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20.w, color: iconColor),
            SizedBox(height: 8.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.grey900,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 2.h),
            Text(
              label,
              style: TextStyle(fontSize: 10.sp, color: AppColors.grey500),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trip Summary Sheet ────────────────────────────────────────────────────────

class _TripSummarySheet extends StatelessWidget {
  final String vehicleLabel;
  final String vehicleName;
  final String vehicleNumber;
  final String vehicleImageUrl;
  final String stopName;
  final String route;
  final Color typeColor;
  final IconData typeIcon;
  final int durationSeconds;
  final int xpEarned;
  final double fare;
  final VoidCallback onDone;

  const _TripSummarySheet({
    required this.vehicleLabel,
    required this.stopName,
    required this.route,
    required this.typeColor,
    required this.typeIcon,
    required this.durationSeconds,
    required this.xpEarned,
    required this.onDone,
    this.fare = 0,
    this.vehicleName = '',
    this.vehicleNumber = '',
    this.vehicleImageUrl = '',
  });

  String get _durationStr {
    final m = durationSeconds ~/ 60;
    final s = durationSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.white;
    final subBg = isDark ? AppColors.darkElevated : AppColors.grey100;
    final divider = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.07);

    return Container(
      padding: EdgeInsets.fromLTRB(24.w, 12.h, 24.w, 36.h),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),

            // Vehicle icon or image
            Container(
              width: 68.w,
              height: 68.w,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              clipBehavior: Clip.antiAlias,
              child: vehicleImageUrl.isNotEmpty
                  ? Image.network(
                      vehicleImageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          Icon(typeIcon, size: 34.w, color: typeColor),
                    )
                  : Icon(typeIcon, size: 34.w, color: typeColor),
            ),
            SizedBox(height: 12.h),

            Text(
              'Trip Complete!',
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : AppColors.grey900,
              ),
            ),
            SizedBox(height: 4.h),
            // Vehicle name + number
            if (vehicleName.isNotEmpty || vehicleNumber.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      vehicleName.isNotEmpty ? vehicleName : vehicleLabel,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.grey900,
                      ),
                    ),
                    if (vehicleNumber.isNotEmpty) ...[
                      Text(
                        '  ·  ',
                        style: TextStyle(
                            fontSize: 13.sp, color: AppColors.grey400),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: typeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          vehicleNumber,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                            color: typeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            Text(
              '$vehicleLabel · $route',
              style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
            ),

            SizedBox(height: 20.h),

            // ── Stats row ──────────────────────────────────────────────
            Container(
              padding:
                  EdgeInsets.symmetric(vertical: 16.h, horizontal: 12.w),
              decoration: BoxDecoration(
                color: subBg,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summaryItem(
                    Icons.timer_rounded,
                    _durationStr,
                    'Duration',
                    isDark,
                  ),
                  Container(width: 1, height: 36.h, color: divider),
                  _summaryItem(
                    Icons.location_on_rounded,
                    stopName,
                    'Boarded At',
                    isDark,
                    iconColor: typeColor,
                  ),
                  Container(width: 1, height: 36.h, color: divider),
                  _summaryItem(
                    Icons.star_rounded,
                    '+$xpEarned XP',
                    'XP Earned',
                    isDark,
                    iconColor: const Color(0xFFFFB300),
                  ),
                ],
              ),
            ),

            SizedBox(height: 14.h),

            // ── Payment breakdown ──────────────────────────────────────
            Container(
              decoration: BoxDecoration(
                color: subBg,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                children: [
                  _payRow(
                    'Base Fare',
                    fare > 0 ? '₹5.00' : 'Covered',
                    isDark,
                    divider,
                    valueColor: fare > 0 ? null : AppColors.success,
                  ),
                  Divider(height: 1, color: divider),
                  _payRow(
                    'Per Minute Charge',
                    fare > 0 ? '₹${(fare - 5).clamp(0, double.infinity).toStringAsFixed(2)}' : 'Covered',
                    isDark,
                    divider,
                    valueColor: fare > 0 ? null : AppColors.success,
                  ),
                  Divider(height: 1, color: divider),
                  _payRow(
                    fare > 0 ? 'Payment Method' : 'Subscription Discount',
                    fare > 0 ? 'Wallet' : '–100%',
                    isDark,
                    divider,
                    valueColor: fare > 0 ? AppColors.warning : AppColors.success,
                  ),
                  Divider(height: 1, color: divider),
                  Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 14.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Total Charged',
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color:
                                  isDark ? Colors.white : AppColors.grey900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          '₹${fare.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w900,
                            color: fare > 0 ? AppColors.warning : AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 10.h),

            // Subscription/wallet note
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: (fare > 0 ? AppColors.warning : AppColors.success).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                    color: (fare > 0 ? AppColors.warning : AppColors.success).withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  Icon(fare > 0 ? Icons.account_balance_wallet_rounded : Icons.card_membership_rounded,
                      color: fare > 0 ? AppColors.warning : AppColors.success, size: 16.w),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      fare > 0
                          ? '₹${fare.toStringAsFixed(2)} charged to your wallet'
                          : 'Ride covered by your Subscription Plan',
                      style: TextStyle(
                          fontSize: 11.sp, color: fare > 0 ? AppColors.warning : AppColors.success),
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 20.h),

            // Done button
            SizedBox(
              width: double.infinity,
              height: 52.h,
              child: ElevatedButton(
                onPressed: onDone,
                style: ElevatedButton.styleFrom(
                  backgroundColor: typeColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                ),
                child: Text(
                  'Back to Transit',
                  style: TextStyle(
                      fontSize: 15.sp, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(
    IconData icon,
    String value,
    String label,
    bool isDark, {
    Color? iconColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18.w, color: iconColor ?? AppColors.grey500),
          SizedBox(height: 5.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.grey900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 9.sp, color: AppColors.grey500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _payRow(
    String label,
    String value,
    bool isDark,
    Color divider, {
    Color? valueColor,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                color: isDark ? AppColors.grey300 : AppColors.grey600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10.w),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
              color: valueColor ??
                  (isDark ? Colors.white : AppColors.grey900),
            ),
          ),
        ],
      ),
    );
  }
}

// ── End Trip Confirmation Sheet ───────────────────────────────────────────────

class _EndTripConfirmSheet extends StatefulWidget {
  final String vehicleLabel;
  final String vehicleName;
  final String vehicleNumber;
  final String vehicleImageUrl;
  final Color typeColor;
  final IconData typeIcon;
  final int elapsedSeconds;
  final String stopName;
  final VoidCallback onConfirmed;

  const _EndTripConfirmSheet({
    required this.vehicleLabel,
    required this.typeColor,
    required this.typeIcon,
    required this.elapsedSeconds,
    required this.stopName,
    required this.onConfirmed,
    this.vehicleName = '',
    this.vehicleNumber = '',
    this.vehicleImageUrl = '',
  });

  @override
  State<_EndTripConfirmSheet> createState() => _EndTripConfirmSheetState();
}

class _EndTripConfirmSheetState extends State<_EndTripConfirmSheet> {
  double _drag = 0;

  String get _elapsed {
    final m = widget.elapsedSeconds ~/ 60;
    final s = widget.elapsedSeconds % 60;
    if (m == 0) return '${s}s';
    return '${m}m ${s}s';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxDrag = MediaQuery.of(context).size.width - 160.w;
    final progress = (_drag / maxDrag).clamp(0.0, 1.0);

    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 32.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(32.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.22),
            blurRadius: 30,
            offset: const Offset(0, -10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top accent bar
          Container(
            height: 5.h,
            decoration: BoxDecoration(
              color: AppColors.error,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(32.r)),
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 24.h),
            child: Column(
              children: [
                // Handle
                Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkElevated
                        : AppColors.grey200,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                SizedBox(height: 22.h),

                // Icon
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 80.w,
                      height: 80.w,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 60.w,
                      height: 60.w,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Icon(Icons.flag_rounded,
                          size: 28.w, color: Colors.white),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),

                Text(
                  'End Your Trip?',
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.white : AppColors.grey900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  'Your trip stats will be saved and you\'ll\nsee a full summary.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.grey500,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 20.h),

                // Vehicle name + number card
                if (widget.vehicleName.isNotEmpty ||
                    widget.vehicleNumber.isNotEmpty)
                  Container(
                    margin: EdgeInsets.only(bottom: 16.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: 14.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: widget.typeColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                          color: widget.typeColor.withValues(alpha: 0.20)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 40.w,
                          height: 40.w,
                          decoration: BoxDecoration(
                            color: widget.typeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: widget.vehicleImageUrl.isNotEmpty
                              ? Image.network(
                                  widget.vehicleImageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    widget.typeIcon,
                                    size: 20.w,
                                    color: widget.typeColor,
                                  ),
                                )
                              : Icon(widget.typeIcon,
                                  size: 20.w, color: widget.typeColor),
                        ),
                        SizedBox(width: 12.w),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.vehicleName.isNotEmpty)
                              Text(
                                widget.vehicleName,
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? AppColors.white
                                      : AppColors.grey900,
                                ),
                              ),
                            if (widget.vehicleNumber.isNotEmpty)
                              Text(
                                widget.vehicleNumber,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w700,
                                  color: widget.typeColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Quick stats
                Container(
                  padding: EdgeInsets.symmetric(
                      vertical: 14.h, horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkElevated
                        : AppColors.grey50,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.grey200,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _quickStat(Icons.timer_rounded, _elapsed,
                          'Duration', widget.typeColor, isDark),
                      Container(
                          width: 1,
                          height: 36.h,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.grey200),
                      _quickStat(Icons.location_on_rounded,
                          widget.stopName, 'Boarded At', widget.typeColor, isDark),
                      Container(
                          width: 1,
                          height: 36.h,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.grey200),
                      _quickStat(Icons.star_rounded,
                          '+${5 + widget.elapsedSeconds ~/ 60} XP',
                          'XP Earned', const Color(0xFFFFB300), isDark),
                    ],
                  ),
                ),
                SizedBox(height: 24.h),

                // Slide to end
                Container(
                  height: 60.h,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(30.r),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.18),
                      width: 1,
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Progress fill
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(30.r),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: FractionallySizedBox(
                              widthFactor: progress,
                              child: Container(
                                color: AppColors.error
                                    .withValues(alpha: 0.12),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Label
                      Center(
                        child: AnimatedOpacity(
                          opacity: progress > 0.3 ? 0.0 : 1.0,
                          duration: const Duration(milliseconds: 150),
                          child: Text(
                            'Slide to end trip',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error
                                  .withValues(alpha: 0.55),
                            ),
                          ),
                        ),
                      ),
                      // Thumb
                      Positioned(
                        left: 4 + _drag,
                        top: 5,
                        bottom: 5,
                        child: GestureDetector(
                          onHorizontalDragUpdate: (d) {
                            setState(() {
                              _drag =
                                  (_drag + d.delta.dx).clamp(0.0, maxDrag);
                            });
                          },
                          onHorizontalDragEnd: (_) {
                            if (_drag >= maxDrag * 0.75) {
                              widget.onConfirmed();
                            } else {
                              setState(() => _drag = 0);
                            }
                          },
                          child: Container(
                            width: 50.w,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              borderRadius: BorderRadius.circular(25.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.error
                                      .withValues(alpha: 0.45),
                                  blurRadius: 12,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Icon(Icons.double_arrow_rounded,
                                size: 22.w, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 14.h),

                // Keep riding button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkElevated
                          : AppColors.grey100,
                      borderRadius: BorderRadius.circular(16.r),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Keep Going',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? AppColors.grey300
                            : AppColors.grey600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickStat(IconData icon, String value, String label,
      Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 18.w, color: color),
          SizedBox(height: 5.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.grey900,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 9.sp, color: AppColors.grey500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
