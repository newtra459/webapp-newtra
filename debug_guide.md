# Mjollnir App — Debug Guide

> Symptoms → causes → fixes for the most common development and runtime issues.

---

## Table of Contents

1. [Debug Setup](#1-debug-setup)
2. [Error Hierarchy Quick Reference](#2-error-hierarchy-quick-reference)
3. [Auth & Token Issues](#3-auth--token-issues)
4. [Network & API Issues](#4-network--api-issues)
5. [State Management Issues](#5-state-management-issues)
6. [Navigation Issues](#6-navigation-issues)
7. [Ride Feature Issues](#7-ride-feature-issues)
8. [Storage Issues](#8-storage-issues)
9. [UI & Rendering Issues](#9-ui--rendering-issues)
10. [Build & Environment Issues](#10-build--environment-issues)
11. [Testing Issues](#11-testing-issues)
12. [Inspecting Live State](#12-inspecting-live-state)
13. [Useful Debug Snippets](#13-useful-debug-snippets)

---

## 1. Debug Setup

### Switch to development API

In `lib/core/network/api_endpoints.dart`, change the active environment:

```dart
abstract final class ApiConfig {
  static const ApiEnv current = ApiEnv.development; // ← change here
}
```

| Env | Base URL |
|---|---|
| `development` | `http://localhost:8080/v1` |
| `staging` | `https://staging-api.mjollnir.app/v1` |
| `production` | `https://api.mjollnir.app/v1` |

> **iOS Simulator note:** Use `http://127.0.0.1:8080` not `http://localhost:8080` — the simulator resolves localhost differently.

### Enable Dio request logging

Add a `LogInterceptor` to `ApiClient` temporarily:

```dart
// lib/core/network/api_client.dart — add inside the constructor, after the auth interceptor
_dio.interceptors.add(
  LogInterceptor(
    requestBody: true,
    responseBody: true,
    error: true,
    logPrint: (obj) => debugPrint('[DIO] $obj'),
  ),
);
```

> Remove before committing. Do not log in production — tokens appear in request headers.

### Flutter DevTools

```bash
# Run with DevTools Observatory link
flutter run --debug
# Open the printed URL in Chrome: http://127.0.0.1:<port>
```

Useful DevTools tabs:
- **Inspector** — widget tree, layout issues
- **Performance** — jank, rebuild counts
- **Memory** — heap size, leaks (streams not cancelled)
- **Network** — HTTP traffic (requires `dart:developer` binding)

---

## 2. Error Hierarchy Quick Reference

All app errors extend `AppError` (sealed class in `lib/core/errors/app_error.dart`):

```
AppError
├── NetworkError       — HTTP failures, timeouts, no internet
├── ValidationError    — 400/422 with field-level errors map
├── AuthenticationError — invalid credentials, session expired
├── AuthorizationError — 403 forbidden
├── CacheError         — SharedPrefs / SecureStorage read/write failure
├── FileError          — multipart upload failure
├── ParseError         — JSON decode failure
└── GenericError       — catch-all for unexpected exceptions
```

Every `AppError` exposes:

| Property | Type | Notes |
|---|---|---|
| `.message` | `String` | User-readable; safe to display |
| `.code` | `String?` | Machine code, e.g. `"401"`, `"404"` |
| `.originalError` | `dynamic` | Raw cause for logging; may be `DioException` |
| `.toString()` | `String` | Same as `.message` |

**Pattern-match to handle specific types:**

```dart
} catch (e) {
  final msg = switch (e) {
    NetworkError()        => 'Check your internet connection.',
    ValidationError()     => (e as ValidationError).getFieldError('phone') ?? e.message,
    AuthenticationError() => 'Please log in again.',
    AuthorizationError()  => 'You do not have permission.',
    AppError()            => e.message,            // any other AppError
    _                     => 'Unexpected error.',  // non-AppError
  };
}
```

---

## 3. Auth & Token Issues

### Symptom: Every request gets a 401, user is immediately logged out

**Cause:** JWT expired and the refresh token is also expired or missing.

**Fix:**
1. Check `LocalStorage.getToken()` and `LocalStorage.getRefreshToken()` are non-null.
2. Check the refresh token's expiry in [jwt.io](https://jwt.io) (decode the token).
3. Clear stored tokens and force re-login:

```dart
await LocalStorage.clearAuth();
// Then navigate to /auth/login
```

**In test:** Mock `AuthRepository.refreshToken` to throw `AuthenticationError` and verify the router redirects to `/auth/login`.

---

### Symptom: OTP "resend" succeeds but the new OTP also fails

**Cause:** Old `request_id` from the first send is still being passed to `verifyOtp`.

**Check:** `OtpScreen` should call `sendOtp()` again on resend and update the local `requestId`. Verify `AuthFormState.otpSent` is reset and the new `request_id` is stored.

---

### Symptom: After registration, app redirects back to `/auth/register` on next launch

**Cause:** `registration_complete` flag was not persisted.

**Fix:** Confirm the registration flow calls `LocalStorage.setBool('registration_complete', true)` (or equivalent) before navigating to `/home`. Check `AuthStateNotifier.setAuthenticated()` sets this flag.

**Verify in code:**
```dart
debugPrint('reg complete: ${LocalStorage.getBool('registration_complete')}');
```

---

### Symptom: Token refresh causes infinite retry loop

**Cause:** `_isRefreshing` is not being reset to `false` on refresh failure.

**Check `api_client.dart`:**
```dart
// _isRefreshing must be set false in the catch block of _tryRefreshToken()
_isRefreshing = false;  // ← ensure this executes on error paths
```

The current implementation does reset it in all paths — if you see the loop, the interceptor is being called re-entrantly (e.g. two simultaneous 401s). Set a breakpoint in `onError` to confirm.

---

### Symptom: `LocalStorage.getToken()` returns null synchronously even after login

**Cause:** `LocalStorage.init()` was not awaited before the Riverpod scope is built, or `saveToken()` was not awaited.

**Fix:** `main.dart` must await `LocalStorage.init()` before calling `runApp()`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LocalStorage.init();           // ← must be awaited
  await LocalStorage.ensureAppUserId();
  runApp(const ProviderScope(child: MjollnirApp()));
}
```

---

## 4. Network & API Issues

### Symptom: `NetworkError('No internet connection…')` on a working network

**Cause:** iOS simulator networking can drop on sleep/resume. Android Emulator may not route to `localhost`.

**Fix:**
- iOS Simulator: toggle Wi-Fi in System Preferences.
- Android Emulator: use `10.0.2.2` instead of `localhost` for the dev server.
- Real device on LAN: use the machine's local IP address (e.g. `192.168.1.x`).

---

### Symptom: `Connection timeout` on every request in staging/production

**Check in order:**
1. Correct `ApiEnv` selected — confirm `ApiConfig.current`.
2. VPN required? The staging server may be firewalled.
3. `ApiConfig.connectTimeoutSec = 30` — increase temporarily if the network is slow.

---

### Symptom: `GET /config` succeeds but feature flags remain false

**Cause:** Response JSON key casing mismatch during deserialization.

**Debug:**
```dart
// In AppConfigRepositoryImpl.fetchConfig(), print the raw response:
debugPrint('[CONFIG] raw: ${res.data}');
```

**Expected key names** (`lib/core/config/app_config_model.dart`):

```json
{
  "features": { "ride": true, "wallet": true, ... }
}
```

If the backend sends e.g. `"Ride"` (capitalised), `fromJson` will miss it — fix the model's `fromJson` or align the backend.

---

### Symptom: `ValidationError` thrown but `.getFieldError('phone')` returns null

**Cause:** The server returned the error under a different field key (e.g. `"phone_number"` vs `"phone"`).

**Fix:** Log `ValidationError.fieldErrors` to see the actual keys, then either fix the key in the switch or update `ValidationError.fromJson` to normalise field names.

```dart
} on ValidationError catch (e) {
  debugPrint('[VALIDATION] $e \n fields: ${e.fieldErrors}');
}
```

---

### Symptom: `Response type 'String' is not a subtype of 'Map<String, dynamic>'`

**Cause:** `ApiClient` received an HTML error page (often a 502/503 from a misconfigured proxy) rather than JSON.

**Fix:** Check the raw response body:
```dart
} on DioException catch (e) {
  debugPrint('[RAW RESPONSE] ${e.response?.data}');
}
```

If it's an HTML page, the issue is upstream (load balancer, nginx config). Not a Flutter bug.

---

## 5. State Management Issues

### Symptom: UI does not rebuild after state changes

**Cause A:** Using `ref.read()` in `build()` instead of `ref.watch()`.

```dart
// ❌ — no rebuild
final state = ref.read(homeProvider);

// ✅ — reactive
final state = ref.watch(homeProvider);
```

**Cause B:** `copyWith()` was called but the new object was never assigned to `state`.

```dart
// ❌ — does nothing
state.copyWith(isLoading: true);

// ✅
state = state.copyWith(isLoading: true);
```

---

### Symptom: Provider throws `ProviderException: X was already disposed`

**Cause:** A `StateNotifier` method was called after the widget it was attached to was disposed (common in async gaps after `await`).

**Fix:** Check `mounted` before updating state after any `await`:

```dart
Future<void> loadData() async {
  state = state.copyWith(isLoading: true);
  final result = await _repository.getData();
  if (!mounted) return; // ← guard
  state = state.copyWith(isLoading: false, data: result);
}
```

---

### Symptom: `ref.watch()` causes rebuild on every frame

**Cause:** A provider creates a new object on each access (e.g. an `AutoDisposeProvider` that runs an expensive computation).

**Debug with Riverpod Logger:**
```dart
// pubspec.yaml (dev only)
riverpod_lint: ^x.y.z
```

Or temporarily add:
```dart
ref.listenManual(someProvider, (prev, next) {
  debugPrint('[PROVIDER] prev: $prev\nnext: $next');
});
```

---

### Symptom: Optimistic update shows stale data after API failure

**Cause:** The notifier updates state immediately but fails to roll back on error.

**Pattern to follow** (Social / Groups optimistic updates):

```dart
Future<void> followUser(String userId) async {
  // 1. optimistic update
  state = state.copyWith(
    friends: state.friends.map((u) =>
      u.id == userId ? u.copyWith(isFollowing: true) : u).toList(),
  );
  try {
    await _repository.follow(userId);
  } catch (e) {
    // 2. rollback on failure
    state = state.copyWith(
      friends: state.friends.map((u) =>
        u.id == userId ? u.copyWith(isFollowing: false) : u).toList(),
      error: e.toString(),
    );
  }
}
```

---

## 6. Navigation Issues

### Symptom: App redirects to `/auth/login` on every launch despite valid session

**Cause:** `AuthStateNotifier` reads the token before `LocalStorage.init()` completes, sees `null`, and sets status to `unauthenticated`.

**Fix:** Ensure `LocalStorage.init()` is awaited in `main()` before `runApp()` (see [section 3](#3-auth--token-issues)).

---

### Symptom: Deep link to `/wallet` shows a blank screen

**Cause A:** Feature flag `wallet` is `false` in remote config — the route is blocked.

**Check:**
```dart
final config = ref.read(appConfigProvider);
debugPrint('[FLAGS] wallet: ${config.features.wallet}');
```

**Cause B:** `GoRouter` redirect is firing before the auth state is resolved.

**Check:** `AppRouter` has an `unknown` state guard — confirm `AuthStateNotifier.status` is never stuck in `AuthStatus.unknown`.

---

### Symptom: Pressing back from a detail screen goes to the wrong route

**Cause:** `GoRouter.pop()` pops to the previous entry in the history stack, which may not be what you expect if the user deep-linked in.

**Fix:** Use `context.go('/home')` for explicit navigation instead of `context.pop()` in screens that are also accessible via deep link.

---

### Symptom: Bottom nav bar still visible on a detail screen

**Cause:** The route was added inside the `ShellRoute` instead of as a top-level route.

**Fix:** Detail routes (`/ride`, `/wallet`, `/trips`, etc.) must be outside the `ShellRoute` in `app_router.dart`:

```dart
// ✅ Outside ShellRoute — no bottom bar
GoRoute(path: '/ride', builder: (ctx, state) => const RideScreen()),

// ❌ Inside ShellRoute — bottom bar will show
ShellRoute(
  builder: ...,
  routes: [
    GoRoute(path: '/ride', ...),  // wrong placement
  ],
)
```

---

## 7. Ride Feature Issues

### Symptom: Active ride is lost after app is force-killed

**Cause:** Ride state is persisted to `LocalStorage` by `RideNotifier`, but only at the point when `startRide()` succeeds. If the app is killed before the first write, there is nothing to restore.

**Debug:**
```dart
debugPrint('[RIDE PERSIST] rideId: ${LocalStorage.getString('active_ride_id')}');
```

**Fix:** Ensure `RideNotifier.startRide()` writes the ride ID to `LocalStorage` immediately after `PUT /rides/start` responds successfully — before any other state mutation.

---

### Symptom: Ride timer keeps running after `pauseRide()` is called

**Cause A:** UI is calling `ref.read(rideProvider.notifier).pauseRide()` but watching a different provider instance.

**Cause B:** `Timer` or `Stream` from `Geolocator` is not cancelled on pause.

**Debug:** Check that `RideStatus.paused` is the current status and that the timer's `isActive` flag is false after pause.

---

### Symptom: `POST /rides/start` is called twice (duplicate ride)

**Cause:** `QrScannerScreen` does not check for an existing active ride before routing to `/ride`.

**Fix:** Before starting a new ride, check:
```dart
if (LocalStorage.getString('active_ride_id') != null) {
  context.go('/ride'); // rejoin existing ride
  return;
}
```

The scanner already has this guard — if it regresses, verify the `detectActiveRide` check in `QrScannerScreen`.

---

### Symptom: Fare shows ₹0 for a shared-bike ride

**Cause A:** `rideMode` was incorrectly set to `1` (own-bike) when launching the shared ride.

**Cause B:** `RidePricing.calculate()` received `durationSeconds < 1`.

**Debug:**
```dart
final bill = RidePricing.calculate(ride.seconds);
debugPrint('[FARE] mode=${ride.rideMode} secs=${ride.seconds} total=${bill.total}');
```

---

### Symptom: GPS polyline jumps erratically on the ride map

**Cause:** `Geolocator` is returning cached locations with stale accuracy.

**Fix:** Increase the accuracy filter in the location stream:

```dart
Geolocator.getPositionStream(
  locationSettings: const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 5, // only emit if moved 5 m
  ),
)
```

---

## 8. Storage Issues

### Symptom: `LocalStorage._prefs` is null → NullPointerException

**Cause:** A method that reads `_prefs` was called before `LocalStorage.init()` completed.

**Rule:** `LocalStorage.init()` must complete before any other `LocalStorage` call. It is awaited in `main()` — never call storage helpers in static initializers or `const` constructors.

---

### Symptom: Loyalty coins show 0 even after rides

**Key names in SharedPreferences:**

| Key | Holds |
|---|---|
| `loyalty_coin_dates` | Comma-separated ISO dates, one per coin |
| `wallet_ride_count` | Running count of wallet-paid rides |
| `sub_coins_remaining` | Remaining subscription coin balance |
| `sub_last_redeem_date` | Date of last subscription coin redemption |

**Debug:**
```dart
debugPrint('[COINS] loyalty: ${LocalStorage.getCoinBalance()}');
debugPrint('[COINS] sub: ${LocalStorage.getSubCoinsRemaining()}');
debugPrint('[COINS] available today: ${LocalStorage.getAvailableSubCoinsToday()}');
debugPrint('[COINS] wallet rides: ${LocalStorage.getWalletRideCount()}');
```

**Loyalty coins** expire after 30 days; `getCoinBalance()` purges expired entries on every call — if all entries are older than 30 days, it returns 0 and removes them.

---

### Symptom: Config cache is stale after a backend change

**Cause:** `app_config_cache` in SharedPreferences is returned on network failure. If the server is reachable, `fetchConfig()` always fetches fresh data.

**Force clear:**
```dart
await LocalStorage.remove('app_config_cache');
// Then hot-restart to re-fetch
```

---

### Symptom: `FlutterSecureStorage` throws on Android emulator

**Cause:** The emulator has no keystore set up (common on fresh emulators).

**Fix:** Set a PIN on the emulator: Settings → Security → Screen Lock. `FlutterSecureStorage` with `encryptedSharedPreferences: true` requires the keystore to be initialised.

---

## 9. UI & Rendering Issues

### Symptom: Text overflows on tablets or large font-size devices

**Cause:** `ScreenUtil` scaling is not clamped.

**Fix:** Already clamped in `main.dart` — confirm this block exists:

```dart
ScreenUtilInit(
  designSize: const Size(375, 812),
  minTextAdapt: true,
  splitScreenMode: true,
  // ...
)
```

And in `MjollnirApp`:
```dart
builder: (context, child) {
  final mq = MediaQuery.of(context);
  return MediaQuery(
    data: mq.copyWith(
      textScaler: TextScaler.linear(
        mq.textScaleFactor.clamp(0.85, 1.25),
      ),
    ),
    child: child!,
  );
},
```

---

### Symptom: Logo shows black box in dark mode

**Cause:** A white-fill SVG/PNG logo is being used but dark theme needs the white version.

**Fix (from user preferences):** Always use the white logo asset in dark theme. Check the theme switch in the relevant screen:

```dart
final isDark = Theme.of(context).brightness == Brightness.dark;
Image.asset(isDark ? 'assets/images/logo/logo_white.png'
                   : 'assets/images/logo/logo_dark.png');
```

---

### Symptom: Map renders black on iOS

**Cause A:** `google_maps_flutter` requires a valid Google Maps API key in `ios/Runner/AppDelegate.swift`.

**Cause B:** The simulator may not support Metal rendering — use a physical device or change the renderer.

**Check `AppDelegate.swift`:**
```swift
GMSServices.provideAPIKey("YOUR_API_KEY")
```

---

### Symptom: Shimmer or Lottie animation not playing

**Cause:** Asset not listed in `pubspec.yaml` `flutter.assets`.

**Check `pubspec.yaml`:**
```yaml
flutter:
  assets:
    - assets/animations/   # ← animations must be listed
    - assets/images/
    - assets/icons/
```

Run `flutter pub get` after adding an asset.

---

## 10. Build & Environment Issues

### Symptom: `flutter run` fails with `CocoaPods` errors on iOS

```bash
cd ios && pod install && cd ..
flutter run -d <device-id>
```

If `pod install` hangs or fails:
```bash
cd ios
pod repo update
pod install --repo-update
```

---

### Symptom: `build_runner` generates wrong or stale files

```bash
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

If conflicts persist, manually delete `.g.dart` and `.freezed.dart` files then re-run.

---

### Symptom: `flutter clean` needed before every build

This is usually caused by `pubspec.yaml` changes (new packages) not being reflected in `pubspec.lock`. Always run:

```bash
flutter clean && flutter pub get
```

After:
- Adding or removing a dependency
- Changing package version constraints
- Pulling changes that modify `pubspec.yaml`

---

### Symptom: `Undefined symbol` linker error on iOS after adding a plugin

```bash
cd ios && pod deintegrate && pod install && cd ..
flutter run
```

If it persists, check that the plugin supports the iOS deployment target in `ios/Podfile`:
```ruby
platform :ios, '14.0'
```

---

### Symptom: Android build fails with `minSdkVersion` error

In `android/app/build.gradle.kts`, ensure:
```kotlin
defaultConfig {
  minSdk = 21   // flutter_secure_storage requires ≥21
}
```

---

## 11. Testing Issues

### Symptom: `AppError` pattern-match test fails with `switch` exhaustiveness error

`AppError` is a **sealed class** — all subclasses must be listed. If you add a new `AppError` subclass, update every `switch` statement in the app and in tests.

---

### Symptom: Mocked repository method is never called

**Cause:** Riverpod's `overrideWithValue` is not applied to the test's `ProviderScope`.

```dart
// ✅ Correct
await tester.pumpWidget(
  ProviderScope(
    overrides: [
      rideRepositoryProvider.overrideWithValue(MockRideRepository()),
    ],
    child: const MaterialApp(home: RideScreen()),
  ),
);
```

---

### Symptom: `LocalStorage` throws in unit tests

`LocalStorage` depends on `SharedPreferences` and `FlutterSecureStorage` — both require platform channels.

**Fix:** Mock them in tests:

```dart
setUpAll(() async {
  SharedPreferences.setMockInitialValues({});
  // FlutterSecureStorage has no built-in mock; inject a fake
});
```

Or extract the logic that needs testing into pure functions that don't touch `LocalStorage`.

---

## 12. Inspecting Live State

### Print all SharedPreferences keys

```dart
final prefs = await SharedPreferences.getInstance();
debugPrint('[PREFS] keys: ${prefs.getKeys()}');
for (final key in prefs.getKeys()) {
  debugPrint('  $key = ${prefs.get(key)}');
}
```

### Print auth state

```dart
debugPrint('[AUTH] token: ${LocalStorage.getToken()?.substring(0, 20)}...');
debugPrint('[AUTH] isLoggedIn: ${LocalStorage.isLoggedIn}');
debugPrint('[AUTH] userId: ${LocalStorage.getUserId()}');
```

### Print active ride state

```dart
debugPrint('[RIDE] id: ${LocalStorage.getString('active_ride_id')}');
debugPrint('[RIDE] mode: ${LocalStorage.getString('ride_mode')}');
debugPrint('[RIDE] paused: ${LocalStorage.getBool('ride_is_paused')}');
```

### Print remote config flags

```dart
// Inside any ConsumerWidget
final config = ref.read(appConfigProvider);
debugPrint('[CONFIG] flags: ${config.features}');
debugPrint('[CONFIG] settings: coinRate=${config.settings.coinConversionRate}');
```

### Watch a Riverpod provider from outside a widget

```dart
// In main() after ProviderScope, grab the container:
final container = ProviderContainer();
container.listen(rideProvider, (prev, next) {
  debugPrint('[RIDE STATE] $next');
});
```

---

## 13. Useful Debug Snippets

### Force logout and clear all local data

```dart
await LocalStorage.clearAuth();
await LocalStorage.clear(); // clears SharedPreferences
// Then restart the app
```

> **Warning:** This also clears active ride state, coin balances, and cached config.

### Simulate a 401 / token expiry

```dart
// Corrupt the token so the next request gets a 401
await LocalStorage.saveToken('invalid_token');
```

### Simulate offline mode

Wrap an API call in a try/catch and throw manually:

```dart
throw const NetworkError('No internet connection. Please check your network settings.');
```

Or use the iOS Simulator's Network Link Conditioner (Xcode → Open Developer Tool → More Developer Tools).

### Reset ride pricing to test edge cases

```dart
// Test the buffer zones directly:
debugPrint(RidePricing.calculate(60 * 60).toString());  // exactly 60 min
debugPrint(RidePricing.calculate(62 * 60).toString());  // in buffer (60–65)
debugPrint(RidePricing.calculate(70 * 60).toString());  // in tier 1 (65–90)
debugPrint(RidePricing.calculate(91 * 60).toString());  // in second buffer (90–95)
```

### Check coin expiry status

```dart
debugPrint('[COINS] expires in: ${LocalStorage.loyaltyCoinExpiryDays()} days');
debugPrint('[COINS] available today: ${LocalStorage.getAvailableSubCoinsToday()}');
```

---

*See also:*
- [developer_guide.md](developer_guide.md) — architecture conventions and error-handling patterns
- [api_contract.md](api_contract.md) — expected request/response shapes and HTTP status codes
- [features.md](features.md) — per-feature state, models, and API endpoints
