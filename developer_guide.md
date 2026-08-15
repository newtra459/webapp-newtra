# Mjollnir App — Developer Guide

> For new engineers joining the project.  
> Covers project setup, architecture, all conventions, and how to add a new feature end-to-end.

---

## Table of Contents

1. [Prerequisites & Setup](#1-prerequisites--setup)
2. [Project Structure](#2-project-structure)
3. [Architecture Overview](#3-architecture-overview)
4. [State Management (Riverpod)](#4-state-management-riverpod)
5. [Dependency Injection](#5-dependency-injection)
6. [Network Layer](#6-network-layer)
7. [Error Handling](#7-error-handling)
8. [Storage](#8-storage)
9. [Navigation (GoRouter)](#9-navigation-gorouter)
10. [Theming & Design System](#10-theming--design-system)
11. [Responsive Layout](#11-responsive-layout)
12. [Remote Config & Feature Flags](#12-remote-config--feature-flags)
13. [Adding a New Feature — Step-by-Step](#13-adding-a-new-feature--step-by-step)
14. [Testing](#14-testing)
15. [Running the App](#15-running-the-app)
16. [Key Dependencies](#16-key-dependencies)

---

## 1. Prerequisites & Setup

### Required tools

| Tool | Min version | Install |
|------|-------------|---------|
| Flutter SDK | `3.x` (Dart `^3.11.1`) | [flutter.dev/docs/get-started](https://flutter.dev/docs/get-started) |
| Xcode | 15+ | Mac App Store |
| CocoaPods | latest | `sudo gem install cocoapods` |
| Android Studio | latest | For Android emulator (optional) |

### First-time setup

```bash
# 1. Clone the repo and enter the directory
cd "Mjollnir App"

# 2. Fetch Dart/Flutter dependencies
flutter pub get

# 3. Install iOS CocoaPods (macOS only)
cd ios && pod install && cd ..

# 4. Run on a simulator/device
flutter run
```

### Environment switching

The API base URL is controlled by a single constant in [lib/core/network/api_endpoints.dart](../lib/core/network/api_endpoints.dart):

```dart
abstract final class ApiConfig {
  static const ApiEnv current = ApiEnv.production; // ← change this
}
```

| Enum value | URL |
|------------|-----|
| `ApiEnv.development` | `http://localhost:8080/v1` |
| `ApiEnv.staging` | `https://staging-api.mjollnir.app/v1` |
| `ApiEnv.production` | `https://api.mjollnir.app/v1` |

---

## 2. Project Structure

```
lib/
├── main.dart                  ← App entry point
├── core/                      ← Shared infrastructure (no feature logic)
│   ├── config/                ← Remote app config + feature flags
│   ├── constants/             ← AppColors, AppSizes, AppAssets, AppStrings
│   ├── errors/                ← AppError sealed class hierarchy
│   ├── network/               ← ApiClient (Dio), ApiEndpoints, providers.dart
│   ├── router/                ← GoRouter setup (app_router.dart)
│   ├── storage/               ← LocalStorage (SharedPrefs + SecureStorage)
│   ├── theme/                 ← AppTheme, ThemeNotifier
│   ├── utils/                 ← Result<T>, helpers
│   └── widgets/               ← shared UI: MjButton, NavigationShell, …
│
└── features/                  ← One folder per product feature
    ├── activity/
    ├── auth/
    ├── groups/
    ├── home/
    ├── profile/
    ├── ride/
    ├── social/
    ├── subscription/
    ├── support/
    ├── transit/
    ├── trips/
    └── wallet/

test/
├── core/                      ← Unit tests for core utilities
└── features/                  ← Unit tests per feature (provider tests)
```

Every feature follows an identical internal structure:

```
features/<feature>/
├── data/
│   ├── models/                ← JSON-serialisable data models
│   └── repositories/          ← Abstract interface + concrete implementation
└── presentation/
    ├── providers/             ← Riverpod StateNotifier + Provider definitions
    ├── screens/               ← Route-level widgets
    └── widgets/               ← Feature-specific reusable widgets
```

---

## 3. Architecture Overview

The app uses **Feature-First Layered Architecture** — a Clean Architecture variant with two layers per feature: `data` and `presentation`. There is no explicit domain/use-case layer; business logic lives in `StateNotifier` classes.

```
UI (screens/widgets)
        ↓ reads/watches
StateNotifier (provider)
        ↓ calls
RepositoryImpl (data layer)
        ↓ calls
ApiClient (core/network)
        ↓ HTTP
Backend API
```

**Key principle:** `core/` has zero imports from `features/`. Features may import from `core/`, never from other features.

---

## 4. State Management (Riverpod)

The app uses **Riverpod 2** (`flutter_riverpod ^2.6.1`).

### Provider types in use

| Provider | Used for |
|----------|---------|
| `Provider<T>` | Singletons: repositories, `ApiClient` |
| `StateNotifierProvider<N, S>` | Feature state with async operations |
| `FutureProvider<T>` | One-shot async reads (e.g. achievements list) |
| `StateNotifierProvider<ThemeNotifier, ThemeMode>` | Theme persistence |

### Pattern — StateNotifier

Every feature notifier follows this shape:

```dart
// 1. State class (plain Dart, immutable-ish via copyWith)
class RideState {
  final RideStatus status;
  final RideModel? ride;
  final String? error;

  const RideState({ this.status = RideStatus.idle, this.ride, this.error });

  RideState copyWith({ RideStatus? status, RideModel? ride, String? error }) =>
      RideState(
        status: status ?? this.status,
        ride:   ride   ?? this.ride,
        error:  error,           // null clears the error
      );
}

// 2. Notifier — wraps async calls, always uses copyWith
class RideNotifier extends StateNotifier<RideState> {
  final RideRepository _repository;

  RideNotifier(this._repository) : super(const RideState());

  Future<bool> startRide({required String bikeId, required int rideMode}) async {
    state = state.copyWith(status: RideStatus.starting);
    try {
      final ride = await _repository.startRide(bikeId: bikeId, rideMode: rideMode);
      state = state.copyWith(status: RideStatus.active, ride: ride);
      return true;
    } catch (e) {
      state = state.copyWith(status: RideStatus.error, error: e.toString());
      return false;
    }
  }
}

// 3. Provider declaration (always at the bottom of the provider file)
final rideProvider = StateNotifierProvider<RideNotifier, RideState>((ref) {
  return RideNotifier(ref.watch(rideRepositoryProvider));
});
```

### Reading providers in widgets

```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(rideProvider);            // reactive
    final notifier = ref.read(rideProvider.notifier); // for event callbacks only

    if (state.status == RideStatus.starting) {
      return const CircularProgressIndicator();
    }
    return ElevatedButton(
      onPressed: () => notifier.startRide(bikeId: 'MJ-001', rideMode: 0),
      child: const Text('Start Ride'),
    );
  }
}
```

**Rule:** Use `ref.watch` for reactive data in `build()`. Use `ref.read` only inside callbacks/event handlers to avoid rebuilds.

---

## 5. Dependency Injection

DI is done entirely through Riverpod providers — no `get_it` or `injectable`.

### The dependency chain

```
apiClientProvider          (core/network/providers.dart)
       ↓
*RepositoryProvider         (features/<x>/presentation/providers/<x>_provider.dart)
       ↓
*Notifier / FutureProvider  (same file)
```

### `apiClientProvider`

The global `ApiClient` singleton lives in **`lib/core/network/providers.dart`**:

```dart
// core/network/providers.dart
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
```

Every feature repository provider imports from this file:

```dart
// features/ride/presentation/providers/ride_provider.dart
import '../../../../core/network/providers.dart'; // ← correct

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepositoryImpl(ref.watch(apiClientProvider));
});
```

> ⚠️ **Do not** import `apiClientProvider` from any feature file. Always import from `core/network/providers.dart`.

---

## 6. Network Layer

### `ApiClient` — `lib/core/network/api_client.dart`

A thin Dio wrapper. All HTTP methods convert `DioException` to `NetworkError` automatically — repositories never need to catch `DioException`.

```dart
// ✅ Correct — repositories just call and let NetworkError propagate
Future<ProfileModel> getProfile() async {
  final response = await _apiClient.get(ApiEndpoints.profile.profile);
  return ProfileModel.fromJson(response.data['data']);
}

// ❌ Wrong — DioException will never reach here; ApiClient already converts it
} on DioException catch (e) {
  throw NetworkError.fromDioException(e); // unnecessary
}
```

#### Built-in Dio interceptor behaviour

| Event | Action |
|-------|--------|
| Every request | Reads `LocalStorage.getToken()` (sync, from memory cache), attaches `Authorization: Bearer` |
| `401` response | Calls `POST /auth/refresh` once, retries original request with new token |
| Refresh fails | Calls `LocalStorage.clearAuth()`, forwards `NetworkError(code: "401")` |

### `ApiEndpoints` — `lib/core/network/api_endpoints.dart`

Single source of truth for every API path.

```dart
// Reading an endpoint
ApiEndpoints.auth.sendOtp          // → '/auth/otp/send'
ApiEndpoints.ride.end('ride-123')  // → '/rides/ride-123/end'
ApiEndpoints.trips.detail(id)      // → '/trips/<id>'
```

#### Adding a new API module

```dart
// 1. Add a new endpoint class at the bottom of api_endpoints.dart
class _NotificationsEndpoints {
  const _NotificationsEndpoints();
  String get list  => '/notifications';
  String read(String id) => '/notifications/$id/read';
}

// 2. Register it in ApiEndpoints
abstract final class ApiEndpoints {
  // ... existing ...
  static const notifications = _NotificationsEndpoints(); // ← add here
}
```

### `ApiConfig` — environments

```dart
ApiConfig.current = ApiEnv.staging; // switch environment here
```

---

## 7. Error Handling

All errors in the application extend `AppError` (a sealed class). The full hierarchy:

```
AppError (sealed)
├── NetworkError       — HTTP / connection failures
├── ValidationError    — field-level form/API validation errors
├── AuthenticationError
├── AuthorizationError
├── CacheError
├── FileError          — multipart upload failures
├── ParseError         — JSON decode failures
└── GenericError       — catch-all
```

### In repositories

Repositories catch non-`AppError` exceptions and wrap them:

```dart
Future<ProfileModel> getProfile() async {
  try {
    final response = await _apiClient.get(ApiEndpoints.profile.profile);
    return ProfileModel.fromJson(response.data['data']);
  } on AppError {
    rethrow; // already typed, pass through
  } catch (e) {
    throw GenericError('Failed to load profile: $e', originalError: e);
  }
}
```

### In notifiers

```dart
} catch (e) {
  state = state.copyWith(
    isLoading: false,
    error: e.toString(), // AppError.toString() is always user-readable
  );
}
```

### Pattern matching on error type

```dart
try {
  await _repository.sendOtp(phone);
} catch (e) {
  final message = switch (e) {
    NetworkError()       => 'No internet connection.',
    ValidationError()    => (e as ValidationError).getFieldError('phone') ?? e.message,
    AuthenticationError()=> 'Invalid credentials.',
    AppError()           => e.message,
    _                    => 'Unexpected error.',
  };
}
```

### `Result<T>` — `lib/core/utils/result.dart`

Use `Result<T>` for operations where both success and failure are expected return values (not exceptions):

```dart
final result = Result<String>.success('hello');
final value = result.when(
  success: (data) => data,
  failure: (error) => 'default',
);
```

---

## 8. Storage

### `LocalStorage` — `lib/core/storage/local_storage.dart`

A static utility class. Call `await LocalStorage.init()` once in `main()` before any reads.

| Method | Backend | Notes |
|--------|---------|-------|
| `saveToken(t)` / `getToken()` | FlutterSecureStorage | Keychain (iOS) / Keystore (Android) |
| `saveRefreshToken(t)` / `getRefreshToken()` | FlutterSecureStorage | |
| `clearAuth()` | FlutterSecureStorage | Wipes both tokens |
| `setString/getString(key, value)` | SharedPreferences | Everything else |
| `setBool/getBool`, `setInt/getInt`, `setDouble/getDouble` | SharedPreferences | |

> **Security rule:** Auth tokens are stored in `FlutterSecureStorage` and cached in memory after `init()`. The Dio interceptor reads `getToken()` **synchronously** — this is only safe because the memory cache is pre-loaded during init.

#### Common Storage Keys

| Key | Type | Purpose |
|-----|------|---------|
| `auth_token` | secure | JWT access token |
| `refresh_token` | secure | Refresh token |
| `app_user_id` | prefs | `MJL-XXXXXXXX` app user number |
| `registration_complete` | prefs | Whether user has registered |
| `theme_mode` | prefs | `"dark"` \| `"light"` \| `"system"` |
| `cached_profile` | prefs | Pipe-delimited profile cache |
| `wallet_balance` | prefs | Last known wallet balance |
| `app_config_cache` | prefs | Serialised `AppConfigModel` JSON |

---

## 9. Navigation (GoRouter)

Router is in **`lib/core/router/app_router.dart`**, exposed as `routerProvider`.

### Route table

| Path | Screen | Auth required |
|------|--------|---------------|
| `/splash` | `SplashScreen` | No |
| `/auth/login` | `LoginScreen` | No |
| `/auth/otp` | `OtpScreen` | No |
| `/auth/register` | `RegistrationScreen` | No |
| `/home` | `HomeScreen` (shell) | ✓ |
| `/bikes` | `QrScannerScreen` (shell) | ✓ |
| `/community` | `FriendsScreen` (shell) | ✓ |
| `/profile` | `ProfileScreen` (shell) | ✓ |
| `/ride` | `RideScreen` | ✓ |
| `/ride/summary` | `RideSummaryScreen` | ✓ |
| `/trips` | `TripsScreen` | ✓ |
| `/trips/detail` | `TripDetailScreen` | ✓ |
| `/wallet` | `WalletScreen` | ✓ |
| `/subscriptions` | `SubscriptionScreen` | ✓ |
| `/profile/edit` | `EditProfileScreen` | ✓ |
| `/achievements` | `AchievementsScreen` | ✓ |
| `/leaderboard` | `LeaderboardScreen` | ✓ |
| `/user-profile` | `UserProfileScreen` | ✓ |
| `/groups` | `GroupsScreen` | ✓ |
| `/groups/detail` | `GroupDetailScreen` | ✓ |
| `/groups/create` | `CreateGroupScreen` | ✓ |
| `/activity` | `ActivityScreen` | ✓ |
| `/support` | `SupportScreen` | ✓ |
| `/support/report` | `ReportIssueScreen` | ✓ |
| `/support/chat` | `AiChatScreen` | ✓ |
| `/support/email` | `EmailUsScreen` | ✓ |
| `/transit` | `TransitScreen` | ✓ |
| `/transit/board` | `TransitBoardScreen` | ✓ |
| `/transit/active` | `TransitActiveTripScreen` | ✓ |

### Auth guard

GoRouter automatically redirects based on `AuthStatus`:

```
unauthenticated + any protected route → /auth/login
authenticated   + /auth/** route      → /home
```

The guard is wired through `AuthChangeNotifier`, a `ChangeNotifier` that listens to `authStateProvider` and calls `notifyListeners()` on status changes — GoRouter re-evaluates the redirect on each notification.

### Navigating

```dart
// Simple navigation
context.go('/trips');
context.push('/wallet');

// Navigation with parameters (currently via state.extra)
context.push('/ride', extra: {
  'rideMode': 0,
  'isEBike': true,
  'paidWithCoin': false,
});

// In the receiving screen's builder:
final extra = state.extra as Map<String, dynamic>? ?? {};
final rideMode = extra['rideMode'] as int? ?? 0;
```

> **Note:** Route parameters use `state.extra` (untyped `Map`). Always provide a safe default when casting: `extra['key'] as Type? ?? defaultValue`.

### Adding a new route

```dart
// 1. Import the screen at the top of app_router.dart
import '../../features/notifications/presentation/screens/notifications_screen.dart';

// 2. Add the GoRoute inside the routes: [ ] list
GoRoute(
  path: '/notifications',
  builder: (context, state) => const NotificationsScreen(),
),
```

---

## 10. Theming & Design System

### Colours — `lib/core/constants/app_colors.dart`

| Token | Value | Use |
|-------|-------|-----|
| `AppColors.primary` | `#00A877` | Brand green, CTAs |
| `AppColors.primaryLight` | `#33BF95` | Hover/secondary |
| `AppColors.primaryDark` | `#008A62` | Pressed state |
| `AppColors.darkSurface` | `#121212` | Dark mode scaffold |
| `AppColors.darkCard` | `#1E1E1E` | Dark mode cards |
| `AppColors.darkElevated` | `#2C2C2C` | Elevated dark surfaces |
| `AppColors.error` | `#E53935` | Error states |
| `AppColors.success` | `#4CAF50` | Success states |
| `AppColors.warning` | `#FF9800` | Warning states |
| `AppColors.speed` | `#00BCD4` | Ride speed metric |
| `AppColors.distance` | `#8BC34A` | Ride distance metric |
| `AppColors.calories` | `#FF7043` | Ride calories metric |

### Typography

Font: **Poppins** (via `google_fonts`). Access via `Theme.of(context).textTheme` — do not create custom `TextStyle` instances inline.

```dart
// ✅ Correct
Text('Hello', style: Theme.of(context).textTheme.titleMedium)

// ✅ Also correct — for specific sizes with ScreenUtil
Text('Hello', style: GoogleFonts.poppins(fontSize: 16.sp, fontWeight: FontWeight.w600))

// ❌ Avoid — hardcoded pixel sizes
Text('Hello', style: TextStyle(fontSize: 16))
```

### Sizes — `lib/core/constants/app_sizes.dart`

Always use `flutter_screenutil` suffixes for all dimensions:

| Suffix | Meaning |
|--------|---------|
| `.sp` | Scaled font size |
| `.w` | Scaled width (based on design width 375 px) |
| `.h` | Scaled height (based on design height 812 px) |
| `.r` | Scaled border radius |

**Design reference:** iPhone 14 — 375 × 812 logical pixels.

```dart
// ✅ Correct — scales across devices
SizedBox(height: 16.h, width: 16.w)
BorderRadius.circular(12.r)
Text('Hi', style: TextStyle(fontSize: 14.sp))

// ❌ Wrong — fixed pixels
SizedBox(height: 16, width: 16)
```

### Assets — `lib/core/constants/app_assets.dart`

```dart
// Logo variants
AppAssets.fullLogoDark    // SVG wordmark — white text, green bolt (for dark backgrounds)
AppAssets.fullLogoLight   // SVG wordmark — black text, green bolt (for light backgrounds)
AppAssets.iconLogoDark    // SVG icon mark — dark variant
AppAssets.iconLogoLight   // SVG icon mark — light variant
```

Always pick the variant matching the current brightness:

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
SvgPicture.asset(isDark ? AppAssets.fullLogoDark : AppAssets.fullLogoLight)
```

### Theme switching

```dart
ref.read(themeProvider.notifier).toggleTheme();
// or
ref.read(themeProvider.notifier).setTheme(ThemeMode.light);
```

Default theme is **dark**. Preference is persisted in `LocalStorage`.

### Shared widget — `MjButton`

```dart
MjButton(
  text: 'Start Ride',
  onPressed: () { ... },
  isLoading: state.isLoading, // shows spinner, disables tap
  isOutlined: false,          // true for secondary buttons
  icon: Icons.pedal_bike,     // optional leading icon
)
```

---

## 11. Responsive Layout

The app supports phones, tablets, and Samsung foldables using `AppBreakpoints` (`lib/core/constants/app_sizes.dart`).

| Device | Navigation | Check |
|--------|-----------|-------|
| Phone (`shortestSide < 600`) | Bottom navigation bar | `!AppBreakpoints.useRailNav(context)` |
| Tablet / unfolded foldable (`≥ 600`) | Left navigation rail (compact) | `AppBreakpoints.useRailNav(context)` |
| Wide tablet / landscape foldable (`≥ 840`) | Left navigation rail (extended + labels) | `AppBreakpoints.useWideRailNav(context)` |
| Foldable in half-open posture | Bottom navigation bar (single panel only) | `AppBreakpoints.isFoldHalfOpen(context)` |

```dart
// Check in widgets when you need layout-specific code
if (AppBreakpoints.useRailNav(context)) {
  // tablet layout
} else {
  // phone layout
}
```

`NavigationShell` in `core/widgets/navigation_shell.dart` handles the switch automatically — screens do not need to implement this themselves.

---

## 12. Remote Config & Feature Flags

App configuration is fetched from `GET /config` on every launch and cached in `SharedPreferences`.

### Reading a feature flag

```dart
final config = AppConfigRepositoryImpl.cachedOrDefaults(); // synchronous

if (config.features.wallet) {
  // show wallet tab
}
```

### Feature flags

| Flag | Controls |
|------|---------|
| `features.ride` | Bike ride tab |
| `features.transit` | Bus/buggy transit tab |
| `features.wallet` | Wallet screen |
| `features.social` | Friends/leaderboard |
| `features.groups` | Groups screen |
| `features.subscriptions` | Subscription plans |
| `features.support` | Support & AI chat |
| `features.activity` | Activity stats |
| `features.trips` | Trip history |
| `features.profile` | Profile screen |

When a flag is `false`, the admin can hide an entire feature without pushing a new app version.

### Fallback chain

```
GET /config (live)
      ↓ on failure
SharedPreferences cache
      ↓ on cache miss
AppConfigModel.defaults (compile-time, all flags = true)
```

---

## 13. Adding a New Feature — Step-by-Step

Example: adding a **Notifications** feature.

### Step 1 — Add API endpoints

In `lib/core/network/api_endpoints.dart`:

```dart
// At the bottom of the file, add the endpoint class
class _NotificationsEndpoints {
  const _NotificationsEndpoints();
  String get list => '/notifications';
  String read(String id) => '/notifications/$id/read';
}

// Register in the registry
abstract final class ApiEndpoints {
  // ... existing ...
  static const notifications = _NotificationsEndpoints(); // ← add
}
```

### Step 2 — Create the model

`lib/features/notifications/data/models/notification_model.dart`:

```dart
class NotificationModel {
  final String id;
  final String title;
  final String body;
  final bool read;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    this.read = false,
    required this.createdAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id:        json['id']         as String? ?? '',
      title:     json['title']      as String? ?? '',
      body:      json['body']       as String? ?? '',
      read:      json['read']       as bool?   ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
```

### Step 3 — Create the repository interface

`lib/features/notifications/data/repositories/notifications_repository.dart`:

```dart
import '../models/notification_model.dart';

abstract interface class NotificationsRepository {
  Future<List<NotificationModel>> getNotifications();
  Future<void> markRead(String notificationId);
}
```

### Step 4 — Create the repository implementation

`lib/features/notifications/data/repositories/notifications_repository_impl.dart`:

```dart
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_endpoints.dart';
import '../../../../core/errors/app_error.dart';
import '../models/notification_model.dart';
import 'notifications_repository.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final ApiClient _api;
  NotificationsRepositoryImpl(this._api);

  @override
  Future<List<NotificationModel>> getNotifications() async {
    final res = await _api.get(ApiEndpoints.notifications.list);
    final list = res.data['data'] as List? ?? [];
    return list
        .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> markRead(String id) async {
    await _api.post(ApiEndpoints.notifications.read(id));
  }
}
```

> Note: No `try/catch` for `DioException` needed — `ApiClient` handles that.

### Step 5 — Create the state and provider

`lib/features/notifications/presentation/providers/notifications_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/notification_model.dart';
import '../../data/repositories/notifications_repository.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../../../../core/network/providers.dart'; // ← always from core

// Repository provider
final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepositoryImpl(ref.watch(apiClientProvider));
});

// State
class NotificationsState {
  final List<NotificationModel> items;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.items = const [],
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<NotificationModel>? items,
    bool? isLoading,
    String? error,
  }) => NotificationsState(
    items:     items     ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    error:     error,
  );
}

// Notifier
class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final NotificationsRepository _repository;
  NotificationsNotifier(this._repository) : super(const NotificationsState());

  Future<void> load() async {
    state = state.copyWith(isLoading: true);
    try {
      final items = await _repository.getNotifications();
      state = state.copyWith(isLoading: false, items: items);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> markRead(String id) async {
    try {
      await _repository.markRead(id);
      final updated = state.items.map((n) =>
        n.id == id ? NotificationModel(id: n.id, title: n.title, body: n.body, read: true, createdAt: n.createdAt) : n
      ).toList();
      state = state.copyWith(items: updated);
    } catch (_) { /* non-critical */ }
  }
}

// Provider
final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.watch(notificationsRepositoryProvider));
});
```

### Step 6 — Create the screen

`lib/features/notifications/presentation/screens/notifications_screen.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(notificationsProvider);

    if (state.isLoading) return const Center(child: CircularProgressIndicator());
    if (state.error != null) return Center(child: Text(state.error!));

    return ListView.builder(
      itemCount: state.items.length,
      itemBuilder: (_, i) => ListTile(
        title: Text(state.items[i].title),
        subtitle: Text(state.items[i].body),
      ),
    );
  }
}
```

### Step 7 — Register the route

In `lib/core/router/app_router.dart`:

```dart
// Add import at the top
import '../../features/notifications/presentation/screens/notifications_screen.dart';

// Add route in the routes list
GoRoute(
  path: '/notifications',
  builder: (context, state) => const NotificationsScreen(),
),
```

### Step 8 — (Optional) Guard with a feature flag

In `api_endpoints.dart`, add a flag to `FeatureFlags` if the feature needs server-side toggling. Then check it before rendering the entry point:

```dart
final config = AppConfigRepositoryImpl.cachedOrDefaults();
if (config.features.notifications) {
  // show notifications icon in app bar
}
```

### Step 9 — Write tests

`test/features/notifications/notifications_provider_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mjollnir_app/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:mjollnir_app/features/notifications/data/repositories/notifications_repository.dart';
import 'package:mjollnir_app/features/notifications/data/models/notification_model.dart';

class MockNotificationsRepository implements NotificationsRepository {
  @override
  Future<List<NotificationModel>> getNotifications() async => [
    NotificationModel(id: '1', title: 'Test', body: 'Body', createdAt: DateTime.now()),
  ];

  @override
  Future<void> markRead(String id) async {}
}

void main() {
  test('loads notifications', () async {
    final notifier = NotificationsNotifier(MockNotificationsRepository());
    await notifier.load();

    expect(notifier.state.isLoading, isFalse);
    expect(notifier.state.items.length, 1);
    expect(notifier.state.items.first.title, 'Test');
  });
}
```

---

## 14. Testing

### Running tests

```bash
# All tests
flutter test

# Single file
flutter test test/features/ride/ride_provider_test.dart

# With coverage
flutter test --coverage
```

### Test structure

Tests mirror the `lib/` folder structure under `test/`. One test file per notifier/provider.

```
test/
├── core/
│   └── error_and_result_test.dart   ← AppError hierarchy + Result<T>
└── features/
    ├── groups/groups_provider_test.dart
    ├── profile/profile_provider_test.dart
    ├── ride/ride_provider_test.dart
    ├── trips/trips_provider_test.dart
    └── wallet/wallet_provider_test.dart
```

### Testing pattern — manual mock

The project uses manual mocks (not `mockito` code-gen), implementing the repository interface directly:

```dart
class MockRideRepository implements RideRepository {
  bool shouldThrow = false;

  @override
  Future<RideModel> startRide({required String bikeId, required int rideMode, bool isEBike = true}) async {
    if (shouldThrow) throw Exception('Start failed');
    return RideModel(id: 'ride-1', bikeId: bikeId);
  }

  @override
  Future<RideModel> endRide(String rideId) async => RideModel(id: rideId);

  @override
  Future<void> updateRideLocation(String rideId, double lat, double lng) async {}
}
```

Instantiate the notifier directly with the mock (no `ProviderScope` needed for unit tests):

```dart
setUp(() {
  mockRepo = MockRideRepository();
  notifier = RideNotifier(mockRepo);
});

test('transitions to error on failure', () async {
  mockRepo.shouldThrow = true;
  final success = await notifier.startRide(bikeId: 'MJ-001', rideMode: 0);
  expect(success, isFalse);
  expect(notifier.state.status, RideStatus.error);
});
```

---

## 15. Running the App

```bash
# List available devices
flutter devices

# Run on a specific simulator
flutter run -d <device-id>

# Run in release mode
flutter run --release

# Build iOS IPA
flutter build ipa

# Build Android APK
flutter build apk --release

# Analyze — must be clean before PR
flutter analyze

# Format code
dart format lib/ test/
```

### iOS pods refresh (after adding a new plugin)

```bash
cd ios && pod install && cd ..
flutter run
```

### Clean build

```bash
flutter clean && flutter pub get && flutter run
```

---

## 16. Key Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | `^2.6.1` | State management & DI |
| `go_router` | `^14.8.1` | Declarative navigation |
| `dio` | `^5.7.0` | HTTP client |
| `flutter_secure_storage` | `^9.2.4` | JWT token storage (Keychain/Keystore) |
| `shared_preferences` | `^2.3.4` | Non-sensitive local persistence |
| `flutter_screenutil` | `^5.9.3` | Responsive font/size scaling |
| `google_fonts` | `^6.2.1` | Poppins typeface |
| `google_maps_flutter` | `^2.10.0` | Station map |
| `mobile_scanner` | `^7.2.0` | QR code scanning |
| `geolocator` | `^13.0.2` | GPS location |
| `lottie` | `^3.1.3` | Lottie animations |
| `fl_chart` | `^0.69.2` | Activity charts |
| `flutter_svg` | `^2.0.10+1` | SVG logo/icon assets |
| `image_picker` | `^1.1.2` | Profile photo selection |
| `intl` | `^0.19.0` | Date formatting |
| `connectivity_plus` | `^6.0.5` | Network connectivity detection |
| `hive` + `hive_flutter` | `^2.2.3` | Offline caching (wired in future) |
| `build_runner` + `json_serializable` | dev | Code generation for models |
| `freezed` | dev | Immutable model generation (planned) |

---

## Quick Reference Cheat Sheet

```
New endpoint?       → api_endpoints.dart  (add class + register in ApiEndpoints)
New model?          → features/<x>/data/models/
New repository?     → features/<x>/data/repositories/  (interface + impl)
New state/provider? → features/<x>/presentation/providers/
New screen?         → features/<x>/presentation/screens/
New route?          → core/router/app_router.dart
New colour/size?    → core/constants/app_colors.dart or app_sizes.dart
New shared widget?  → core/widgets/
New storage key?    → core/storage/local_storage.dart
Need ApiClient?     → import 'core/network/providers.dart'  (never from a feature)
```
