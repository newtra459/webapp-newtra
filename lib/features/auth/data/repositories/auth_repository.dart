import '../models/auth_user_model.dart';

abstract class AuthRepository {
  /// Sends OTP to phone. Returns whether the account already exists.
  Future<bool> sendOtp(String phone);

  /// Verifies OTP. Returns token and whether the account exists.
  Future<({String token, bool accountExists})> verifyOtp(
    String phone,
    String otp,
  );

  /// Registers a new user. Returns the new auth token.
  Future<String> register(AuthUserModel user);
  Future<String> refreshToken(String refreshToken);
  Future<void> deleteAccount({required String phone});
}
