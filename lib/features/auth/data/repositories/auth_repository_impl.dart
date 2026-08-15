import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../models/auth_user_model.dart';
import 'auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;

  AuthRepositoryImpl(this._api);

  @override
  Future<bool> sendOtp(String phone) async {
    // Backend POST /auth/login returns:
    // { success: true, data: { account_exists: bool }, message: "OTP sent..." }
    final res = await _api.post(
      ApiEndpoints.auth.sendOtp,
      data: {'phone': phone},
    );
    final data = res.data['data'] as Map<String, dynamic>? ?? {};
    return data['account_exists'] as bool? ?? false;
  }

  @override
  Future<({String token, bool accountExists})> verifyOtp(
    String phone,
    String otp,
  ) async {
    // Backend POST /auth/verify_otp returns:
    // { success: true, data: { account_exists: bool, token: "jwt..." }, message: "OTP verified." }
    final res = await _api.post(
      ApiEndpoints.auth.verifyOtp,
      data: {'phone': phone, 'otp': otp},
    );
    final root = (res.data is Map<String, dynamic>)
        ? (res.data as Map<String, dynamic>)
        : <String, dynamic>{};
    final data = (root['data'] is Map<String, dynamic>)
        ? (root['data'] as Map<String, dynamic>)
        : root;

    final token = data['token'] as String? ?? root['token'] as String? ?? '';
    final accountExists = data['account_exists'] as bool? ?? false;

    return (token: token, accountExists: accountExists);
  }

  @override
  Future<String> register(AuthUserModel user) async {
    // Backend POST /auth/register returns:
    // { success: true, data: "jwt_token_string", message: "User registered successfully" }
    final res = await _api.post(
      ApiEndpoints.auth.register,
      data: user.toJson(),
    );
    // data is the JWT token string directly
    final token = res.data['data'] as String? ?? '';
    return token;
  }

  @override
  Future<String> refreshToken(String refreshToken) async {
    final res = await _api.post(
      ApiEndpoints.auth.refresh,
      data: {'refresh_token': refreshToken},
    );
    return res.data['data']?['token'] as String? ??
        res.data['token'] as String? ??
        '';
  }

  @override
  Future<void> deleteAccount({required String phone}) async {
    await _api.post(ApiEndpoints.user.delete, data: {'phone': phone});
  }
}
