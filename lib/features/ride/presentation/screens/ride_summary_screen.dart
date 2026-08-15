import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:dio/dio.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/route_sanitizer.dart';
import '../../../../core/widgets/route_map_widget.dart';
import '../../../trips/data/models/trip_model.dart';
import '../../../trips/presentation/providers/trips_provider.dart';

class RideSummaryScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> rideData;
  const RideSummaryScreen({super.key, this.rideData = const {}});

  int get rideMode => rideData['rideMode'] as int? ?? 0;

  @override
  ConsumerState<RideSummaryScreen> createState() => _RideSummaryScreenState();
}

class _RideSummaryScreenState extends ConsumerState<RideSummaryScreen> {
  final GlobalKey<RouteMapWidgetState> _mapKey =
      GlobalKey<RouteMapWidgetState>();
  String _startLocationName = '';
  String _endLocationName = '';

  @override
  void initState() {
    super.initState();
    _syncCompletedTripAfterFrame(refreshTrips: true);
    _resolveLocationNames();
  }

  void _syncCompletedTripAfterFrame({bool refreshTrips = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (refreshTrips) {
        ref.read(tripsProvider.notifier).refresh();
      }
      _upsertCompletedTrip();
    });
  }

  Future<void> _resolveLocationNames() async {
    final points = _routePoints;
    if (points.isEmpty) return;

    final startPt = points.first;
    final endPt = points.last;

    final results = await Future.wait([
      _reverseGeocode(startPt.lat, startPt.lng),
      _reverseGeocode(endPt.lat, endPt.lng),
    ]);

    if (mounted) {
      setState(() {
        _startLocationName = results[0];
        _endLocationName = results[1];
      });
      _syncCompletedTripAfterFrame();
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final dio = Dio();
      final res = await dio.get(
        'https://nominatim.openstreetmap.org/reverse',
        queryParameters: {
          'lat': lat,
          'lon': lng,
          'format': 'json',
          'zoom': 16,
          'addressdetails': 1,
        },
        options: Options(headers: {'User-Agent': 'EV-App/1.0'}),
      );
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final data = res.data as Map<String, dynamic>;
        final addr = data['address'] as Map<String, dynamic>?;
        if (addr != null) {
          final name =
              addr['amenity'] ??
              addr['building'] ??
              addr['road'] ??
              addr['neighbourhood'] ??
              addr['suburb'] ??
              addr['village'] ??
              addr['town'] ??
              addr['city'] ??
              '';
          final area =
              addr['suburb'] ??
              addr['neighbourhood'] ??
              addr['city_district'] ??
              '';
          if (name.toString().isNotEmpty &&
              area.toString().isNotEmpty &&
              name != area) {
            return '$name, $area';
          }
          if (name.toString().isNotEmpty) return name.toString();
        }
        final display = data['display_name'] as String? ?? '';
        if (display.isNotEmpty) {
          final parts = display.split(',');
          return parts.take(2).join(',').trim();
        }
      }
    } catch (_) {}
    return '${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}';
  }

  // Helpers to read ride data with fallbacks
  int get _durationSec =>
      (widget.rideData['durationSeconds'] as num?)?.round() ?? 0;
  double get _reportedDistanceKm =>
      (widget.rideData['distanceKm'] as num?)?.toDouble() ?? 0.0;
  double get _routeDistanceKm {
    final segments = _routeSegments
        .map(
          (segment) =>
              segment.map((p) => LatLng(p.lat, p.lng)).toList(growable: false),
        )
        .toList(growable: false);
    return RouteSanitizer.distanceKm(segments);
  }

  bool get _reportedDistanceLooksInflated {
    final routeDistance = _routeDistanceKm;
    return routeDistance > 0 &&
        _reportedDistanceKm > routeDistance + 1.0 &&
        _reportedDistanceKm > routeDistance * 2.0;
  }

  double get _distanceKm =>
      _reportedDistanceLooksInflated ? _routeDistanceKm : _reportedDistanceKm;
  double get _avgSpeed {
    final reported = (widget.rideData['avgSpeed'] as num?)?.toDouble() ?? 0.0;
    if (!_reportedDistanceLooksInflated || _durationSec <= 0) return reported;
    return _distanceKm / (_durationSec / 3600.0);
  }

  double get _maxSpeed =>
      (widget.rideData['maxSpeed'] as num?)?.toDouble() ?? 0.0;
  int get _calories => (widget.rideData['calories'] as num?)?.round() ?? 0;
  int get _elevation => (widget.rideData['elevation'] as num?)?.round() ?? 0;
  double get _billTotal =>
      (widget.rideData['billTotal'] as num?)?.toDouble() ?? 0.0;
  double get _billBase =>
      (widget.rideData['billBaseFare'] as num?)?.toDouble() ?? 0.0;
  double get _billExtra =>
      (widget.rideData['billExtra'] as num?)?.toDouble() ?? 0;
  double get _billCancel =>
      (widget.rideData['billCancelFee'] as num?)?.toDouble() ?? 0;
  double get _billGst =>
      (widget.rideData['billGst'] as num?)?.toDouble() ?? 0.0;
  double get _billSubtotal =>
      (widget.rideData['billSubtotal'] as num?)?.toDouble() ?? 0.0;
  bool get _paidWithCoin => widget.rideData['paidWithCoin'] as bool? ?? false;
  int get _loyaltyCoin => widget.rideData['loyaltyCoinAwarded'] as int? ?? 0;
  String get _bikeId => widget.rideData['bikeId']?.toString() ?? '';
  bool get _isEBike => widget.rideData['isEBike'] as bool? ?? true;

  String get _startTimeFormatted {
    final ms = (widget.rideData['startTimeMs'] as num?)?.round();
    if (ms == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String get _endTimeFormatted {
    final ms = (widget.rideData['endTimeMs'] as num?)?.round();
    if (ms == null) return '—';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $ampm';
  }

  String get _headerDateString {
    final ms = (widget.rideData['startTimeMs'] as num?)?.round();
    if (ms == null) return '';
    final dt = DateTime.fromMillisecondsSinceEpoch(ms);
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}  •  $_startTimeFormatted';
  }

  String get _durationDisplay {
    final h = _durationSec ~/ 3600;
    final m = _durationSec ~/ 60;
    final s = _durationSec % 60;
    if (h > 0) {
      final mm = (_durationSec % 3600) ~/ 60;
      return '$h:${mm.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String get _rideTypeLabel {
    if (widget.rideMode == 1) return 'Personal Ride';
    return _isEBike ? 'E-Bike Ride' : 'Cycle Ride';
  }

  String get _dateLabel {
    final ms = (widget.rideData['startTimeMs'] as num?)?.round();
    final dt = ms != null
        ? DateTime.fromMillisecondsSinceEpoch(ms)
        : DateTime.now();
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
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
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  String get _distanceText => '${_distanceKm.toStringAsFixed(1)} km';
  String get _avgSpeedText => '${_avgSpeed.toStringAsFixed(1)} km/h';
  String get _caloriesText => '$_calories cal';
  String get _elevationText => '$_elevation m';
  String get _co2SavedText => '${(_distanceKm * 0.21).toStringAsFixed(2)} kg';
  String get _shareStatsTitle =>
      widget.rideMode == 1 ? 'FITNESS STATS' : 'RIDE STATS';

  String get _shareText {
    final lines = <String>[
      'Just completed $_rideTypeLabel on Newtra!',
      '',
      'Distance: $_distanceText',
      'Duration: $_durationDisplay',
      'Avg Speed: $_avgSpeedText',
      'Calories: $_caloriesText',
      'CO2 Saved: $_co2SavedText',
    ];

    if (_startLocationName.isNotEmpty) {
      lines.add('From: $_startLocationName');
    }
    if (_endLocationName.isNotEmpty) {
      lines.add('To: $_endLocationName');
    }

    lines.add('');
    lines.add('Track your rides on Newtra.');
    return lines.join('\n');
  }

  List<List<RoutePoint>> get _routeSegments {
    final rawSegments = widget.rideData['routeSegments'] as List?;
    if (rawSegments == null || rawSegments.isEmpty) return const [];

    final segments = <List<RoutePoint>>[];
    for (final segment in rawSegments) {
      if (segment is! List || segment.isEmpty) continue;
      final routeSegment = <RoutePoint>[];
      for (final point in segment) {
        final map = Map<String, dynamic>.from(point as Map);
        routeSegment.add(
          RoutePoint(
            (map['lat'] as num).toDouble(),
            (map['lng'] as num).toDouble(),
          ),
        );
      }
      if (routeSegment.isNotEmpty) {
        segments.add(routeSegment);
      }
    }
    return _sanitizeRoutePointSegments(segments);
  }

  List<RoutePoint> get _routePoints {
    if (_routeSegments.isNotEmpty) {
      return _routeSegments
          .expand((segment) => segment)
          .toList(growable: false);
    }

    final raw = widget.rideData['routePoints'] as List?;
    if (raw != null && raw.isNotEmpty) {
      final points = raw.map((p) {
        final m = Map<String, dynamic>.from(p as Map);
        return RoutePoint(
          (m['lat'] as num).toDouble(),
          (m['lng'] as num).toDouble(),
        );
      }).toList();
      return _sanitizeRoutePointSegments([
        points,
      ]).expand((segment) => segment).toList(growable: false);
    }
    return const [];
  }

  List<List<RoutePoint>> _sanitizeRoutePointSegments(
    List<List<RoutePoint>> segments,
  ) {
    final latLngSegments = segments
        .map(
          (segment) =>
              segment.map((p) => LatLng(p.lat, p.lng)).toList(growable: false),
        )
        .toList(growable: false);
    return RouteSanitizer.sanitizeSegments(latLngSegments)
        .map(
          (segment) => segment
              .map((point) => RoutePoint(point.latitude, point.longitude))
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  void _upsertCompletedTrip() {
    final tripId = widget.rideData['tripId']?.toString().trim() ?? '';
    if (tripId.isEmpty) return;

    final points = _routePoints;
    final startPoint = points.isNotEmpty ? points.first : null;
    final endPoint = points.isNotEmpty ? points.last : null;
    final fromLabel = _startLocationName.isNotEmpty
        ? _startLocationName
        : (startPoint != null
              ? '${startPoint.lat.toStringAsFixed(4)}, ${startPoint.lng.toStringAsFixed(4)}'
              : 'Ride start');
    final toLabel = _endLocationName.isNotEmpty
        ? _endLocationName
        : (endPoint != null
              ? '${endPoint.lat.toStringAsFixed(4)}, ${endPoint.lng.toStringAsFixed(4)}'
              : 'Ride end');

    ref
        .read(tripsProvider.notifier)
        .upsertLocalTrip(
          TripModel(
            id: tripId,
            date: _dateLabel,
            type: 'cycle',
            from: fromLabel,
            to: toLabel,
            distance: _distanceText,
            duration: _durationDisplay,
            startTime: _startTimeFormatted,
            endTime: _endTimeFormatted,
            calories: _caloriesText,
            avgSpeed: _avgSpeedText,
            elevation: _elevationText,
            co2: _co2SavedText,
            paymentType: widget.rideMode == 1
                ? 'own_bike'
                : (_paidWithCoin || _billTotal <= 0 ? 'subscription' : 'paid'),
            price: widget.rideMode == 0
                ? '₹${_billTotal.toStringAsFixed(2)}'
                : null,
            coins: _loyaltyCoin,
            vehicle: widget.rideMode == 1 ? 'Personal Ride' : 'Bike $_bikeId',
            startLat: startPoint?.lat,
            startLng: startPoint?.lng,
            endLat: endPoint?.lat,
            endLng: endPoint?.lng,
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.grey50,
      body: CustomScrollView(
        slivers: [
          // ── Hero header ────────────────────────────────────────────────
          SliverToBoxAdapter(child: _buildHeroHeader(context, isDark)),

          SliverPadding(
            padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 40.h),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                SizedBox(height: 20.h),

                // ── Route map ──────────────────────────────────────────
                _buildMapCard(isDark),
                SizedBox(height: 16.h),

                // ── Primary stats 2×3 grid ─────────────────────────────
                _buildPrimaryStats(isDark),
                SizedBox(height: 16.h),

                // ── Eco impact card ────────────────────────────────────
                _buildEcoCard(isDark),
                SizedBox(height: 16.h),

                // ── Route timeline card ────────────────────────────────
                _buildRouteCard(isDark),
                SizedBox(height: 16.h),

                // ── Bike info card (shared rides only) ─────────────────
                if (widget.rideMode == 0) ...[
                  _buildBikeInfoCard(isDark),
                  SizedBox(height: 16.h),
                ],

                // ── Price summary card ─────────────────────────────────
                if (widget.rideMode == 0) ...[
                  _buildPriceCard(isDark),
                  SizedBox(height: 16.h),
                ],

                // ── XP breakdown card ──────────────────────────────────
                _buildXpCard(isDark),
                SizedBox(height: 24.h),

                // ── Action buttons ─────────────────────────────────────
                _buildActions(context, isDark),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero header ──────────────────────────────────────────────────────────

  Widget _buildHeroHeader(BuildContext context, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF003D2A), const Color(0xFF001F15)]
              : [const Color(0xFF00643D), const Color(0xFF004A2D)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 28.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top bar ──────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => context.go('/home'),
                    child: Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 15.w,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                  SvgPicture.asset(AppAssets.fullLogoOnDark, height: 18.h),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await _shareRide();
                    },
                    child: Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.share_rounded,
                        size: 17.w,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // ── Completion badge + title ─────────────────────────
              Row(
                children: [
                  Container(
                    width: 52.w,
                    height: 52.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.flag_rounded,
                      size: 24.sp,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ride Complete!',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.w900,
                          color: AppColors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 3.h),
                      Text(
                        _headerDateString,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.white.withValues(alpha: 0.70),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 24.h),

              // ── Hero stats row ───────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _heroStat(_distanceKm.toStringAsFixed(1), 'km', 'Distance'),
                  _heroDivider(),
                  _heroStat(_durationDisplay, 'min', 'Duration'),
                  _heroDivider(),
                  _heroStat(_avgSpeed.toStringAsFixed(1), 'km/h', 'Avg Speed'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _heroStat(String value, String unit, String label) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.white,
                    height: 1,
                  ),
                ),
                SizedBox(width: 3.w),
                Padding(
                  padding: EdgeInsets.only(bottom: 3.h),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white.withValues(alpha: 0.70),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.white.withValues(alpha: 0.60),
              fontWeight: FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _heroDivider() {
    return Container(
      width: 1,
      height: 36.h,
      color: Colors.white.withValues(alpha: 0.22),
    );
  }

  // ── Map card ──────────────────────────────────────────────────────────────

  Widget _buildMapCard(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 12.h),
            child: _cardTitle(
              'Travelled Path',
              Icons.map_rounded,
              AppColors.primary,
              isDark,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20.r)),
            child: _routePoints.length >= 2
                ? RouteMapWidget(
                    key: _mapKey,
                    points: _routePoints,
                    segments: _routeSegments,
                    type: TripType.cycle,
                    height: 180,
                  )
                : Container(
                    height: 180.h,
                    color: isDark ? AppColors.darkElevated : AppColors.grey100,
                    alignment: Alignment.center,
                    child: Text(
                      'Route data was not available for this ride.',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: AppColors.grey500,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Primary stats grid ────────────────────────────────────────────────────

  Widget _buildPrimaryStats(bool isDark) {
    final stats = [
      (
        '${_distanceKm.toStringAsFixed(1)} km',
        'Distance',
        Icons.straighten_rounded,
        AppColors.distance,
      ),
      (_durationDisplay, 'Duration', Icons.timer_rounded, AppColors.speed),
      (
        '$_calories cal',
        'Calories',
        Icons.local_fire_department_rounded,
        AppColors.calories,
      ),
      (
        '${_avgSpeed.toStringAsFixed(1)} km/h',
        'Avg Speed',
        Icons.speed_rounded,
        AppColors.primary,
      ),
      (
        '${_maxSpeed.toStringAsFixed(1)} km/h',
        'Max Speed',
        Icons.flash_on_rounded,
        AppColors.info,
      ),
      (
        '$_elevation m',
        'Elevation',
        Icons.terrain_rounded,
        AppColors.elevation,
      ),
    ];

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10.h,
      crossAxisSpacing: 10.w,
      childAspectRatio: 0.95,
      children: stats.map((s) {
        final (value, label, icon, color) = s;
        return Container(
          padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 8.w),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(icon, size: 17.w, color: color),
              ),
              SizedBox(height: 8.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9.sp,
                  color: AppColors.grey500,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ── Eco impact ────────────────────────────────────────────────────────────

  Widget _buildEcoCard(bool isDark) {
    return _buildCard(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            'Eco Impact',
            Icons.eco_rounded,
            AppColors.success,
            isDark,
          ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.success.withValues(alpha: 0.10),
                  AppColors.primary.withValues(alpha: 0.06),
                ],
              ),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                color: AppColors.success.withValues(alpha: 0.20),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                _ecoStat(
                  '${(_distanceKm * 0.2).toStringAsFixed(2)} kg',
                  'CO2 Saved',
                  AppColors.success,
                  isDark,
                ),
                _ecoVertDivider(isDark),
                _ecoStat(
                  '${_distanceKm.toStringAsFixed(1)} km',
                  'Car km\nAvoided',
                  AppColors.distance,
                  isDark,
                ),
                _ecoVertDivider(isDark),
                _ecoStat(
                  '+${((_distanceKm * (widget.rideMode == 1 ? 7 : 10)).round() + (_durationSec / 60 * 0.5).round().clamp(1, 50) + (_distanceKm * 1.2).round().clamp(1, 20))} XP',
                  'Eco Points',
                  AppColors.warning,
                  isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _ecoVertDivider(bool isDark) {
    return Container(
      width: 1,
      height: 40.h,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.07),
    );
  }

  Widget _ecoStat(String value, String label, Color color, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppColors.grey500,
              fontWeight: FontWeight.w500,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // ── Route timeline card ───────────────────────────────────────────────────

  Widget _buildRouteCard(bool isDark) {
    return _buildCard(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle('Route', Icons.route_rounded, AppColors.primary, isDark),
          SizedBox(height: 18.h),

          // From
          Row(
            children: [
              _timelineDot(AppColors.primary, isDark),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Started',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.grey500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _startLocationName.isEmpty
                          ? 'Loading...'
                          : _startLocationName,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _startTimeFormatted,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey500,
                ),
              ),
            ],
          ),

          // Dotted line
          Padding(
            padding: EdgeInsets.only(left: 10.5.w, top: 4.h, bottom: 4.h),
            child: Column(
              children: List.generate(
                4,
                (_) => Container(
                  width: 2,
                  height: 6.h,
                  margin: EdgeInsets.symmetric(vertical: 2.h),
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(1.r),
                  ),
                ),
              ),
            ),
          ),

          // To
          Row(
            children: [
              _timelineDot(AppColors.error, isDark),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finished',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.grey500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      _endLocationName.isEmpty
                          ? 'Loading...'
                          : _endLocationName,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                _endTimeFormatted,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.grey500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timelineDot(Color color, bool isDark) {
    return Container(
      width: 22.w,
      height: 22.w,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 8.w,
        height: 8.w,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  // ── Bike info card ───────────────────────────────────────────────────────

  Widget _buildBikeInfoCard(bool isDark) {
    final bikeType = _isEBike ? 'Electric Bike' : 'Regular Bike';
    final bikeTypeSub = _isEBike ? 'E-Bike · Battery assisted' : 'Pedal only';
    final bikeColor = _isEBike ? AppColors.primary : const Color(0xFF8B6914);

    return _buildCard(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            'Bike Details',
            Icons.pedal_bike_rounded,
            bikeColor,
            isDark,
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Container(
                width: 56.w,
                height: 56.w,
                decoration: BoxDecoration(
                  color: bikeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: bikeColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _isEBike
                      ? Icons.electric_bike_rounded
                      : Icons.pedal_bike_rounded,
                  size: 26.w,
                  color: bikeColor,
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bike $_bikeId',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppColors.white : AppColors.grey900,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    Text(
                      bikeType,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: bikeColor,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      bikeTypeSub,
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: AppColors.grey500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: bikeColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  _bikeId,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: bikeColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Price summary card ──────────────────────────────────────────────────

  Widget _buildPriceCard(bool isDark) {
    return _buildCard(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            'Price Summary',
            Icons.receipt_long_rounded,
            AppColors.info,
            isDark,
          ),
          SizedBox(height: 16.h),

          if (_paidWithCoin) ...[
            // Coin-paid ride
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.monetization_on_rounded,
                    size: 24.w,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Paid with 1 MJ Coin',
                          style: TextStyle(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w800,
                            color: AppColors.warning,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'This ride was free!',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: AppColors.grey500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ] else if (_billCancel > 0) ...[
            // Cancelled ride
            _priceRow(
              'Cancellation fee (within 10 min)',
              '₹${_billCancel.toStringAsFixed(2)}',
              isDark,
            ),
            SizedBox(height: 10.h),
            _priceRow('GST (18%)', '₹${_billGst.toStringAsFixed(2)}', isDark),
            SizedBox(height: 12.h),
            _totalRow(isDark),
          ] else ...[
            // Normal ride
            _priceRow(
              'Base fare (10–60 min)',
              '₹${_billBase.toStringAsFixed(2)}',
              isDark,
            ),
            if (_billExtra > 0) ...[
              SizedBox(height: 10.h),
              _priceRow(
                'Overtime charges',
                '₹${_billExtra.toStringAsFixed(2)}',
                isDark,
              ),
            ],
            SizedBox(height: 6.h),
            Container(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            SizedBox(height: 10.h),
            _priceRow(
              'Subtotal',
              '₹${_billSubtotal.toStringAsFixed(2)}',
              isDark,
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 7.w,
                          vertical: 3.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.grey500.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'GST',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: AppColors.grey500,
                          ),
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        '18%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: isDark ? AppColors.grey300 : AppColors.grey700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '₹${_billGst.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.grey300 : AppColors.grey700,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _totalRow(isDark),
          ],
          SizedBox(height: 10.h),

          // Loyalty coin badge (if earned)
          if (_loyaltyCoin > 0)
            Container(
              margin: EdgeInsets.only(top: 6.h),
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.stars_rounded,
                    size: 16.w,
                    color: AppColors.warning,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      'Loyalty Bonus! +1 MJ Coin earned (10 rides completed)',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Payment method
          if (!_paidWithCoin) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 14.w,
                  color: AppColors.success,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Paid via Newtra Wallet',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.grey500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _totalRow(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.info.withValues(alpha: 0.12),
            AppColors.primary.withValues(alpha: 0.06),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.info.withValues(alpha: 0.20),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Total Charged',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.white : AppColors.grey900,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10.w),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                size: 16.w,
                color: AppColors.info,
              ),
              SizedBox(width: 6.w),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '₹${_billTotal.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w900,
                    color: AppColors.info,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _priceRow(String label, String amount, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: isDark ? AppColors.grey400 : AppColors.grey600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 10.w),
        Text(
          amount,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.grey200 : AppColors.grey800,
          ),
        ),
      ],
    );
  }

  // ── XP breakdown card ─────────────────────────────────────────────────────

  Widget _buildXpCard(bool isDark) {
    final bool isOwnBike = widget.rideMode == 1;
    final xpPerKm = isOwnBike ? 7 : 10;
    final int distanceXp = (_distanceKm * xpPerKm).round();
    final int durationXp = (_durationSec / 60 * 0.5).round().clamp(1, 50);
    final int ecoXp = (_distanceKm * 1.2).round().clamp(1, 20);
    final int totalXp = distanceXp + durationXp + ecoXp;

    return _buildCard(
      isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            'XP Earned',
            Icons.bolt_rounded,
            AppColors.warning,
            isDark,
          ),
          SizedBox(height: 16.h),
          _xpRow(
            'Distance (${_distanceKm.toStringAsFixed(1)} km × $xpPerKm)',
            '+$distanceXp XP',
            AppColors.distance,
            isDark,
          ),
          SizedBox(height: 10.h),
          _xpRow('Duration bonus', '+$durationXp XP', AppColors.speed, isDark),
          SizedBox(height: 10.h),
          _xpRow('Eco rider bonus', '+$ecoXp XP', AppColors.success, isDark),
          SizedBox(height: 14.h),
          Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Total Earned',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 10.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 7.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFB300), Color(0xFFFF9800)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.warning.withValues(alpha: 0.30),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt_rounded,
                      size: 14.w,
                      color: AppColors.white,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '+$totalXp XP',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                        color: AppColors.white,
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

  Widget _xpRow(String label, String xp, Color color, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isDark ? AppColors.grey300 : AppColors.grey700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Text(
            xp,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  // ── Action buttons ────────────────────────────────────────────────────────

  Widget _buildActions(BuildContext context, bool isDark) {
    return Column(
      children: [
        // Share button
        GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            await _shareRide();
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkCard : AppColors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.10)
                    : AppColors.grey200,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share_rounded, size: 17.w, color: AppColors.primary),
                SizedBox(width: 7.w),
                Text(
                  'Share',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: 10.h),
        // Home — full-width primary
        GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            context.go('/home');
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 15.h),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryDark, AppColors.primary],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(18.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.home_rounded, size: 20.w, color: AppColors.white),
                SizedBox(width: 8.w),
                Text(
                  'Back to Home',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Share helpers ─────────────────────────────────────────────────────

  Future<void> _shareRide() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mapBytes = await _mapKey.currentState?.takeSnapshot();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RideSummaryShareSheet(
        isDark: isDark,
        routePoints: _routePoints,
        routeSegments: _routeSegments,
        mapBytes: mapBytes,
        rideLabel: _rideTypeLabel,
        dateLabel: _dateLabel,
        statsTitle: _shareStatsTitle,
        distanceText: _distanceText,
        durationText: _durationDisplay,
        avgSpeedText: _avgSpeedText,
        caloriesText: _caloriesText,
        elevationText: _elevationText,
        co2SavedText: _co2SavedText,
        shareText: _shareText,
        startLocation: _startLocationName,
        endLocation: _endLocationName,
        startTime: _startTimeFormatted,
        endTime: _endTimeFormatted,
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _buildCard(bool isDark, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardTitle(String title, IconData icon, Color color, bool isDark) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15.w, color: color),
        ),
        SizedBox(width: 10.w),
        Text(
          title,
          style: TextStyle(
            fontSize: 15.sp,
            fontWeight: FontWeight.w800,
            color: isDark ? AppColors.white : AppColors.grey900,
          ),
        ),
      ],
    );
  }
}

// ── Ride summary share sheet ──────────────────────────────────────────────────

class _RideSummaryShareSheet extends StatefulWidget {
  final bool isDark;
  final List<RoutePoint> routePoints;
  final List<List<RoutePoint>> routeSegments;
  final Uint8List? mapBytes;
  final String rideLabel;
  final String dateLabel;
  final String statsTitle;
  final String distanceText;
  final String durationText;
  final String avgSpeedText;
  final String caloriesText;
  final String elevationText;
  final String co2SavedText;
  final String shareText;
  final String startLocation;
  final String endLocation;
  final String startTime;
  final String endTime;

  const _RideSummaryShareSheet({
    required this.isDark,
    required this.routePoints,
    this.routeSegments = const [],
    this.mapBytes,
    required this.rideLabel,
    required this.dateLabel,
    required this.statsTitle,
    required this.distanceText,
    required this.durationText,
    required this.avgSpeedText,
    required this.caloriesText,
    required this.elevationText,
    required this.co2SavedText,
    required this.shareText,
    this.startLocation = '',
    this.endLocation = '',
    this.startTime = '—',
    this.endTime = '—',
  });

  @override
  State<_RideSummaryShareSheet> createState() => _RideSummaryShareSheetState();
}

class _RideSummaryShareSheetState extends State<_RideSummaryShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  final GlobalKey<RouteMapWidgetState> _shareMapKey =
      GlobalKey<RouteMapWidgetState>();
  bool _isCapturing = false;
  Uint8List? _liveMapBytes;
  String get _shareText => widget.shareText;

  @override
  void initState() {
    super.initState();
    _liveMapBytes = widget.mapBytes;
  }

  Future<void> _shareWithScreenshot() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      // Capture the embedded live map first so tiles appear in the card
      if (_liveMapBytes == null) {
        final bytes = await _shareMapKey.currentState?.takeSnapshot();
        if (bytes != null && mounted) {
          setState(() => _liveMapBytes = bytes);
          await Future.delayed(const Duration(milliseconds: 150));
        }
      }
      // Now capture the card RepaintBoundary (map is Image.memory at this point)
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final file = File(
        '${Directory.systemTemp.path}/newtra_ride_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: _shareText,
        subject: 'My Newtra Ride Summary',
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  void _shareTextOnly() {
    Share.share(_shareText, subject: 'My Newtra Ride Summary');
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg = widget.isDark
        ? const Color(0xFF0D1117)
        : const Color(0xFFF2F4F7);
    final handleColor = (widget.isDark ? Colors.white : Colors.black)
        .withValues(alpha: 0.15);

    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 36.h),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: handleColor,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 16.h),

            // The card that will be captured
            RepaintBoundary(
              key: _cardKey,
              child: _RideSummaryShareCard(
                isDark: widget.isDark,
                routePoints: widget.routePoints,
                routeSegments: widget.routeSegments,
                mapBytes: _liveMapBytes,
                mapKey: _liveMapBytes == null ? _shareMapKey : null,
                rideLabel: widget.rideLabel,
                dateLabel: widget.dateLabel,
                statsTitle: widget.statsTitle,
                distanceText: widget.distanceText,
                durationText: widget.durationText,
                avgSpeedText: widget.avgSpeedText,
                caloriesText: widget.caloriesText,
                elevationText: widget.elevationText,
                co2SavedText: widget.co2SavedText,
                startLocation: widget.startLocation,
                endLocation: widget.endLocation,
                startTime: widget.startTime,
                endTime: widget.endTime,
              ),
            ),

            SizedBox(height: 20.h),

            // Share with Screenshot
            GestureDetector(
              onTap: _isCapturing ? null : _shareWithScreenshot,
              child: Container(
                width: double.infinity,
                height: 50.h,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00A877), Color(0xFF00C896)],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Center(
                  child: _isCapturing
                      ? SizedBox(
                          width: 20.w,
                          height: 20.w,
                          child: const CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.image_rounded,
                              color: Colors.white,
                              size: 18.w,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'Share with Screenshot',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.sp,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ),
            SizedBox(height: 10.h),

            // Share Text Only
            GestureDetector(
              onTap: _shareTextOnly,
              child: Container(
                width: double.infinity,
                height: 50.h,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.darkElevated
                      : AppColors.grey100,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.text_fields_rounded,
                        size: 18.w,
                        color: widget.isDark
                            ? AppColors.grey300
                            : AppColors.grey700,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Share Text Only',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark
                              ? AppColors.grey300
                              : AppColors.grey700,
                        ),
                      ),
                    ],
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

// ── Share card (captured as image) ────────────────────────────────────────────────

class _RideSummaryShareCard extends StatelessWidget {
  final bool isDark;
  final List<RoutePoint> routePoints;
  final List<List<RoutePoint>> routeSegments;
  final Uint8List? mapBytes;
  final GlobalKey<RouteMapWidgetState>? mapKey;
  final String rideLabel;
  final String dateLabel;
  final String statsTitle;
  final String distanceText;
  final String durationText;
  final String avgSpeedText;
  final String caloriesText;
  final String elevationText;
  final String co2SavedText;
  final String startLocation;
  final String endLocation;
  final String startTime;
  final String endTime;

  const _RideSummaryShareCard({
    required this.isDark,
    required this.routePoints,
    this.routeSegments = const [],
    this.mapBytes,
    this.mapKey,
    required this.rideLabel,
    required this.dateLabel,
    required this.statsTitle,
    required this.distanceText,
    required this.durationText,
    required this.avgSpeedText,
    required this.caloriesText,
    required this.elevationText,
    required this.co2SavedText,
    this.startLocation = '',
    this.endLocation = '',
    this.startTime = '—',
    this.endTime = '—',
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final mapBg = isDark ? const Color(0xFF0D1117) : const Color(0xFFEEF0F3);
    final dividerColor = (isDark ? Colors.white : Colors.black).withValues(
      alpha: 0.07,
    );
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.grey500;
    final valueColor = isDark ? Colors.white : AppColors.grey900;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: dividerColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Green accent strip
          Container(height: 5.h, color: AppColors.primary),

          // Logo + badge
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
            child: Row(
              children: [
                SvgPicture.asset(
                  AppAssets.fullLogoForTheme(isDark),
                  height: 18.h,
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.30),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_bike_rounded,
                        size: 12.w,
                        color: AppColors.primary,
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        rideLabel,
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 10.h),
            child: Text(
              dateLabel,
              style: TextStyle(fontSize: 11.sp, color: labelColor),
            ),
          ),

          // Route map
          Container(
            height: 140.h,
            decoration: BoxDecoration(color: mapBg),
            clipBehavior: Clip.antiAlias,
            child: mapBytes != null
                ? Image.memory(
                    mapBytes!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: double.infinity,
                  )
                : mapKey != null
                ? RouteMapWidget(
                    key: mapKey,
                    points: routePoints,
                    segments: routeSegments,
                    type: TripType.cycle,
                    height: 140,
                  )
                : CustomPaint(
                    painter: _SummaryRoutePainter(
                      points: routePoints,
                      lineColor: AppColors.primary,
                      isDark: isDark,
                    ),
                  ),
          ),

          SizedBox(height: 12.h),

          // From → To
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 9.w,
                      height: 9.w,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 26.h,
                      margin: EdgeInsets.symmetric(vertical: 2.h),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppColors.primary, AppColors.error],
                        ),
                        borderRadius: BorderRadius.all(Radius.circular(1)),
                      ),
                    ),
                    Container(
                      width: 9.w,
                      height: 9.w,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              startLocation.isEmpty ? 'Start' : startLocation,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: valueColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            startTime,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: labelColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              endLocation.isEmpty ? 'End' : endLocation,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: valueColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            endTime,
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: labelColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Divider(color: dividerColor, height: 1),
          ),
          SizedBox(height: 10.h),

          // Stats label
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              statsTitle,
              style: TextStyle(
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w700,
                color: labelColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: 10.h),

          // Row 1
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _statItem(
                  distanceText,
                  'Distance',
                  Icons.straighten_rounded,
                  AppColors.primary,
                  isDark,
                ),
                _statItem(
                  durationText,
                  'Duration',
                  Icons.timer_rounded,
                  AppColors.speed,
                  isDark,
                ),
                _statItem(
                  avgSpeedText,
                  'Avg Speed',
                  Icons.speed_rounded,
                  AppColors.info,
                  isDark,
                ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          // Row 2
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Row(
              children: [
                _statItem(
                  caloriesText,
                  'Calories',
                  Icons.local_fire_department_rounded,
                  AppColors.calories,
                  isDark,
                ),
                _statItem(
                  elevationText,
                  'Elevation',
                  Icons.terrain_rounded,
                  AppColors.elevation,
                  isDark,
                ),
                _statItem(
                  co2SavedText,
                  'CO2 Saved',
                  Icons.eco_rounded,
                  AppColors.success,
                  isDark,
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),

          // Footer
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            color: AppColors.primary.withValues(alpha: 0.07),
            child: Row(
              children: [
                Icon(
                  Icons.download_rounded,
                  size: 14.w,
                  color: AppColors.primary,
                ),
                SizedBox(width: 6.w),
                Text(
                  'Download Newtra · newtra.app',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
    String value,
    String label,
    IconData icon,
    Color color,
    bool isDark,
  ) {
    final labelC = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.grey500;
    final valueC = isDark ? Colors.white : AppColors.grey900;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 18.w, color: color),
          ),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: valueC,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            label,
            style: TextStyle(fontSize: 9.sp, color: labelC),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Route CustomPainter (fallback when map snapshot unavailable) ────────────────

class _SummaryRoutePainter extends CustomPainter {
  final List<RoutePoint> points;
  final Color lineColor;
  final bool isDark;

  const _SummaryRoutePainter({
    required this.points,
    required this.lineColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minLat = points.map((p) => p.lat).reduce(math.min);
    final maxLat = points.map((p) => p.lat).reduce(math.max);
    final minLng = points.map((p) => p.lng).reduce(math.min);
    final maxLng = points.map((p) => p.lng).reduce(math.max);
    final latRange = (maxLat - minLat).abs();
    final lngRange = (maxLng - minLng).abs();
    if (latRange == 0 || lngRange == 0) return;
    const pad = 24.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    Offset toOffset(RoutePoint p) => Offset(
      pad + (p.lng - minLng) / lngRange * w,
      pad + (1.0 - (p.lat - minLat) / latRange) * h,
    );
    final positions = points.map(toOffset).toList();
    final shadowPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.30)
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final path = Path();
    path.moveTo(positions.first.dx, positions.first.dy);
    for (int i = 1; i < positions.length; i++) {
      path.lineTo(positions[i].dx, positions[i].dy);
    }
    canvas.drawPath(path, shadowPaint);
    canvas.drawPath(path, linePaint);
    final start = positions.first;
    canvas.drawCircle(
      start,
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      start,
      7,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      start,
      3.5,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill,
    );
    final end = positions.last;
    canvas.drawCircle(
      end,
      7,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      end,
      7,
      Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    canvas.drawCircle(
      end,
      3.5,
      Paint()
        ..color = const Color(0xFFE53935)
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_SummaryRoutePainter old) => old.points != points;
}
