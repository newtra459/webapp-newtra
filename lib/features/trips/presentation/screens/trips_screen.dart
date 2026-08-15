import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/trip_model.dart';
import '../providers/trips_provider.dart';

class TripsScreen extends ConsumerStatefulWidget {
  const TripsScreen({super.key});

  @override
  ConsumerState<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends ConsumerState<TripsScreen> {
  String? _activeFilter;

  static Map<String, dynamic> _tripToMap(TripModel t) => {
        'id': t.id,
        'date': t.date,
        'type': t.type,
        'from': t.from,
        'to': t.to,
        'distance': t.distance,
        'duration': t.duration,
        'startTime': t.startTime,
        'endTime': t.endTime,
        'calories': t.calories,
        'avgSpeed': t.avgSpeed,
        'elevation': t.elevation,
        'co2': t.co2,
        'paymentType': t.paymentType,
        'plan': t.plan,
        'price': t.price,
        'coins': t.coins,
        'vehicle': t.vehicle,
        'buggyNumber': t.buggyNumber,
        'routeNumber': t.routeNumber,
        'passengers': t.passengers,
        'stops': t.stops,
        'seat': t.seat,
        'startLat': t.startLat,
        'startLng': t.startLng,
        'endLat': t.endLat,
        'endLng': t.endLng,
      };

  List<Map<String, dynamic>> _getFiltered(List<Map<String, dynamic>> trips) {
    if (_activeFilter == null) return trips;
    if (_activeFilter == 'own_bike') {
      return trips.where((t) => t['paymentType'] == 'own_bike').toList();
    }
    return trips
        .where((t) =>
            t['type'] == _activeFilter && t['paymentType'] != 'own_bike')
        .toList();
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'bus':
        return Icons.directions_bus_rounded;
      case 'buggy':
        return Icons.airport_shuttle_rounded;
      default:
        return Icons.directions_bike_rounded;
    }
  }

  Color _typeColor(String type) {
    switch (type) {
      case 'bus':
        return const Color(0xFFFF8F00);
      case 'buggy':
        return AppColors.success;
      case 'own_bike':
        return const Color(0xFF1565C0);
      default:
        return AppColors.primary;
    }
  }

  Color _filterColor(String? filter) {
    switch (filter) {
      case 'bus':
        return const Color(0xFFFF8F00);
      case 'buggy':
        return AppColors.success;
      case 'own_bike':
        return const Color(0xFF1565C0);
      case 'cycle':
        return AppColors.primary;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsState = ref.watch(tripsProvider);
    final allTrips = tripsState.mergedTrips.map(_tripToMap).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trips = _getFiltered(allTrips);
    final headerBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final bg = isDark ? const Color(0xFF0D1117) : AppColors.grey50;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        body: Column(
          children: [
            _buildHeader(context, isDark, headerBg, allTrips),
            _buildFilterRow(isDark, headerBg),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () => ref.read(tripsProvider.notifier).refresh(),
                child: _TripsListView(
                trips: trips,
                isDark: isDark,
                typeIcon: _typeIcon,
                typeColor: _typeColor,
                onPaymentTap: (trip) =>
                    _showPaymentSheet(context, trip, isDark),
              ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, Color bg,
      List<Map<String, dynamic>> trips) {
    final totalKm = trips.fold<double>(0, (sum, t) {
      final d = (t['distance'] as String?)?.replaceAll(' km', '') ?? '0';
      return sum + (double.tryParse(d) ?? 0);
    });
    final totalCo2 = trips.fold<double>(0, (sum, t) {
      final c = (t['co2'] as String?)?.replaceAll(' kg', '') ?? '0';
      return sum + (double.tryParse(c) ?? 0);
    });

    return Container(
      color: bg,
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(8.w, 8.h, 16.w, 4.h),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18.w),
                    color: isDark ? Colors.white : AppColors.grey900,
                  ),
                  SizedBox(width: 2.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('My Trips',
                          style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.grey900)),
                      Text('${trips.length} trips recorded',
                          style: TextStyle(
                              fontSize: 12.sp, color: AppColors.grey500)),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 16.h),
              child: Row(
                children: [
                  _statPill(Icons.route_rounded, '${trips.length}', 'Trips',
                      AppColors.primary, isDark),
                  SizedBox(width: 10.w),
                  _statPill(Icons.straighten_rounded,
                      '${totalKm.toStringAsFixed(1)} km', 'Distance',
                      AppColors.info, isDark),
                  SizedBox(width: 10.w),
                  _statPill(Icons.eco_rounded,
                      '${totalCo2.toStringAsFixed(2)} kg', 'CO2 Saved',
                      AppColors.success, isDark),
                ],
              ),
            ),
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.06),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statPill(
      IconData icon, String value, String label, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14.w, color: color),
            SizedBox(width: 5.w),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.grey900),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                        fontSize: 9.sp,
                        color: isDark ? AppColors.grey500 : AppColors.grey600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow(bool isDark, Color bg) {
    final filters = [
      {'label': 'All', 'filter': null, 'icon': Icons.grid_view_rounded},
      {'label': 'Cycle', 'filter': 'cycle', 'icon': Icons.directions_bike_rounded},
      {'label': 'Own Bike', 'filter': 'own_bike', 'icon': Icons.directions_bike_rounded},
      {'label': 'Bus', 'filter': 'bus', 'icon': Icons.directions_bus_rounded},
      {'label': 'Buggy', 'filter': 'buggy', 'icon': Icons.airport_shuttle_rounded},
    ];

    return Container(
      color: bg,
      padding: EdgeInsets.fromLTRB(0, 10.h, 0, 12.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: filters.map((f) {
            final filter = f['filter'] as String?;
            final isActive = _activeFilter == filter;
            final color = _filterColor(filter);
            return Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: GestureDetector(
                onTap: () => setState(() => _activeFilter = filter),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding:
                      EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: isActive
                        ? color
                        : (isDark ? const Color(0xFF1E242C) : Colors.white),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: isActive
                          ? color
                          : (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.09)),
                    ),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.30),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        f['icon'] as IconData,
                        size: 13.w,
                        color: isActive
                            ? Colors.white
                            : (isDark
                                ? AppColors.grey400
                                : AppColors.grey500),
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        f['label'] as String,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight:
                              isActive ? FontWeight.w700 : FontWeight.w500,
                          color: isActive
                              ? Colors.white
                              : (isDark
                                  ? AppColors.grey400
                                  : AppColors.grey600),
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

  void _showPaymentSheet(
      BuildContext context, Map<String, dynamic> trip, bool isDark) {
    final isPaid = (trip['paymentType'] as String?) == 'paid';
    final plan = trip['plan'] as String? ?? 'Student Plan';
    final price = trip['price'] as String? ?? '₹0';
    final coins = trip['coins'] as int? ?? 0;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          margin: EdgeInsets.all(12.w),
          padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 32.h),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  margin: EdgeInsets.only(bottom: 16.h),
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              Text('Payment Details',
                  style: TextStyle(
                      fontSize: 17.sp, fontWeight: FontWeight.w700)),
              SizedBox(height: 16.h),
              _payRow(Icons.card_membership_rounded, 'Plan', plan,
                  AppColors.primary, isDark),
              SizedBox(height: 10.h),
              if (isPaid)
                _payRow(Icons.currency_rupee_rounded, 'Amount Charged',
                    price, AppColors.warning, isDark)
              else
                _payRow(Icons.check_circle_outline_rounded,
                    'Charged to Plan', 'Included', AppColors.success, isDark),
              SizedBox(height: 10.h),
              _payRow(
                Icons.toll_rounded,
                coins >= 0 ? 'Coins Earned' : 'Coins Used',
                coins >= 0 ? '+$coins MJ coins' : '${coins.abs()} MJ coins',
                coins >= 0 ? AppColors.success : AppColors.error,
                isDark,
              ),
              SizedBox(height: 16.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(
                    horizontal: 14.w, vertical: 12.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        size: 16.w, color: AppColors.primary),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        isPaid
                            ? 'This trip was charged to your wallet.'
                            : 'Covered under your $plan subscription.',
                        style: TextStyle(
                            fontSize: 12.sp,
                            color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _payRow(
      IconData icon, String label, String value, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 18.w, color: color),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(label,
              style: TextStyle(
                  fontSize: 13.sp,
                  color: isDark ? AppColors.grey400 : AppColors.grey600)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : AppColors.grey900)),
      ],
    );
  }
}

// ─── Trip list view ───────────────────────────────────────────────────────────

class _TripsListView extends StatelessWidget {
  final List<Map<String, dynamic>> trips;
  final bool isDark;
  final IconData Function(String) typeIcon;
  final Color Function(String) typeColor;
  final void Function(Map<String, dynamic>) onPaymentTap;

  const _TripsListView({
    required this.trips,
    required this.isDark,
    required this.typeIcon,
    required this.typeColor,
    required this.onPaymentTap,
  });

  @override
  Widget build(BuildContext context) {
    if (trips.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.route_outlined,
                  size: 36.w,
                  color: isDark ? AppColors.grey600 : AppColors.grey400),
            ),
            SizedBox(height: 16.h),
            Text('No trips here yet',
                style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.grey400 : AppColors.grey700)),
            SizedBox(height: 6.h),
            Text('Start a ride to see it here',
                style: TextStyle(
                    fontSize: 13.sp,
                    color: isDark ? AppColors.grey600 : AppColors.grey400)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 32.h),
      itemCount: trips.length,
      itemBuilder: (context, index) {
        final trip = trips[index];
        final showDate =
            index == 0 || trips[index]['date'] != trips[index - 1]['date'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDate) ...[
              if (index > 0) SizedBox(height: 10.h),
              _DateHeader(date: trip['date'] as String, isDark: isDark),
              SizedBox(height: 8.h),
            ],
            _TripCard(
              trip: trip,
              isDark: isDark,
              typeIcon: typeIcon,
              typeColor: typeColor,
              onPaymentTap: onPaymentTap,
            ),
            SizedBox(height: 10.h),
          ],
        );
      },
    );
  }
}

// ─── Date header ──────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  final String date;
  final bool isDark;
  const _DateHeader({required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          date.toUpperCase(),
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.grey500 : AppColors.grey500,
            letterSpacing: 1.2,
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.07)
                : Colors.black.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }
}

// ─── Trip card ────────────────────────────────────────────────────────────────

class _TripCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isDark;
  final IconData Function(String) typeIcon;
  final Color Function(String) typeColor;
  final void Function(Map<String, dynamic>) onPaymentTap;

  const _TripCard({
    required this.trip,
    required this.isDark,
    required this.typeIcon,
    required this.typeColor,
    required this.onPaymentTap,
  });

  @override
  Widget build(BuildContext context) {
    final type = trip['type'] as String;
    final isOwnBike = trip['paymentType'] == 'own_bike';
    final isCycle = type == 'cycle' && !isOwnBike;
    final color = isOwnBike ? const Color(0xFF1565C0) : typeColor(type);
    final accentLabel = isOwnBike
        ? 'Own Bike'
        : isCycle
            ? 'Cycle'
            : type == 'bus'
                ? 'Bus'
                : 'Buggy';
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;

    return GestureDetector(
      onTap: () => context.push('/trips/detail', extra: trip),
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.30)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left accent bar ──────────────────────────────────
                Container(width: 4.w, color: color),

                // ── Card content ─────────────────────────────────────
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 12.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Type pill + time + receipt icon
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 8.w, vertical: 3.h),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    typeIcon(isOwnBike ? 'own_bike' : type),
                                    size: 11.w,
                                    color: color,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(accentLabel,
                                      style: TextStyle(
                                          fontSize: 10.sp,
                                          fontWeight: FontWeight.w700,
                                          color: color)),
                                ],
                              ),
                            ),
                            const Spacer(),
                            Text(
                              trip['startTime'] as String? ?? '',
                              style: TextStyle(
                                  fontSize: 11.sp,
                                  color: isDark
                                      ? AppColors.grey500
                                      : AppColors.grey500),
                            ),
                            if (!isOwnBike) ...[
                              SizedBox(width: 8.w),
                              GestureDetector(
                                onTap: () => onPaymentTap(trip),
                                child: Icon(
                                  Icons.receipt_long_rounded,
                                  size: 16.w,
                                  color: AppColors.primary
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ],
                        ),

                        SizedBox(height: 12.h),

                        // Route: from → to
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 8.w,
                                  height: 8.w,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Container(
                                  width: 2,
                                  height: 22.h,
                                  margin: EdgeInsets.symmetric(vertical: 3.h),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        AppColors.primary,
                                        AppColors.error,
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(1.r),
                                  ),
                                ),
                                Container(
                                  width: 8.w,
                                  height: 8.w,
                                  decoration: const BoxDecoration(
                                    color: AppColors.error,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(width: 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    trip['from'] as String? ?? '',
                                    style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.grey900),
                                  ),
                                  SizedBox(height: 16.h),
                                  Text(
                                    trip['to'] as String? ?? '',
                                    style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.white
                                            : AppColors.grey900),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        SizedBox(height: 12.h),

                        Container(
                          height: 1,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        SizedBox(height: 10.h),

                        // Stats row
                        Wrap(
                          spacing: 16.w,
                          runSpacing: 4.h,
                          children: [
                            _statChip(Icons.straighten_rounded,
                                trip['distance'] as String? ?? '—', isDark),
                            _statChip(Icons.timer_outlined,
                                trip['duration'] as String? ?? '—', isDark),
                            if (isCycle || isOwnBike)
                              _statChip(
                                  Icons.local_fire_department_outlined,
                                  trip['calories'] as String? ?? '—',
                                  isDark),
                            _statChip(Icons.eco_outlined,
                                trip['co2'] as String? ?? '—', isDark),
                          ],
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
    );
  }

  Widget _statChip(IconData icon, String value, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 12.w,
            color: isDark ? AppColors.grey400 : AppColors.grey500),
        SizedBox(width: 3.w),
        Text(value,
            style: TextStyle(
                fontSize: 11.sp,
                color: isDark ? AppColors.grey400 : AppColors.grey500)),
      ],
    );
  }
}
