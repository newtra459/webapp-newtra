import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../home/data/models/station_model.dart';
import '../../../home/data/repositories/home_repository_impl.dart';
import '../../data/repositories/ride_repository_impl.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final RideRepositoryImpl _rideRepository = RideRepositoryImpl(ApiClient());
  bool _flashOn = false;
  int _selectedMode = 0; // 0 = Scan Bike, 1 = Record Ride

  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLine;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulse;
  late final MobileScannerController _cameraController;
  final GlobalKey<_RecordRideMapPreviewState> _recordRideMapKey =
      GlobalKey<_RecordRideMapPreviewState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _scanLine = Tween<double>(
      begin: 0.05,
      end: 0.95,
    ).animate(CurvedAnimation(parent: _scanLineCtrl, curve: Curves.easeInOut));
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulse = Tween<double>(
      begin: 0.55,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _cameraController = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
      formats: [BarcodeFormat.qrCode],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scanLineCtrl.dispose();
    _pulseCtrl.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _qrProcessed || _selectedMode != 0) return;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final activeRideParams = LocalStorage.hasActiveRide()
        ? LocalStorage.getActiveRideParams()
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: _selectedMode == 0
                ? Stack(
                    fit: StackFit.expand,
                    children: [
                      MobileScanner(
                        controller: _cameraController,
                        onDetect: _onBikeQrDetected,
                      ),
                      CustomPaint(
                        size: Size.infinite,
                        painter: _DimOverlayPainter(),
                      ),
                      Center(child: _buildScanFrame()),
                      if (activeRideParams != null &&
                          activeRideParams.isNotEmpty)
                        Positioned(
                          top: MediaQuery.of(context).padding.top + 64.h,
                          left: 16.w,
                          right: 16.w,
                          child: _ActiveRideScanBanner(
                            isDark: isDark,
                            onContinue: () {
                              context.push('/ride',
                                  extra: {...activeRideParams, 'resume': true});
                            },
                          ),
                        ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 20.h,
                        child: Center(
                          child: AnimatedBuilder(
                            animation: _pulse,
                            builder: (_, __) => Opacity(
                              opacity: _pulse.value,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 8.h,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(24.r),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                    width: 0.8,
                                  ),
                                ),
                                child: Text(
                                  'Point camera at QR code on the bike',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      _buildTopBar(context),
                    ],
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: [
                      _RecordRideMapPreview(key: _recordRideMapKey),
                      _buildTopBar(context),
                    ],
                  ),
          ),
          // Bottom panel – naturally above nav bar
          _buildBottomPanel(context, isDark, bottomPad),
        ],
      ),
    );
  }

  // ── QR detection ──────────────────────────────────────────────────────────

  bool _qrProcessed = false;

  Future<void> _onBikeQrDetected(BarcodeCapture capture) async {
    if (_qrProcessed || _selectedMode != 0) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null || barcode.rawValue == null) return;
    final router = GoRouter.of(context);
    final bikeId = barcode.rawValue!.trim();
    if (bikeId.isEmpty) {
      _showScannerMessage('Invalid bike QR. Please scan the bike QR code.');
      return;
    }

    _qrProcessed = true;
    await _safeStopCamera();
    HapticFeedback.mediumImpact();

    try {
      await _rideRepository.validateBike(bikeId);
    } catch (e) {
      _qrProcessed = false;
      _showScannerMessage(e.toString());
      await _safeStartCamera();
      return;
    }

    try {
      if (!mounted) return;
      await router.push(
        '/ride',
        extra: {'rideMode': _selectedMode, 'bikeId': bikeId, 'qrData': bikeId},
      );
    } finally {
      _qrProcessed = false;
      if (mounted && !LocalStorage.hasActiveRide()) {
        await _safeStartCamera();
      }
    }
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

  Future<void> _setSelectedMode(int mode) async {
    if (_selectedMode == mode) return;

    if (mode == 0) {
      if (!mounted) return;
      setState(() => _selectedMode = mode);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _safeStartCamera();
        }
      });
      return;
    }

    await _safeStopCamera();
    if (_flashOn) {
      try {
        await _cameraController.toggleTorch();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _selectedMode = mode;
      _flashOn = false;
    });
  }

  void _showScannerMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.error,
      ),
    );
  }

  // ── Scan frame ────────────────────────────────────────────────────────────

  Widget _buildScanFrame() {
    final sz = 230.w;
    return SizedBox(
      width: sz,
      height: sz,
      child: Stack(
        children: [
          CustomPaint(size: Size(sz, sz), painter: _CornerPainter()),
          AnimatedBuilder(
            animation: _scanLine,
            builder: (_, __) {
              return Positioned(
                top: _scanLine.value * sz,
                left: 10.w,
                right: 10.w,
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0),
                        AppColors.primary.withValues(alpha: 0.9),
                        AppColors.primary,
                        AppColors.primary.withValues(alpha: 0.9),
                        AppColors.primary.withValues(alpha: 0),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(2.r),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
        child: Row(
          children: [
            _topBtn(
              icon: Icons.arrow_back_ios_new_rounded,
              onTap: () => context.go('/home'),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  key: ValueKey(_selectedMode),
                  _selectedMode == 0 ? 'Scan Bike' : 'Record Ride',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
            _selectedMode == 0
                ? _topBtn(
                    icon: _flashOn
                        ? Icons.flashlight_on_rounded
                        : Icons.flashlight_off_rounded,
                    color: _flashOn ? AppColors.warning : Colors.white,
                    bg: _flashOn
                        ? AppColors.warning.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.12),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _cameraController.toggleTorch();
                      setState(() => _flashOn = !_flashOn);
                    },
                  )
                : _topBtn(
                    icon: Icons.my_location_rounded,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _recordRideMapKey.currentState?.recenter();
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _topBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color? bg,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: bg ?? Colors.white.withValues(alpha: 0.12),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 18.w, color: color),
      ),
    );
  }

  // ── Bottom panel ──────────────────────────────────────────────────────────

  Widget _buildBottomPanel(
    BuildContext context,
    bool isDark,
    double bottomPad,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.20),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, bottomPad + 16.h),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36.w,
            height: 4.h,
            decoration: BoxDecoration(
              color: isDark ? AppColors.grey700 : AppColors.grey300,
              borderRadius: BorderRadius.circular(2.r),
            ),
          ),
          SizedBox(height: 18.h),

          // Mode cards
          Row(
            children: [
              _modeCard(
                index: 0,
                icon: Icons.qr_code_scanner_rounded,
                label: 'Scan Bike',
                sub: 'Unlock a station bike',
                isDark: isDark,
                activeColor: AppColors.primary,
              ),
              SizedBox(width: 10.w),
              _modeCard(
                index: 1,
                icon: Icons.pedal_bike_rounded,
                label: 'Record Ride',
                sub: 'Track your own bike',
                isDark: isDark,
                activeColor: AppColors.info,
              ),
            ],
          ),

          SizedBox(height: 14.h),

          // Info rows with animated swap
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _selectedMode == 0
                ? _infoSection(
                    key: const ValueKey(0),
                    isDark: isDark,
                    rows: const [
                      _InfoData(
                        icon: Icons.lock_open_rounded,
                        color: AppColors.primary,
                        title: 'Unlock a campus bike',
                        sub:
                            'Scan the QR on any station bike to unlock and ride',
                      ),
                      _InfoData(
                        icon: Icons.payment_rounded,
                        color: AppColors.warning,
                        title: 'Auto billed to wallet',
                        sub: 'Ride cost deducted automatically at trip end',
                      ),
                    ],
                  )
                : _infoSection(
                    key: const ValueKey(1),
                    isDark: isDark,
                    rows: const [
                      _InfoData(
                        icon: Icons.route_rounded,
                        color: AppColors.info,
                        title: 'Track your own bike',
                        sub:
                            'Records distance, speed & eco impact in real time',
                      ),
                      _InfoData(
                        icon: Icons.eco_rounded,
                        color: AppColors.success,
                        title: 'Earn XP & reduce CO2',
                        sub:
                            'Every km earns +10 XP and counts toward eco goals',
                      ),
                    ],
                  ),
          ),

          SizedBox(height: 18.h),

          // CTA button
          GestureDetector(
            onTap: () {
              HapticFeedback.mediumImpact();
              if (_selectedMode == 0) {
                // Check for coins first
                final totalCoins = LocalStorage.getTotalDisplayCoins();
                if (totalCoins > 0) {
                  _showCoinOrWalletChoice(context);
                  return;
                }
                // No coins: check wallet balance ≥ ₹300
                final balance = LocalStorage.getWalletBalance();
                if (balance < 300) {
                  _showInsufficientBalanceDialog(context, balance);
                  return;
                }
              }
              context.push('/ride', extra: {'rideMode': _selectedMode});
            },
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 15.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _selectedMode == 0
                      ? [AppColors.primaryDark, AppColors.primary]
                      : [const Color(0xFF1565C0), AppColors.info],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(18.r),
                boxShadow: [
                  BoxShadow(
                    color:
                        (_selectedMode == 0
                                ? AppColors.primary
                                : AppColors.info)
                            .withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _selectedMode == 0
                        ? Icons.lock_open_rounded
                        : Icons.play_arrow_rounded,
                    size: 20.w,
                    color: AppColors.white,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    _selectedMode == 0
                        ? 'Unlock & Start Ride'
                        : 'Start Recording',
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Mode card ─────────────────────────────────────────────────────────────

  Widget _modeCard({
    required int index,
    required IconData icon,
    required String label,
    required String sub,
    required bool isDark,
    required Color activeColor,
  }) {
    final selected = _selectedMode == index;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.selectionClick();
          await _setSelectedMode(index);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: selected
                ? activeColor.withValues(alpha: 0.10)
                : (isDark ? AppColors.darkElevated : AppColors.grey100),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(
              color: selected
                  ? activeColor.withValues(alpha: 0.45)
                  : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 34.w,
                height: 34.w,
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor.withValues(alpha: 0.15)
                      : (isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.grey200),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                alignment: Alignment.center,
                child: Icon(
                  icon,
                  size: 17.w,
                  color: selected
                      ? activeColor
                      : (isDark ? AppColors.grey400 : AppColors.grey500),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? activeColor
                            : (isDark ? AppColors.grey300 : AppColors.grey700),
                      ),
                    ),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.grey500,
                        height: 1.3,
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

  // ── Info section ──────────────────────────────────────────────────────────

  Widget _infoSection({
    required Key key,
    required bool isDark,
    required List<_InfoData> rows,
  }) {
    return Column(
      key: key,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          _infoRow(isDark, data: rows[i]),
          if (i < rows.length - 1) SizedBox(height: 8.h),
        ],
      ],
    );
  }

  Widget _infoRow(bool isDark, {required _InfoData data}) {
    return Row(
      children: [
        Container(
          width: 36.w,
          height: 36.w,
          decoration: BoxDecoration(
            color: data.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10.r),
          ),
          alignment: Alignment.center,
          child: Icon(data.icon, size: 16.w, color: data.color),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.title,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.white : AppColors.grey900,
                ),
              ),
              Text(
                data.sub,
                style: TextStyle(
                  fontSize: 11.sp,
                  color: AppColors.grey500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCoinOrWalletChoice(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalCoins = LocalStorage.getTotalDisplayCoins();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Icon(
              Icons.monetization_on_rounded,
              size: 40.w,
              color: AppColors.warning,
            ),
            SizedBox(height: 12.h),
            Text(
              'Use a Coin?',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
                color: isDark ? AppColors.white : AppColors.grey900,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'You have $totalCoins MJ Coin${totalCoins > 1 ? 's' : ''}.\n1 coin = 1 free ride',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
            ),
            SizedBox(height: 24.h),
            // Use coin button
            GestureDetector(
              onTap: () async {
                final router = GoRouter.of(context);
                Navigator.pop(ctx);
                final used = await LocalStorage.useCoinForRide();
                if (!mounted) return;
                if (!used) return;
                router.push(
                  '/ride',
                  extra: {'rideMode': _selectedMode, 'paidWithCoin': true},
                );
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFA000), Color(0xFFFFB300)],
                  ),
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Use 1 Coin (Free Ride)',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: AppColors.white,
                  ),
                ),
              ),
            ),
            SizedBox(height: 10.h),
            // Pay with wallet button
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                final balance = LocalStorage.getWalletBalance();
                if (balance < 300) {
                  _showInsufficientBalanceDialog(context, balance);
                  return;
                }
                context.push('/ride', extra: {'rideMode': _selectedMode});
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkElevated : AppColors.grey100,
                  borderRadius: BorderRadius.circular(14.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  'Pay with Wallet Instead',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.grey300 : AppColors.grey700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInsufficientBalanceDialog(BuildContext context, double balance) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Use the actual bottom inset (includes nav bar when extendBody: true)
    final bottomPad = MediaQuery.of(context).padding.bottom;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, bottomPad + 16.h),
        padding: EdgeInsets.fromLTRB(24.w, 20.h, 24.w, 8.h),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? AppColors.grey700 : AppColors.grey300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Container(
              width: 62.w,
              height: 62.w,
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.account_balance_wallet_rounded,
                size: 28.w,
                color: AppColors.error,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              'Insufficient Balance',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.white : AppColors.grey900,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'You need at least ₹300 to unlock a shared bike.\nCurrent balance: ₹${balance.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                color: AppColors.grey500,
                height: 1.5,
              ),
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
                    color: AppColors.white,
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
}

class _RecordRideMapPreview extends StatefulWidget {
  const _RecordRideMapPreview({super.key});

  @override
  State<_RecordRideMapPreview> createState() => _RecordRideMapPreviewState();
}

class _RecordRideMapPreviewState extends State<_RecordRideMapPreview> {
  final HomeRepositoryImpl _homeRepository = HomeRepositoryImpl(ApiClient());
  final MapController _mapController = MapController();

  LatLng _mapCenter = const LatLng(17.4577, 78.2753);
  LatLng? _userLocation;
  List<StationModel> _stations = const [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMapData();
  }

  Future<void> _loadMapData() async {
    await _loadUserLocation();
    await _loadStations();
    if (mounted) {
      setState(() => _isLoading = false);
    }
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
      if (!mounted) return;

      final userPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userLocation = userPos;
        _mapCenter = userPos;
      });
      _mapController.move(userPos, 15);
    } catch (_) {}
  }

  Future<void> _loadStations() async {
    try {
      final loc = _userLocation ?? _mapCenter;
      final stations = await _homeRepository.getNearbyStations(
        loc.latitude,
        loc.longitude,
      );
      if (!mounted) return;
      setState(() {
        _stations = stations
            .where((station) => station.lat != 0 && station.lng != 0)
            .toList();
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _stations = const []);
    }
  }

  void recenter() {
    final loc = _userLocation ?? _mapCenter;
    _mapController.move(loc, 16);
  }

  String _tileUrlFor(bool isDark) {
    return isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  }

  List<String> _subdomainsFor() => const ['a', 'b', 'c', 'd'];

  List<Marker> _buildMarkers(bool isDark) {
    final markers = _stations.map((station) {
      return Marker(
        point: LatLng(station.lat, station.lng),
        width: 54,
        height: 54,
        child: Padding(
          padding: EdgeInsets.all(4.w),
          child: SvgPicture.asset(
            AppAssets.iconLogoForTheme(isDark),
            fit: BoxFit.contain,
          ),
        ),
      );
    }).toList();

    final loc = _userLocation;
    if (loc != null) {
      markers.add(
        Marker(
          point: loc,
          width: 28,
          height: 28,
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      fit: StackFit.expand,
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
            MarkerLayer(markers: _buildMarkers(isDark)),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('OpenStreetMap contributors'),
                TextSourceAttribution('CARTO'),
              ],
            ),
          ],
        ),
        Positioned(
          left: 0,
          bottom: 0,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1A1A1A).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
            ),
            child: SvgPicture.asset(
              AppAssets.fullLogoForTheme(isDark),
              height: 16.h,
            ),
          ),
        ),
        Positioned(
          left: 16.w,
          right: 16.w,
          bottom: 20.h,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: (isDark ? Colors.black : Colors.white).withValues(
                alpha: 0.74,
              ),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(
                color: Colors.white.withValues(alpha: isDark ? 0.10 : 0.65),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 34.w,
                  height: 34.w,
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.route_rounded,
                    size: 18.w,
                    color: AppColors.info,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Record Ride Map',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.white : AppColors.grey900,
                        ),
                      ),
                      Text(
                        _isLoading
                            ? 'Loading nearby stations...'
                            : '${_stations.length} nearby stations available',
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
        ),
      ],
    );
  }
}

class _ActiveRideScanBanner extends StatelessWidget {
  final bool isDark;
  final VoidCallback onContinue;

  const _ActiveRideScanBanner({required this.isDark, required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Colors.white.withValues(alpha: isDark ? 0.12 : 0.65),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, color: AppColors.primary, size: 20.w),
          SizedBox(width: 10.w),
          Expanded(
            child: Text(
              'Active ride in progress',
              style: TextStyle(
                color: isDark ? AppColors.white : AppColors.grey900,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
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

// ── Data class ────────────────────────────────────────────────────────────────

class _InfoData {
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  const _InfoData({
    required this.icon,
    required this.color,
    required this.title,
    required this.sub,
  });
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _DimOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const frameSize = 230.0;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final rect = Rect.fromCenter(
      center: Offset(cx, cy),
      width: frameSize,
      height: frameSize,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(20));
    final path = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height))
      ..addRRect(rrect)
      ..fillType = PathFillType.evenOdd;
    canvas.drawPath(
      path,
      Paint()..color = Colors.black.withValues(alpha: 0.65),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const r = 20.0;
    const arm = 30.0;
    final w = size.width;
    final h = size.height;

    final glow = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.22)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    final line = Paint()
      ..color = AppColors.primary
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final corners = [
      Path()
        ..moveTo(0, arm + r)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(arm + r, 0),
      Path()
        ..moveTo(w - arm - r, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, arm + r),
      Path()
        ..moveTo(0, h - arm - r)
        ..lineTo(0, h - r)
        ..arcToPoint(Offset(r, h), radius: const Radius.circular(r))
        ..lineTo(arm + r, h),
      Path()
        ..moveTo(w - arm - r, h)
        ..lineTo(w - r, h)
        ..arcToPoint(Offset(w, h - r), radius: const Radius.circular(r))
        ..lineTo(w, h - arm - r),
    ];

    for (final path in corners) {
      canvas.drawPath(path, glow);
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
