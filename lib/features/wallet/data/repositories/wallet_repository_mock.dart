// Dummy data mock — swap back to WalletRepositoryImpl in wallet_provider.dart
// when the backend /wallet endpoints are live.

import '../../../../core/storage/local_storage.dart';
import '../models/transaction_model.dart';
import 'wallet_repository.dart';

class WalletRepositoryMock implements WalletRepository {
  double _balance = 0.0;

  WalletRepositoryMock() {
    final saved = LocalStorage.getWalletBalance();
    if (saved >= 0) {
      _balance = saved;
    }
  }

  static final List<TransactionModel> _transactions = [
    TransactionModel(
      id: 'tx-01',
      icon: 'directions_bike',
      title: 'Ride Payment',
      subtitle: 'Sports Complex → Hostel Block C',
      amount: '₹8',
      type: TransactionType.debit,
      tag: 'Ride',
      date: DateTime(2026, 3, 18, 18, 56),
    ),
    TransactionModel(
      id: 'tx-02',
      icon: 'add_circle_rounded',
      title: 'Wallet Top-up',
      subtitle: 'UPI · XXXXXX1234',
      amount: '₹200',
      type: TransactionType.credit,
      tag: 'Top-up',
      date: DateTime(2026, 3, 17, 11, 30),
    ),
    TransactionModel(
      id: 'tx-03',
      icon: 'star_rounded',
      title: 'Coins Redeemed',
      subtitle: '150 coins → ₹15',
      amount: '₹15',
      type: TransactionType.credit,
      tag: 'Coins',
      date: DateTime(2026, 3, 16, 9, 45),
    ),
    TransactionModel(
      id: 'tx-04',
      icon: 'directions_bus',
      title: 'Bus Fare',
      subtitle: 'Route R1 · Main Gate → Research Park',
      amount: '₹5',
      type: TransactionType.debit,
      tag: 'Transit',
      date: DateTime(2026, 3, 14, 10, 35),
    ),
    TransactionModel(
      id: 'tx-05',
      icon: 'card_membership',
      title: 'Subscription',
      subtitle: 'Campus Pro · 30 days',
      amount: '₹149',
      type: TransactionType.debit,
      tag: 'Subscription',
      date: DateTime(2026, 3, 1, 8, 0),
    ),
    TransactionModel(
      id: 'tx-06',
      icon: 'add_circle_rounded',
      title: 'Wallet Top-up',
      subtitle: 'UPI · XXXXXX1234',
      amount: '₹500',
      type: TransactionType.credit,
      tag: 'Top-up',
      date: DateTime(2026, 2, 28, 14, 20),
    ),
    TransactionModel(
      id: 'tx-07',
      icon: 'directions_bike',
      title: 'Ride Payment',
      subtitle: 'Main Gate → Library Hub',
      amount: '₹6',
      type: TransactionType.debit,
      tag: 'Ride',
      date: DateTime(2026, 2, 27, 7, 36),
    ),
    TransactionModel(
      id: 'tx-08',
      icon: 'local_offer',
      title: 'Coupon Applied',
      subtitle: 'WELCOME50 · ₹50 credited',
      amount: '₹50',
      type: TransactionType.credit,
      tag: 'Coupon',
      date: DateTime(2026, 2, 25, 10, 0),
    ),
    TransactionModel(
      id: 'tx-09',
      icon: 'directions_bike',
      title: 'Ride Payment',
      subtitle: 'Library Hub → Sports Complex',
      amount: '₹7',
      type: TransactionType.debit,
      tag: 'Ride',
      date: DateTime(2026, 2, 23, 17, 15),
    ),
    TransactionModel(
      id: 'tx-10',
      icon: 'directions_bike',
      title: 'E-Bike Charge',
      subtitle: 'Battery charge credit',
      amount: '₹5',
      type: TransactionType.debit,
      tag: 'Ride',
      date: DateTime(2026, 2, 22, 9, 30),
    ),
    TransactionModel(
      id: 'tx-11',
      icon: 'directions_bus',
      title: 'Bus Fare',
      subtitle: 'Route R2 · Admin Block → Main Gate',
      amount: '₹5',
      type: TransactionType.debit,
      tag: 'Transit',
      date: DateTime(2026, 2, 20, 8, 45),
    ),
    TransactionModel(
      id: 'tx-12',
      icon: 'add_circle_rounded',
      title: 'Wallet Top-up',
      subtitle: 'Credit Card · XXXXXX5678',
      amount: '₹1000',
      type: TransactionType.credit,
      tag: 'Top-up',
      date: DateTime(2026, 2, 18, 16, 0),
    ),
    TransactionModel(
      id: 'tx-13',
      icon: 'directions_bike',
      title: 'Ride Payment',
      subtitle: 'Hostel Block A → Main Gate',
      amount: '₹4',
      type: TransactionType.debit,
      tag: 'Ride',
      date: DateTime(2026, 2, 15, 7, 20),
    ),
    TransactionModel(
      id: 'tx-14',
      icon: 'star_rounded',
      title: 'Coins Redeemed',
      subtitle: '100 coins → ₹10',
      amount: '₹10',
      type: TransactionType.credit,
      tag: 'Coins',
      date: DateTime(2026, 2, 12, 11, 0),
    ),
    TransactionModel(
      id: 'tx-15',
      icon: 'card_membership',
      title: 'Subscription',
      subtitle: 'Campus Lite · 15 days',
      amount: '₹99',
      type: TransactionType.debit,
      tag: 'Subscription',
      date: DateTime(2026, 2, 10, 9, 15),
    ),
  ];

  @override
  Future<double> getBalance() async {
    await Future.delayed(const Duration(milliseconds: 400));
    final saved = LocalStorage.getWalletBalance();
    if (saved >= 0) {
      _balance = saved;
    }
    return _balance;
  }

  @override
  Future<double> addMoney(double amount) async {
    await Future.delayed(const Duration(milliseconds: 700));
    _balance += amount;
    await LocalStorage.saveWalletBalance(_balance);
    return _balance;
  }

  @override
  Future<double> withdraw(double amount) async {
    await Future.delayed(const Duration(milliseconds: 700));
    if (amount > _balance) throw Exception('Insufficient balance');
    _balance -= amount;
    await LocalStorage.saveWalletBalance(_balance);
    return _balance;
  }

  @override
  Future<List<TransactionModel>> getTransactions() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _transactions;
  }

  @override
  Future<String?> applyCoupon(String code) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (code == 'RIDE50') {
      _balance += 50;
      await LocalStorage.saveWalletBalance(_balance);
      return '₹50 credited successfully!';
    }
    if (code == 'WELCOME50') {
      _balance += 50;
      await LocalStorage.saveWalletBalance(_balance);
      return '₹50 credited successfully!';
    }
    throw Exception('Invalid or expired coupon code');
  }

  @override
  Future<Map<String, dynamic>?> createDodoPayment(double amount) async {
    return null;
  }

  @override
  Future<String> checkDodoPaymentStatus(String paymentId) async {
    return 'pending';
  }

  @override
  Future<Map<String, dynamic>> getCoins() async {
    return {
      'coins_balance': 0,
      'time_balance_mins': 0,
      'daily_coins_used': 0,
      'daily_time_used': 0,
      'active_plans': 0,
    };
  }
}
