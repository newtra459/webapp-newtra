import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:latlong2/latlong.dart';
import '../constants/app_assets.dart';

/// A point in geographic coordinates.
class RoutePoint {
  final double lat;
  final double lng;
  const RoutePoint(this.lat, this.lng);
  LatLng get latLng => LatLng(lat, lng);
}

/// Type of trip — determines colour scheme.
enum TripType { cycle, bus, buggy }

/// Apple Fitness-style route map.
///
/// Free map tile layer with a branded route polyline and start/end markers.
class RouteMapWidget extends StatefulWidget {
  final List<RoutePoint> points;
  final List<List<RoutePoint>> segments;
  final TripType type;
  final double height;
  final BorderRadius? borderRadius;

  const RouteMapWidget({
    super.key,
    required this.points,
    this.segments = const [],
    this.type = TripType.cycle,
    this.height = 200,
    this.borderRadius,
  });

  @override
  State<RouteMapWidget> createState() => RouteMapWidgetState();
}

class RouteMapWidgetState extends State<RouteMapWidget> {
  final MapController _previewCtrl = MapController();
  final GlobalKey _mapCaptureKey = GlobalKey();

  List<List<RoutePoint>> get _segments {
    if (widget.segments.isNotEmpty) return widget.segments;
    if (widget.points.isNotEmpty) return [widget.points];
    return const [];
  }

  List<RoutePoint> get _allPoints =>
      _segments.expand((segment) => segment).toList(growable: false);

  /// Captures the current map view as PNG bytes for sharing.
  Future<Uint8List?> takeSnapshot() async {
    final boundary =
        _mapCaptureKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  List<Polyline> _buildPolylines() {
    return _segments
        .where((segment) => segment.length >= 2)
        .map(
          (segment) => Polyline(
            points: segment.map((p) => p.latLng).toList(),
            color: const Color(0xFF00A877),
            strokeWidth: 9,
          ),
        )
        .toList();
  }

  // ── Camera ───────────────────────────────────────────────────────────────

  LatLng get _center {
    if (_allPoints.isEmpty) return const LatLng(0, 0);
    final lats = _allPoints.map((p) => p.lat).toList();
    final lngs = _allPoints.map((p) => p.lng).toList();
    return LatLng(
      (lats.reduce(math.min) + lats.reduce(math.max)) / 2,
      (lngs.reduce(math.min) + lngs.reduce(math.max)) / 2,
    );
  }

  double get _zoom {
    if (_allPoints.length < 2) return 15.0;
    final lats = _allPoints.map((p) => p.lat).toList();
    final lngs = _allPoints.map((p) => p.lng).toList();
    final span = math.max(
      lats.reduce(math.max) - lats.reduce(math.min),
      lngs.reduce(math.max) - lngs.reduce(math.min),
    );
    if (span < 0.003) return 16.5;
    if (span < 0.007) return 15.5;
    if (span < 0.015) return 14.5;
    return 13.5;
  }

  void _showFullRoute() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FullRouteSheet(
        points: _allPoints,
        segments: _segments,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final radius = widget.borderRadius ?? BorderRadius.circular(16.r);
    final tileUrl = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    return ClipRRect(
      borderRadius: radius,
      child: SizedBox(
        height: widget.height.h,
        width: double.infinity,
        child: RepaintBoundary(
          key: _mapCaptureKey,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _previewCtrl,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: _zoom,
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                ),
                children: [
                  TileLayer(
                    urlTemplate: tileUrl,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.newtra.app',
                  ),
                  PolylineLayer(polylines: _buildPolylines()),
                  MarkerLayer(
                    markers: [
                      if (_allPoints.isNotEmpty)
                        Marker(
                          point: _allPoints.first.latLng,
                          width: 28,
                          height: 28,
                          child: _dotMarker(const Color(0xFF34C759)),
                        ),
                      if (_allPoints.length >= 2)
                        Marker(
                          point: _allPoints.last.latLng,
                          width: 28,
                          height: 28,
                          child: _dotMarker(const Color(0xFFFF3B30)),
                        ),
                    ],
                  ),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                      TextSourceAttribution('CARTO'),
                    ],
                  ),
                ],
              ),

              // Tap anywhere → open full-screen route view
              Positioned.fill(
                child: GestureDetector(
                  onTap: _showFullRoute,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),

              Positioned(
                left: 10.w,
                top: 10.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.45)
                        : Colors.white.withValues(alpha: 0.70),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: SvgPicture.asset(
                    AppAssets.fullLogoForTheme(isDark),
                    height: 16.h,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dotMarker(Color fill) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}

// ── Full-screen route sheet ───────────────────────────────────────────────────

class _FullRouteSheet extends StatefulWidget {
  final List<RoutePoint> points;
  final List<List<RoutePoint>> segments;

  const _FullRouteSheet({
    required this.points,
    this.segments = const [],
  });

  @override
  State<_FullRouteSheet> createState() => _FullRouteSheetState();
}

class _FullRouteSheetState extends State<_FullRouteSheet> {
  final MapController _ctrl = MapController();

  List<List<RoutePoint>> get _segments {
    if (widget.segments.isNotEmpty) return widget.segments;
    if (widget.points.isNotEmpty) return [widget.points];
    return const [];
  }

  List<RoutePoint> get _allPoints =>
      _segments.expand((segment) => segment).toList(growable: false);

  LatLng get _center {
    if (_allPoints.isEmpty) return const LatLng(0, 0);
    final lats = _allPoints.map((p) => p.lat).toList();
    final lngs = _allPoints.map((p) => p.lng).toList();
    return LatLng(
      (lats.reduce(math.min) + lats.reduce(math.max)) / 2,
      (lngs.reduce(math.min) + lngs.reduce(math.max)) / 2,
    );
  }

  LatLngBounds get _bounds =>
      LatLngBounds.fromPoints(_allPoints.map((e) => e.latLng).toList());

  double get _previewZoom {
    if (_allPoints.length < 2) return 15.0;
    final lats = _allPoints.map((p) => p.lat).toList();
    final lngs = _allPoints.map((p) => p.lng).toList();
    final span = math.max(
      lats.reduce(math.max) - lats.reduce(math.min),
      lngs.reduce(math.max) - lngs.reduce(math.min),
    );
    if (span < 0.003) return 16.0;
    if (span < 0.007) return 15.0;
    if (span < 0.015) return 14.0;
    return 13.0;
  }

  List<Polyline> get _polylines => _segments
      .where((segment) => segment.length >= 2)
      .map(
        (segment) => Polyline(
          points: segment.map((p) => p.latLng).toList(),
          color: const Color(0xFF00A877),
          strokeWidth: 11,
        ),
      )
      .toList();

  List<Marker> get _markers => [
        if (_allPoints.isNotEmpty)
          Marker(
            point: _allPoints.first.latLng,
            width: 28,
            height: 28,
            child: _dotMarker(const Color(0xFF34C759)),
          ),
        if (_allPoints.length >= 2)
          Marker(
            point: _allPoints.last.latLng,
            width: 28,
            height: 28,
            child: _dotMarker(const Color(0xFFFF3B30)),
          ),
      ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final logoAsset = AppAssets.fullLogoForTheme(isDark);
    final tileUrl = isDark
      ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
      : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';

    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.97,
      builder: (_, __) => Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle + logo header
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 8.h),
              child: Column(
                children: [
                  Container(
                    width: 40.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black26,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      SvgPicture.asset(logoAsset, height: 22.h),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          padding: EdgeInsets.all(6.r),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.black12,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            size: 18.r,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Full interactive map
            Expanded(
              child: FlutterMap(
                mapController: _ctrl,
                options: MapOptions(
                  initialCenter: _center,
                  initialZoom: _previewZoom,
                ),
                children: [
                  TileLayer(
                    urlTemplate: tileUrl,
                    subdomains: const ['a', 'b', 'c', 'd'],
                    userAgentPackageName: 'com.newtra.app',
                  ),
                  PolylineLayer(polylines: _polylines),
                  MarkerLayer(markers: _markers),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('OpenStreetMap contributors'),
                      TextSourceAttribution('CARTO'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dotMarker(Color fill) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}
