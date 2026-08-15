import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'dart:ui' as ui;
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/directions_service.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/widgets/mj_glass.dart';
import '../../../ride/data/models/ride_model.dart';
import '../../../ride/presentation/providers/ride_provider.dart';
import '../providers/home_provider.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _selectedMapType = 0;
  static const int _streetMap = 0;
  static const int _terrainMap = 1;
  static const int _satelliteMap = 2;
  static const int _hybridMap = 3;

  final MapController _mapController = MapController();
  LatLng _mapCenter = const LatLng(17.4577, 78.2753);
  LatLng? _userLocation;
  Map<String, dynamic>? _selectedStation;

  // Road-following directions to the selected station (empty = straight-line
  // fallback). _directionsRequestId guards against out-of-order async results.
  final DirectionsService _directionsService = DirectionsService();
  List<LatLng> _directionsRoute = const [];
  int _directionsRequestId = 0;

  // Stations loaded from backend API
  List<Map<String, dynamic>> _stations = [];

  /// Returns stations sorted nearest-first (from user location) and capped at 10.
  List<Map<String, dynamic>> get _sortedStations {
    final origin = _userLocation ?? _mapCenter;
    final withDist =
        _stations.map((s) {
          final meters = Geolocator.distanceBetween(
            origin.latitude,
            origin.longitude,
            s['lat'] as double,
            s['lng'] as double,
          );
          final km = meters / 1000;
          final walkMin = (meters / 80).round().clamp(1, 999);
          return {
            ...s,
            'distance': meters < 1000
                ? '${meters.round()} m'
                : '${km.toStringAsFixed(1)} km',
            'walkMin': walkMin,
            '_distMeters': meters,
          };
        }).toList()..sort(
          (a, b) => (a['_distMeters'] as double).compareTo(
            b['_distMeters'] as double,
          ),
        );
    return withDist.take(10).toList();
  }

  bool _showStationList = false;
  bool _activeRideRecoveryStarted = false;
  Map<String, dynamic>? _activeRideResumeParams;

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_recoverActiveRideThenLoadStations());
      }
    });
  }

  Future<void> _recoverActiveRideThenLoadStations() async {
    await _recoverActiveRide();
    if (!mounted) return;
    await _loadStationsFromApi();
  }

  // A locally-persisted ride older than this was abandoned, not paused; we
  // finalize it on recovery instead of resuming it. No legitimate single ride
  // runs this long, so this can never trip on a real in-progress ride.
  static const int _staleRideThresholdMs = 12 * 60 * 60 * 1000; // 12 hours

  // Finalize an abandoned/stale ride: best-effort close it on the server (so it
  // stops blocking new rides and stops accruing anything), then clear it
  // locally so Home shows no stale "Continue" banner.
  Future<void> _finalizeStaleRide(Map<String, dynamic> params) async {
    double d(dynamic v) => v is num ? v.toDouble() : 0.0;
    final serverId = LocalStorage.getActiveRideServerId();
    if (serverId != null && serverId.isNotEmpty) {
      try {
        final distance = d(params['distanceKm']);
        final movingSeconds = d(params['movingSeconds']);
        final avg = (distance > 0 && movingSeconds > 0)
            ? distance / (movingSeconds / 3600.0)
            : 0.0;
        await ref.read(rideRepositoryProvider).endRide(
              serverId,
              personal: (params['rideMode'] as num?)?.toInt() == 1,
              distance: distance,
              duration: movingSeconds,
              averageSpeed: avg,
              kcal: d(params['calories']),
              maxElevation: d(params['elevationGainM']),
            );
      } catch (_) {
        // The server-side reaper also closes abandoned trips, so it is safe to
        // proceed and clear the local state even if this call fails.
      }
    }
    await LocalStorage.clearActiveRide();
    if (!mounted) return;
    setState(() => _activeRideResumeParams = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ended a ride you had left open.'),
        duration: Duration(seconds: 3),
      ),
    );
  }

  Future<void> _recoverActiveRide() async {
    if (_activeRideRecoveryStarted) return;
    _activeRideRecoveryStarted = true;

    if (LocalStorage.hasActiveRide()) {
      final params = LocalStorage.getActiveRideParams();
      // A ride that started long ago and is still "active" locally was
      // abandoned (app killed, or the user forgot to end it). Don't offer to
      // resume it as a live ride — that produced the frozen "24:00:00" ride
      // screen the user could not get rid of, and (for wallet rides) risked a
      // runaway fare. Finalize it instead so the user can start clean.
      final startMs = (params['startTime'] as num?)?.toInt();
      final elapsedMs = startMs != null
          ? DateTime.now().millisecondsSinceEpoch - startMs
          : 0;
      if (elapsedMs > _staleRideThresholdMs) {
        await _finalizeStaleRide(params);
        return;
      }
      if (!mounted) return;
      setState(() => _activeRideResumeParams = params);
      return;
    }

    RideModel? activeRide;
    try {
      activeRide = await ref.read(rideRepositoryProvider).getActiveRide();
    } catch (_) {
      return;
    }

    if (!mounted || activeRide == null || activeRide.id.trim().isEmpty) {
      return;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startMs = activeRide.seconds > 0
        ? nowMs - (activeRide.seconds * 1000)
        : nowMs;
    final params = _activeRideParams(activeRide, startMs);

    await LocalStorage.saveActiveRide(params);
    await LocalStorage.saveActiveRideServerId(activeRide.id.trim());

    if (!mounted) return;
    setState(() => _activeRideResumeParams = params);
  }

  Map<String, dynamic> _activeRideParams(RideModel ride, int startMs) {
    final routePoints = ride.routePoints
        .map((p) => {'lat': p[0], 'lng': p[1]})
        .toList(growable: false);
    final hasLocation = _hasUsableTripLocation(ride);

    return {
      'rideMode': ride.rideMode,
      'isEBike': ride.isEBike,
      'paidWithCoin': ride.paidWithCoin,
      'bikeId': ride.bikeId,
      'startTime': startMs,
      'isPaused': false,
      'distanceKm': ride.distance,
      'currentSpeedKmh': 0.0,
      'maxSpeedKmh': ride.maxSpeed,
      'movingSeconds': 0.0,
      'calories': ride.calories,
      'elevationGainM': ride.elevation,
      'routePoints': routePoints,
      'routeSegments': routePoints.isEmpty ? const [] : [routePoints],
      'syncedRoutePointCount': routePoints.length,
      if (hasLocation) 'currentLat': ride.lat,
      if (hasLocation) 'currentLng': ride.lng,
    };
  }

  bool _hasUsableTripLocation(RideModel ride) {
    final validRange =
        ride.lat >= -90 &&
        ride.lat <= 90 &&
        ride.lng >= -180 &&
        ride.lng <= 180;
    if (!validRange) return false;
    if (ride.lat == 0 && ride.lng == 0) return false;

    const defaultLat = 17.4577;
    const defaultLng = 78.2753;
    final isFallbackDefault =
        (ride.lat - defaultLat).abs() < 0.000001 &&
        (ride.lng - defaultLng).abs() < 0.000001 &&
        ride.routePoints.isEmpty;
    return !isFallbackDefault;
  }

  Future<void> _loadStationsFromApi() async {
    final loc = _userLocation ?? _mapCenter;
    await ref
        .read(homeProvider.notifier)
        .loadStations(loc.latitude, loc.longitude);
    if (!mounted) return;

    final homeState = ref.read(homeProvider);
    if (homeState.stations.isNotEmpty) {
      setState(() {
        _stations = homeState.stations
            .map(
              (s) => <String, dynamic>{
                'id': s.id,
                'name': s.name,
                'lat': s.lat,
                'lng': s.lng,
                'bikes': s.currentCapacity,
                'ebikes': 0,
                'docks': s.capacity,
              },
            )
            .toList();
      });
    }
  }

  void _updateSelectedStation(Map<String, dynamic>? station) {
    setState(() {
      _selectedStation = station;
      _directionsRoute = const [];
    });
    _fetchDirections(station);
  }

  Future<void> _fetchDirections(Map<String, dynamic>? station) async {
    if (station == null) return;
    final from = _userLocation ?? _mapCenter;
    final to = LatLng(station['lat'] as double, station['lng'] as double);
    final requestId = ++_directionsRequestId;
    final route = await _directionsService.getRoute(from, to);
    // Ignore if a newer request started or the selection changed meanwhile.
    if (!mounted ||
        requestId != _directionsRequestId ||
        _selectedStation != station ||
        route.isEmpty) {
      return;
    }
    setState(() => _directionsRoute = route);
  }

  void _continueActiveRide() {
    final params =
        _activeRideResumeParams ??
        (LocalStorage.hasActiveRide()
            ? LocalStorage.getActiveRideParams()
            : null);
    if (params == null || params.isEmpty) return;
    context.push('/ride', extra: {...params, 'resume': true});
  }

  Future<void> _loadUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() {
          _userLocation = LatLng(pos.latitude, pos.longitude);
          _mapCenter = _userLocation!;
        });
        _mapController.move(_mapCenter, 15);
        _loadStationsFromApi();
      }
    } catch (_) {}
  }

  String _tileUrlFor(bool isDark) {
    switch (_selectedMapType) {
      case _terrainMap:
        return 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';
      case _satelliteMap:
      case _hybridMap:
        return 'https://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}';
      case _streetMap:
      default:
        return isDark
            ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
            : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
    }
  }

  List<String> _subdomainsFor() {
    switch (_selectedMapType) {
      case _terrainMap:
        return const ['a', 'b', 'c'];
      case _streetMap:
        return const ['a', 'b', 'c', 'd'];
      default:
        return const [];
    }
  }

  bool get _showHybridLabels => _selectedMapType == _hybridMap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: null, // Uses the shell drawer
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _mapCenter,
              initialZoom: 15,
              onMapReady: () {
                final loc = _userLocation;
                if (loc != null) {
                  _mapController.move(loc, 15);
                }
              },
            ),
            children: [
              TileLayer(
                urlTemplate: _tileUrlFor(isDark),
                subdomains: _subdomainsFor(),
                userAgentPackageName: 'com.newtra.app',
              ),
              if (_showHybridLabels)
                TileLayer(
                  urlTemplate: isDark
                      ? 'https://{s}.basemaps.cartocdn.com/dark_only_labels/{z}/{x}/{y}{r}.png'
                      : 'https://{s}.basemaps.cartocdn.com/light_only_labels/{z}/{x}/{y}{r}.png',
                  subdomains: const ['a', 'b', 'c', 'd'],
                  userAgentPackageName: 'com.newtra.app',
                ),
              PolylineLayer(polylines: _buildPolylines()),
              MarkerLayer(markers: _buildMarkers(isDark)),
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('OpenStreetMap contributors'),
                  TextSourceAttribution('CARTO'),
                  TextSourceAttribution('Esri'),
                ],
              ),
            ],
          ),

          // Top search bar
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 0),
              child: Row(
                children: [
                  // Menu button
                  _mapIconButton(
                    Icons.menu,
                    onTap: () => Scaffold.of(context).openDrawer(),
                  ),
                  SizedBox(width: 8.w),

                  // Search bar
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _showSearchSheet(context),
                      child: GlassContainer(
                        height: 48.h,
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        borderRadius: BorderRadius.circular(24.r),
                        child: Row(
                          children: [
                            Icon(
                              Icons.search,
                              size: 20.w,
                              color: isDark
                                  ? AppColors.grey300
                                  : AppColors.grey600,
                            ),
                            SizedBox(width: 12.w),
                            Text(
                              'Search stations...',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: isDark
                                    ? AppColors.grey400
                                    : AppColors.grey500,
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
          ),

          // Map type selector
          Positioned(
            right: 16.w,
            top:
                MediaQuery.of(context).padding.top +
                (_activeRideResumeParams == null ? 64.h : 126.h),
            child: Column(
              children: [
                _mapIconButton(
                  Icons.layers_outlined,
                  onTap: () {
                    setState(() {
                      _selectedMapType = (_selectedMapType + 1) % 4;
                    });
                  },
                ),
                SizedBox(height: 8.h),
                _mapIconButton(
                  Icons.my_location,
                  onTap: () {
                    final loc = _userLocation;
                    if (loc != null) {
                      _mapController.move(loc, 16);
                    } else {
                      _loadUserLocation();
                    }
                  },
                ),
                if (_selectedStation != null) ...[
                  SizedBox(height: 8.h),
                  _mapIconButton(
                    Icons.close,
                    onTap: () => _updateSelectedStation(null),
                  ),
                ],
              ],
            ),
          ),

          if (_activeRideResumeParams != null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 64.h,
              left: 16.w,
              right: 16.w,
              child: _ActiveRideBanner(
                params: _activeRideResumeParams!,
                isDark: isDark,
                onContinue: _continueActiveRide,
              ),
            ),

          // Directions banner
          if (_selectedStation != null)
            Positioned(
              bottom: _showStationList ? 390.h : 185.h,
              left: 16.w,
              right: 70.w,
              child: GlassContainer(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
                borderRadius: BorderRadius.circular(12.r),
                tint: AppColors.warning.withValues(alpha: 0.82),
                borderColor: Colors.white.withValues(alpha: 0.35),
                child: Row(
                  children: [
                    Icon(Icons.directions, color: Colors.white, size: 18.w),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Directions to ${_selectedStation!['name']}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _updateSelectedStation(null),
                      child: Icon(Icons.close, color: Colors.white, size: 16.w),
                    ),
                  ],
                ),
              ),
            ),

          // Bottom station panel
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy < -5) {
                  setState(() => _showStationList = true);
                } else if (details.delta.dy > 5) {
                  setState(() => _showStationList = false);
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                height: _showStationList ? 380.h : 175.h,
                child: ClipRRect(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(28.r),
                  ),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.72)
                            : Colors.white.withValues(alpha: 0.88),
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(28.r),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.10)
                                : Colors.black.withValues(alpha: 0.08),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Drag handle
                          Center(
                            child: Container(
                              width: 36.w,
                              height: 4.h,
                              margin: EdgeInsets.only(top: 10.h, bottom: 14.h),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.20)
                                    : Colors.black.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),
                          ),

                          // Header
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 20.w),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(7.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    size: 16.w,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                Text(
                                  'Nearby Stations',
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.grey900,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 7.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                  child: Text(
                                    '${_sortedStations.length}',
                                    style: TextStyle(
                                      fontSize: 10.sp,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () => setState(
                                    () => _showStationList = !_showStationList,
                                  ),
                                  child: Row(
                                    children: [
                                      Text(
                                        _showStationList
                                            ? 'Collapse'
                                            : 'See All',
                                        style: TextStyle(
                                          fontSize: 12.sp,
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      SizedBox(width: 2.w),
                                      AnimatedRotation(
                                        turns: _showStationList ? 0.5 : 0,
                                        duration: const Duration(
                                          milliseconds: 300,
                                        ),
                                        child: Icon(
                                          Icons.expand_more_rounded,
                                          size: 16.w,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(height: 12.h),

                          // Station list
                          Expanded(
                            child: ListView.builder(
                              padding: EdgeInsets.fromLTRB(
                                16.w,
                                0,
                                16.w,
                                MediaQuery.of(context).padding.bottom,
                              ),
                              itemCount: _sortedStations.length,
                              itemBuilder: (context, index) {
                                final station = _sortedStations[index];
                                return _StationCard(
                                  station: station,
                                  isDark: isDark,
                                  onTap: () =>
                                      _showStationInfo(context, station),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Scan QR FAB
          Positioned(
            bottom: _showStationList ? 390.h : 185.h,
            right: 16.w,
            child: FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => context.go('/bikes'),
              child: Icon(
                Icons.qr_code_scanner,
                color: AppColors.white,
                size: 26.w,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapIconButton(IconData icon, {VoidCallback? onTap}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: GlassContainer(
        width: 44.w,
        height: 44.w,
        borderRadius: BorderRadius.circular(22.r),
        child: Icon(
          icon,
          size: 22.w,
          color: isDark ? Colors.white : AppColors.grey800,
        ),
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (_, scrollController) {
            return Column(
              children: [
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search stations...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _sortedStations.length,
                    itemBuilder: (_, i) {
                      final station = _sortedStations[i];
                      return ListTile(
                        leading: const Icon(
                          Icons.ev_station,
                          color: AppColors.primary,
                        ),
                        title: Text(station['name'] as String),
                        subtitle: Text(station['distance'] as String),
                        trailing: Text(
                          '${station['bikes']} bikes',
                          style: const TextStyle(color: AppColors.primary),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          _showStationInfo(context, station);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Marker> _buildMarkers(bool isDark) {
    final markers = _sortedStations.map((station) {
      return Marker(
        point: LatLng(station['lat'] as double, station['lng'] as double),
        width: 61,
        height: 61,
        child: GestureDetector(
          onTap: () => _showStationInfo(context, station),
          child: Padding(
            padding: EdgeInsets.all(4.w),
            child: SvgPicture.asset(
              AppAssets.iconLogoForTheme(isDark),
              fit: BoxFit.contain,
            ),
          ),
        ),
      );
    }).toList();

    final loc = _userLocation;
    if (loc != null) {
      markers.add(
        Marker(
          point: loc,
          width: 30,
          height: 30,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF2196F3),
              border: Border.all(color: Colors.white, width: 3),
            ),
          ),
        ),
      );
    }

    return markers;
  }

  List<Polyline> _buildPolylines() {
    final sel = _selectedStation;
    if (sel == null) return const [];
    final from = _userLocation ?? _mapCenter;
    final to = LatLng(sel['lat'] as double, sel['lng'] as double);
    // Prefer the road-following route; fall back to a straight line until it
    // resolves (or if routing is unavailable).
    final points =
        _directionsRoute.isNotEmpty ? _directionsRoute : <LatLng>[from, to];
    return [
      Polyline(points: points, color: AppColors.primary, strokeWidth: 4),
    ];
  }

  Color _availColor(Map<String, dynamic> s) {
    final avail = (s['bikes'] as int) + (s['ebikes'] as int);
    final total = s['docks'] as int;
    final pct = avail / total;
    if (pct >= 0.5) return AppColors.success;
    if (pct >= 0.25) return AppColors.warning;
    return AppColors.error;
  }

  String _availLabel(Map<String, dynamic> s) {
    final avail = (s['bikes'] as int) + (s['ebikes'] as int);
    final total = s['docks'] as int;
    final pct = avail / total;
    if (pct >= 0.5) return 'Available';
    if (pct >= 0.25) return 'Limited';
    return 'Low';
  }

  void _showStationInfo(BuildContext context, Map<String, dynamic> station) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bikes = station['bikes'] as int;
    final ebikes = station['ebikes'] as int;
    final docks = station['docks'] as int;
    final total = bikes + ebikes;
    final occupancy = total / docks;
    final statusColor = _availColor(station);
    final statusLabel = _availLabel(station);
    final cardBg = isDark ? const Color(0xFF161B22) : Colors.white;
    final bg = isDark ? const Color(0xFF0D1117) : AppColors.grey50;
    final labelColor = isDark
        ? Colors.white.withValues(alpha: 0.45)
        : AppColors.grey500;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Container(
          margin: EdgeInsets.fromLTRB(10.w, 0, 10.w, 10.h),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(28.r),
          ),
          // Limit height so it never overflows the screen
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.82,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36.w,
                    height: 4.h,
                    margin: EdgeInsets.only(top: 12.h, bottom: 8.h),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : AppColors.grey300,
                      borderRadius: BorderRadius.circular(2.r),
                    ),
                  ),
                ),

                // Header band
                Container(
                  margin: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 0),
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 54.w,
                        height: 54.w,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.primary.withValues(alpha: 0.20),
                              AppColors.primary.withValues(alpha: 0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16.r),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(
                          Icons.pedal_bike_rounded,
                          size: 26.w,
                          color: AppColors.primary,
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              station['name'] as String,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.grey900,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 5.h),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on_rounded,
                                  size: 12.w,
                                  color: AppColors.grey500,
                                ),
                                SizedBox(width: 3.w),
                                Flexible(
                                  child: Text(
                                    station['distance'] as String,
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.grey500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Icon(
                                  Icons.directions_walk_rounded,
                                  size: 12.w,
                                  color: AppColors.grey500,
                                ),
                                SizedBox(width: 3.w),
                                Flexible(
                                  child: Text(
                                    '~${station['walkMin']} min',
                                    style: TextStyle(
                                      fontSize: 12.sp,
                                      color: AppColors.grey500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10.r),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.30),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6.w,
                              height: 6.w,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            SizedBox(width: 5.w),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10.h),

                // Availability boxes
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18.r),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 46.w,
                                height: 46.w,
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.10,
                                  ),
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                child: Icon(
                                  Icons.pedal_bike_rounded,
                                  size: 24.w,
                                  color: AppColors.primary,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$bikes',
                                  style: TextStyle(
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.grey900,
                                  ),
                                ),
                              ),
                              Text(
                                'Regular Bikes',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: labelColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Container(
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(18.r),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 46.w,
                                height: 46.w,
                                decoration: BoxDecoration(
                                  color: AppColors.info.withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                child: Icon(
                                  Icons.electric_bike_rounded,
                                  size: 24.w,
                                  color: AppColors.info,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '$ebikes',
                                  style: TextStyle(
                                    fontSize: 28.sp,
                                    fontWeight: FontWeight.w900,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.grey900,
                                  ),
                                ),
                              ),
                              Text(
                                'E-Bikes',
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  color: labelColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 10.h),

                // Occupancy bar
                Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w),
                  padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(18.r),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Dock Availability',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.white
                                    : AppColors.grey900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Flexible(
                            child: Text(
                              '$total / $docks bikes',
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: labelColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4.r),
                        child: LinearProgressIndicator(
                          value: occupancy.clamp(0.0, 1.0),
                          minHeight: 8.h,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 14.h),

                // Action buttons
                Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            final dest = LatLng(
                              station['lat'] as double,
                              station['lng'] as double,
                            );
                            Navigator.pop(ctx);
                            // Update state immediately — no blocking delay
                            _updateSelectedStation(station);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _mapController.move(dest, 15.5);
                            });
                          },
                          child: Container(
                            height: 50.h,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : AppColors.grey100,
                              borderRadius: BorderRadius.circular(16.r),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.12)
                                    : AppColors.grey200,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.directions_rounded,
                                  size: 18.w,
                                  color: isDark
                                      ? Colors.white
                                      : AppColors.grey800,
                                ),
                                SizedBox(width: 7.w),
                                Text(
                                  'Directions',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : AppColors.grey800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(ctx);
                            context.go('/bikes');
                          },
                          child: Container(
                            height: 50.h,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  AppColors.primary,
                                  AppColors.primaryDark,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16.r),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.35,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.qr_code_scanner_rounded,
                                  size: 18.w,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 7.w),
                                Text(
                                  'Scan & Ride',
                                  style: TextStyle(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActiveRideBanner extends StatelessWidget {
  final Map<String, dynamic> params;
  final bool isDark;
  final VoidCallback onContinue;

  const _ActiveRideBanner({
    required this.params,
    required this.isDark,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final bikeId = (params['bikeId'] as String?)?.trim();
    final rideMode = params['rideMode'] == 1 ? 'recording' : 'ride';
    final title = bikeId == null || bikeId.isEmpty
        ? 'Active $rideMode in progress'
        : 'Active $rideMode · $bikeId';

    return GlassContainer(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      borderRadius: BorderRadius.circular(16.r),
      tint: isDark
          ? Colors.black.withValues(alpha: 0.70)
          : Colors.white.withValues(alpha: 0.88),
      borderColor: isDark
          ? Colors.white.withValues(alpha: 0.12)
          : Colors.black.withValues(alpha: 0.08),
      child: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.route_rounded,
              size: 19.w,
              color: AppColors.primary,
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.grey900,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: 10.w),
          TextButton.icon(
            onPressed: onContinue,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: Icon(Icons.arrow_forward_rounded, size: 17.w),
            label: Text(
              'Continue',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationCard extends StatelessWidget {
  final Map<String, dynamic> station;
  final bool isDark;
  final VoidCallback? onTap;

  const _StationCard({required this.station, required this.isDark, this.onTap});

  Color get _statusColor {
    final avail = (station['bikes'] as int) + (station['ebikes'] as int);
    final total = station['docks'] as int;
    final pct = avail / total;
    if (pct >= 0.5) return AppColors.success;
    if (pct >= 0.25) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final bikes = station['bikes'] as int;
    final ebikes = station['ebikes'] as int;
    final docks = station['docks'] as int;
    final total = bikes + ebikes;
    final statusColor = _statusColor;
    final cardBg = isDark ? const Color(0xFF1A2030) : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18.r),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.25)
                  : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 12.h, 14.w, 10.h),
                child: Row(
                  children: [
                    // Icon
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(
                        Icons.pedal_bike_rounded,
                        size: 22.w,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 12.w),

                    // Name + distance
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            station['name'] as String,
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : AppColors.grey900,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 3.h),
                          Row(
                            children: [
                              Icon(
                                Icons.directions_walk_rounded,
                                size: 11.w,
                                color: AppColors.grey500,
                              ),
                              SizedBox(width: 3.w),
                              Flexible(
                                child: Text(
                                  '${station['distance']} · ~${station['walkMin']} min',
                                  style: TextStyle(
                                    fontSize: 11.sp,
                                    color: AppColors.grey500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    SizedBox(width: 10.w),

                    // Bike count chips
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _miniChip(
                          Icons.pedal_bike_rounded,
                          '$bikes',
                          AppColors.primary,
                          isDark,
                        ),
                        SizedBox(height: 4.h),
                        _miniChip(
                          Icons.electric_bike_rounded,
                          '$ebikes',
                          AppColors.info,
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Availability bar
              Padding(
                padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 10.h),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3.r),
                        child: LinearProgressIndicator(
                          value: (total / docks).clamp(0.0, 1.0),
                          minHeight: 4.h,
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.07)
                              : Colors.black.withValues(alpha: 0.06),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            statusColor,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Container(
                      width: 7.w,
                      height: 7.w,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '$total/$docks',
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.grey500,
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

  Widget _miniChip(IconData icon, String label, Color color, bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.w, color: color),
          SizedBox(width: 3.w),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 36.w),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
