# Mjollnir App — API Integration Architecture

**Document Version:** 1.0  
**Last Updated:** March 2026  
**Scope:** Complete API client setup, endpoint registry, repositories, and data models

---

## 1. Network & API Configuration

### Base Configuration (`lib/core/network/api_endpoints.dart`)

**Environment URLs:**
- **Development:** `http://localhost:8080/v1`
- **Staging:** `https://staging-api.mjollnir.app/v1`
- **Production:** `https://api.mjollnir.app/v1` (current)

**Global Timeouts:**
- Connection timeout: 30 seconds
- Receive timeout: 30 seconds

**API Version:** v1 (baked into base URL)

### API Client Setup (`lib/core/network/api_client.dart`)

**HTTP Client:** [Dio](https://pub.dev/packages/dio)

**Default Headers:**
```
Content-Type: application/json
Accept: application/json
```

**Authentication:**
- Bearer token automatically added to all requests via `Authorization` header
- Token sourced from local storage on each request

**Auto-Refresh Logic:**
- 401 Unauthorized responses trigger automatic token refresh
- Failed refresh logs user out and clears auth tokens
- Refresh endpoint: `POST /auth/refresh`

**Error Handling:**
- DioException converted to custom `NetworkError` with detailed messages
- Graceful fallback to cached data where available

### Providers (`lib/core/network/providers.dart`)

**Global API Client Singleton:**
```dart
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
```

---

## 2. HTTP Methods Available

The ApiClient supports the following HTTP methods:

| Method | Path | Data | Query Params |
|--------|------|------|--------------|
| **GET** | ✓ | ✗ | ✓ |
| **POST** | ✓ | ✓ | ✓ |
| **PUT** | ✓ | ✓ | ✗ |
| **PATCH** | ✓ | ✓ | ✗ |
| **DELETE** | ✓ | ✗ | ✗ |

All methods wrap DioException and throw `NetworkError` on network failures.

---

## 3. Complete Endpoint Registry

### 3.1 Authentication (`/auth`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Send OTP | `POST` | Send OTP to phone number | `/auth/otp/send` |
| Verify OTP | `POST` | Verify OTP and get tokens | `/auth/otp/verify` |
| Register | `POST` | Register new user | `/auth/register` |
| Refresh Token | `POST` | Refresh access token | `/auth/refresh` |
| Delete Account | `DELETE` | Permanently delete account | `/auth/account` |

**Request/Response Models:**
- Model: `AuthUserModel` (id, userNumber, phone, firstName, lastName, email, userType, organization)

---

### 3.2 Profile (`/profile`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Get/Update Profile | `GET, PUT` | Fetch or update profile | `/profile` |
| Upload Photo | `POST` | Upload profile image (multipart) | `/profile/image` |
| Delete Photo | `DELETE` | Remove profile photo | `/profile/image` |
| Get Achievements | `GET` | All achievements + user progress | `/profile/achievements` |
| Acknowledge Achievement | `POST` | Mark achievement as seen | `/profile/achievements/{achievementId}/acknowledge` |

**Request/Response Models:**
- Model: `ProfileModel` (id, firstName, lastName, email, phone, bio, dob, city, gender, height, weight, rating, totalRatings, punctualityRating, safetyRating, friendlinessRating, profileImageUrl)
- Model: `AchievementModel`

---

### 3.3 Ride Management (`/rides`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Start Ride | `POST` | Unlock bike and start session | `/rides/start` |
| End Ride | `POST` | End ride session | `/rides/{rideId}/end` |
| Update Location | `POST` | Stream live GPS coordinates | `/rides/{rideId}/location` |

**Request/Response Models:**
- Model: `RideModel` (id, rideMode, isEBike, seconds, distance, currentSpeed, maxSpeed, calories, elevation, lat, lng, routePoints, bikeId, batteryPct, paidWithCoin)

**Request Bodies:**
- Start Ride:
  ```json
  {
    "bike_id": "string",
    "ride_mode": 0|1,    // 0=shared, 1=own bike
    "is_ebike": boolean
  }
  ```
- Update Location:
  ```json
  {
    "lat": double,
    "lng": double
  }
  ```

---

### 3.4 Trip History (`/trips`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| List Trips | `GET` | Paginated trip history (optional type filter) | `/trips` |
| Get Trip Detail | `GET` | Full details for past trip | `/trips/{tripId}` |

**Query Parameters:**
- `type` (optional): Filter by trip type

**Request/Response Models:**
- Model: `TripModel`

---

### 3.5 Stations (Home Map) (`/stations`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Get Nearby Stations | `GET` | Stations near lat/lng coordinate | `/stations/nearby` |

**Query Parameters:**
- `lat` (required): Latitude
- `lng` (required): Longitude

**Request/Response Models:**
- Model: `StationModel`

---

### 3.6 Wallet (`/wallet`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Get Balance | `GET` | Current wallet balance | `/wallet/balance` |
| Top-up | `POST` | Add money to wallet | `/wallet/topup` |
| Withdraw | `POST` | Withdraw funds | `/wallet/withdraw` |
| Get Transactions | `GET` | Paginated transaction history | `/wallet/transactions` |
| Apply Coupon | `POST` | Apply promotional coupon code | `/wallet/coupon` |

**Request Bodies:**
- Top-up/Withdraw:
  ```json
  {
    "amount": double
  }
  ```
- Apply Coupon:
  ```json
  {
    "code": "string"
  }
  ```

**Request/Response Models:**
- Model: `TransactionModel`

---

### 3.7 Social (`/social`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Get Suggested Users | `GET` | Users you may know | `/social/suggested` |
| Get Followers | `GET` | Users following you | `/social/followers` |
| Get Following | `GET` | Users you follow | `/social/following` |
| Follow User | `POST` | Follow a user | `/social/follow/{userId}` |
| Unfollow User | `POST` | Unfollow a user | `/social/unfollow/{userId}` |
| Rider Leaderboard | `GET` | Individual rider rankings | `/social/leaderboard/riders` |
| Group Leaderboard | `GET` | Group rankings | `/social/leaderboard/groups` |

**Request/Response Models:**
- Model: `FriendModel`
- Model: `LeaderboardEntry`

---

### 3.8 Groups (`/groups`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Get My Groups | `GET` | Groups user belongs to | `/groups/mine` |
| Discover Groups | `GET` | Public groups to explore | `/groups/discover` |
| Create Group | `POST` | Create new group | `/groups` |
| Get Group Detail | `GET` | Full group details | `/groups/{groupId}` |
| Join Group | `POST` | Request to join group | `/groups/{groupId}/join` |
| Leave Group | `POST` | Leave a group | `/groups/{groupId}/leave` |

**Request Bodies:**
- Create Group:
  ```json
  {
    "name": "string",
    "description": "string",
    "category": "string"
  }
  ```

**Request/Response Models:**
- Model: `GroupModel`

---

### 3.9 Subscriptions (`/subscriptions`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Get Plans | `GET` | All subscription plans | `/subscriptions/plans` |
| Subscribe | `POST` | Purchase/activate plan | `/subscriptions` |
| Get Active Subscription | `GET` | Current active plan | `/subscriptions/active` |
| Cancel Subscription | `DELETE` | Cancel active subscription | `/subscriptions/{subscriptionId}` |
| Verify Institution ID | `POST` | Auto-allocate org-paid subscription | `/subscriptions/verify-id` |

**Query Parameters (Get Plans):**
- `location` (optional): Filter by location

**Request Bodies:**
- Subscribe:
  ```json
  {
    "plan_id": "string"
  }
  ```
- Verify Institution ID:
  ```json
  {
    "org": "string",
    "institution_id": "string"
  }
  ```

**Request/Response Models:**
- Model: `SubscriptionPlan`
- Model: `UserSubscription`

---

### 3.10 Support (`/support`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Create Ticket | `POST` | Open new support ticket | `/support/tickets` |
| Get My Tickets | `GET` | All tickets from user | `/support/tickets` |
| Send Chat Message | `POST` | Message AI/human agent | `/support/chat` |

**Request Bodies:**
- Create Ticket:
  ```json
  {
    "subject": "string",
    "description": "string",
    ...
  }
  ```
- Send Chat Message:
  ```json
  {
    "message": "string"
  }
  ```

**Request/Response Models:**
- Model: `SupportTicket`

---

### 3.11 Activity/Analytics (`/activity`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Get Summary | `GET` | Riding stats with time period | `/activity/summary` |
| Get Activity Feed | `GET` | Paginated activity event log | `/activity/feed` |

**Query Parameters:**
- Summary: `period` (day|week|month|year, default: week)
- Feed: `page` (pagination, default: 1)

**Request/Response Models:**
- Model: `ActivitySummary`
- Model: `ActivityFeedEvent`

---

### 3.12 Transit (Bus & Buggy) (`/transit`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Get Nearby Stops | `GET` | Transit stops near user | `/transit/stops` |
| Board Vehicle | `POST` | QR-board vehicle (start trip) | `/transit/trips/board` |
| Get Active Trip | `GET` | Currently active transit trip | `/transit/trips/active` |
| End Trip | `POST` | End active transit trip | `/transit/trips/{tripId}/end` |

**Query Parameters (Get Stops):**
- `type` (optional): Filter by bus|buggy
- `search` (optional): Search stops

**Request Bodies:**
- Board Vehicle:
  ```json
  {
    "vehicle_id": "string",
    "stop_id": "string"
  }
  ```

**Request/Response Models:**
- Model: `TransitStopModel`
- Model: `TransitTripModel`

---

### 3.13 Config/Admin (`/config`)

| Endpoint | Method | Purpose | Path |
|----------|--------|---------|------|
| Fetch App Config | `GET` | Feature flags, transport config, settings | `/config` |
| Location Config | `GET` | Per-location transport configuration | `/config/locations/{locationId}` |

---

## 4. Repository Pattern Architecture

### Design Pattern
Each feature module implements the **Repository Pattern**:

```
Feature (e.g., auth)
├── data/
│   ├── repositories/
│   │   ├── *_repository.dart          (Abstract interface)
│   │   ├── *_repository_impl.dart     (Dio-based implementation)
│   │   └── *_repository_mock.dart     (Mock for testing)
│   └── models/
│       └── *_model.dart               (JSON serializable data)
├── domain/
│   └── usecases/                      (Business logic)
└── presentation/
    ├── pages/
    └── providers/                     (Riverpod state management)
```

### Implementation Pattern

**Repository Interface Example:**
```dart
// auth_repository.dart
abstract class AuthRepository {
  Future<String> sendOtp(String phone);
  Future<({String token, String refreshToken, AuthUserModel user})> verifyOtp(
    String phone,
    String otp,
  );
  Future<AuthUserModel> register(AuthUserModel user);
  Future<String> refreshToken(String refreshToken);
  Future<void> deleteAccount();
}
```

**Repository Implementation Pattern:**
```dart
// auth_repository_impl.dart
class AuthRepositoryImpl implements AuthRepository {
  final ApiClient _api;
  
  AuthRepositoryImpl(this._api);
  
  @override
  Future<String> sendOtp(String phone) async {
    final res = await _api.post(
      ApiEndpoints.auth.sendOtp,
      data: {'phone': phone},
    );
    return res.data['data']?['request_id'] as String? ?? '';
  }
  // ... other methods
}
```

### All Implemented Repositories

| Module | Repository | File |
|--------|------------|------|
| Auth | `AuthRepository` | `lib/features/auth/data/repositories/` |
| Profile | `ProfileRepository` | `lib/features/profile/data/repositories/` |
| Profile | `AchievementsRepository` | `lib/features/profile/data/repositories/` |
| Ride | `RideRepository` | `lib/features/ride/data/repositories/` |
| Trips | `TripRepository` | `lib/features/trips/data/repositories/` |
| Home | `HomeRepository` | `lib/features/home/data/repositories/` |
| Wallet | `WalletRepository` | `lib/features/wallet/data/repositories/` |
| Social | `SocialRepository` | `lib/features/social/data/repositories/` |
| Groups | `GroupRepository` | `lib/features/groups/data/repositories/` |
| Subscriptions | `SubscriptionRepository` | `lib/features/subscription/data/repositories/` |
| Support | `SupportRepository` | `lib/features/support/data/repositories/` |
| Activity | `ActivityRepository` | `lib/features/activity/data/repositories/` |
| Transit | `TransitRepository` | `lib/features/transit/data/repositories/` |

---

## 5. Response Structure

**All API responses follow a standard envelope:**

```json
{
  "data": { ... },      // Actual response data
  "error": null,        // null if success, error object if failure
  "status": "success"   // or "error"
}
```

**Models extract data from `response.data['data']` or `response.data` directly.**

---

## 6. Examples of API Calls in Codebase

### Example 1: Authentication Flow

**Login with OTP (2-step process):**

```dart
// Step 1: Send OTP
final requestId = await authRepository.sendOtp('+919876543210');

// Step 2: Verify OTP
final (token, refreshToken, user) = await authRepository.verifyOtp(
  '+919876543210',
  '123456',
);

// Token automatically saved and used in all future requests
```

### Example 2: Starting a Ride

```dart
final ride = await rideRepository.startRide(
  bikeId: 'bike_123',
  rideMode: 0,  // 0=shared, 1=own bike
  isEBike: true,
);

// Update position every 5 seconds
await rideRepository.updateRideLocation(
  ride.id,
  currentLat,
  currentLng,
);
```

### Example 3: Profile Update with Image Upload

```dart
// Update profile fields
final updated = await profileRepository.updateProfile(
  profile.copyWith(
    firstName: 'John',
    lastName: 'Doe',
  ),
);

// Upload profile image (multipart/form-data)
final imageUrl = await profileRepository.uploadProfileImage(imageFile);

// Image URL automatically cached
```

### Example 4: Fetching User's Trip History

```dart
// Get all trips with optional type filter
final trips = await tripRepository.getTrips(filter: 'bike'); // or 'transit'

// Get detailed info for one trip
final details = await tripRepository.getTripDetail(trips.first.id);
```

### Example 5: Wallet and Coupon

```dart
// Check balance (with local cache fallback)
final balance = await walletRepository.getBalance();

// Top-up wallet
final newBalance = await walletRepository.addMoney(500.0);

// Apply promotional coupon
final message = await walletRepository.applyCoupon('SAVE50');
```

### Example 6: Social Features

```dart
// Get suggested users
final suggested = await socialRepository.getSuggested();

// Follow a user
await socialRepository.follow('user_456');

// Get leaderboards
final riderBoard = await socialRepository.getRiderLeaderboard();
final groupBoard = await socialRepository.getGroupLeaderboard();
```

### Example 7: Groups

```dart
// Discover public groups
final groups = await groupRepository.discoverGroups();

// Create new group
final newGroup = await groupRepository.createGroup(
  name: 'Morning Riders',
  description: 'Daily morning rides',
  category: 'recreational',
);

// Join group
await groupRepository.joinGroup(newGroup.id);
```

### Example 8: Transit (Bus/Buggy)

```dart
// Get nearby transit stops (filter by type: bus|buggy)
final stops = await transitRepository.getNearbyStops(type: 'bus');

// Board a vehicle (creates active trip)
final trip = await transitRepository.boardVehicle(
  vehicleId: 'bus_789',
  stopId: 'stop_123',
);

// Check active transit trip
final activeTrip = await transitRepository.getActiveTrip();

// End trip
final ended = await transitRepository.endTrip(trip.id);
```

---

## 7. Error Handling

**All API errors are wrapped in `AppError` subtypes:**

| Error Type | Cause | Handling |
|-----------|-------|----------|
| `NetworkError` | Network I/O failures | Fallback to cache or retry |
| `AuthError` | 401/403 auth failures | Token refresh or logout |
| `ValidationError` | 400 invalid data | Show user-friendly message |
| `NotFoundError` | 404 resource missing | Show "not found" UI |
| `ServerError` | 5xx server issues | Show error & offer retry |
| `GenericError` | Unknown error | Log and show generic message |

**Repository Pattern provides centralized error handling and cache fallbacks.**

---

## 8. Local Caching Strategy

Certain entities cache locally via `LocalStorage`:

| Entity | Purpose | Cache Key |
|--------|---------|-----------|
| Auth Tokens | Session persistence | `auth_token`, `refresh_token` |
| Profile | Offline access | `cached_profile` |
| Wallet Balance | Quick UI display | `wallet_balance` |

**Fallback on network errors ensures app remains functional.**

---

## 9. State Management Integration

All repositories are injected via **Riverpod providers**:

```dart
// In feature-specific _impl.dart files
final <featureName>RepositoryProvider = Provider(
  (ref) => <FeatureRepository>Impl(ref.watch(apiClientProvider)),
);
```

**Queries wrapped in `FutureProvider` or `StateNotifierProvider` for reactive UI updates.**

---

## 10. API Evolution Roadmap

### Future Endpoints (Commented Out)

The following endpoints are pre-designed but not yet implemented:

- **Ride:** `pause`, `resume`, `report`
- **Trips:** `receipt`, `rateTrip`
- **Stations:** `detail`, `search`, `bikes`
- **Wallet:** `paymentMethods`, `linkedAccounts`, `upiPay`
- **Social:** `feed`, `stories`, `searchUsers`
- **Groups:** `members`, `invite`, `rides`
- **Subscriptions:** `history`, `renew`
- **Support:** `ticketDetail`, `closeTicket`, `faq`
- **Activity:** `streaks`, `achievements`, `co2Saved`
- **Transit:** `history`, `detail`, `vehicles`, `stopDetail`

These are documented and ready to implement when backend support is added.

---

## 11. Key Design Principles

1. **Single Source of Truth:** `ApiEndpoints` centralizes all paths
2. **Bearer Token Auth:** Automatic injection and refresh
3. **Graceful Degradation:** Cache fallback on network failures
4. **Clean Architecture:** Repositories abstract API details
5. **Testability:** Mock repositories available for testing
6. **Environment Management:** Easy switching between dev/staging/prod
7. **Type Safety:** JSON models with proper serialization
8. **Global Error Handling:** Custom AppError hierarchy

---

## 12. Quick Reference: How to Add a New Endpoint

1. **Add endpoint path** in `lib/core/network/api_endpoints.dart`:
   ```dart
   class _NewFeatureEndpoints {
     String get newPath => '/new-feature/path';
   }
   static const newFeature = _NewFeatureEndpoints();
   ```

2. **Create data model** in `lib/features/newfeature/data/models/`:
   ```dart
   class NewModel {
     // ... fields and fromJson/toJson
   }
   ```

3. **Implement repository** in `lib/features/newfeature/data/repositories/`:
   ```dart
   class NewRepositoryImpl implements NewRepository {
     final ApiClient _api;
     Future<NewModel> fetch() async {
       final res = await _api.get(ApiEndpoints.newFeature.newPath);
       return NewModel.fromJson(res.data['data']);
     }
   }
   ```

4. **Expose via provider** in feature's `_impl.dart`

5. **Use in UI** via Riverpod state notifiers

---

**End of API Integration Architecture Document**
