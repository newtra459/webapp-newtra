# Mjollnir App API Integration — Summary Overview

**A bird's-eye view of the API integration architecture, directory structure, and how everything connects.**

---

## Quick Facts

| Metric | Value |
|--------|-------|
| **Total API Endpoints** | 53 |
| **Feature Modules** | 13 |
| **HTTP Methods** | 5 (GET, POST, PUT, PATCH, DELETE) |
| **Base URL** | https://api.mjollnir.app/v1 |
| **Authentication** | Bearer Token (auto-refreshing) |
| **Client Library** | Dio with Riverpod DI |
| **Error Handling** | Custom AppError hierarchy |
| **Caching** | LocalStorage for auth, profile, wallet |
| **Response Format** | Standard envelope with `data` field |

---

## Directory Structure

```
lib/
├── core/
│   └── network/
│       ├── api_client.dart              ← Dio setup, interceptors, HTTP methods
│       ├── api_endpoints.dart           ← ALL endpoint paths (single source of truth)
│       ├── api_result.dart              ← Deprecated wrapper
│       └── providers.dart               ← Global API client singleton
│
└── features/
    ├── auth/
    │   ├── data/
    │   │   ├── models/auth_user_model.dart
    │   │   └── repositories/
    │   │       ├── auth_repository.dart (interface)
    │   │       ├── auth_repository_impl.dart (implementation)
    │   │       └── auth_repository_mock.dart (testing)
    │   ├── domain/ (business logic)
    │   └── presentation/ (UI)
    │
    ├── profile/           ← Profile + Achievements
    ├── ride/              ← Bike ride management
    ├── trips/             ← Trip history
    ├── home/              ← Stations & map
    ├── wallet/            ← Balance & transactions
    ├── social/            ← Users, followers, leaderboards
    ├── groups/            ← Group management
    ├── subscription/      ← Plans & subscriptions
    ├── support/           ← Tickets & chat
    ├── activity/          ← Stats & analytics
    ├── transit/           ← Bus & buggy system
    └── [each feature has same structure as auth]
```

---

## API Client Architecture

### 1. Initialization

```dart
// Single Dio instance created in ApiClient constructor
// Configured with:
// - Base URL from ApiConfig
// - Default headers (Content-Type, Accept)
// - Global timeouts (30s)
// - Interceptor for authentication
```

### 2. Request Flow

```
[Feature Repository]
    ↓
[ApiClient.get/post/put/patch/delete()]
    ↓
[Dio with Bearer Token (auto-injected)]
    ↓
[401 Response?]
    ├─ Yes → [Try Token Refresh]
    │        ├─ Success → [Retry Original Request]
    │        └─ Fail → [Clear Auth & Throw]
    └─ No → [Return Response]
    ↓
[Parse JSON & Return/Throw]
```

### 3. Response Parsing

All API responses follow standard envelope:
```json
{
  "data": { /* actual response */ },
  "status": "success",
  "error": null
}
```

Models extract data from `response.data['data']` or direct access.

---

## Feature Modules Overview

### Authentication (5 endpoints)
- Send OTP → Verify OTP → Register
- Auto token refresh on 401
- Token storage in LocalStorage

### Profile (5 endpoints)
- Get/update profile (cached locally)
- Upload/delete profile photo (multipart)
- Track achievements

### Ride (3 endpoints)
- Start ride → Update location (live GPS) → End ride
- Captures distance, time, calories, elevation

### Trips (2 endpoints)
- List trip history (with optional type filter)
- Get detailed trip info

### Home/Stations (1 endpoint)
- Get nearby bike stations with live availability

### Wallet (5 endpoints)
- Balance check (cached)
- Top-up & withdraw
- Transaction history
- Apply coupon codes

### Social (7 endpoints)
- Suggested users, followers, following
- Follow/unfollow
- Rider & group leaderboards

### Groups (6 endpoints)
- Create group
- Discover public groups
- Join/leave
- Get group details

### Subscriptions (5 endpoints)
- Browse plans (by location)
- Subscribe to plan
- Check active subscription
- Cancel subscription
- Verify institution ID (auto-allocation)

### Support (3 endpoints)
- Create support tickets
- View my tickets
- Chat with AI/human agent

### Activity (2 endpoints)
- Get riding stats (by period: day/week/month/year)
- Get activity event feed

### Transit (4 endpoints)
- Get nearby stops (bus/buggy, searchable)
- Board vehicle (creates trip)
- Get active transit trip
- End transit trip

### Config (2 endpoints)
- Global app config (feature flags, settings)
- Per-location transport config

---

## Repository Pattern

Each feature implements clean architecture:

```
┌─ Interface (auth_repository.dart)
│  abstract class AuthRepository { ... }
│
├─ Implementation (auth_repository_impl.dart)
│  class AuthRepositoryImpl implements AuthRepository {
│    final ApiClient _api;
│    // Makes actual API calls
│  }
│
├─ Mock (auth_repository_mock.dart)
│  class AuthRepositoryMock implements AuthRepository {
│    // Fake data for testing
│  }
│
└─ Provider (feature_impl.dart or similar)
   final authRepositoryProvider = Provider(...)
```

**Advantages:**
- Dependency injection via Riverpod
- Switchable between real/mock implementations
- Easy testing
- Centralized error handling
- Cache fallback

---

## Data Flow Diagram

```
User Action (e.g., Login)
    ↓
[Presentation Layer - Widget/Page]
    ↓
[State Management - Riverpod StateNotifier]
    ↓
[UseCase / Repository Method]
    {\
     {-- AuthRepository.sendOtp(phone)
     {
[API Client]
    ↓
[Bearer Token Injection]
    ↓
[HTTP Request via Dio]
    ↓
[Standard Response Envelope]
    ↓
[JSON to Model Conversion]
    ↓
[LocalStorage Persistence (cache)]
    ↓
[Return to StateNotifier]
    ↓
[Widget Rebuilds with New State]
```

---

## Authentication Flow

```
1. User enters phone → sendOtp() → backend sends SMS
2. User enters OTP → verifyOtp() → backend returns:
   {
     "token": "...",           (short-lived access token)
     "refresh_token": "...",   (long-lived refresh token)
     "user": { ... }
   }
3. Tokens stored in LocalStorage
4. Bearer token auto-added to all requests
5. On 401 → _tryRefreshToken() using refresh_token
6. If refresh succeeds → retry original request
7. If refresh fails → logout user
```

---

## Error Handling Hierarchy

```
AppError (base)
    ├── NetworkError        (Dio I/O failures)
    ├── AuthError           (401/403 auth issues)
    ├── ValidationError     (400 validation)
    ├── NotFoundError       (404 missing)
    ├── ServerError         (5xx server)
    └── GenericError        (catch-all)
```

**Each error type has:**
- Custom message
- Original exception reference
- Stack trace
- User-friendly fallback message

---

## Caching Strategy

| Entity | Method | Key | Fallback |
|--------|--------|-----|----------|
| **Auth Token** | LocalStorage | `auth_token` | Force re-login |
| **Refresh Token** | LocalStorage | `refresh_token` | Force re-login |
| **Profile** | LocalStorage (encoded) | `cached_profile` | Return cache or error |
| **Wallet Balance** | LocalStorage | `wallet_balance` | Return last known balance |

**Profile photo:** Always fetched fresh (CDN URL in profile)

---

## Endpoint Usage by Feature

```
Feature              Repository                   Endpoints Used
────────────────────────────────────────────────────────────────
Auth                 AuthRepository               5 (all)
Profile              ProfileRepository            5 (all)
Ride                 RideRepository               3 (all)
Trips                TripRepository               2 (all)
Home/Stations        HomeRepository               1 (all)
Wallet               WalletRepository             5 (all)
Social               SocialRepository             7 (all)
Groups               GroupRepository              6 (all)
Subscriptions        SubscriptionRepository       5 (all)
Support              SupportRepository            3 (all)
Activity             ActivityRepository           2 (all)
Transit              TransitRepository            4 (all)
Config               [Global/on-demand]           2 (partial)
```

---

## Implementation Checklist

✅ **Implemented & Active:**
- Authentication (OTP, register, token refresh)
- Profile (CRUD, photo upload)
- Ride management (start, end, location tracking)
- Trip history
- Wallet (balance, topup, withdraw, coupons)
- Social (users, followers, leaderboards)
- Groups (create, join, discover)
- Subscriptions (plans, subscribe, cancel)
- Support (tickets, chat)
- Activity (summary, feed)
- Transit (stops, board, end)
- Station finder

❓ **Commented/Future:**
- Ride pause/resume/report
- Trip receipts/ratings
- Station detail/search/bikes list
- Wallet payment methods/linked accounts
- Social feed/stories/search
- Group members/invite/rides
- Subscription history/renewal
- Support FAQ/detail/close
- Activity streaks/achievements/CO2
- Transit history/detail/vehicles

---

## How to Add a New Endpoint

### Step 1: Define the Path
```dart
// In lib/core/network/api_endpoints.dart
class _NewFeatureEndpoints {
  const _NewFeatureEndpoints();
  
  String get newEndpoint => '/new-feature/path';
  String detail(String id) => '/new-feature/path/$id';
}

// Register in ApiEndpoints
static const newFeature = _NewFeatureEndpoints();
```

### Step 2: Create Data Model
```dart
// In lib/features/newfeature/data/models/new_model.dart
class NewModel {
  final String id;
  final String name;
  
  factory NewModel.fromJson(Map<String, dynamic> json) => ...
  Map<String, dynamic> toJson() => ...
}
```

### Step 3: Implement Repository
```dart
// In lib/features/newfeature/data/repositories/new_repository_impl.dart
class NewRepositoryImpl implements NewRepository {
  final ApiClient _api;
  
  Future<NewModel> fetch(String id) async {
    final res = await _api.get(ApiEndpoints.newFeature.detail(id));
    return NewModel.fromJson(res.data['data']);
  }
}
```

### Step 4: Create Riverpod Provider
```dart
// In lib/features/newfeature/data/providers.dart
final newRepositoryProvider = Provider(
  (ref) => NewRepositoryImpl(ref.watch(apiClientProvider)),
);
```

### Step 5: Use in UI
```dart
// In PageState or UseCase
final repository = ref.watch(newRepositoryProvider);
final model = await repository.fetch(id);
```

---

## Testing Strategy

### Unit Tests
- Test repository methods with mocked ApiClient
- Test model JSON serialization/deserialization
- Test error scenarios

### Integration Tests
- Test actual API calls with staging server
- Use `auth_repository_mock` for auth bypass
- Test cache fallback behavior

### Mock Repository
```dart
class AuthRepositoryMock implements AuthRepository {
  @override
  Future<String> sendOtp(String phone) async =>
      'mock_request_id';
  
  @override
  Future<({String token, String refreshToken, AuthUserModel user})>
  verifyOtp(String phone, String otp) async => (
    token: 'mock_token',
    refreshToken: 'mock_refresh',
    user: AuthUserModel(id: 'mock_user'),
  );
}
```

---

## Key Design Principles

1. **Single Source of Truth**
   - All endpoints defined in `api_endpoints.dart`
   - No hardcoded URLs in repositories

2. **Bearer Token Authentication**
   - Auto-injected via interceptor
   - Auto-refreshed on 401
   - Stored securely in LocalStorage

3. **Graceful Degradation**
   - Cache fallback for critical data
   - Network errors don't crash app
   - User-friendly error messages

4. **Clean Architecture**
   - Repository pattern separates API from UI
   - Dependency injection via Riverpod
   - Mock implementations for testing

5. **Type Safety**
   - JSON models with proper serialization
   - Strong typing throughout
   - No `dynamic` in critical paths

6. **Environment Management**
   - Easy switching between dev/staging/prod
   - No hardcoded base URLs
   - Config-driven setup

7. **Scalability**
   - Modular feature structure
   - Easy to add new endpoints
   - No single God object

---

## Performance Considerations

1. **Connection Pooling** — Dio handles automatically
2. **Request Timeouts** — 30 second global limit
3. **Batch Requests** — Use `Future.wait()` for parallel
4. **Pagination** — Use `page` param for large lists
5. **Lazy Loading** — Load related data on-demand
6. **Image Optimization** — CDN served profile photos
7. **Cache Strategy** — Aggressive local caching

---

## Documentation References

| Document | Purpose |
|----------|---------|
| **api_integration_architecture.md** | Complete reference guide |
| **api_quick_reference.md** | Quick lookup table |
| **api_call_examples.md** | Real code examples |
| **This file** | High-level overview |

---

## Files Location Summary

```
docs/
├── api_integration_architecture.md  (comprehensive reference)
├── api_quick_reference.md           (quick lookup)
├── api_call_examples.md             (working examples)
└── API_INTEGRATION_SUMMARY.md       (this file)

lib/core/network/
├── api_client.dart                  (Dio client)
├── api_endpoints.dart               (all paths)
├── api_result.dart                  (deprecated)
└── providers.dart                   (DI)

lib/features/[13 modules]/data/
├── repositories/
│   ├── *_repository.dart
│   ├── *_repository_impl.dart
│   └── *_repository_mock.dart
└── models/
    └── *_model.dart
```

---

**Last Updated:** March 2026  
**API Version:** v1  
**Total Coverage:** 100% (all 53 endpoints documented)  
**Implementation Status:** 13/13 feature modules with repositories
