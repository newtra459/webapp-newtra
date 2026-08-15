import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/widgets/mj_button.dart';
import '../../data/models/transaction_model.dart';
import '../providers/wallet_provider.dart';

// ─── demo transaction data ────────────────────────────────────────────────────

enum _TxType { credit, debit }

class _Tx {
  final IconData icon;
  final String title;
  final String subtitle;
  final String amount;
  final _TxType type;
  final String tag;

  const _Tx({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.type,
    required this.tag,
  });
}

// ─── Screen ───────────────────────────────────────────────────────────────────

IconData _iconFromString(String name) {
  switch (name) {
    case 'add_circle_rounded':      return Icons.add_circle_rounded;
    case 'remove_circle_rounded':   return Icons.remove_circle_rounded;
    case 'pedal_bike_rounded':      return Icons.pedal_bike_rounded;
    case 'directions_bus_rounded':  return Icons.directions_bus_rounded;
    case 'stars_rounded':           return Icons.stars_rounded;
    case 'subscriptions_rounded':   return Icons.subscriptions_rounded;
    case 'local_offer_rounded':     return Icons.local_offer_rounded;
    case 'monetization_on_rounded': return Icons.monetization_on_rounded;
    default:                        return Icons.receipt_rounded;
  }
}

_Tx _txFromModel(TransactionModel m) => _Tx(
  icon:     _iconFromString(m.icon),
  title:    m.title,
  subtitle: m.subtitle,
  amount:   m.amount,
  type:     m.type == TransactionType.credit ? _TxType.credit : _TxType.debit,
  tag:      m.tag,
);

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  final _couponController = TextEditingController();
  String? _couponMessage;
  bool _couponSuccess = false;
  double _balance = 0.0;
  List<_Tx> _txList = const [];

  @override
  void initState() {
    super.initState();
    _balance = LocalStorage.getWalletBalance();
  }

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  Future<void> _applyCoupon() async {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;
    HapticFeedback.lightImpact();
    await ref.read(walletProvider.notifier).applyCoupon(code);
    if (!mounted) return;
    final ws = ref.read(walletProvider);
    setState(() {
      _couponSuccess = ws.couponSuccess;
      _couponMessage = ws.couponMessage;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sync balance and transactions from provider
    final walletState = ref.watch(walletProvider);
    _balance = walletState.balance;
    _txList = walletState.transactions.map(_txFromModel).toList().cast<_Tx>();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF4F6F9),
      body: RefreshIndicator(
        onRefresh: () => ref.read(walletProvider.notifier).loadWallet(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Hero header ──────────────────────────────────────────────────────
            SliverToBoxAdapter(child: _buildHero(context, walletState.isLoading)),

            // ── Body ─────────────────────────────────────────────────────────────
            SliverPadding(
              padding: EdgeInsets.fromLTRB(20.w, 24.h, 20.w, 40.h),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                // ── Quick actions ──
                _SectionLabel(label: 'Quick Actions'),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    _QuickAction(
                      icon: Icons.add_rounded,
                      label: 'Add Money',
                      color: AppColors.primary,
                      onTap: () => _showAddMoney(context),
                    ),
                    SizedBox(width: 12.w),
                    _QuickAction(
                      icon: Icons.account_balance_outlined,
                      label: 'Withdraw',
                      color: AppColors.info,
                      onTap: () => _showWithdraw(context),
                    ),
                    SizedBox(width: 12.w),
                    _QuickAction(
                      icon: Icons.history_rounded,
                      label: 'History',
                      color: AppColors.warning,
                      onTap: () => _showHistory(context),
                    ),
                  ],
                ),
                SizedBox(height: 28.h),

                // ── Coin info card ──
                if (LocalStorage.getTotalDisplayCoins() > 0) ...[
                  _CoinInfoCard(isDark: isDark),
                  SizedBox(height: 28.h),
                ],

                // ── Promo banner ──
                _PromoBanner(onClaim: () => _showAddMoney(context), isDark: isDark),
                SizedBox(height: 28.h),

                // ── Coupon ──
                _SectionLabel(label: 'Redeem Coupon'),
                SizedBox(height: 12.h),
                _CouponField(
                  controller: _couponController,
                  message: _couponMessage,
                  isSuccess: _couponSuccess,
                  onApply: _applyCoupon,
                  isDark: isDark,
                ),
                SizedBox(height: 28.h),

                // ── Transactions ──
                Row(
                  children: [
                    Expanded(
                      child: _SectionLabel(label: 'Transactions'),
                    ),
                    Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                ..._txList.map((tx) => _TxTile(tx: tx, isDark: isDark)),
                if (_txList.isEmpty)
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: 24.h),
                    child: Center(
                      child: Text(
                        'No transactions yet',
                        style: TextStyle(
                            fontSize: 13.sp, color: AppColors.grey500),
                      ),
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHero(BuildContext context, bool isRefreshing) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1412), Color(0xFF0A2118)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 8.h, 20.w, 32.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).maybePop(),
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(Icons.arrow_back_ios_new_rounded,
                          size: 16.w, color: Colors.white),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'My Wallet',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () async {
                      HapticFeedback.lightImpact();
                      await ref.read(walletProvider.notifier).loadWallet();
                    },
                    child: Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: isRefreshing
                          ? Padding(
                              padding: EdgeInsets.all(9.w),
                              child: const CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Icon(Icons.refresh_rounded,
                              size: 18.w, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 28.h),

              // Balance display
              Text(
                'Available Balance',
                style:
                    TextStyle(fontSize: 13.sp, color: Colors.white54),
              ),
              SizedBox(height: 6.h),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '₹ ${_balance.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 42.sp,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6.r),
                ),
                child: Text(
                  'ACTIVE',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              SizedBox(height: 24.h),

              // Stats row
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _HeroStat(
                        icon: Icons.stars_rounded,
                        value: '${LocalStorage.getTotalDisplayCoins()}',
                        label: 'Total Coins',
                        iconColor: AppColors.warning,
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 36.h,
                        color: Colors.white.withValues(alpha: 0.12)),
                    Expanded(
                      child: _HeroStat(
                        icon: Icons.monetization_on_outlined,
                        value: '${LocalStorage.getAvailableSubCoinsToday()}',
                        label: 'Redeemable',
                        iconColor: AppColors.primary,
                      ),
                    ),
                    Container(
                        width: 1,
                        height: 36.h,
                        color: Colors.white.withValues(alpha: 0.12)),
                    Expanded(
                      child: _HeroStat(
                        icon: Icons.schedule_rounded,
                        value: '${LocalStorage.getAvailableSubCoinsToday() * 60}',
                        label: 'Daily Time',
                        unit: 'min',
                        iconColor: AppColors.info,
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

  void _showAddMoney(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddMoneySheet(),
    ).then((_) {
      if (mounted) {
        ref.read(walletProvider.notifier).loadWallet();
      }
    });
  }

  void _showWithdraw(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final amountCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = isDark ? const Color(0xFF161C26) : Colors.white;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.only(
            left: 24.w,
            right: 24.w,
            top: 12.h,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 28.h,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w, height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.account_balance_outlined,
                        color: AppColors.info, size: 22.w),
                  ),
                  SizedBox(width: 12.w),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Withdraw Money',
                          style: TextStyle(
                              fontSize: 20.sp, fontWeight: FontWeight.w800)),
                      Text('Available: ₹${_balance.toStringAsFixed(2)}',
                          style: TextStyle(
                              fontSize: 12.sp, color: AppColors.grey500)),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20.h),
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'Enter amount to withdraw',
                  prefixText: '₹  ',
                  prefixStyle: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.grey700),
                  filled: true,
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.grey50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide: BorderSide(
                        color: isDark ? Colors.white12 : AppColors.grey200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                    borderSide:
                        const BorderSide(color: AppColors.info, width: 1.5),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16.w, color: AppColors.info),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'Withdrawals are processed within 2–3 business days to your linked bank account.',
                        style: TextStyle(
                            fontSize: 12.sp, color: AppColors.grey500),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20.h),
              Row(
                children: [
                  Expanded(
                    child: MjButton(
                      text: 'Cancel',
                      isOutlined: true,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: MjButton(
                      text: 'Withdraw',
                      onPressed: () async {
                        final amount = double.tryParse(amountCtrl.text.trim());
                        if (amount == null || amount <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Enter a valid amount'),
                              backgroundColor: AppColors.warning,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12.r)),
                            ),
                          );
                          return;
                        }

                        final ok = await ref.read(walletProvider.notifier).withdraw(amount);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(ok
                                ? 'Withdrawal request submitted!'
                                : 'Insufficient balance or request failed'),
                            backgroundColor: ok ? AppColors.info : AppColors.error,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.r)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHistory(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final bg = isDark ? const Color(0xFF161C26) : Colors.white;
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
          ),
          padding: EdgeInsets.fromLTRB(0, 12.h, 0, 32.h),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.75,
            minChildSize: 0.4,
            maxChildSize: 0.92,
            builder: (ctx2, scrollCtrl) {
              return Column(
                children: [
                  Center(
                    child: Container(
                      width: 36.w, height: 4.h,
                      decoration: BoxDecoration(
                        color: AppColors.grey300,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Transaction History',
                              style: TextStyle(
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800)),
                        ),
                        SizedBox(width: 10.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Text(
                            '${_txList.length} records',
                            style: TextStyle(
                                fontSize: 11.sp,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      itemCount: _txList.length,
                      itemBuilder: (_, i) =>
                          _TxTile(tx: _txList[i], isDark: isDark),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Section label
// ═══════════════════════════════════════════════════════════════════

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 15.sp,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppColors.grey900,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Hero stat
// ═══════════════════════════════════════════════════════════════════

class _HeroStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color iconColor;
  final String? unit;

  const _HeroStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.iconColor,
    this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18.w, color: iconColor),
        SizedBox(height: 4.h),
        if (unit != null)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                text: value,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1,
                ),
                children: [
                  TextSpan(
                    text: ' $unit',
                    style: TextStyle(
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.white54),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Coin info card
// ═══════════════════════════════════════════════════════════════════

class _CoinInfoCard extends StatelessWidget {
  final bool isDark;
  const _CoinInfoCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final perDay = LocalStorage.getSubCoinsPerDay();
    final carryCap = LocalStorage.getSubCoinCarryCap();
    final redeemable = LocalStorage.getAvailableSubCoinsToday();
    final subRemaining = LocalStorage.getSubCoinsRemaining();
    final loyaltyCoins = LocalStorage.getCoinBalance();
    final loyaltyExpiry = LocalStorage.loyaltyCoinExpiryDays();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161C26) : Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 17.w, color: AppColors.primary),
              SizedBox(width: 8.w),
              Text(
                'Coin Usage Rules',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.grey900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _coinInfoRow(
            'Daily redeem limit',
            '$perDay coin/day',
            Icons.today_rounded,
            AppColors.info,
          ),
          SizedBox(height: 8.h),
          _coinInfoRow(
            'Carry forward',
            'Up to $carryCap coins/day',
            Icons.redo_rounded,
            AppColors.warning,
          ),
          SizedBox(height: 8.h),
          _coinInfoRow(
            'Redeemable now',
            '$redeemable coin${redeemable == 1 ? '' : 's'}',
            Icons.monetization_on_rounded,
            AppColors.primary,
          ),
          SizedBox(height: 8.h),
          _coinInfoRow(
            'Subscription coins left',
            '$subRemaining',
            Icons.subscriptions_rounded,
            AppColors.elevation,
          ),
          SizedBox(height: 8.h),
          _coinInfoRow(
            'Loyalty coins (30-day expiry)',
            loyaltyCoins > 0 && loyaltyExpiry > 0
                ? '$loyaltyCoins • oldest expires in $loyaltyExpiry day${loyaltyExpiry == 1 ? '' : 's'}'
                : '$loyaltyCoins',
            Icons.stars_rounded,
            AppColors.success,
          ),
        ],
      ),
    );
  }

  Widget _coinInfoRow(
      String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 24.w,
          height: 24.w,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 13.w, color: color),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: AppColors.grey500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        SizedBox(width: 8.w),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Quick action button
// ═══════════════════════════════════════════════════════════════════

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52.w,
              height: 52.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: color.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: color, size: 22.w),
            ),
            SizedBox(height: 6.h),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : AppColors.grey700,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Promo banner
// ═══════════════════════════════════════════════════════════════════

class _PromoBanner extends StatelessWidget {
  final VoidCallback onClaim;
  final bool isDark;
  const _PromoBanner({required this.onClaim, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.warning.withValues(alpha: 0.15),
            AppColors.warning.withValues(alpha: 0.05),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.local_offer_rounded,
                color: AppColors.warning, size: 22.w),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add ₹500, get ₹50 FREE!',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.grey900,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Limited time offer · Ends tonight',
                  style:
                      TextStyle(fontSize: 11.sp, color: AppColors.grey500),
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: onClaim,
            child: Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: AppColors.warning,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Text(
                'Claim',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Coupon field
// ═══════════════════════════════════════════════════════════════════

class _CouponField extends StatelessWidget {
  final TextEditingController controller;
  final String? message;
  final bool isSuccess;
  final VoidCallback onApply;
  final bool isDark;

  const _CouponField({
    required this.controller,
    required this.message,
    required this.isSuccess,
    required this.onApply,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = isDark ? const Color(0xFF161C26) : Colors.white;
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textCapitalization: TextCapitalization.characters,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter promo code',
                    hintStyle: TextStyle(
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0,
                      color: AppColors.grey400,
                    ),
                    prefixIcon: Icon(Icons.local_offer_outlined,
                        size: 18.w, color: AppColors.grey500),
                    filled: true,
                    fillColor:
                        isDark ? Colors.white.withValues(alpha: 0.05) : AppColors.grey50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                      borderSide: BorderSide.none,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              GestureDetector(
                onTap: onApply,
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 18.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Text(
                    'Apply',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (message != null) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSuccess
                    ? AppColors.success.withValues(alpha: 0.08)
                    : AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                message!,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: isSuccess ? AppColors.success : AppColors.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Transaction tile
// ═══════════════════════════════════════════════════════════════════

class _TxTile extends StatelessWidget {
  final _Tx tx;
  final bool isDark;
  const _TxTile({required this.tx, required this.isDark});

  static Color _tagColor(String tag) {
    switch (tag) {
      case 'Ride':
        return AppColors.info;
      case 'Plan':
        return AppColors.elevation;
      case 'Bonus':
      case 'Coupon':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isCredit = tx.type == _TxType.credit;
    final amountColor = isCredit ? AppColors.success : AppColors.grey600;
    final iconBg = isCredit
        ? AppColors.success.withValues(alpha: 0.1)
        : AppColors.grey100.withValues(alpha: isDark ? 0.1 : 1);
    final cardBg = isDark ? const Color(0xFF161C26) : Colors.white;
    final tagColor = _tagColor(tx.tag);

    return GestureDetector(
      onTap: () => _showTxDetail(context, tx, isDark),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44.w,
              height: 44.w,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12.r)),
              child: Icon(tx.icon,
                  color: isCredit ? AppColors.success : AppColors.grey500,
                  size: 22.w),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.title,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : AppColors.grey900,
                    ),
                  ),
                  SizedBox(height: 3.h),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          tx.subtitle,
                          style: TextStyle(
                              fontSize: 11.sp, color: AppColors.grey500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          tx.tag,
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: tagColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              tx.amount,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  static void _showTxDetail(BuildContext context, _Tx tx, bool isDark) {
    final isCredit = tx.type == _TxType.credit;
    final accentColor = isCredit ? AppColors.success : AppColors.error;
    final tagColor = _tagColor(tx.tag);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        ),
        padding: EdgeInsets.fromLTRB(24.w, 16.h, 24.w, 32.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevated : AppColors.grey200,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 24.h),

            // Icon
            Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(tx.icon, size: 30.w, color: accentColor),
            ),
            SizedBox(height: 16.h),

            // Amount
            Text(
              tx.amount,
              style: TextStyle(
                fontSize: 28.sp,
                fontWeight: FontWeight.w900,
                color: accentColor,
              ),
            ),
            SizedBox(height: 4.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: tagColor.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                tx.tag,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                  color: tagColor,
                ),
              ),
            ),
            SizedBox(height: 24.h),

            // Details rows
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevated : AppColors.grey50,
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Column(
                children: [
                  _detailRow('Description', tx.title, isDark),
                  _divider(isDark),
                  _detailRow('Date & Time', tx.subtitle, isDark),
                  _divider(isDark),
                  _detailRow('Type', isCredit ? 'Credit' : 'Debit', isDark),
                  _divider(isDark),
                  _detailRow('Status', 'Completed', isDark,
                      valueColor: AppColors.success),
                ],
              ),
            ),
            SizedBox(height: 24.h),

            // Close button
            SizedBox(
              width: double.infinity,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkElevated : AppColors.grey100,
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.grey300 : AppColors.grey700,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _detailRow(String label, String value, bool isDark,
      {Color? valueColor}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.sp,
              color: AppColors.grey500,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: valueColor ??
                    (isDark ? AppColors.white : AppColors.grey900),
              ),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _divider(bool isDark) {
    return Container(
      height: 1,
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.05),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  Add Money bottom sheet
// ═══════════════════════════════════════════════════════════════════

class _AddMoneySheet extends ConsumerStatefulWidget {
  const _AddMoneySheet();

  @override
  ConsumerState<_AddMoneySheet> createState() => _AddMoneySheetState();
}

class _AddMoneySheetState extends ConsumerState<_AddMoneySheet> {
  int? _selectedAmount;
  final _customCtrl = TextEditingController();
  static const _presets = [100, 200, 500, 1000];

  @override
  void dispose() {
    _customCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF161C26) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      padding: EdgeInsets.only(
        left: 24.w,
        right: 24.w,
        top: 12.h,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 36.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            'Add Money',
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 4.h),
          Text(
            'Choose an amount or enter a custom value',
            style: TextStyle(fontSize: 13.sp, color: AppColors.grey500),
          ),
          SizedBox(height: 20.h),

          // Preset amounts
          Row(
            children: _presets.map((a) {
              final selected = _selectedAmount == a;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedAmount = a;
                      _customCtrl.clear();
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(
                        right: a == _presets.last ? 0 : 10.w),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary
                          : AppColors.primary.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      '₹$a',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color:
                            selected ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 16.h),

          // Custom amount field
          TextField(
            controller: _customCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() => _selectedAmount = null),
            decoration: InputDecoration(
              hintText: 'Custom amount',
              prefixText: '₹  ',
              prefixStyle: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: AppColors.grey700,
              ),
              filled: true,
              fillColor: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.grey50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(
                    color: isDark ? Colors.white12 : AppColors.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide:
                    const BorderSide(color: AppColors.primary, width: 1.5),
              ),
            ),
          ),
          SizedBox(height: 20.h),

          MjButton(
            text: 'Proceed to Pay',
            onPressed: () async {
              final raw = _customCtrl.text.trim();
              final normalized = raw.replaceAll(',', '');
              final added = _selectedAmount?.toDouble() ??
                  (normalized.isNotEmpty ? double.tryParse(normalized) : null);

              if (added == null || added <= 0) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Enter a valid top-up amount.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final repo = ref.read(walletRepositoryProvider);
              final result = await repo.createDodoPayment(added);
              if (!mounted) return;

              if (result == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Could not create payment. Please try again.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              final checkoutUrl = result['checkout_url'] as String?;
              final paymentId = result['payment_id'] as String?;
              final errorCode = result['error_code'] as String?;

              if (errorCode == 'BILLING_ADDRESS_REQUIRED') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                        'Please add a billing address in your profile first.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              if (checkoutUrl == null || paymentId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Invalid payment response.'),
                    backgroundColor: AppColors.error,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              if (!mounted) return;
              context.push('/wallet/checkout', extra: {
                'checkout_url': checkoutUrl,
                'payment_id': paymentId,
                'amount': added.toStringAsFixed(0),
              });
            },
          ),
        ],
      ),
    );
  }
}
