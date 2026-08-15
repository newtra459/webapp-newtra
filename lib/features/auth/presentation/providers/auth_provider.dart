import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_storage.dart';
import '../../../../core/network/providers.dart';
import '../../data/models/auth_user_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/auth_repository_impl.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(ref.watch(apiClientProvider));
});

class AuthFormState {
  final String phone;
  final bool isLoading;
  final String? error;
  final bool otpSent;
  final bool accountExists;

  const AuthFormState({
    this.phone = '',
    this.isLoading = false,
    this.error,
    this.otpSent = false,
    this.accountExists = false,
  });

  AuthFormState copyWith({
    String? phone,
    bool? isLoading,
    String? error,
    bool? otpSent,
    bool? accountExists,
  }) {
    return AuthFormState(
      phone: phone ?? this.phone,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      otpSent: otpSent ?? this.otpSent,
      accountExists: accountExists ?? this.accountExists,
    );
  }
}

class AuthFormNotifier extends StateNotifier<AuthFormState> {
  final AuthRepository _repository;

  AuthFormNotifier(this._repository) : super(const AuthFormState());

  Future<bool> sendOtp(String phone) async {
    state = state.copyWith(phone: phone, isLoading: true);
    try {
      final exists = await _repository.sendOtp(phone);
      state = state.copyWith(isLoading: false, otpSent: true, accountExists: exists);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> verifyOtp(String otp) async {
    state = state.copyWith(isLoading: true);
    try {
      final result = await _repository.verifyOtp(state.phone, otp);
      await LocalStorage.saveToken(result.token);
      state = state.copyWith(
        isLoading: false,
        accountExists: result.accountExists,
      );
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  Future<bool> register(AuthUserModel user) async {
    state = state.copyWith(isLoading: true);
    try {
      final token = await _repository.register(user);
      if (token.isNotEmpty) {
        await LocalStorage.saveToken(token);
      }
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

final authFormProvider = StateNotifierProvider<AuthFormNotifier, AuthFormState>((ref) {
  return AuthFormNotifier(ref.watch(authRepositoryProvider));
});
