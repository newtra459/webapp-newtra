import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/widgets/mj_logo.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phoneNumber;

  const OtpScreen({super.key, required this.phoneNumber});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  int _resendTimer = 30;
  Timer? _timer;

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _startTimer();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNodes.first.requestFocus());
  }

  void _startTimer() {
    _resendTimer = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        t.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _verifyOtp() async {
    if (_otp.length != 6) return;
    setState(() => _isLoading = true);
    final success = await ref.read(authFormProvider.notifier).verifyOtp(_otp);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (success) {
      final authState = ref.read(authFormProvider);
      final token = LocalStorage.getToken() ?? '';
      if (authState.accountExists && token.isNotEmpty) {
        // Account exists — token already saved, update auth state and go to app
        await ref.read(authStateProvider.notifier).setAuthenticated(token);
        await ref.read(authStateProvider.notifier).setRegistrationComplete();
        if (mounted) context.go('/home');
      } else {
        // New user — go to registration (token saved for auth header in register call)
        if (mounted) context.go('/auth/register');
      }
    } else {
      final error = ref.read(authFormProvider).error;
      if (error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
        ref.read(authFormProvider.notifier).clearError();
      }
    }
  }

  void _resendOtp() {
    if (_resendTimer > 0) return;
    for (final c in _controllers) c.clear();
    _focusNodes.first.requestFocus();
    _startTimer();
    setState(() {});
  }

  String get _maskedPhone {
    final p = widget.phoneNumber;
    if (p.length < 4) return p;
    return '×' * (p.length - 4) + p.substring(p.length - 4);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filled = _controllers.where((c) => c.text.isNotEmpty).length;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20.w,
            color: isDark ? AppColors.white : AppColors.grey900,
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 8.h),

                MjLogo.icon(width: 36.w, height: 36.w),
                SizedBox(height: 20.h),

                Text(
                  'Verify your\nnumber',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    color: isDark ? AppColors.white : AppColors.grey900,
                  ),
                ),

                SizedBox(height: 10.h),

                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text('Code sent to  ',
                        style: TextStyle(
                            fontSize: 14.sp, color: AppColors.grey500)),
                    Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Text(
                        '+91 $_maskedPhone',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 44.h),

                // OTP boxes
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(
                    6,
                    (i) => _OtpBox(
                      controller: _controllers[i],
                      focusNode: _focusNodes[i],
                      isDark: isDark,
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) {
                          _focusNodes[i + 1].requestFocus();
                        } else if (v.isEmpty && i > 0) {
                          _focusNodes[i - 1].requestFocus();
                        }
                        setState(() {});
                        if (_otp.length == 6) _verifyOtp();
                      },
                    ),
                  ),
                ),

                SizedBox(height: 16.h),

                // Progress strip
                Row(
                  children: List.generate(
                    6,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: EdgeInsets.only(right: 4.w),
                      width: i < filled ? 18.w : 8.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: i < filled
                            ? AppColors.primary
                            : (isDark
                                ? AppColors.grey700
                                : AppColors.grey200),
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                ),

                SizedBox(height: 40.h),

                // Verify button
                SizedBox(
                  width: double.infinity,
                  height: 52.h,
                  child: ElevatedButton(
                    onPressed: (_otp.length == 6 && !_isLoading)
                        ? _verifyOtp
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          isDark ? AppColors.grey700 : AppColors.grey200,
                      disabledForegroundColor: AppColors.grey500,
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
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Verify & Continue',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Icon(Icons.verified_outlined, size: 20.w),
                            ],
                          ),
                  ),
                ),

                SizedBox(height: 28.h),

                // Resend row
                Center(
                  child: _resendTimer > 0
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("Didn't receive it? ",
                                style: TextStyle(
                                    fontSize: 13.sp,
                                    color: AppColors.grey500)),
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? AppColors.darkElevated
                                    : AppColors.grey100,
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                'Resend in ${_resendTimer}s',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.grey500,
                                ),
                              ),
                            ),
                          ],
                        )
                      : GestureDetector(
                          onTap: _resendOtp,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text("Didn't receive it? ",
                                  style: TextStyle(
                                      fontSize: 13.sp,
                                      color: AppColors.grey500)),
                              Text(
                                'Resend OTP',
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

                const Spacer(),

                // Security note
                Container(
                  padding: EdgeInsets.all(14.w),
                  margin: EdgeInsets.only(bottom: 24.h),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : AppColors.grey50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkElevated
                          : AppColors.grey200,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.security_outlined,
                          size: 16.w, color: AppColors.grey500),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'Your OTP is valid for 5 minutes. Never share it with anyone.',
                          style: TextStyle(
                              fontSize: 11.sp,
                              color: AppColors.grey500,
                              height: 1.4),
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

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final ValueChanged<String> onChanged;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasValue = controller.text.isNotEmpty;

    return SizedBox(
      width: 44.w,
      height: 56.h,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        style: TextStyle(
          fontSize: 22.sp,
          fontWeight: FontWeight.w700,
          color: hasValue ? AppColors.primary : (isDark ? AppColors.white : AppColors.grey900),
        ),
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: hasValue
              ? AppColors.primary.withValues(alpha: 0.08)
              : (isDark ? AppColors.darkElevated : AppColors.grey50),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide(
              color: hasValue
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : (isDark ? AppColors.grey700 : AppColors.grey200),
              width: hasValue ? 1.5 : 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: const BorderSide(color: AppColors.primary, width: 2.5),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14.r),
            borderSide: BorderSide.none,
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
