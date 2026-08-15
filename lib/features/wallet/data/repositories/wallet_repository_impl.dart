import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/storage/local_storage.dart';
import '../models/transaction_model.dart';
import 'wallet_repository.dart';

class WalletRepositoryImpl implements WalletRepository {
  final ApiClient _api;

  WalletRepositoryImpl(this._api);

  double _extractBalance(Map<String, dynamic> root) {
    final data = (root['data'] is Map<String, dynamic>)
        ? (root['data'] as Map<String, dynamic>)
        : <String, dynamic>{};

    final candidates = [
      data['balance'],
      root['balance'],
      data['wallet'] is Map<String, dynamic>
          ? (data['wallet'] as Map<String, dynamic>)['balance']
          : null,
      root['wallet'] is Map<String, dynamic>
          ? (root['wallet'] as Map<String, dynamic>)['balance']
          : null,
    ];

    for (final value in candidates) {
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0.0;
  }

  List<dynamic> _extractTransactions(Map<String, dynamic> root) {
    final data = root['data'];
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      final tx = data['transactions'];
      if (tx is List) return tx;
    }
    final tx2 = root['transactions'];
    if (tx2 is List) return tx2;
    return const [];
  }

  @override
  Future<double> getBalance() async {
    try {
      final res = await _api.get(ApiEndpoints.wallet.balance);
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final balance = _extractBalance(root);
      await LocalStorage.saveWalletBalance(balance);
      return balance;
    } catch (_) {
      return 0.0;
    }
  }

  @override
  Future<double> addMoney(double amount) async {
    // Backend WalletTopup struct expects {"balance": "string_amount"}
    final res = await _api.post(ApiEndpoints.wallet.topup, data: {
      'balance': amount.toStringAsFixed(0),
    });
    final root = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};
    final balance = _extractBalance(root);
    await LocalStorage.saveWalletBalance(balance);
    return balance;
  }

  @override
  Future<double> withdraw(double amount) async {
    final res = await _api.post(ApiEndpoints.wallet.withdraw, data: {'amount': amount});
    final root = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};
    final balance = _extractBalance(root);
    await LocalStorage.saveWalletBalance(balance);
    return balance;
  }

  @override
  Future<List<TransactionModel>> getTransactions() async {
    try {
      final res = await _api.get(ApiEndpoints.wallet.transactions);
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final list = _extractTransactions(root);
      return list.map((e) => TransactionModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<String?> applyCoupon(String code) async {
    final res = await _api.post(ApiEndpoints.wallet.applyCoupon, data: {'code': code});
    return res.data['data']?['message'] as String? ??
        res.data['message'] as String?;
  }

  @override
  Future<Map<String, dynamic>?> createDodoPayment(double amount) async {
    try {
      final res = await _api.post(ApiEndpoints.wallet.createDodoPayment, data: {
        'amount': amount.toStringAsFixed(0),
      });
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final data = root['data'];
      if (data is Map<String, dynamic>) return data;
      return null;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      if (responseData is Map<String, dynamic>) {
        final data = responseData['data'];
        if (data is Map<String, dynamic> && data['error_code'] != null) {
          return {'error_code': data['error_code']};
        }
      }
      return null;
    }
  }

  @override
  Future<String> checkDodoPaymentStatus(String paymentId) async {
    try {
      final res = await _api.get(ApiEndpoints.wallet.dodoStatus(paymentId));
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final data = root['data'];
      if (data is Map<String, dynamic>) {
        return data['status'] as String? ?? 'pending';
      }
      return 'pending';
    } catch (_) {
      return 'pending';
    }
  }

  @override
  Future<Map<String, dynamic>> getCoins() async {
    try {
      final res = await _api.get(ApiEndpoints.wallet.coins);
      final root = (res.data is Map<String, dynamic>)
          ? (res.data as Map<String, dynamic>)
          : <String, dynamic>{};
      final data = root['data'];
      if (data is Map<String, dynamic>) return data;
      return {};
    } catch (_) {
      return {};
    }
  }
}
