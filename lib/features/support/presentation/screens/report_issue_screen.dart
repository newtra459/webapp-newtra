import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/widgets/mj_button.dart';
import '../../data/models/support_model.dart';
import '../providers/support_provider.dart';

// ── Tab indices ──────────────────────────────────────────────────────────────

const _kBikeTab  = 0;
const _kAppTab   = 1;
const _kOtherTab = 2;

class ReportIssueScreen extends ConsumerStatefulWidget {
  const ReportIssueScreen({super.key});

  @override
  ConsumerState<ReportIssueScreen> createState() => _ReportIssueScreenState();
}

class _ReportIssueScreenState extends ConsumerState<ReportIssueScreen>
    with SingleTickerProviderStateMixin {

  late final TabController _tab;

  // ── Bike tab state ────────────────────────────────────────────────────────
  String? _scannedBikeId;
  final _bikeIdCtrl = TextEditingController();
  final Set<int> _selectedParts = {};
  String? _severity;
  final _bikeDescCtrl = TextEditingController();
  bool _isSubmitting = false;

  // ── App tab state ─────────────────────────────────────────────────────────
  final Set<int> _selectedAppCategories = {};
  final _appDescCtrl = TextEditingController();

  // ── Other tab state ───────────────────────────────────────────────────────
  final _otherDescCtrl = TextEditingController();

  // ── Static data ───────────────────────────────────────────────────────────
  static const _parts = [
    {'icon': Icons.link_rounded,                   'label': 'Chain'},
    {'icon': Icons.battery_charging_full_rounded,  'label': 'Battery'},
    {'icon': Icons.pedal_bike_rounded,             'label': 'Pedal'},
    {'icon': Icons.handyman_rounded,               'label': 'Brake'},
    {'icon': Icons.circle_outlined,                'label': 'Tyre'},
    {'icon': Icons.event_seat_rounded,             'label': 'Seat'},
    {'icon': Icons.lightbulb_outline_rounded,      'label': 'Light'},
    {'icon': Icons.settings_rounded,               'label': 'Gear'},
    {'icon': Icons.warning_amber_rounded,          'label': 'Other'},
  ];

  static const _severities = [
    {'label': 'Low',    'color': Color(0xFF4CAF50)},
    {'label': 'Medium', 'color': Color(0xFFFF9800)},
    {'label': 'High',   'color': Color(0xFFE53935)},
  ];

  static const _appCategories = [
    {'icon': Icons.bug_report_rounded,        'label': 'Bug / Crash'},
    {'icon': Icons.payment_rounded,           'label': 'Payment'},
    {'icon': Icons.map_rounded,               'label': 'Map / GPS'},
    {'icon': Icons.notifications_rounded,     'label': 'Notifications'},
    {'icon': Icons.account_circle_rounded,    'label': 'Account'},
    {'icon': Icons.speed_rounded,             'label': 'Performance'},
    {'icon': Icons.lock_rounded,              'label': 'Login / Auth'},
    {'icon': Icons.help_outline_rounded,      'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _bikeIdCtrl.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tab.dispose();
    _bikeIdCtrl.dispose();
    _bikeDescCtrl.dispose();
    _appDescCtrl.dispose();
    _otherDescCtrl.dispose();
    super.dispose();
  }

  // ── QR scan ───────────────────────────────────────────────────────────────

  Future<void> _scanBikeQr() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const _ReportQrScanner(),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _scannedBikeId = result;
        _bikeIdCtrl.text = result;
      });
      HapticFeedback.mediumImpact();
    }
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final idx = _tab.index;
    final bikeId = _bikeIdCtrl.text.trim();
    bool valid = false;
    String errorMessage = 'Please fill in the required details';
    if (idx == _kBikeTab) {
      if (bikeId.isEmpty) {
        errorMessage = 'Enter or scan the bike number';
      } else {
        valid = _selectedParts.isNotEmpty ||
            _bikeDescCtrl.text.trim().isNotEmpty;
      }
    } else if (idx == _kAppTab) {
      valid = _selectedAppCategories.isNotEmpty ||
          _appDescCtrl.text.trim().isNotEmpty;
    } else {
      valid = _otherDescCtrl.text.trim().isNotEmpty;
    }

    if (!valid) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r)),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      await ref.read(supportRepositoryProvider).createTicket(
            _buildTicket(idx, bikeId),
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Issue reported. Our team will look into it.'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  SupportTicket _buildTicket(int idx, String bikeId) {
    final now = DateTime.now();

    if (idx == _kBikeTab) {
      final parts = _selectedParts.map((i) => _parts[i]['label'] as String).toList();
      final descriptionParts = <String>[
        if (parts.isNotEmpty) 'Affected parts: ${parts.join(', ')}',
        if (_severity != null) 'Severity: $_severity',
        if (_bikeDescCtrl.text.trim().isNotEmpty) _bikeDescCtrl.text.trim(),
      ];

      return SupportTicket(
        id: '',
        category: 'bike',
        subject: 'Bike issue',
        description: descriptionParts.join('\n'),
        createdAt: now,
        bikeId: bikeId,
      );
    }

    if (idx == _kAppTab) {
      final categories = _selectedAppCategories
          .map((i) => _appCategories[i]['label'] as String)
          .toList();
      final subject = categories.isEmpty ? 'App issue' : categories.join(', ');
      final descriptionParts = <String>[
        if (categories.isNotEmpty) 'Categories: ${categories.join(', ')}',
        if (_appDescCtrl.text.trim().isNotEmpty) _appDescCtrl.text.trim(),
      ];
      return SupportTicket(
        id: '',
        category: 'app',
        subject: subject,
        description:
            descriptionParts.isEmpty ? subject : descriptionParts.join('\n'),
        createdAt: now,
      );
    }

    return SupportTicket(
      id: '',
      category: 'other',
      subject: 'Other issue',
      description: _otherDescCtrl.text.trim(),
      createdAt: now,
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg      = isDark ? AppColors.darkSurface : const Color(0xFFF5F7F5);
    final cardBg  = isDark ? AppColors.darkCard : Colors.white;
    final border  = isDark ? AppColors.darkElevated : const Color(0xFFE8EDE8);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── App bar ──────────────────────────────────────────────
            _buildAppBar(isDark),

            // ── Tab bar ──────────────────────────────────────────────
            _buildTabBar(isDark),

            // ── Tab views ────────────────────────────────────────────
            Expanded(
              child: TabBarView(
                controller: _tab,
                children: [
                  _buildBikeTab(isDark, cardBg, border),
                  _buildAppTab(isDark, cardBg, border),
                  _buildOtherTab(isDark, cardBg, border),
                ],
              ),
            ),

            // ── Bottom action bar ────────────────────────────────────
            _buildBottomBar(cardBg, border),
          ],
        ),
      ),
    );
  }

  // ── App bar ───────────────────────────────────────────────────────────────

  Widget _buildAppBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 20.w, 0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                size: 20.w,
                color: isDark ? Colors.white : AppColors.grey900),
            onPressed: () => Navigator.pop(context),
          ),
          SizedBox(width: 4.w),
          Text(
            'Report an Issue',
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppColors.grey900,
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ───────────────────────────────────────────────────────────────

  Widget _buildTabBar(bool isDark) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 0),
      child: Container(
        height: 46.h,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TabBar(
          controller: _tab,
          indicator: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(11.r),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.grey500,
          labelStyle:
              TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500),
          padding: EdgeInsets.all(4.w),
          labelPadding: EdgeInsets.zero,
          tabs: const [
            Tab(text: 'Bike Issue'),
            Tab(text: 'App Issue'),
            Tab(text: 'Other'),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════ BIKE TAB ════════════════════════════════

  Widget _buildBikeTab(bool isDark, Color cardBg, Color border) {
    final hasBikeId = _bikeIdCtrl.text.trim().isNotEmpty;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── QR Scan card ────────────────────────────────────────────
          GestureDetector(
            onTap: _scanBikeQr,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: double.infinity,
              padding: EdgeInsets.all(18.w),
              decoration: BoxDecoration(
                color: hasBikeId
                    ? AppColors.success
                    : AppColors.primary,
                borderRadius: BorderRadius.circular(18.r),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48.w,
                    height: 48.w,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      _scannedBikeId != null
                          ? Icons.check_circle_rounded
                          : Icons.qr_code_scanner_rounded,
                      size: 26.w,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 14.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hasBikeId
                              ? 'Bike Attached'
                              : 'Scan Bike QR',
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          hasBikeId
                              ? 'Bike ID: ${_bikeIdCtrl.text.trim()}  ·  Tap to re-scan'
                              : 'Attach the bike to this report',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                    size: 22.w,
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 16.h),

          _sectionTitle('Bike Number', isDark),
          SizedBox(height: 12.h),
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: border),
            ),
            child: TextField(
              controller: _bikeIdCtrl,
              textCapitalization: TextCapitalization.characters,
              style: TextStyle(
                fontSize: 14.sp,
                color: isDark ? Colors.white : AppColors.grey900,
              ),
              decoration: InputDecoration(
                hintText: 'Enter bike number manually',
                hintStyle: TextStyle(
                  fontSize: 14.sp,
                  color: AppColors.grey500,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.all(16.w),
              ),
            ),
          ),

          SizedBox(height: 22.h),

          // ── Affected parts ──────────────────────────────────────────
          _sectionTitle('Affected Part', isDark),
          SizedBox(height: 12.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 1.0,
            ),
            itemCount: _parts.length,
            itemBuilder: (_, i) {
              final sel = _selectedParts.contains(i);
              return GestureDetector(
                onTap: () => setState(() =>
                    sel ? _selectedParts.remove(i) : _selectedParts.add(i)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : cardBg,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(
                      color: sel ? AppColors.primary : border,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _parts[i]['icon'] as IconData,
                        size: 28.w,
                        color: sel ? AppColors.primary : AppColors.grey500,
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        _parts[i]['label'] as String,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight:
                              sel ? FontWeight.w600 : FontWeight.w400,
                          color: sel
                              ? AppColors.primary
                              : (isDark
                                  ? AppColors.grey400
                                  : AppColors.grey700),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 22.h),

          // ── Severity ────────────────────────────────────────────────
          _sectionTitle('Severity', isDark),
          SizedBox(height: 12.h),
          Row(
            children: _severities.map((s) {
              final label = s['label'] as String;
              final color = s['color'] as Color;
              final sel   = _severity == label;
              return Padding(
                padding: EdgeInsets.only(right: 10.w),
                child: GestureDetector(
                  onTap:
                      () => setState(() => _severity = sel ? null : label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: EdgeInsets.symmetric(
                        horizontal: 18.w, vertical: 10.h),
                    decoration: BoxDecoration(
                      color: sel ? color.withValues(alpha: 0.12) : cardBg,
                      borderRadius: BorderRadius.circular(30.r),
                      border: Border.all(
                          color: sel ? color : border,
                          width: sel ? 2 : 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: sel
                                ? color
                                : (isDark
                                    ? AppColors.grey400
                                    : AppColors.grey700),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          SizedBox(height: 22.h),

          // ── Description ─────────────────────────────────────────────
          _sectionTitle('Description', isDark),
          SizedBox(height: 12.h),
          _descField(_bikeDescCtrl, 'Describe the bike issue…', isDark,
              cardBg, border),

          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  // ═══════════════════════════════ APP TAB ═════════════════════════════════

  Widget _buildAppTab(bool isDark, Color cardBg, Color border) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Issue Category', isDark),
          SizedBox(height: 12.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 10.w,
              mainAxisSpacing: 10.h,
              childAspectRatio: 0.88,
            ),
            itemCount: _appCategories.length,
            itemBuilder: (_, i) {
              final cat   = _appCategories[i];
              final label = cat['label'] as String;
              final sel   = _selectedAppCategories.contains(i);
              return GestureDetector(
                onTap: () => setState(() => sel
                    ? _selectedAppCategories.remove(i)
                    : _selectedAppCategories.add(i)),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primary.withValues(alpha: 0.10)
                        : cardBg,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(
                      color: sel ? AppColors.primary : border,
                      width: sel ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        cat['icon'] as IconData,
                        size: 24.w,
                        color:
                            sel ? AppColors.primary : AppColors.grey500,
                      ),
                      SizedBox(height: 5.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4.w),
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: sel
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.grey400
                                    : AppColors.grey700),
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          SizedBox(height: 22.h),

          _sectionTitle('Description', isDark),
          SizedBox(height: 12.h),
          _descField(_appDescCtrl,
              'Describe what happened and steps to reproduce…',
              isDark, cardBg, border),

          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  // ═══════════════════════════════ OTHER TAB ═══════════════════════════════

  Widget _buildOtherTab(bool isDark, Color cardBg, Color border) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14.r),
              border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 18.w, color: AppColors.info),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'For bike or app issues, use the dedicated tabs above for faster resolution.',
                    style: TextStyle(
                        fontSize: 12.sp, color: AppColors.grey500),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 22.h),

          _sectionTitle('Tell us what happened', isDark),
          SizedBox(height: 12.h),
          _descField(_otherDescCtrl,
              'Describe your concern in detail…',
              isDark, cardBg, border,
              maxLines: 8),

          SizedBox(height: 16.h),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────

  Widget _descField(
    TextEditingController ctrl,
    String hint,
    bool isDark,
    Color cardBg,
    Color border, {
    int maxLines = 5,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: border),
      ),
      child: TextField(
        controller: ctrl,
        maxLines: maxLines,
        style: TextStyle(
            fontSize: 14.sp,
            color: isDark ? Colors.white : AppColors.grey900),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              TextStyle(fontSize: 14.sp, color: AppColors.grey500),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16.w),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t, bool isDark) => Text(
        t,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : AppColors.grey900,
        ),
      );

  // ── Bottom action bar ─────────────────────────────────────────────────────

  Widget _buildBottomBar(Color cardBg, Color border) {
    return Container(
      padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: MjButton(
              text: 'Cancel',
              isOutlined: true,
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: MjButton(
              text: 'Submit Report',
              isLoading: _isSubmitting,
              onPressed: _submit,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  QR Scanner for Report (returns scanned bike ID via Navigator.pop)
// ═══════════════════════════════════════════════════════════════════════════

class _ReportQrScanner extends StatefulWidget {
  const _ReportQrScanner();

  @override
  State<_ReportQrScanner> createState() => _ReportQrScannerState();
}

class _ReportQrScannerState extends State<_ReportQrScanner>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode],
  );

  bool _scanned = false;
  bool _torchOn = false;

  late final AnimationController _lineCtrl;
  late final Animation<double>   _line;
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lineCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _line = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _lineCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lineCtrl.dispose();
    _pulseCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted || _scanned) return;
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

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_scanned) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;
    final bikeId = _extractBikeId(raw);
    if (bikeId.isEmpty) {
      _showScannerMessage('Invalid bike QR. Please scan the bike QR code.');
      return;
    }
    _scanned = true;
    HapticFeedback.mediumImpact();
    await _safeStopCamera();
    if (!mounted) return;
    Navigator.pop(context, bikeId);
  }

  Future<void> _safeStartCamera() async {
    try {
      await _controller.start();
    } catch (_) {}
  }

  Future<void> _safeStopCamera() async {
    try {
      await _controller.stop();
    } catch (_) {}
  }

  String _extractBikeId(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '';
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        for (final key in const [
          'bike_id',
          'bikeId',
          'vehicle_id',
          'vehicleId',
          'id',
        ]) {
          final value = decoded[key];
          if (value == null) continue;
          final text = value.toString().trim();
          if (text.isNotEmpty) return text;
        }
      }
    } catch (_) {}
    return trimmed;
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

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Camera feed ──────────────────────────────────────────────
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),

          // ── Dim overlay ──────────────────────────────────────────────
          CustomPaint(size: Size.infinite, painter: _DimPainter(holeSize: 230.w)),

          // ── Scan frame ───────────────────────────────────────────────
          Center(child: _buildScanFrame()),

          // ── Hint pill ────────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 140.h + bottomPad,
            child: Center(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Opacity(
                  opacity: _pulse.value,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: 16.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24.r),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12),
                          width: 0.8),
                    ),
                    child: Text(
                      'Point camera at the QR code on the bike',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white.withValues(alpha: 0.80),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Top bar ──────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
              child: Row(
                children: [
                  _topBtn(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Text(
                      'Scan Bike QR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  _topBtn(
                    icon: _torchOn
                        ? Icons.flashlight_on_rounded
                        : Icons.flashlight_off_rounded,
                    color: _torchOn ? AppColors.warning : Colors.white,
                    bg: _torchOn
                        ? AppColors.warning.withValues(alpha: 0.22)
                        : Colors.white.withValues(alpha: 0.12),
                    onTap: () {
                      setState(() => _torchOn = !_torchOn);
                      _controller.toggleTorch();
                    },
                  ),
                ],
              ),
            ),
          ),

          // ── Bottom label ─────────────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPad + 32.h,
            child: Center(
              child: Text(
                'Scan the QR code on the bike to attach it to your report',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.white54,
                    height: 1.4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanFrame() {
    final sz = 230.w;
    return SizedBox(
      width: sz,
      height: sz,
      child: Stack(
        children: [
          CustomPaint(size: Size(sz, sz), painter: _CornerPainter()),
          AnimatedBuilder(
            animation: _line,
            builder: (_, __) => Positioned(
              top: _line.value * sz,
              left: 10.w,
              right: 10.w,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.primary.withValues(alpha: 0),
                    AppColors.primary.withValues(alpha: 0.9),
                    AppColors.primary,
                    AppColors.primary.withValues(alpha: 0.9),
                    AppColors.primary.withValues(alpha: 0),
                  ]),
                  borderRadius: BorderRadius.circular(2.r),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 6,
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

  Widget _topBtn({
    required IconData icon,
    required VoidCallback onTap,
    Color color = Colors.white,
    Color? bg,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: bg ?? Colors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withValues(alpha: 0.10), width: 0.8),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 18.w, color: color),
        ),
      );
}

// ── Painters ──────────────────────────────────────────────────────────────────

class _DimPainter extends CustomPainter {
  const _DimPainter({required this.holeSize});
  final double holeSize;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.62);
    final outer = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final hole  = Path()..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(cx, cy), width: holeSize, height: holeSize),
          const Radius.circular(16),
        ));
    canvas.drawPath(
        Path.combine(PathOperation.difference, outer, hole), paint);
    // Corner glow
    final glow = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy), width: holeSize + 16, height: holeSize + 16),
        const Radius.circular(20),
      ),
      glow,
    );
  }

  @override
  bool shouldRepaint(_DimPainter old) => old.holeSize != holeSize;
}

class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    const l = 28.0;
    const r = 14.0;
    final w = size.width;
    final h = size.height;
    // top-left
    canvas.drawLine(Offset(r, 0), Offset(l, 0), paint);
    canvas.drawLine(Offset(0, r), Offset(0, l), paint);
    canvas.drawArc(const Rect.fromLTWH(0, 0, r * 2, r * 2),
        -3.14 / 2 * 2, 3.14 / 2, false, paint);
    // top-right
    canvas.drawLine(Offset(w - l, 0), Offset(w - r, 0), paint);
    canvas.drawLine(Offset(w, r), Offset(w, l), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, 0, r * 2, r * 2),
        -3.14 / 2, 3.14 / 2, false, paint);
    // bottom-left
    canvas.drawLine(Offset(0, h - l), Offset(0, h - r), paint);
    canvas.drawLine(Offset(r, h), Offset(l, h), paint);
    canvas.drawArc(Rect.fromLTWH(0, h - r * 2, r * 2, r * 2),
        3.14 / 2 * 2, 3.14 / 2, false, paint);
    // bottom-right
    canvas.drawLine(Offset(w, h - l), Offset(w, h - r), paint);
    canvas.drawLine(Offset(w - l, h), Offset(w - r, h), paint);
    canvas.drawArc(Rect.fromLTWH(w - r * 2, h - r * 2, r * 2, r * 2),
        0, 3.14 / 2, false, paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
