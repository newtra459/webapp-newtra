// Dummy data mock — swap back to AuthRepositoryImpl in auth_provider.dart
// when the backend /auth endpoints are live.
//
// Dev credentials: any phone number + OTP "0000"

import '../models/auth_user_model.dart';
import 'auth_repository.dart';

class AuthRepositoryMock implements AuthRepository {
  static const _mockToken = 'mock-jwt-access-token-dev';

  @override
  Future<bool> sendOtp(String phone) async {
    await Future.delayed(const Duration(milliseconds: 800));
    return true; // account exists
  }

  @override
  Future<({String token, bool accountExists})> verifyOtp(
    String phone,
    String otp,
  ) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (otp != '0000') throw Exception('Invalid OTP — enter 0000 in dev mode');
    return (token: _mockToken, accountExists: true);
  }

  @override
  Future<String> register(AuthUserModel user) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return _mockToken;
  }

  @override
  Future<String> refreshToken(String refreshToken) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _mockToken;
  }

  @override
  Future<void> deleteAccount({required String phone}) async {
    await Future.delayed(const Duration(milliseconds: 400));
  }
}
