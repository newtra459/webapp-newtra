import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/storage/local_storage.dart';

final authStateProvider = StateNotifierProvider<AuthStateNotifier, AuthState>((ref) {
  return AuthStateNotifier();
});

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? token;
  final bool hasCompletedRegistration;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.token,
    this.hasCompletedRegistration = false,
  });

  AuthState copyWith({
    AuthStatus? status,
    String? token,
    bool? hasCompletedRegistration,
  }) {
    return AuthState(
      status: status ?? this.status,
      token: token ?? this.token,
      hasCompletedRegistration:
          hasCompletedRegistration ?? this.hasCompletedRegistration,
    );
  }
}

class AuthStateNotifier extends StateNotifier<AuthState> {
  AuthStateNotifier() : super(const AuthState()) {
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    final token = LocalStorage.getToken();
    final registered = LocalStorage.getBool('registration_complete') ?? false;

    if (token != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        token: token,
        hasCompletedRegistration: registered,
      );
    } else {
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<void> setAuthenticated(String token) async {
    await LocalStorage.saveToken(token);
    state = state.copyWith(
      status: AuthStatus.authenticated,
      token: token,
    );
  }

  Future<void> setRegistrationComplete() async {
    await LocalStorage.setBool('registration_complete', true);
    state = state.copyWith(hasCompletedRegistration: true);
  }

  Future<void> logout() async {
    // Set state synchronously first so router redirect sees it immediately
    state = const AuthState(status: AuthStatus.unauthenticated);
    await Future.wait([
      LocalStorage.clearAuth(),
      LocalStorage.remove('registration_complete'),
      LocalStorage.clearActiveRide(),
      LocalStorage.clearActiveTransitTrip(),
    ]);
  }

  Future<void> deleteAccount() async {
    // API call to delete account would go here
    await logout();
  }
}
