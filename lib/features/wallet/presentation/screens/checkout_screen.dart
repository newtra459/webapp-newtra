import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../../core/constants/app_colors.dart';
import '../providers/wallet_provider.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  final String checkoutUrl;
  final String paymentId;
  final String amount;

  const CheckoutScreen({
    super.key,
    required this.checkoutUrl,
    required this.paymentId,
    required this.amount,
  });

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late final WebViewController _controller;
  Timer? _pollTimer;
  String _status = 'webview'; // webview | success | failed
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {},
        onPageFinished: (_) {},
      ))
      ..loadRequest(Uri.parse(widget.checkoutUrl));

    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      _attempts++;
      if (_attempts > 60) {
        _pollTimer?.cancel();
        return;
      }
      try {
        final repo = ref.read(walletRepositoryProvider);
        final status = await repo.checkDodoPaymentStatus(widget.paymentId);
        if (status == 'success') {
          _pollTimer?.cancel();
          await ref.read(walletProvider.notifier).loadWallet();
          if (mounted) setState(() => _status = 'success');
        } else if (status == 'failed' || status == 'cancelled') {
          _pollTimer?.cancel();
          if (mounted) setState(() => _status = 'failed');
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  void _handleCancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel payment?'),
        content: const Text('Are you sure you want to cancel this payment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Keep Paying'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _pollTimer?.cancel();
              context.pop();
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_status == 'success') {
      return _buildStateScreen(
        icon: Icons.check_circle_rounded,
        iconColor: AppColors.success,
        title: 'Payment Successful',
        subtitle: '₹${widget.amount} has been added to your wallet.',
        buttonText: 'Done',
        onPressed: () => context.pop(),
      );
    }

    if (_status == 'failed') {
      return _buildStateScreen(
        icon: Icons.cancel_rounded,
        iconColor: AppColors.error,
        title: 'Payment Failed',
        subtitle: 'The payment could not be processed. Please try again.',
        buttonText: 'Try Again',
        onPressed: () => context.pop(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _handleCancel,
        ),
        title: Text(
          'Complete Payment',
          style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _handleCancel,
            child: Text(
              'Cancel',
              style: TextStyle(
                color: AppColors.error,
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  Widget _buildStateScreen({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback onPressed,
  }) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72.w,
                  height: 72.w,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(24.r),
                  ),
                  child: Icon(icon, size: 40.w, color: iconColor),
                ),
                SizedBox(height: 16.h),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 22.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: AppColors.grey500,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 24.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPressed,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 16.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      buttonText,
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
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
