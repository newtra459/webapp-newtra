import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/transit_model.dart';
import '../providers/transit_provider.dart';

class TransitBoardScreen extends ConsumerStatefulWidget {
  final String stopId;
  final String vehicleId;
  final String stopName;
  final String transitType; // 'bus' | 'buggy'
  final String route;
  final String vehicleName;
  final String vehicleNumber;
  final String vehicleImageUrl;

  const TransitBoardScreen({
    super.key,
    required this.stopId,
    this.vehicleId = '',
    required this.stopName,
    required this.transitType,
    required this.route,
    this.vehicleName = '',
    this.vehicleNumber = '',
    this.vehicleImageUrl = '',
  });

  @override
  ConsumerState<TransitBoardScreen> createState() => _TransitBoardScreenState();
}

class _TransitBoardScreenState extends ConsumerState<TransitBoardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  bool _flashOn = false;
  bool _scanned = false;
  bool _isProcessingScan = false;

  // Populated after QR decode — unknown until scan
  String _decodedVehicleName = '';
  String _decodedVehicleNumber = '';
  String _decodedVehicleImageUrl = '';

  late final AnimationController _scanCtrl;
  late final Animation<double> _scanPos;
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;

  late final MobileScannerController _cameraController;

  Color get _typeColor => widget.transitType == 'buggy'
      ? AppColors.primary
      : const Color(0xFFFF8F00);

  IconData get _typeIcon => widget.transitType == 'buggy'
      ? Icons.airport_shuttle_rounded
      : Icons.directions_bus_rounded;

  String get _vehicleLabel =>
      widget.transitType == 'buggy' ? 'Buggy' : 'Bus';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final active = await ref.read(transitProvider.notifier).checkActiveTrip();
      if (!mounted || active == null) return;
      context.pushReplacement('/transit/active', extra: {
        'tripId': active.id,
        'stopName': active.stopName,
        'type': active.type,
        'route': active.route,
        'vehicleName': active.vehicleName,
        'vehicleNumber': active.vehicleNumber,
        'vehicleImageUrl': active.vehicleImageUrl ?? '',
        'startTime': active.startTime,
      });
    });
    _scanCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _scanPos = CurvedAnimation(parent: _scanCtrl, curve: Curves.easeInOut);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _pulseAnim =
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut);
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanCtrl.dispose();
    _pulseCtrl.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _scanned || _isProcessingScan) return;
    switch (state) {
      case AppLifecycleState.resumed:
        _safeStartCamera();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _safeStopCamera();
        break;
    }
  }

  void _onQrDetected(BarcodeCapture capture) {
    if (_scanned) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;

    final vehicleId = barcode.rawValue!.trim();

    if (vehicleId.isEmpty) {
      _handleInvalidScan('Invalid transit QR. Please scan the vehicle QR.');
      return;
    }
    if (widget.vehicleId.isNotEmpty && vehicleId != widget.vehicleId) {
      _handleInvalidScan(
        'This QR does not match the selected ${_vehicleLabel.toLowerCase()}.',
      );
      return;
    }

    _performBoarding(vehicleId);
  }

  void _handleInvalidScan(String message) {
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _restartScanner() async {
    if (!mounted) return;
    setState(() {
      _scanned = false;
      _isProcessingScan = false;
    });
    _scanCtrl.repeat(reverse: true);
    await _safeStartCamera();
  }

  void _showScanHint() {
    HapticFeedback.selectionClick();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Point the camera at the QR code inside the vehicle.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _performBoarding(String vehicleId) async {
    if (_scanned || _isProcessingScan) return;
    _isProcessingScan = true;
    if (mounted) {
      setState(() => _scanned = true);
    }
    _scanCtrl.stop();
    await _safeStopCamera();
    HapticFeedback.mediumImpact();

    final trip = await ref.read(transitProvider.notifier).boardVehicle(
      vehicleId: vehicleId,
      stopId: widget.stopId,
    );

    if (!mounted) return;

    if (trip == null) {
      final errorMessage = ref.read(transitProvider).error;
      await _restartScanner();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            errorMessage?.isNotEmpty == true
                ? errorMessage!
                : 'Unable to board. Scan a valid transit QR and try again.',
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    _isProcessingScan = false;

    if (trip.vehicleName.isNotEmpty) _decodedVehicleName = trip.vehicleName;
    if (trip.vehicleNumber.isNotEmpty) _decodedVehicleNumber = trip.vehicleNumber;
    if (trip.vehicleImageUrl != null && trip.vehicleImageUrl!.isNotEmpty) {
      _decodedVehicleImageUrl = trip.vehicleImageUrl!;
    }

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _showBoardedSheet(trip);
    });
  }

  Future<void> _safeStartCamera() async {
    try {
      await _cameraController.start();
    } catch (_) {}
  }

  Future<void> _safeStopCamera() async {
    try {
      await _cameraController.stop();
    } catch (_) {}
  }

  void _showBoardedSheet(TransitTripModel trip) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _BoardedSheet(
        vehicleLabel: _vehicleLabel,
        stopName: trip.stopName,
        route: trip.route,
        typeColor: _typeColor,
        typeIcon: _typeIcon,
        vehicleName: _decodedVehicleName,
        vehicleNumber: _decodedVehicleNumber,
        vehicleImageUrl: _decodedVehicleImageUrl,
        onDone: () {
          Navigator.pop(context); // close the boarded sheet
          context.pushReplacement('/transit/active', extra: {
            'tripId': trip.id,
            'stopName': trip.stopName,
            'type': trip.type,
            'route': trip.route,
            'vehicleName': trip.vehicleName,
            'vehicleNumber': trip.vehicleNumber,
            'vehicleImageUrl': trip.vehicleImageUrl ?? '',
            'startTime': trip.startTime,
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            MobileScanner(
              controller: _cameraController,
              onDetect: _onQrDetected,
            ),
            _VignetteOverlay(),
            Center(
              child: _ScanFrame(
                typeColor: _typeColor,
                scanned: _scanned,
                scanPos: _scanPos,
                pulseAnim: _pulseAnim,
              ),
            ),
            SafeArea(
              child: Padding(
                padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 1),
                        ),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white, size: 16.w),
                      ),
                    ),
                    const Spacer(),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(_typeIcon, size: 14.w, color: _typeColor),
                            SizedBox(width: 5.w),
                            Text(
                              'Scan to Board',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          widget.stopName,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.60),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        _cameraController.toggleTorch();
                        setState(() => _flashOn = !_flashOn);
                      },
                      child: Container(
                        width: 40.w,
                        height: 40.w,
                        decoration: BoxDecoration(
                          color: _flashOn
                              ? Colors.white.withValues(alpha: 0.25)
                              : Colors.white.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.20),
                              width: 1),
                        ),
                        child: Icon(
                          _flashOn
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          color: _flashOn ? AppColors.primary : AppColors.white,
                          size: 18.w,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _BottomPanel(
                isDark: isDark,
                vehicleLabel: _vehicleLabel,
                typeColor: _typeColor,
                typeIcon: _typeIcon,
                route: widget.route,
                scanned: _scanned,
                onScan: _showScanHint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Vignette overlay ───────────────────────────────────────────────────

class _VignetteOverlay extends StatelessWidget {
  const _VignetteOverlay();

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return IgnorePointer(
      child: Column(
        children: [
          Container(
            height: h * 0.22,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.85),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: h * 0.48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.95),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Scan frame with animated line ────────────────────────────────────

class _ScanFrame extends StatelessWidget {
  final Color typeColor;
  final bool scanned;
  final Animation<double> scanPos;
  final Animation<double> pulseAnim;
  const _ScanFrame({
    required this.typeColor,
    required this.scanned,
    required this.scanPos,
    required this.pulseAnim,
  });

  @override
  Widget build(BuildContext context) {
    final size = 230.w;

    if (scanned) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.success, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.25),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: Center(
          child: Icon(Icons.check_circle_rounded,
              size: 72.w, color: AppColors.success),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Scan line
          AnimatedBuilder(
            animation: scanPos,
            builder: (context, _) => Positioned(
              top: scanPos.value * (size - 3),
              left: 16.w,
              right: 16.w,
              child: Container(
                height: 2.5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      typeColor.withValues(alpha: 0.8),
                      typeColor,
                      typeColor.withValues(alpha: 0.8),
                      Colors.transparent,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                        color: typeColor.withValues(alpha: 0.5),
                        blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
          // Corner brackets
          _bracket(size, typeColor, top: true, left: true),
          _bracket(size, typeColor, top: true, left: false),
          _bracket(size, typeColor, top: false, left: true),
          _bracket(size, typeColor, top: false, left: false),
          // Pulse ring
          AnimatedBuilder(
            animation: pulseAnim,
            builder: (context, _) => Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: typeColor.withValues(alpha: pulseAnim.value * 0.18),
                  width: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bracket(double size, Color color,
      {required bool top, required bool left}) {
    const cSize = 24.0;
    final child = SizedBox(
      width: cSize,
      height: cSize,
      child: CustomPaint(
        painter: _CornerPainter(
            color: color, thickness: 3.5, top: top, left: left),
      ),
    );
    return top
        ? left
            ? Positioned(top: 0, left: 0, child: child)
            : Positioned(top: 0, right: 0, child: child)
        : left
            ? Positioned(bottom: 0, left: 0, child: child)
            : Positioned(bottom: 0, right: 0, child: child);
  }
}

// ── Bottom panel ─────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  final bool isDark;
  final String vehicleLabel;
  final Color typeColor;
  final IconData typeIcon;
  final String route;
  final bool scanned;
  final VoidCallback onScan;

  const _BottomPanel({
    required this.isDark,
    required this.vehicleLabel,
    required this.typeColor,
    required this.typeIcon,
    required this.route,
    required this.scanned,
    required this.onScan,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? AppColors.darkCard : AppColors.white;
    final subBg =
        isDark ? AppColors.darkSurface : AppColors.grey100;
    final ticketBorder = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 32.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────────
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.15)
                    : Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 14.h),

          // ── Boarding pass ticket ───────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: subBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: ticketBorder, width: 1),
            ),
            child: Column(
              children: [
                // Header strip: route + BOARDING badge
                Container(
                  padding:
                      EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
                  decoration: BoxDecoration(
                    color: typeColor,
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(15.r)),
                  ),
                  child: Row(
                    children: [
                      Icon(typeIcon, color: Colors.white, size: 20.w),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          '$vehicleLabel · $route',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.20),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          'BOARDING',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Perforation divider
                Row(
                  children: [
                    Container(
                      width: 16.w,
                      height: 16.w,
                      decoration: BoxDecoration(
                        color: cardBg,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(builder: (_, box) {
                        const dashW = 6.0;
                        const dashGap = 4.0;
                        final count =
                            (box.maxWidth / (dashW + dashGap)).floor();
                        return Row(
                          children: List.generate(
                            count,
                            (i) => Padding(
                              padding: EdgeInsets.only(
                                  right: i < count - 1 ? dashGap : 0),
                              child: Container(
                                width: dashW,
                                height: 1.5,
                                color: ticketBorder,
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    Container(
                      width: 16.w,
                      height: 16.w,
                      decoration: BoxDecoration(
                        color: cardBg,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),

                // Three pass fields: PAYMENT · MODE · STATUS
                Padding(
                  padding:
                      EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 14.h),
                  child: Row(
                    children: [
                      _passField(
                        'PAYMENT',
                        'Subscription',
                        Icons.card_membership_rounded,
                        isDark,
                      ),
                      Container(
                        width: 1,
                        height: 32.h,
                        margin:
                            EdgeInsets.symmetric(horizontal: 12.w),
                        color: ticketBorder,
                      ),
                      _passField(
                        'MODE',
                        vehicleLabel,
                        typeIcon,
                        isDark,
                        color: typeColor,
                      ),
                      Container(
                        width: 1,
                        height: 32.h,
                        margin:
                            EdgeInsets.symmetric(horizontal: 12.w),
                        color: ticketBorder,
                      ),
                      _passField(
                        'STATUS',
                        'Open',
                        Icons.check_circle_outline_rounded,
                        isDark,
                        color: AppColors.success,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 14.h),

          // Instruction
          Text(
            'Aim camera at the QR code displayed inside the vehicle',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.sp, color: AppColors.grey500, height: 1.4),
          ),

          SizedBox(height: 14.h),

          // Scan button
          SizedBox(
            width: double.infinity,
            height: 50.h,
          child: ElevatedButton(
            onPressed: scanned ? null : onScan,
              style: ElevatedButton.styleFrom(
                backgroundColor: typeColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.success.withValues(alpha: 0.75),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    scanned
                        ? Icons.check_rounded
                        : Icons.qr_code_scanner_rounded,
                    size: 20.w,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    scanned ? 'Scanned!' : 'Awaiting QR Scan',
                    style: TextStyle(
                        fontSize: 15.sp, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _passField(
    String label,
    String value,
    IconData icon,
    bool isDark, {
    Color? color,
  }) {
    final textColor = isDark ? Colors.white : AppColors.grey900;
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 16.w, color: color ?? AppColors.grey500),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: 1.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 9.sp,
              color: AppColors.grey500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top;
  final bool left;

  _CornerPainter({
    required this.color,
    required this.thickness,
    required this.top,
    required this.left,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final path = Path();
    if (top && left) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (top && !left) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!top && left) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(0, size.height);
      path.lineTo(size.width, size.height);
      path.lineTo(size.width, 0);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_CornerPainter old) => false;
}

// ── Boarded confirmation sheet ───────────────────────────────────────────────

class _BoardedSheet extends StatelessWidget {
  final String vehicleLabel;
  final String stopName;
  final String route;
  final Color typeColor;
  final IconData typeIcon;
  final String vehicleName;
  final String vehicleNumber;
  final String vehicleImageUrl;
  final VoidCallback onDone;

  const _BoardedSheet({
    required this.vehicleLabel,
    required this.stopName,
    required this.route,
    required this.typeColor,
    required this.typeIcon,
    required this.onDone,
    this.vehicleName = '',
    this.vehicleNumber = '',
    this.vehicleImageUrl = '',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkCard : AppColors.white;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            24.w, 20.h, 24.w, MediaQuery.of(context).padding.bottom + 24.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
          SizedBox(height: 24.h),

          Container(
            width: 72.w,
            height: 72.w,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.success.withValues(alpha: 0.22),
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Icon(Icons.check_circle_rounded,
                size: 40.w, color: AppColors.success),
          ),

          SizedBox(height: 14.h),

          Text(
            'Boarded!',
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.grey900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '$vehicleLabel · $route',
            style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
          ),

          // Vehicle name + number
          if (vehicleName.isNotEmpty || vehicleNumber.isNotEmpty) ...
            [
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: 14.w, vertical: 10.h),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                      color: typeColor.withValues(alpha: 0.22), width: 1),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: vehicleImageUrl.isNotEmpty
                          ? Image.network(
                              vehicleImageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                typeIcon,
                                size: 22.w,
                                color: typeColor,
                              ),
                            )
                          : Icon(typeIcon, size: 22.w, color: typeColor),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (vehicleName.isNotEmpty)
                            Text(
                              vehicleName,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? AppColors.white
                                    : AppColors.grey900,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          if (vehicleNumber.isNotEmpty)
                            Text(
                              vehicleNumber,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: typeColor,
                                letterSpacing: 0.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

          SizedBox(height: 20.h),

          Container(
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _tripItem(Icons.location_on_rounded, 'Stop', stopName, isDark),
                Container(
                    width: 1,
                    height: 32.h,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08)),
                _tripItem(
                    Icons.access_time_rounded, 'Time', 'Now', isDark),
                Container(
                    width: 1,
                    height: 32.h,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.08)),
                _tripItem(typeIcon, 'Type', vehicleLabel, isDark,
                    iconColor: typeColor),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          SizedBox(
            width: double.infinity,
            height: 50.h,
            child: ElevatedButton(
              onPressed: onDone,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14.r),
                ),
              ),
              child: Text(
                'Done',
                style: TextStyle(
                    fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _tripItem(IconData icon, String label, String value, bool isDark,
      {Color? iconColor}) {
    return Flexible(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18.w, color: iconColor ?? AppColors.grey500),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.grey900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 1.h),
          Text(label,
              style: TextStyle(
                  fontSize: 10.sp, color: AppColors.grey500),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}



// ── Boarded confirmation sheet ────────────────────────────────────────────────
