import 'package:flutter_test/flutter_test.dart';
import 'package:mjollnir_app/features/wallet/presentation/providers/wallet_provider.dart';
import 'package:mjollnir_app/features/wallet/data/models/transaction_model.dart';
import 'package:mjollnir_app/features/wallet/data/repositories/wallet_repository.dart';

// ── Mock ─────────────────────────────────────────────────────────────────────

class MockWalletRepository implements WalletRepository {
  double _balance = 500.0;
  bool shouldThrow = false;

  @override
  Future<double> getBalance() async {
    if (shouldThrow) throw Exception('Network error');
    return _balance;
  }

  @override
  Future<double> addMoney(double amount) async {
    if (shouldThrow) throw Exception('Failed');
    _balance += amount;
    return _balance;
  }

  @override
  Future<double> withdraw(double amount) async {
    if (shouldThrow) throw Exception('Failed');
    _balance -= amount;
    return _balance;
  }

  @override
  Future<List<TransactionModel>> getTransactions() async {
    if (shouldThrow) return [];
    return [
      TransactionModel(
        id: '1',
        icon: 'add',
        title: 'Top-up',
        subtitle: 'Today',
        amount: '+₹500',
        type: TransactionType.credit,
        tag: 'Top-up',
        date: DateTime.now(),
      ),
    ];
  }

  @override
  Future<String?> applyCoupon(String code) async {
    if (code == 'VALID') return 'Coupon applied! ₹10 credited.';
    throw Exception('Invalid coupon');
  }

  @override
  Future<Map<String, dynamic>> createDodoPayment(double amount) async {
    return {'payment_id': 'dodo-1', 'checkout_url': 'https://example.com', 'amount': amount};
  }

  @override
  Future<String> checkDodoPaymentStatus(String paymentId) async {
    return 'completed';
  }

  @override
  Future<Map<String, dynamic>> getCoins() async {
    return {
      'coins_balance': 10,
      'time_balance_mins': 60,
      'daily_coins_used': 2,
      'daily_time_used': 15,
      'active_plans': 1,
    };
  }
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late MockWalletRepository mockRepo;
  late WalletNotifier notifier;

  setUp(() {
    mockRepo = MockWalletRepository();
    notifier = WalletNotifier(mockRepo);
  });

  group('WalletNotifier', () {
    test('initializes and loads wallet', () async {
      // Give time for loadWallet in constructor
      await Future.delayed(const Duration(milliseconds: 100));

      expect(notifier.state.balance, 500.0);
      expect(notifier.state.transactions.length, 1);
      expect(notifier.state.isLoading, isFalse);
    });

    test('addMoney increases balance', () async {
      final success = await notifier.addMoney(200);

      expect(success, isTrue);
      expect(notifier.state.balance, 700.0);
    });

    test('addMoney returns false on failure', () async {
      mockRepo.shouldThrow = true;
      final success = await notifier.addMoney(100);

      expect(success, isFalse);
    });

    test('withdraw decreases balance', () async {
      final success = await notifier.withdraw(100);

      expect(success, isTrue);
      expect(notifier.state.balance, 400.0);
    });

    test('applyCoupon sets success message for valid code', () async {
      await notifier.applyCoupon('VALID');

      expect(notifier.state.couponSuccess, isTrue);
      expect(notifier.state.couponMessage, contains('Coupon applied'));
    });

    test('applyCoupon sets failure message for invalid code', () async {
      await notifier.applyCoupon('INVALID');

      expect(notifier.state.couponSuccess, isFalse);
      expect(notifier.state.couponMessage, contains('Invalid'));
    });

    test('clearCouponMessage clears the message', () async {
      await notifier.applyCoupon('VALID');
      notifier.clearCouponMessage();

      expect(notifier.state.couponMessage, isNull);
    });

    test('updateBalance sets balance directly', () {
      notifier.updateBalance(999.0);
      expect(notifier.state.balance, 999.0);
    });
  });

  group('WalletState', () {
    test('copyWith preserves unchanged fields', () {
      const state = WalletState(balance: 100);
      final updated = state.copyWith(balance: 200);

      expect(updated.balance, 200);
      expect(updated.transactions, isEmpty);
    });
  });

  group('TransactionModel', () {
    test('fromJson parses correctly', () {
      final json = {
        'id': 'tx1',
        'title': 'Top-up',
        'subtitle': 'Now',
        'amount': '+₹100',
        'type': 'credit',
        'tag': 'Top-up',
        'date': '2026-03-19T10:00:00.000',
      };

      final tx = TransactionModel.fromJson(json);
      expect(tx.id, 'tx1');
      expect(tx.type, TransactionType.credit);
      expect(tx.title, 'Top-up');
    });

    test('toJson round-trips', () {
      final tx = TransactionModel(
        id: 'tx2',
        icon: 'bike',
        title: 'Ride',
        subtitle: 'Today',
        amount: '-₹25',
        type: TransactionType.debit,
        tag: 'Ride',
        date: DateTime(2026, 3, 19),
      );

      final json = tx.toJson();
      expect(json['type'], 'debit');
      expect(json['tag'], 'Ride');
    });
  });
}
