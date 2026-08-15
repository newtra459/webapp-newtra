import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/registration_screen.dart';
import '../../features/auth/presentation/screens/delete_account_otp_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/ride/presentation/screens/qr_scanner_screen.dart';
import '../../features/ride/presentation/screens/ride_screen.dart';
import '../../features/ride/presentation/screens/ride_summary_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/profile/presentation/screens/edit_profile_screen.dart';
import '../../features/profile/presentation/screens/achievements_screen.dart';
import '../../features/trips/presentation/screens/trips_screen.dart';
import '../../features/trips/presentation/screens/trip_detail_screen.dart';
import '../../features/wallet/presentation/screens/wallet_screen.dart';
import '../../features/wallet/presentation/screens/checkout_screen.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';
import '../../features/social/presentation/screens/friends_screen.dart';
import '../../features/social/presentation/screens/leaderboard_screen.dart';
import '../../features/social/presentation/screens/user_profile_screen.dart';
import '../../features/groups/presentation/screens/groups_screen.dart';
import '../../features/groups/presentation/screens/group_detail_screen.dart';
import '../../features/groups/presentation/screens/create_group_screen.dart';
import '../../features/activity/presentation/screens/activity_screen.dart';
import '../../features/support/presentation/screens/support_screen.dart';
import '../../features/support/presentation/screens/report_issue_screen.dart';
import '../../features/support/presentation/screens/ai_chat_screen.dart';
import '../../features/support/presentation/screens/email_us_screen.dart';
import '../../features/transit/presentation/screens/transit_screen.dart';
import '../../features/transit/presentation/screens/transit_board_screen.dart';
import '../../features/transit/presentation/screens/transit_active_trip_screen.dart';
import '../widgets/navigation_shell.dart';
import '../../features/auth/presentation/providers/auth_state_provider.dart';

/// A [ChangeNotifier] that bridges Riverpod state changes to GoRouter.
class AuthChangeNotifier extends ChangeNotifier {
  AuthChangeNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (prev, next) {
      if (prev?.status != next.status) {
        notifyListeners();
      }
    });
  }
  final Ref _ref;
}

final _authChangeNotifierProvider = Provider<AuthChangeNotifier>((ref) {
  return AuthChangeNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.read(_authChangeNotifierProvider);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: authNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);
      final isAuth = authState.status == AuthStatus.authenticated;
      final isUnauth = authState.status == AuthStatus.unauthenticated;
      final isSplash = state.matchedLocation == '/splash';
      final isAuthRoute = state.matchedLocation.startsWith('/auth');

      if (isSplash) return null;

      if (isUnauth && !isAuthRoute) return '/auth/login';
      if (isAuth && isAuthRoute) return '/home';

      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) =>
            NoTransitionPage(key: state.pageKey, child: const SplashScreen()),
      ),

      // Auth routes
      GoRoute(
        path: '/auth/login',
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final slideIn =
                Tween<Offset>(
                  begin: const Offset(1.0, 0.0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeInOut),
                );
            return SlideTransition(position: slideIn, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        ),
      ),
      GoRoute(
        path: '/auth/otp',
        builder: (context, state) {
          final phone = state.extra as String? ?? '';
          return OtpScreen(phoneNumber: phone);
        },
      ),
      GoRoute(
        path: '/auth/register',
        builder: (context, state) => const RegistrationScreen(),
      ),
      GoRoute(
        path: '/account/delete-verify',
        builder: (context, state) => const DeleteAccountOtpScreen(),
      ),

      // Main app with bottom nav
      ShellRoute(
        builder: (context, state, child) => NavigationShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomeScreen()),
          ),
          GoRoute(
            path: '/bikes',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: QrScannerScreen()),
          ),
          GoRoute(
            path: '/community',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FriendsScreen()),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProfileScreen()),
          ),
        ],
      ),

      // Detail routes
      GoRoute(
        path: '/ride',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return RideScreen(
            rideMode: extra['rideMode'] as int? ?? 0,
            isEBike: extra['isEBike'] as bool? ?? true,
            paidWithCoin: extra['paidWithCoin'] as bool? ?? false,
            bikeId:
                extra['bikeId'] as String? ?? extra['qrData'] as String? ?? '',
            // Resume is explicit from the "Continue" entry points; also treat a
            // saved session (has startTime) as a resume as a safety net.
            resume: extra['resume'] as bool? ?? extra.containsKey('startTime'),
          );
        },
      ),
      GoRoute(
        path: '/ride/summary',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return RideSummaryScreen(rideData: extra);
        },
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(path: '/trips', builder: (context, state) => const TripsScreen()),
      GoRoute(
        path: '/trips/detail',
        builder: (context, state) {
          final trip = state.extra as Map<String, dynamic>? ?? {};
          return TripDetailScreen(trip: trip);
        },
      ),
      GoRoute(
        path: '/wallet',
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: '/wallet/checkout',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return CheckoutScreen(
            checkoutUrl: extra['checkout_url'] as String? ?? '',
            paymentId: extra['payment_id'] as String? ?? '',
            amount: extra['amount'] as String? ?? '0',
          );
        },
      ),
      GoRoute(
        path: '/subscriptions',
        builder: (context, state) => const SubscriptionScreen(),
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/user-profile',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return UserProfileScreen(
            name: extra['name'] as String? ?? '',
            type: extra['type'] as String? ?? '',
            distance: extra['distance'] as String? ?? '',
            following: extra['following'] as bool? ?? false,
            userId: extra['userId'] as String? ?? '',
            avatarUrl: extra['avatarUrl'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsScreen(),
      ),
      GoRoute(
        path: '/groups/detail',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return GroupDetailScreen(
            groupId: extra['id'] as String? ?? '',
            name: extra['name'] as String? ?? 'Campus Cyclists',
            desc: extra['desc'] as String? ?? 'Ride together across campus!',
            members: extra['members'] as int? ?? 32,
            joined: extra['joined'] as bool? ?? false,
            createdByMe: extra['createdByMe'] as bool? ?? false,
          );
        },
      ),
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => const ActivityScreen(),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/support/report',
        builder: (context, state) => const ReportIssueScreen(),
      ),
      GoRoute(
        path: '/support/chat',
        builder: (context, state) => const AiChatScreen(),
      ),
      GoRoute(
        path: '/support/email',
        builder: (context, state) => const EmailUsScreen(),
      ),
      GoRoute(
        path: '/transit',
        builder: (context, state) => const TransitScreen(),
      ),
      GoRoute(
        path: '/transit/board',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return TransitBoardScreen(
            stopId: extra['stopId'] as String? ?? '',
            vehicleId: extra['vehicleId'] as String? ?? '',
            stopName: extra['stopName'] as String? ?? '',
            transitType: extra['type'] as String? ?? 'bus',
            route: extra['route'] as String? ?? '',
            vehicleName: extra['vehicleName'] as String? ?? '',
            vehicleNumber: extra['vehicleNumber'] as String? ?? '',
            vehicleImageUrl: extra['vehicleImageUrl'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: '/transit/active',
        builder: (context, state) {
          final extra = state.extra as Map<String, dynamic>? ?? {};
          return TransitActiveTripScreen(
            tripId: extra['tripId'] as String? ?? '',
            stopName: extra['stopName'] as String? ?? '',
            transitType: extra['type'] as String? ?? 'bus',
            route: extra['route'] as String? ?? '',
            vehicleName: extra['vehicleName'] as String? ?? '',
            vehicleNumber: extra['vehicleNumber'] as String? ?? '',
            vehicleImageUrl: extra['vehicleImageUrl'] as String? ?? '',
            startTime: extra['startTime'] as String? ?? '',
          );
        },
      ),
    ],
  );
});
