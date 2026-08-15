import 'package:flutter/foundation.dart';

// ============================================================
//  MJOLLNIR — MODULAR API ENDPOINT REGISTRY
//  lib/core/network/api_endpoints.dart
//
//  Single source of truth for every API path in the app.
//  Inspired by Uber / Rapido scalable module patterns.
//
//  ┌─ HOW TO ADD A NEW FEATURE ─────────────────────────────┐
//  │  1. Create a new endpoint class  _<Feature>Endpoints   │
//  │  2. Add static const / static methods for each path    │
//  │  3. Expose it via ApiEndpoints.<featureName>           │
//  │  4. Import this file in the feature's _impl.dart       │
//  └────────────────────────────────────────────────────────┘
// ============================================================

// ── Environment / Base Config ────────────────────────────────────────────────

/// Switch environments by changing [ApiEnv.current].
enum ApiEnv { development, staging, production }

enum ApiContract { mjollnir, ev }

abstract final class ApiConfig {
  const ApiConfig._();

  /// Change this to switch environments app-wide.
  static const String _apiEnvName = String.fromEnvironment(
    'API_ENV',
    defaultValue: 'production',
  );

  static ApiEnv get current {
    switch (_apiEnvName) {
      case 'development':
        return ApiEnv.development;
      case 'staging':
        return ApiEnv.staging;
      default:
        return ApiEnv.production;
    }
  }

  static const ApiContract contract = ApiContract.ev;

  static const _baseUrls = {
    ApiEnv.development: 'http://localhost:8080/v1',
    ApiEnv.staging: 'https://staging-api.mjollnir.app/v1',
    ApiEnv.production: 'https://api.mjollnir.app/v1',
  };

  static const _evBaseUrls = {
    ApiEnv.development: 'http://localhost:4000/v1',
    ApiEnv.staging: 'https://ev.coffeecodes.in/v1',
    ApiEnv.production: 'https://ev-api.aks2.mellob.in/v1',
  };

  static String get _localEvBaseUrl {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:4000/v1';
    }
    return 'http://localhost:4000/v1';
  }

  static String get baseUrl => contract == ApiContract.ev
      ? (current == ApiEnv.development
            ? _localEvBaseUrl
            : _evBaseUrls[current]!)
      : _baseUrls[current]!;

  /// EV headers are injected when [contract] is [ApiContract.ev].
  /// Keep secrets out of source code by passing values through --dart-define.
  static const String evAppSecret = String.fromEnvironment(
    'EV_APP_SECRET',
    defaultValue: 'dafjcnalnsjn',
  );
  static const String evAdminSecret = String.fromEnvironment(
    'EV_ADMIN_SECRET',
    defaultValue: '',
  );

  /// Enable request mapping logs: original path -> mapped path.
  /// Run with: --dart-define=API_CONTRACT_TRACE=true
  static const bool enableContractTrace = bool.fromEnvironment(
    'API_CONTRACT_TRACE',
    defaultValue: false,
  );

  /// Global timeouts (seconds)
  static const int connectTimeoutSec = 30;
  static const int receiveTimeoutSec = 30;

  /// API version prefix already baked into baseUrl.
  /// Use this if you ever need to reference it separately.
  static const String apiVersion = 'v1';
}

// ── Root Registry ────────────────────────────────────────────────────────────

/// Top-level access point for all API paths.
///
/// Usage:
///   ApiEndpoints.auth.sendOtp
///   ApiEndpoints.ride.end('abc123')
///   ApiEndpoints.groups.detail('g1')
///
/// To add a new feature module, add a static const field here
/// and implement the corresponding class below.
abstract final class ApiEndpoints {
  const ApiEndpoints._();

  static const auth = _AuthEndpoints();
  static const profile = _ProfileEndpoints();
  static const ride = _RideEndpoints();
  static const trips = _TripsEndpoints();
  static const bikes = _BikesEndpoints();
  static const stations = _StationsEndpoints();
  static const wallet = _WalletEndpoints();
  static const social = _SocialEndpoints();
  static const groups = _GroupsEndpoints();
  static const community = _CommunityEndpoints();
  static const subscriptions = _SubscriptionsEndpoints();
  static const support = _SupportEndpoints();
  static const activity = _ActivityEndpoints();
  static const transit = _TransitEndpoints();
  static const config = _AppConfigEndpoints();

  // ─── REGISTER NEW FEATURE MODULES BELOW ──────────────────
  static const user = _UserEndpoints();
  // static const notifications = _NotificationsEndpoints();
  // static const tracking      = _TrackingEndpoints();
  // static const rewards       = _RewardsEndpoints();
  // static const vehicles      = _VehiclesEndpoints();
  // static const payments      = _PaymentsEndpoints();
  // ─────────────────────────────────────────────────────────
}

// ─────────────────────────────────────────────────────────────────────────────
//  FEATURE MODULES
//  Each class owns all paths for one feature.
//  Static const  → no dynamic segments   (/profile)
//  Static method → path has a variable   (/rides/:id/end)
// ─────────────────────────────────────────────────────────────────────────────

// ── App / Admin Config ───────────────────────────────────────────────────────
class _AppConfigEndpoints {
  const _AppConfigEndpoints();

  /// GET — Full app config: feature flags, transport config, and global settings.
  ///        Admin panel writes to the backend; app reads on launch + refresh.
  String get fetch => '/config';

  /// GET — Per-location transport configuration.
  ///   [locationId] — campus / zone identifier
  String locationConfig(String locationId) => '/config/locations/$locationId';
}

// ── Auth ─────────────────────────────────────────────────────────────────────
class _AuthEndpoints {
  const _AuthEndpoints();

  /// POST   — Send OTP to phone number
  String get sendOtp => '/auth/otp/send';

  /// POST   — Verify OTP and obtain tokens
  String get verifyOtp => '/auth/otp/verify';

  /// POST   — Register a new user
  String get register => '/auth/register';

  /// POST   — Refresh access token using refresh_token
  String get refresh => '/auth/refresh';

  /// DELETE — Permanently delete the authenticated account
  String get deleteAccount => '/auth/account';
}

// ── Profile ──────────────────────────────────────────────────────────────────
class _ProfileEndpoints {
  const _ProfileEndpoints();

  /// GET / PUT  — Fetch or fully update current user profile
  String get profile => '/user/me';

  /// POST       — Upload profile photo (multipart/form-data)
  String get uploadImage => '/profile/image';

  /// DELETE     — Remove profile photo
  String get deleteImage => '/profile/image';

  /// GET  — All achievement definitions + user progress.
  ///         Admin panel controls: title, description, category, icon, thresholds.
  String get achievements => '/profile/achievements';

  /// POST — Mark an achievement as seen / acknowledged by the user.
  ///   [achievementId] — server-assigned achievement identifier
  String acknowledgeAchievement(String achievementId) =>
      '/profile/achievements/$achievementId/acknowledge';
}

// ── Ride ─────────────────────────────────────────────────────────────────────
class _RideEndpoints {
  const _RideEndpoints();

  /// POST — Start a ride session (trips/start)
  String get start => '/trips/start';

  /// POST — End a ride session (trips/end/{tripId})
  ///   [rideId] — active trip identifier
  String end(String rideId) => '/trips/end/$rideId';

  /// PUT — Stream live GPS while riding (trips/{tripId}/location)
  ///   [rideId] — active trip identifier
  String updateLocation(String rideId) => '/trips/$rideId/location';

  /// PUT — Batch update multiple GPS points at once (trips/{tripId}/locations/batch)
  ///   [rideId] — active trip identifier
  String batchUpdateLocations(String rideId) =>
      '/trips/$rideId/locations/batch';

  // ── Future ride endpoints ──────────────────────────────────
  // String pause(String rideId)   => '/trips/$rideId/pause';
  // String resume(String rideId)  => '/trips/$rideId/resume';
  // String report(String rideId)  => '/trips/$rideId/report';
}

// ── Trips (History) ──────────────────────────────────────────────────────────
class _TripsEndpoints {
  const _TripsEndpoints();

  /// GET — User's trip history: trips/my?limit=100&order=desc&sort_by=start_timestamp
  String get list => '/trips/my';

  /// GET — Full detail for a single past trip
  ///   [tripId] — trip identifier
  String detail(String tripId) => '/trips/$tripId';

  /// POST — Start a new trip
  String get start => '/trips/start';

  /// POST — End a trip with metrics
  ///   [tripId] — active trip identifier
  String end(String tripId) => '/trips/end/$tripId';

  /// GET — Currently active trip
  String get active => '/trips/active';

  /// PUT — Stream live GPS while riding
  ///   [tripId] — active trip identifier
  String updateLocation(String tripId) => '/trips/$tripId/location';

  /// GET — Get all location points for a trip
  String locations(String tripId) => '/trips/$tripId/locations';

  /// GET — Get road-snapped (OSRM-matched) route for a completed trip
  String snappedRoute(String tripId) => '/trips/$tripId/snapped-route';

  /// GET — Trip summary stats
  String get summary => '/trips/summary';

  // ── Future trip endpoints ──────────────────────────────────
  // String receipt(String tripId)  => '/trips/$tripId/receipt';
  // String rateTrip(String tripId) => '/trips/$tripId/rate';
}

// ── Stations / Home Map ──────────────────────────────────────────────────────
class _StationsEndpoints {
  const _StationsEndpoints();

  /// GET — All stations
  String get list => '/stations';

  /// GET — Stations near a lat/lng coordinate
  ///        ?latitude=...&longitude=...
  String get nearby => '/stations/get_nearby';

  // ── Future station endpoints ───────────────────────────────
  // String detail(String stationId) => '/stations/$stationId';
  // String get search               => '/stations/search';
  // String bikes(String stationId)  => '/stations/$stationId/bikes';
}

// ── Bikes ────────────────────────────────────────────────────────────────────
class _BikesEndpoints {
  const _BikesEndpoints();

  /// GET — Bike details by ID.
  String detail(String bikeId) => '/bikes/$bikeId';
}

// ── Wallet ───────────────────────────────────────────────────────────────────
class _WalletEndpoints {
  const _WalletEndpoints();

  /// GET  — Current wallet balance (wallet/my → {balance, currency})
  String get balance => '/wallet/my';

  /// POST — Add money (top-up)
  String get topup => '/wallet/topup';

  /// POST — Withdraw funds
  String get withdraw => '/wallet/withdraw';

  /// GET  — Paginated transaction history
  String get transactions => '/transactions';

  /// POST — Apply a promotional coupon code
  String get applyCoupon => '/wallet/coupon';

  /// POST — Create a Dodo payment → {payment_id, checkout_url, amount}
  String get createDodoPayment => '/dodo/create-payment';

  /// GET  — Check Dodo payment status
  String dodoStatus(String paymentId) => '/dodo/status/$paymentId';

  /// GET  — Aggregated coin balances from active subscriptions
  String get coins => '/me/coins';

  // ── Future wallet endpoints ────────────────────────────────
  // String get paymentMethods     => '/wallet/payment-methods';
  // String get linkedAccounts     => '/wallet/linked-accounts';
  // String get upiPay             => '/wallet/upi/pay';
}

// ── Social ───────────────────────────────────────────────────────────────────
class _SocialEndpoints {
  const _SocialEndpoints();

  /// GET  — Users you may know / follow suggestions
  String get suggested => '/social/suggested';

  /// GET  — Users who follow the current user
  String get followers => '/user/followers';

  /// GET  — Users the current user follows
  String get following => '/user/following';

  /// POST — Follow a user
  ///   [userId] — target user identifier
  String follow(String userId) => '/user/follow/$userId';

  /// POST — Unfollow a user
  ///   [userId] — target user identifier
  String unfollow(String userId) => '/user/unfollow/$userId';

  /// GET  — Individual rider leaderboard (all users)
  String get leaderboardRiders => '/user/getAll';

  /// GET  — Group leaderboard
  String get leaderboardGroups => '/social/leaderboard/groups';

  // ── Future social endpoints ────────────────────────────────
  // String get feed               => '/social/feed';
  // String get stories            => '/social/stories';
  // String searchUsers(String q)  => '/social/search?q=$q';
}

// ── Groups ───────────────────────────────────────────────────────────────────
class _GroupsEndpoints {
  const _GroupsEndpoints();

  /// GET  — Groups base path (pass query params via queryParameters)
  String get list => '/groups/';

  /// POST — Create a new group
  String get create => '/groups';

  /// GET  — Full detail of a group
  String detail(String groupId) => '/groups/$groupId';

  /// DELETE — Delete a group (creator only)
  String delete(String groupId) => '/groups/$groupId';

  /// GET — Join a group
  String join(String groupId) => '/groups/$groupId/join';

  /// GET — Leave a group
  String leave(String groupId) => '/groups/$groupId/leave';

  /// GET — Group members with stats
  String membersData(String groupId) => '/groups/$groupId/members/data';

  /// GET — Group aggregate data
  String aggregate(String groupId) => '/groups/$groupId/aggregate';
}

// ── Community ─────────────────────────────────────────────────────────────────
class _CommunityEndpoints {
  const _CommunityEndpoints();

  /// GET  — Community posts (optional ?group_id=&limit=)
  String get posts => '/community/posts';

  /// DELETE — Remove a community post
  String deletePost(String postId) => '/community/posts/$postId';
}

// ── Subscriptions ────────────────────────────────────────────────────────────
class _SubscriptionsEndpoints {
  const _SubscriptionsEndpoints();

  /// GET  — All available subscription plans (with filters: ?location=&user_type=&organization_id=)
  String get plans => '/subscriptions';

  /// GET  — Single subscription plan detail (with pricing rules)
  ///   [planId] — subscription plan identifier
  String detail(String planId) => '/subscriptions/$planId';

  /// POST — Activate a subscription plan for the current user
  ///   [planId] — subscription plan identifier
  String activate(String planId) => '/subscriptions/$planId/activate';

  /// GET  — User's active subscriptions with plan details
  String get active => '/me/subscription';

  /// GET  — Available topup packs (optional: ?subscription_id=)
  String get topups => '/topups';

  /// POST — Purchase a topup pack
  ///   [topupId] — topup pack identifier
  String purchaseTopup(String topupId) => '/topups/$topupId/purchase';

  /// DELETE — Cancel an active subscription
  ///   [subscriptionId] — subscription identifier
  String cancel(String subscriptionId) => '/subscriptions/$subscriptionId';

  /// POST — Verify an institution ID and auto-allocate the org-paid subscription.
  String get verifyId => '/subscriptions/verify-id';

  // Legacy endpoints kept for backward compat
  /// POST — Purchase / activate a plan (legacy via user_subscription/)
  String get subscribe => '/user_subscription';
}

// ── Support ──────────────────────────────────────────────────────────────────
class _SupportEndpoints {
  const _SupportEndpoints();

  /// POST — Open a new support ticket
  String get createTicket => '/support/tickets';

  /// GET  — All tickets raised by the current user
  String get myTickets => '/support/tickets';

  /// POST — Send a message to the in-app AI / human chat agent
  String get chat => '/support/chat';

  // ── Future support endpoints ───────────────────────────────
  // String ticketDetail(String id) => '/support/tickets/$id';
  // String closeTicket(String id)  => '/support/tickets/$id/close';
  // String get faq                 => '/support/faq';
}

// ── Activity / Analytics ─────────────────────────────────────────────────────
class _ActivityEndpoints {
  const _ActivityEndpoints();

  /// GET — Riding summary stats (?period=day|week|month|year)
  String get summary => '/activity/summary';

  /// GET — Paginated activity feed / event log
  String get feed => '/activity/feed';

  /// GET — Distance travelled graph data
  String distanceTravelled(String startDate, String endDate) =>
      '/user/distance_travelled/$startDate/$endDate';

  /// GET — Calories burned graph data
  String caloriesBurned(String startDate, String endDate) =>
      '/user/calories_burned/$startDate/$endDate';

  /// GET — Time travelled graph data
  String timeTravelled(String startDate, String endDate) =>
      '/user/time_travelled/$startDate/$endDate';

  // ── Future activity endpoints ──────────────────────────────
  // String get streaks      => '/activity/streaks';
  // String get achievements => '/activity/achievements';
  // String get co2Saved     => '/activity/co2';
}

// ─────────────────────────────────────────────────────────────────────────────
//  Transit (Bus & Buggy)
// ─────────────────────────────────────────────────────────────────────────────
class _TransitEndpoints {
  const _TransitEndpoints();

  /// GET  — Stops near the user, filtered by ?type=bus|buggy and optional ?search=
  String get stops => '/transit/stops';

  /// POST — QR-board a vehicle; creates an active trip and returns its ID
  String get board => '/transit/trips/board';

  /// GET  — Currently active transit trip for the authenticated user
  String get activeTrip => '/transit/trips/active';

  /// POST — End an active transit trip and receive the summary
  ///   [tripId] — active trip identifier
  String endTrip(String tripId) => '/transit/trips/$tripId/end';

  // ── Future transit endpoints ───────────────────────────────
  // String get history            => '/transit/trips';
  // String detail(String id)      => '/transit/trips/$id';
  // String get vehicles           => '/transit/vehicles';
  // String stopDetail(String id)  => '/transit/stops/$id';
}

// ── User ──────────────────────────────────────────────────────────────────────
class _UserEndpoints {
  const _UserEndpoints();

  /// GET — Current user details
  String get me => '/user/me';

  /// POST — Update current user profile
  String get update => '/user/update';

  /// POST — Delete current user and associated records.
  String get delete => '/user/delete';

  /// GET — Get all users (for leaderboard)
  String get getAll => '/user/getAll';

  /// GET — User profile overview for another user
  String profile(String userId) => '/user/profile/$userId';

  /// GET — Check if following a user
  String isFollowing(String userId) => '/user/is_following/$userId';

  /// POST — Follow a user
  String follow(String userId) => '/user/follow/$userId';

  /// POST — Unfollow a user
  String unfollow(String userId) => '/user/unfollow/$userId';

  /// GET — User's followers
  String get followers => '/user/followers';

  /// GET — User's following
  String get following => '/user/following';

  /// GET — Invite/referral code
  String get inviteCode => '/user/invite_code';
}
