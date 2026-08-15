import '../models/transaction_model.dart';

abstract class WalletRepository {
  Future<double> getBalance();
  Future<double> addMoney(double amount);
  Future<double> withdraw(double amount);
  Future<List<TransactionModel>> getTransactions();
  Future<String?> applyCoupon(String code);

  /// Dodo payment integration
  Future<Map<String, dynamic>?> createDodoPayment(double amount);
  Future<String> checkDodoPaymentStatus(String paymentId);

  /// Coins from active subscriptions
  Future<Map<String, dynamic>> getCoins();
}
