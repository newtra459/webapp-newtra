import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_assets.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _sendOtp() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final phone = '+91${_phoneController.text.trim()}';
    final success = await ref.read(authFormProvider.notifier).sendOtp(phone);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      context.push('/auth/otp', extra: _phoneController.text.trim());
    } else {
      final error = ref.read(authFormProvider).error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        ref.read(authFormProvider.notifier).clearError();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenH = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF0D1412),
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          // ── Dark hero panel ──────────────────────────────────────────
          SizedBox(
            height: screenH * 0.38,
            child: SafeArea(
              bottom: false,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Align(
                  alignment: const Alignment(0, 0.7),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SvgPicture.asset(
                        AppAssets.fullLogoOnDark,
                        width: 190.w,
                      ),
                      SizedBox(height: 8.h),
                      Padding(
                        padding: EdgeInsets.only(left: 2.w),
                        child: Text(
                          'Move Smarter. Move Greener.',
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: AppColors.grey500,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── White/dark card ──────────────────────────────────────────
          Expanded(
            child: SlideTransition(
              position: _slideAnim,
              child: FadeTransition(
                opacity: _fadeAnim,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28.r),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(28.w, 28.h, 28.w, 24.h),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Enter your phone number',
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.white : AppColors.grey900,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            'We\'ll send a one-time code to verify you',
                            style: TextStyle(
                              fontSize: 13.sp,
                              color: AppColors.grey500,
                            ),
                          ),
                          SizedBox(height: 28.h),

                          // Phone input
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _sendOtp(),
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 1.5,
                              color: isDark ? AppColors.white : AppColors.grey900,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Please enter your phone number';
                              }
                              if (v.length != 10) {
                                return 'Enter a valid 10-digit number';
                              }
                              return null;
                            },
                            decoration: InputDecoration(
                              hintText: '98765 43210',
                              hintStyle: TextStyle(
                                letterSpacing: 1.5,
                                color: AppColors.grey400,
                                fontSize: 15.sp,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? AppColors.darkElevated
                                  : AppColors.grey50,
                              contentPadding: EdgeInsets.symmetric(
                                  vertical: 16.h, horizontal: 16.w),
                              prefixIcon: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.w),
                                margin: EdgeInsets.only(right: 8.w),
                                decoration: BoxDecoration(
                                  border: Border(
                                    right: BorderSide(
                                      color: isDark
                                          ? AppColors.grey700
                                          : AppColors.grey200,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.phone_android_rounded,
                                      color: AppColors.primary,
                                      size: 18.sp,
                                    ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      '+91',
                                      style: TextStyle(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? AppColors.white
                                            : AppColors.grey800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14.r),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14.r),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? AppColors.grey700
                                      : AppColors.grey200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14.r),
                                borderSide: const BorderSide(
                                    color: AppColors.primary, width: 2),
                              ),
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14.r),
                                borderSide: const BorderSide(
                                    color: AppColors.error, width: 1.5),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14.r),
                                borderSide: const BorderSide(
                                    color: AppColors.error, width: 2),
                              ),
                            ),
                          ),

                          SizedBox(height: 24.h),

                          // Send OTP button
                          SizedBox(
                            width: double.infinity,
                            height: 52.h,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: AppColors.primary
                                    .withValues(alpha: 0.6),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14.r),
                                ),
                                elevation: 0,
                              ),
                              child: _isLoading
                                  ? SizedBox(
                                      width: 22.w,
                                      height: 22.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          'Send OTP',
                                          style: TextStyle(
                                            fontSize: 16.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Icon(Icons.arrow_forward_rounded,
                                            size: 20.w),
                                      ],
                                    ),
                            ),
                          ),

                          SizedBox(height: 28.h),

                          // Divider
                          Row(
                            children: [
                              Expanded(
                                  child: Divider(
                                      color: isDark
                                          ? AppColors.grey700
                                          : AppColors.grey200)),
                              Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 10.w),
                                child: Row(
                                  children: [
                                    Icon(Icons.lock_outline_rounded,
                                        size: 12.w,
                                        color: AppColors.grey500),
                                    SizedBox(width: 4.w),
                                    Text(
                                      'secure login',
                                      style: TextStyle(
                                          fontSize: 11.sp,
                                          color: AppColors.grey500),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                  child: Divider(
                                      color: isDark
                                          ? AppColors.grey700
                                          : AppColors.grey200)),
                            ],
                          ),

                          SizedBox(height: 24.h),

                          // Feature pills
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _FeaturePill(
                                icon: Icons.verified_user_outlined,
                                label: 'OTP Verified',
                                isDark: isDark,
                              ),
                              _FeaturePill(
                                icon: Icons.shield_outlined,
                                label: 'Secure',
                                isDark: isDark,
                              ),
                              _FeaturePill(
                                icon: Icons.bolt_outlined,
                                label: 'Instant',
                                isDark: isDark,
                              ),
                            ],
                          ),

                          SizedBox(height: 28.h),

                          // Terms
                          Center(
                            child: Text.rich(
                              TextSpan(
                                text: 'By continuing, you agree to our ',
                                style: TextStyle(
                                    fontSize: 11.sp, color: AppColors.grey500),
                                children: [
                                  TextSpan(
                                    text: 'Terms & Privacy Policy',
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
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
        ],
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.grey50,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(
            color: isDark ? AppColors.darkElevated : AppColors.grey200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.w, color: AppColors.primary),
          SizedBox(width: 5.w),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.grey300 : AppColors.grey700,
            ),
          ),
        ],
      ),
    );
  }
}
