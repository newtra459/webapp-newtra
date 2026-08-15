import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_assets.dart';
import 'package:dio/dio.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/widgets/route_map_widget.dart';

class TripDetailScreen extends StatefulWidget {
  final Map<String, dynamic> trip;
  const TripDetailScreen({super.key, required this.trip});

  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final _mapKey = GlobalKey<RouteMapWidgetState>();
  List<RoutePoint>? _loadedRoute;
  String? _resolvedFrom;
  String? _resolvedTo;

  @override
  void initState() {
    super.initState();
    _loadRoute();
    _resolveLocationNames();
  }

  /// Reverse geocode from/to if they look like raw coordinates.
  Future<void> _resolveLocationNames() async {
    final from = widget.trip['from'] as String? ?? '';
    final to = widget.trip['to'] as String? ?? '';

    final futures = <Future>[];
    if (_looksLikeCoords(from)) {
      futures.add(_reverseGeocode(from).then((v) {
        if (mounted) setState(() => _resolvedFrom = v);
      }));
    }
    if (_looksLikeCoords(to)) {
      futures.add(_reverseGeocode(to).then((v) {
        if (mounted) setState(() => _resolvedTo = v);
      }));
    }
    if (futures.isNotEmpty) await Future.wait(futures);
  }

  bool _looksLikeCoords(String s) {
    if (s.isEmpty) return false;
    final parts = s.split(',');
    if (parts.length != 2) return false;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    return lat != null && lng != null;
  }

  Future<String> _reverseGeocode(String coords) async {
    try {
      final parts = coords.split(',');
      final lat = double.parse(parts[0].trim());
      final lng = double.parse(parts[1].trim());
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
          final name = addr['amenity'] ??
              addr['building'] ??
              addr['road'] ??
              addr['neighbourhood'] ??
              addr['suburb'] ??
              addr['village'] ??
              addr['town'] ??
              addr['city'] ??
              '';
          final area = addr['suburb'] ?? addr['neighbourhood'] ?? addr['city_district'] ?? '';
          if (name.toString().isNotEmpty && area.toString().isNotEmpty && name != area) {
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
    return coords;
  }

  Future<void> _loadRoute() async {
    final trip = widget.trip;
    final type = trip['type'] as String? ?? 'cycle';

    if (type == 'cycle') {
      final tripId = trip['id'] as String? ?? '';
      if (tripId.isNotEmpty) {
        final api = ApiClient();

        // 1. Try to load road-snapped route (OSRM-matched) first
        try {
          final snappedRes = await api.get(ApiEndpoints.trips.snappedRoute(tripId));
          final snappedRoot = snappedRes.data is Map<String, dynamic>
              ? snappedRes.data as Map<String, dynamic>
              : <String, dynamic>{};
          final snappedData = snappedRoot['data'];
          if (snappedData is List && snappedData.isNotEmpty) {
            final points = <RoutePoint>[];
            for (final p in snappedData) {
              if (p is Map<String, dynamic>) {
                final lat = (p['lat'] as num?)?.toDouble() ?? 0;
                final lng = (p['long'] as num?)?.toDouble() ?? (p['lng'] as num?)?.toDouble() ?? 0;
                if (lat != 0 && lng != 0) {
                  points.add(RoutePoint(lat, lng));
                }
              }
            }
            if (points.isNotEmpty && mounted) {
              setState(() => _loadedRoute = points);
              return;
            }
          }
        } catch (_) {
          // Snapped route not available — try raw GPS path
        }

        // 2. Fall back to raw GPS path
        try {
          final res = await api.get(ApiEndpoints.trips.locations(tripId));
          final root = res.data is Map<String, dynamic> ? res.data as Map<String, dynamic> : <String, dynamic>{};
          final data = root['data'];
          if (data is List && data.isNotEmpty) {
            final points = <RoutePoint>[];
            for (final p in data) {
              if (p is Map<String, dynamic>) {
                final lat = (p['lat'] as num?)?.toDouble() ?? 0;
                final lng = (p['long'] as num?)?.toDouble() ?? (p['lng'] as num?)?.toDouble() ?? 0;
                if (lat != 0 && lng != 0) {
                  points.add(RoutePoint(lat, lng));
                }
              }
            }
            if (points.isNotEmpty && mounted) {
              setState(() => _loadedRoute = points);
              return;
            }
          }
        } catch (_) {}
      }
    }

    // 3. Final fallback: use start/end coordinates from trip data
    final startLat = (trip['startLat'] as num?)?.toDouble() ?? 0;
    final startLng = (trip['startLng'] as num?)?.toDouble() ?? 0;
    final endLat = (trip['endLat'] as num?)?.toDouble() ?? 0;
    final endLng = (trip['endLng'] as num?)?.toDouble() ?? 0;

    if (startLat != 0 && startLng != 0) {
      final points = <RoutePoint>[RoutePoint(startLat, startLng)];
      if (endLat != 0 && endLng != 0 && (endLat != startLat || endLng != startLng)) {
        points.add(RoutePoint(endLat, endLng));
      }
      if (mounted) setState(() => _loadedRoute = points);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = widget.trip['type'] as String? ?? 'cycle';
    final trip = widget.trip;
    final isCycle = type == 'cycle';
    final isBus = type == 'bus';
    final routePoints = _loadedRoute ?? const [];
    final tripType = type == 'bus'
        ? TripType.bus
        : type == 'buggy'
            ? TripType.buggy
            : TripType.cycle;

    final bg = isDark ? const Color(0xFF0D1117) : const Color(0xFFF2F4F7);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.07)
        : Colors.black.withValues(alpha: 0.06);
    final labelColor =
        isDark ? Colors.white.withValues(alpha: 0.45) : AppColors.grey500;
    final valueColor = isDark ? Colors.white : AppColors.grey900;

    // Type accent
    final isOwnBike = (trip['paymentType'] as String?) == 'own_bike';
    final (typeIcon, typeLabel, typeColor) = isCycle
        ? (Icons.directions_bike_rounded,
            isOwnBike ? 'Own Bike Ride' : 'Cycle Ride',
        isOwnBike ? const Color(0xFF1565C0) : AppColors.primary)
        : type == 'bus'
            ? (Icons.directions_bus_rounded, 'Bus Journey', const Color(0xFFFF8F00))
        : (Icons.airport_shuttle_rounded, 'Buggy Ride', AppColors.success);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: bg,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Padding(
            padding: EdgeInsets.all(8.w),
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.90),
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16.w,
                  color: isDark ? Colors.white : AppColors.grey900,
                ),
              ),
            ),
          ),
          actions: [
            Padding(
              padding: EdgeInsets.only(right: 4.w),
              child: GestureDetector(
                onTap: () async {
                  // Capture the real Google Map snapshot first
                  final mapBytes =
                      await _mapKey.currentState?.takeSnapshot();
                  if (!context.mounted) return;
                  _showShareSheet(
                      context, isDark, trip, typeLabel, typeIcon, typeColor,
                      routePoints, isCycle, mapBytes);
                },
                child: Container(
                  width: 36.w,
                  height: 36.w,
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.55)
                        : Colors.white.withValues(alpha: 0.90),
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 1),
                  ),
                  child: Icon(
                    Icons.share_rounded,
                    size: 17.w,
                    color: isDark ? Colors.white : AppColors.grey900,
                  ),
                ),
              ),
            ),
            if ((trip['paymentType'] as String?) != 'own_bike')
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: GestureDetector(
                  onTap: () => _showPaymentSheet(context, isDark),
                  child: Container(
                    width: 36.w,
                    height: 36.w,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.black.withValues(alpha: 0.55)
                          : Colors.white.withValues(alpha: 0.90),
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor, width: 1),
                    ),
                    child: Icon(
                      Icons.receipt_long_rounded,
                      size: 17.w,
                      color: isDark ? Colors.white : AppColors.grey900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Map is OUTSIDE the scroll — fixes GoogleMap polyline misplacement
        body: Column(
          children: [
            // ── Fixed map — full bleed to top, never inside a ScrollView ──
            Stack(
              children: [
                SizedBox(
                  height: 280.h,
                  child: RouteMapWidget(
                    key: _mapKey,
                    points: routePoints,
                    type: tripType,
                    height: 280,
                    borderRadius: BorderRadius.zero,
                  ),
                ),

              ],
            ),

            // ── Everything else scrolls below ──────────────────────
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // ── Type badge + title ────────────────────────────
                  Container(
                    color: cardBg,
                    padding:
                        EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 18.h),
                    child: Row(
                      children: [
                        Container(
                          width: 44.w,
                          height: 44.w,
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Icon(typeIcon,
                              size: 22.w, color: typeColor),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                typeLabel,
                                style: TextStyle(
                                  fontSize: 17.sp,
                                  fontWeight: FontWeight.w700,
                                  color: valueColor,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                trip['date'] as String? ?? 'Today',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: labelColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Completed badge
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: AppColors.success.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            'Completed',
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(height: 1, color: borderColor),

                  // ── From / To timeline ────────────────────────────
                  Container(
                    color: cardBg,
                    padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
                    child: Row(
                      children: [
                        // Dot–line–dot rail
                        Column(
                          children: [
                            Container(
                              width: 12.w,
                              height: 12.w,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            Container(
                              width: 2,
                              height: 32.h,
                              margin:
                                  EdgeInsets.symmetric(vertical: 3.h),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    AppColors.primary,
                                    AppColors.error,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                            Container(
                              width: 12.w,
                              height: 12.w,
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(width: 14.w),
                        // Places + times
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _placeRow(
                                _resolvedFrom ?? trip['from'] as String? ?? 'Start',
                                trip['startTime'] as String? ?? '—',
                                labelColor,
                                valueColor,
                              ),
                              SizedBox(height: 18.h),
                              _placeRow(
                                _resolvedTo ?? trip['to'] as String? ?? 'End',
                                trip['endTime'] as String? ?? '—',
                                labelColor,
                                valueColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 10.h),

                  // ── Stats label (cycle only — bus/buggy has its own inside the else branch)
                  if (isCycle) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 0),
                    child: Text(
                      'FITNESS STATS',
                      style: TextStyle(
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w700,
                        color: labelColor,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  ],

                  if (isCycle) ...[
                    _statsGrid(context, isDark, cardBg, borderColor, [
                      _StatItem('Distance',
                          trip['distance'] as String? ?? '—',
                          Icons.straighten_rounded, AppColors.primary),
                      _StatItem('Duration',
                          trip['duration'] as String? ?? '—',
                          Icons.timer_rounded, AppColors.speed),
                      _StatItem('Avg Speed',
                          trip['avgSpeed'] as String? ?? '—',
                          Icons.speed_rounded, AppColors.info),
                      _StatItem('Calories',
                          trip['calories'] as String? ?? '—',
                          Icons.local_fire_department_rounded,
                          AppColors.calories),
                      _StatItem('Elevation',
                          trip['elevation'] as String? ?? '—',
                          Icons.terrain_rounded, AppColors.elevation),
                      _StatItem('CO2 Saved',
                          trip['co2'] as String? ?? '—',
                          Icons.eco_rounded, AppColors.success),
                    ]),
                  ] else ...[

                    // ── Vehicle / Route banner ──────────────────────
                    Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 16.w),
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              typeColor.withValues(alpha: 0.13),
                              typeColor.withValues(alpha: 0.04),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18.r),
                          border: Border.all(
                              color: typeColor.withValues(alpha: 0.22),
                              width: 1),
                        ),
                        child: Row(
                          children: [
                            // Big icon circle
                            Container(
                              width: 54.w,
                              height: 54.w,
                              decoration: BoxDecoration(
                                color: typeColor.withValues(alpha: 0.18),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(typeIcon,
                                  size: 28.w, color: typeColor),
                            ),
                            SizedBox(width: 14.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      // Route/vehicle number pill
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 9.w,
                                            vertical: 3.h),
                                        decoration: BoxDecoration(
                                          color: typeColor,
                                          borderRadius:
                                              BorderRadius.circular(7.r),
                                        ),
                                        child: Text(
                                          isBus
                                              ? (trip['routeNumber']
                                                      as String? ??
                                                  'R-?')
                                              : (trip['buggyNumber']
                                                      as String? ??
                                                  'EV-?'),
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          trip['vehicle'] as String? ??
                                              typeLabel,
                                          style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w700,
                                            color: valueColor,
                                          ),
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  // Stops / Passengers row
                                  if (isBus) ...[
                                    _infoRowItem(
                                      Icons.stop_circle_outlined,
                                      '${trip["stops"] ?? "—"} stops',
                                      labelColor,
                                    ),
                                    SizedBox(height: 4.h),
                                    _infoRowItem(
                                      Icons.airline_seat_recline_normal_rounded,
                                      'Seat: ${trip["seat"] ?? "Open"}',
                                      labelColor,
                                    ),
                                  ] else ...[
                                    _infoRowItem(
                                      Icons.people_rounded,
                                      '${trip["passengers"] ?? "1"} passenger(s)',
                                      labelColor,
                                    ),
                                    SizedBox(height: 4.h),
                                    _infoRowItem(
                                      Icons.electric_bolt_rounded,
                                      'Electric Campus Vehicle',
                                      labelColor,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 10.h),

                    // ── Stats label ─────────────────────────────────
                    Padding(
                      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 0),
                      child: Text(
                        'JOURNEY STATS',
                        style: TextStyle(
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w700,
                          color: labelColor,
                          letterSpacing: 1.3,
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),

                    // ── Stats grid ──────────────────────────────────
                    if (isBus)
                      _statsGrid(context, isDark, cardBg, borderColor, [
                        _StatItem(
                            'Distance',
                            trip['distance'] as String? ?? '—',
                            Icons.route_rounded,
                            AppColors.primary),
                        _StatItem(
                            'Duration',
                            trip['duration'] as String? ?? '—',
                            Icons.schedule_rounded,
                            AppColors.speed),
                        _StatItem(
                            'Stops',
                            trip['stops'] as String? ?? '—',
                            Icons.stop_circle_outlined,
                            AppColors.info),
                        _StatItem(
                            'CO2 Saved',
                            trip['co2'] as String? ?? '—',
                            Icons.eco_rounded,
                            AppColors.success),
                      ], crossAxisCount: 2)
                    else
                      _statsGrid(context, isDark, cardBg, borderColor, [
                        _StatItem(
                            'Distance',
                            trip['distance'] as String? ?? '—',
                            Icons.route_rounded,
                            AppColors.primary),
                        _StatItem(
                            'Duration',
                            trip['duration'] as String? ?? '—',
                            Icons.schedule_rounded,
                            AppColors.speed),
                        _StatItem(
                            'CO2 Saved',
                            trip['co2'] as String? ?? '—',
                            Icons.eco_rounded,
                            AppColors.success),
                        _StatItem(
                            'Passengers',
                            trip['passengers'] as String? ?? '—',
                            Icons.people_rounded,
                            AppColors.warning),
                      ], crossAxisCount: 2),
                  ],

                  SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeRow(
      String place, String time, Color labelC, Color valueC) {
    return Row(
      children: [
        Expanded(
          child: Text(
            place,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: valueC,
            ),
          ),
        ),
        Text(
          time,
          style: TextStyle(
            fontSize: 12.sp,
            color: labelC,
          ),
        ),
      ],
    );
  }

  Widget _infoRowItem(IconData icon, String text, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12.w, color: color),
        SizedBox(width: 5.w),
        Flexible(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.sp, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _statsGrid(
    BuildContext context,
    bool isDark,
    Color cardBg,
    Color borderColor,
    List<_StatItem> stats, {
    int crossAxisCount = 3,
  }) {
    return GridView.builder(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 8.h,
        crossAxisSpacing: 8.w,
        childAspectRatio: crossAxisCount == 2 ? 1.45 : 1.05,
      ),
      itemCount: stats.length,
      itemBuilder: (_, i) {
        final s = stats[i];
        return Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor, width: 1),
          ),
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 30.w,
                height: 30.w,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9.r),
                ),
                child: Icon(s.icon, size: 16.w, color: s.color),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      s.value,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.grey900,
                      ),
                    ),
                  ),
                  Text(
                    s.label,
                    style: TextStyle(
                      fontSize: 9.5.sp,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.40)
                          : AppColors.grey500,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showShareSheet(
    BuildContext context,
    bool isDark,
    Map<String, dynamic> trip,
    String typeLabel,
    IconData typeIcon,
    Color typeColor,
    List<RoutePoint> routePoints,
    bool isCycle,
    Uint8List? mapBytes,
  ) {
    // Apply resolved location names
    final resolvedTrip = Map<String, dynamic>.from(trip);
    if (_resolvedFrom != null) resolvedTrip['from'] = _resolvedFrom;
    if (_resolvedTo != null) resolvedTrip['to'] = _resolvedTo;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TripShareSheet(
        trip: resolvedTrip,
        isDark: isDark,
        typeLabel: typeLabel,
        typeIcon: typeIcon,
        typeColor: typeColor,
        routePoints: routePoints,
        isCycle: isCycle,
        mapBytes: mapBytes,
      ),
    );
  }

  void _showPaymentSheet(BuildContext context, bool isDark) {
    final trip = widget.trip;
    final isPaid = (trip['paymentType'] as String?) == 'paid';
    final plan = trip['plan'] as String? ?? 'Student Plan';
    final price = trip['price'] as String? ?? '₹0';
    final coins = trip['coins'] as int? ?? 0;
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final labelColor =
        isDark ? Colors.white.withValues(alpha: 0.45) : AppColors.grey500;
    final valueColor = isDark ? Colors.white : AppColors.grey900;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        margin: EdgeInsets.fromLTRB(12.w, 0, 12.w, 12.h),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(24.r),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36.w,
                height: 4.h,
                margin: EdgeInsets.only(bottom: 18.h),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : AppColors.grey200,
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(Icons.receipt_long_rounded,
                      size: 18.w, color: AppColors.primary),
                ),
                SizedBox(width: 10.w),
                Text(
                  'Payment Details',
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),
            _payRow(Icons.card_membership_rounded, 'Plan', plan,
                AppColors.primary, labelColor, valueColor),
            _divider(isDark),
            if (isPaid)
              _payRow(Icons.currency_rupee_rounded, 'Amount Charged',
                  price, AppColors.warning, labelColor, valueColor)
            else
              _payRow(Icons.check_circle_outline_rounded, 'Charged to Plan',
                  'Included', AppColors.success, labelColor, valueColor),
            _divider(isDark),
            _payRow(
              Icons.toll_rounded,
              coins >= 0 ? 'Coins Earned' : 'Coins Used',
              coins >= 0 ? '+$coins MJ' : '${coins.abs()} MJ',
              coins >= 0 ? AppColors.success : AppColors.error,
              labelColor,
              valueColor,
            ),
            SizedBox(height: 18.h),
            Container(
              width: double.infinity,
              padding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15.w, color: AppColors.primary),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      isPaid
                          ? 'This trip was charged to your wallet.'
                          : 'Covered under your $plan subscription.',
                      style: TextStyle(
                          fontSize: 11.5.sp, color: AppColors.primary),
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

  Widget _divider(bool isDark) => Container(
        height: 1,
        margin: EdgeInsets.symmetric(vertical: 12.h),
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.black.withValues(alpha: 0.05),
      );

  Widget _payRow(IconData icon, String label, String value, Color color,
      Color labelColor, Color valueColor) {
    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10.r),
          ),
          child: Icon(icon, size: 17.w, color: color),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 13.sp, color: labelColor)),
        ),
        Text(value,
            style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: valueColor)),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

// ── Share sheet ────────────────────────────────────────────────────────────────

class _TripShareSheet extends StatefulWidget {
  final Map<String, dynamic> trip;
  final bool isDark;
  final String typeLabel;
  final IconData typeIcon;
  final Color typeColor;
  final List<RoutePoint> routePoints;
  final bool isCycle;
  final Uint8List? mapBytes;

  const _TripShareSheet({
    required this.trip,
    required this.isDark,
    required this.typeLabel,
    required this.typeIcon,
    required this.typeColor,
    required this.routePoints,
    required this.isCycle,
    this.mapBytes,
  });

  @override
  State<_TripShareSheet> createState() => _TripShareSheetState();
}

class _TripShareSheetState extends State<_TripShareSheet> {
  final GlobalKey _cardKey = GlobalKey();
  bool _isCapturing = false;

  String get _shareText {
    final lines = <String>[
      'Completed ${widget.typeLabel} on Newtra!',
    ];

    final trip = widget.trip;
    final distance = trip['distance']?.toString();
    final duration = trip['duration']?.toString();
    final from = trip['from']?.toString();
    final to = trip['to']?.toString();

    if (distance != null && distance.isNotEmpty) {
      lines.add('Distance: $distance');
    }
    if (duration != null && duration.isNotEmpty) {
      lines.add('Duration: $duration');
    }
    if (from != null && from.isNotEmpty) {
      lines.add('From: $from');
    }
    if (to != null && to.isNotEmpty) {
      lines.add('To: $to');
    }

    lines
      ..add('')
      ..add('Track your rides on Newtra.');
    return lines.join('\n');
  }

  Future<void> _share() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      // Use 3× pixel ratio for crisp screenshot output
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final file = File(
          '${Directory.systemTemp.path}/newtra_trip_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: _shareText,
      );
    } finally {
      if (mounted) setState(() => _isCapturing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheetBg =
        widget.isDark ? const Color(0xFF0D1117) : const Color(0xFFF2F4F7);
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
          // Sheet handle
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
            child: _ShareCard(
              trip: widget.trip,
              isDark: widget.isDark,
              typeLabel: widget.typeLabel,
              typeIcon: widget.typeIcon,
              typeColor: widget.typeColor,
              routePoints: widget.routePoints,
              isCycle: widget.isCycle,
              mapBytes: widget.mapBytes,
            ),
          ),

          SizedBox(height: 20.h),

          // Share button
          GestureDetector(
            onTap: _share,
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
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share_rounded,
                              color: Colors.white, size: 18.w),
                          SizedBox(width: 8.w),
                          Text(
                            'Share Trip',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 15.sp,
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

// ── Share card (captured as image) ────────────────────────────────────────────

class _ShareCard extends StatelessWidget {
  final Map<String, dynamic> trip;
  final bool isDark;
  final String typeLabel;
  final IconData typeIcon;
  final Color typeColor;
  final List<RoutePoint> routePoints;
  final bool isCycle;
  final Uint8List? mapBytes;

  const _ShareCard({
    required this.trip,
    required this.isDark,
    required this.typeLabel,
    required this.typeIcon,
    required this.typeColor,
    required this.routePoints,
    required this.isCycle,
    this.mapBytes,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF161B22) : Colors.white;
    final mapBg = isDark ? const Color(0xFF0D1117) : const Color(0xFFEEF0F3);
    final dividerColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07);
    final labelColor =
        isDark ? Colors.white.withValues(alpha: 0.45) : AppColors.grey500;
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

          // Logo + trip type badge
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(
                        color: typeColor.withValues(alpha: 0.30), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 12.w, color: typeColor),
                      SizedBox(width: 4.w),
                      Text(
                        typeLabel,
                        style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: typeColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Date
          Padding(
            padding: EdgeInsets.fromLTRB(16.w, 6.h, 16.w, 10.h),
            child: Text(
              trip['date'] as String? ?? 'Today',
              style: TextStyle(fontSize: 11.sp, color: labelColor),
            ),
          ),

          // ── Route map (real Google Maps snapshot) ──────────────
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
                : CustomPaint(
                    painter: _RoutePainter(
                      points: routePoints,
                      lineColor: AppColors.primary,
                      isDark: isDark,
                    ),
                  ),
          ),

          SizedBox(height: 12.h),

          // ── From → To with times ────────────────────────────────
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
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle)),
                    Container(
                        width: 2,
                        height: 26.h,
                        margin: EdgeInsets.symmetric(vertical: 2.h),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [AppColors.primary, AppColors.error],
                          ),
                          borderRadius: BorderRadius.circular(1),
                        )),
                    Container(
                        width: 9.w,
                        height: 9.w,
                        decoration: BoxDecoration(
                            color: AppColors.error, shape: BoxShape.circle)),
                  ],
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(trip['from'] as String? ?? 'Start',
                                style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: valueColor)),
                          ),
                          Text(trip['startTime'] as String? ?? '',
                              style: TextStyle(
                                  fontSize: 11.sp, color: labelColor)),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(trip['to'] as String? ?? 'End',
                                style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w600,
                                    color: valueColor)),
                          ),
                          Text(trip['endTime'] as String? ?? '',
                              style: TextStyle(
                                  fontSize: 11.sp, color: labelColor)),
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
              child: Divider(color: dividerColor, height: 1)),
          SizedBox(height: 10.h),

          // ── Stats label ─────────────────────────────────────────
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Text(
              isCycle ? 'FITNESS STATS' : 'JOURNEY STATS',
              style: TextStyle(
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w700,
                color: labelColor,
                letterSpacing: 1.2,
              ),
            ),
          ),
          SizedBox(height: 10.h),

          // ── Stats grid ──────────────────────────────────────────
          if (isCycle) ...[
            // Row 1
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _statItem(trip['distance'] as String? ?? '—', 'Distance',
                      Icons.straighten_rounded, AppColors.primary, isDark),
                  _statItem(trip['duration'] as String? ?? '—', 'Duration',
                      Icons.timer_rounded, AppColors.speed, isDark),
                  _statItem(trip['avgSpeed'] as String? ?? '—', 'Avg Speed',
                      Icons.speed_rounded, AppColors.info, isDark),
                ],
              ),
            ),
            SizedBox(height: 12.h),
            // Row 2
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _statItem(trip['calories'] as String? ?? '—', 'Calories',
                      Icons.local_fire_department_rounded,
                      AppColors.calories, isDark),
                  _statItem(trip['elevation'] as String? ?? '—', 'Elevation',
                      Icons.terrain_rounded, AppColors.elevation, isDark),
                  _statItem(trip['co2'] as String? ?? '—', 'CO2 Saved',
                      Icons.eco_rounded, AppColors.success, isDark),
                ],
              ),
            ),
          ] else ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: [
                  _statItem(trip['distance'] as String? ?? '—', 'Distance',
                      Icons.route_rounded, AppColors.primary, isDark),
                  _statItem(trip['duration'] as String? ?? '—', 'Duration',
                      Icons.schedule_rounded, AppColors.speed, isDark),
                  _statItem(trip['co2'] as String? ?? '—', 'CO2 Saved',
                      Icons.eco_rounded, AppColors.success, isDark),
                ],
              ),
            ),
          ],

          SizedBox(height: 16.h),

          // App link footer
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            color: AppColors.primary.withValues(alpha: 0.07),
            child: Row(
              children: [
                Icon(Icons.download_rounded, size: 14.w, color: AppColors.primary),
                SizedBox(width: 6.w),
                Text(
                  'Download Newtra · newtra.app',
                  style: TextStyle(
                      fontSize: 11.sp,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statItem(
      String value, String label, IconData icon, Color color, bool isDark) {
    final labelC =
        isDark ? Colors.white.withValues(alpha: 0.45) : AppColors.grey500;
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
          Text(value,
              style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: valueC)),
          SizedBox(height: 2.h),
          Text(label,
              style: TextStyle(fontSize: 9.sp, color: labelC),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// ── Route CustomPainter (fallback when map snapshot unavailable) ──────────────

class _RoutePainter extends CustomPainter {
  final List<RoutePoint> points;
  final Color lineColor;
  final bool isDark;

  const _RoutePainter({
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
    canvas.drawCircle(start, 7, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(start, 7, Paint()..color = lineColor..style = PaintingStyle.stroke..strokeWidth = 2.5);
    canvas.drawCircle(start, 3.5, Paint()..color = lineColor..style = PaintingStyle.fill);
    final end = positions.last;
    canvas.drawCircle(end, 7, Paint()..color = Colors.white..style = PaintingStyle.fill);
    canvas.drawCircle(end, 7, Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.stroke..strokeWidth = 2.5);
    canvas.drawCircle(end, 3.5, Paint()..color = const Color(0xFFE53935)..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_RoutePainter old) => old.points != points;
}
