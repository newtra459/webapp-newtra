import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/local_storage.dart';
import '../providers/auth_state_provider.dart';
import '../providers/auth_provider.dart';
import '../../../profile/presentation/providers/profile_provider.dart';
import '../../../../core/widgets/mj_button.dart';

class DeleteAccountOtpScreen extends ConsumerStatefulWidget {
  const DeleteAccountOtpScreen({super.key});

  @override
  ConsumerState<DeleteAccountOtpScreen> createState() =>
      _DeleteAccountOtpScreenState();
}

class _DeleteAccountOtpScreenState
    extends ConsumerState<DeleteAccountOtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isSendingOtp = false;
  int _resendTimer = 30;
  Timer? _timer;
  String _phone = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendDeletionOtp(showMessage: false);
    });
  }

  void _startTimer() {
    _resendTimer = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _sendDeletionOtp({bool showMessage = true}) async {
    if (_isSendingOtp) return;
    setState(() {
      _isSendingOtp = true;
      _error = null;
    });

    try {
      await ref.read(profileProvider.notifier).loadProfile();
      final profile = ref.read(profileProvider).valueOrNull;
      final phone = profile?.phone.trim() ?? '';
      if (phone.isEmpty) {
        throw Exception('Profile phone number is missing.');
      }

      await ref.read(authRepositoryProvider).sendOtp(phone);
      if (!mounted) return;
      setState(() {
        _phone = phone;
        _isSendingOtp = false;
      });
      _startTimer();

      if (showMessage) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Deletion OTP sent.')));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSendingOtp = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _verifyAndDelete() async {
    if (_otp.length != 6) return;
    if (_phone.isEmpty) {
      await _sendDeletionOtp(showMessage: true);
      if (_phone.isEmpty) return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authRepositoryProvider);
      final verified = await auth.verifyOtp(_phone, _otp);
      if (verified.token.isNotEmpty) {
        await LocalStorage.saveToken(verified.token);
      }
      await auth.deleteAccount(phone: _phone);
      await ref.read(authStateProvider.notifier).logout();
      if (!mounted) return;
      context.go('/auth/login');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _resendOtp() {
    if (_resendTimer > 0) return;
    _sendDeletionOtp();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: 16.h),
            Text(
              'Confirm Deletion',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.white : AppColors.black,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              _phone.isEmpty
                  ? 'Sending a deletion code to your registered phone number.'
                  : 'Enter the 6-digit code sent to $_phone to permanently delete your account.',
              style: TextStyle(
                fontSize: 14.sp,
                color: AppColors.grey500,
                height: 1.5,
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: 12.h),
              Text(
                _error!,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: AppColors.error,
                  height: 1.4,
                ),
              ),
            ],
            SizedBox(height: 32.h),

            // OTP fields
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 44.w,
                  child: TextFormField(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    style: TextStyle(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(
                          color: AppColors.error,
                          width: 2,
                        ),
                      ),
                    ),
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) {
                      if (value.isNotEmpty && i < 5) {
                        _focusNodes[i + 1].requestFocus();
                      } else if (value.isEmpty && i > 0) {
                        _focusNodes[i - 1].requestFocus();
                      }
                      if (_otp.length == 6) _verifyAndDelete();
                    },
                  ),
                );
              }),
            ),
            SizedBox(height: 24.h),

            // Resend
            Center(
              child: _resendTimer > 0
                  ? Text(
                      'Resend code in ${_resendTimer}s',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: AppColors.grey500,
                      ),
                    )
                  : TextButton(
                      onPressed: _isSendingOtp ? null : _resendOtp,
                      child: Text(
                        _isSendingOtp ? 'Sending...' : 'Resend OTP',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
            ),
            SizedBox(height: 32.h),

            MjButton(
              text: _isLoading ? 'Verifying...' : 'Delete My Account',
              onPressed: (_isLoading || _isSendingOtp)
                  ? null
                  : _verifyAndDelete,
            ),

            SizedBox(height: 16.h),
            Center(
              child: TextButton(
                onPressed: () => context.pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
