import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_storage.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/wallet_repository.dart';
import '../../data/repositories/wallet_repository_impl.dart';
import '../../../../core/network/providers.dart';

// ── Repository ───────────────────────────────────────────────────────────────

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepositoryImpl(ref.watch(apiClientProvider));
});

// ── State ────────────────────────────────────────────────────────────────────

class WalletState {
  final double balance;
  final List<TransactionModel> transactions;
  final bool isLoading;
  final String? error;
  final String? couponMessage;
  final bool couponSuccess;
  final bool isPaymentProcessing;

  const WalletState({
    this.balance = 0.0,
    this.transactions = const [],
    this.isLoading = false,
    this.error,
    this.couponMessage,
    this.couponSuccess = false,
    this.isPaymentProcessing = false,
  });

  WalletState copyWith({
    double? balance,
    List<TransactionModel>? transactions,
    bool? isLoading,
    String? error,
    String? couponMessage,
    bool? couponSuccess,
    bool? isPaymentProcessing,
  }) {
    return WalletState(
      balance: balance ?? this.balance,
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      couponMessage: couponMessage ?? this.couponMessage,
      couponSuccess: couponSuccess ?? this.couponSuccess,
      isPaymentProcessing: isPaymentProcessing ?? this.isPaymentProcessing,
    );
  }
}

// ── Notifier ─────────────────────────────────────────────────────────────────

class WalletNotifier extends StateNotifier<WalletState> {
  final WalletRepository _repository;
  Timer? _pollTimer;

  WalletNotifier(this._repository) : super(const WalletState()) {
    loadWallet();
  }

  Future<void> loadWallet() async {
    state = state.copyWith(isLoading: true);
    try {
      final balance = await _repository.getBalance();
      final txns = await _repository.getTransactions();
      await LocalStorage.saveWalletBalance(balance);

      // Sync coins from backend
      final coins = await _repository.getCoins();
      if (coins.isNotEmpty) {
        final coinsBalance = coins['coins_balance'] as int? ?? 0;
        final timeBalanceMins = coins['time_balance_mins'] as int? ?? 0;
        final dailyCoinsUsed = coins['daily_coins_used'] as int? ?? 0;
        await LocalStorage.saveSubCoinsRemaining(coinsBalance);
        await LocalStorage.saveSubCoinsRedeemedToday(dailyCoinsUsed);
        // time_balance_mins can inform daily time display
        if (timeBalanceMins > 0) {
          await LocalStorage.saveSubCoinsPerDay(timeBalanceMins > 0 ? 1 : 0);
        }
      }

      state = state.copyWith(balance: balance, transactions: txns, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<bool> addMoney(double amount) async {
    try {
      final balance = await _repository.addMoney(amount);
      await LocalStorage.saveWalletBalance(balance);
      state = state.copyWith(balance: balance);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Create a Dodo payment and return the checkout URL.
  /// Starts background polling for payment status.
  Future<String?> createDodoPayment(double amount) async {
    try {
      final result = await _repository.createDodoPayment(amount);
      if (result == null) return null;

      final checkoutUrl = result['checkout_url'] as String?;
      final paymentId = result['payment_id'] as String?;

      if (checkoutUrl != null && paymentId != null) {
        _startPaymentPolling(paymentId);
        return checkoutUrl;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _startPaymentPolling(String paymentId) {
    _pollTimer?.cancel();
    state = state.copyWith(isPaymentProcessing: true);
    var attempts = 0;
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      attempts++;
      if (attempts > 40) {
        timer.cancel();
        state = state.copyWith(isPaymentProcessing: false);
        return;
      }
      try {
        final status = await _repository.checkDodoPaymentStatus(paymentId);
        if (status == 'success') {
          timer.cancel();
          await loadWallet();
          state = state.copyWith(isPaymentProcessing: false);
        } else if (status == 'failed' || status == 'cancelled') {
          timer.cancel();
          state = state.copyWith(
            isPaymentProcessing: false,
            error: 'Payment failed. Please try again.',
          );
        }
      } catch (_) {}
    });
  }

  Future<bool> withdraw(double amount) async {
    try {
      final balance = await _repository.withdraw(amount);
      await LocalStorage.saveWalletBalance(balance);
      state = state.copyWith(balance: balance);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> applyCoupon(String code) async {
    try {
      final msg = await _repository.applyCoupon(code);
      state = state.copyWith(couponSuccess: true, couponMessage: msg ?? 'Coupon applied!');
      await loadWallet();
    } catch (_) {
      state = state.copyWith(couponSuccess: false, couponMessage: 'Invalid coupon code.');
    }
  }

  void clearCouponMessage() {
    state = WalletState(
      balance: state.balance,
      transactions: state.transactions,
      isLoading: state.isLoading,
      couponSuccess: false,
    );
  }

  /// Direct balance update for local operations
  void updateBalance(double balance) {
    LocalStorage.saveWalletBalance(balance);
    state = state.copyWith(balance: balance);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

// ── Provider ─────────────────────────────────────────────────────────────────

final walletProvider = StateNotifierProvider<WalletNotifier, WalletState>((ref) {
  return WalletNotifier(ref.watch(walletRepositoryProvider));
});
