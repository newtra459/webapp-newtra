# Mjollnir App — API Quick Reference

**Quick lookup for all endpoints, request/response structures, and common API calls.**

---

## API Endpoints Quick Summary

### Base URL: `https://api.mjollnir.app/v1`
### Auth: Bearer token (auto-injected)
### Global Timeouts: 30s

---

## All Endpoints by Module (53 Total)

```
Authentication (5)
├── POST   /auth/otp/send                        → request_id
├── POST   /auth/otp/verify                      → {token, refresh_token, user}
├── POST   /auth/register                        → user
├── POST   /auth/refresh                         → {token}
└── DELETE /auth/account                         → void

Profile (5)
├── GET    /profile                              → profile
├── PUT    /profile                              → profile
├── POST   /profile/image                        → {url}
├── DELETE /profile/image                        → void
├── GET    /profile/achievements                 → [achievements]
└── POST   /profile/achievements/{id}/acknowledge → void

Ride (3)
├── POST   /rides/start                          → ride
├── POST   /rides/{id}/end                       → ride
└── POST   /rides/{id}/location                  → void

Trips (2)
├── GET    /trips                                → [trips]
└── GET    /trips/{id}                           → trip

Stations (1)
└── GET    /stations/nearby                      → [stations]

Wallet (5)
├── GET    /wallet/balance                       → {balance}
├── POST   /wallet/topup                         → {balance}
├── POST   /wallet/withdraw                      → {balance}
├── GET    /wallet/transactions                  → [transactions]
└── POST   /wallet/coupon                        → {message}

Social (7)
├── GET    /social/suggested                     → [users]
├── GET    /social/followers                     → [users]
├── GET    /social/following                     → [users]
├── POST   /social/follow/{userId}               → void
├── POST   /social/unfollow/{userId}             → void
├── GET    /social/leaderboard/riders            → [entries]
└── GET    /social/leaderboard/groups            → [entries]

Groups (6)
├── GET    /groups/mine                          → [groups]
├── GET    /groups/discover                      → [groups]
├── POST   /groups                               → group
├── GET    /groups/{id}                          → group
├── POST   /groups/{id}/join                     → void
└── POST   /groups/{id}/leave                    → void

Subscriptions (5)
├── GET    /subscriptions/plans                  → [plans]
├── POST   /subscriptions                        → subscription
├── GET    /subscriptions/active                 → subscription | null
├── DELETE /subscriptions/{id}                   → void
└── POST   /subscriptions/verify-id              → {verified, subscription?}

Support (3)
├── POST   /support/tickets                      → ticket
├── GET    /support/tickets                      → [tickets]
└── POST   /support/chat                         → {reply}

Activity (2)
├── GET    /activity/summary                     → summary
└── GET    /activity/feed                        → [events]

Transit (4)
├── GET    /transit/stops                        → [stops]
├── POST   /transit/trips/board                  → trip
├── GET    /transit/trips/active                 → trip | null
└── POST   /transit/trips/{id}/end               → trip

Config (2)
├── GET    /config                               → config
└── GET    /config/locations/{id}                → config
```

---

## Common API Patterns

### Pattern 1: GET List with Optional Filters
```dart
// Example: Get trips with optional type filter
await _api.get(
  ApiEndpoints.trips.list,
  queryParameters: {'type': 'bike'}, // optional
);
```

### Pattern 2: POST with JSON Body
```dart
// Example: Send OTP
await _api.post(
  ApiEndpoints.auth.sendOtp,
  data: {'phone': '+919876543210'},
);
```

### Pattern 3: POST with File Upload (Multipart)
```dart
// Example: Upload profile image
final formData = FormData.fromMap({
  'image': await MultipartFile.fromFile(imageFile.path),
});
await _api.post(ApiEndpoints.profile.uploadImage, data: formData);
```

### Pattern 4: Dynamic Path Parameters
```dart
// Example: End a ride
ApiEndpoints.ride.end(rideId)        // → /rides/{rideId}/end
ApiEndpoints.groups.join(groupId)   // → /groups/{groupId}/join
```

### Pattern 5: Error Handling with Cache Fallback
```dart
try {
  return await _api.get(ApiEndpoints.wallet.balance);
} catch (_) {
  // Fallback to cached value
  return LocalStorage.getWalletBalance();
}
```

---

## Data Models Structure

### Authentication
```dart
AuthUserModel {
  id: String
  userNumber: String        // e.g., "MJL-A1B2C3D4"
  phone: String
  firstName: String
  lastName: String
  email: String
  userType: String          // e.g., "General User"
  organization: String?
}
```

### Profile
```dart
ProfileModel {
  id: String?
  firstName: String
  lastName: String
  email: String
  phone: String
  bio: String
  dob: String
  city: String
  gender: String
  height: String
  weight: String
  rating: double
  totalRatings: int
  punctualityRating: double
  safetyRating: double
  friendlinessRating: double
  profileImageUrl: String?
}
```

### Ride
```dart
RideModel {
  id: String
  rideMode: int             // 0=shared, 1=own bike
  isEBike: bool
  seconds: int
  distance: double
  currentSpeed: double
  maxSpeed: double
  calories: double
  elevation: double
  lat: double
  lng: double
  routePoints: List<List<double>>
  bikeId: String
  batteryPct: int
  paidWithCoin: bool
}
```

### Trip
```dart
TripModel {
  id: String
  // ... (duration, distance, etc.)
}
```

### Station
```dart
StationModel {
  // ... (location, available bikes, etc.)
}
```

### Wallet
```dart
TransactionModel {
  // ... (amount, date, type, etc.)
}
```

### Social
```dart
FriendModel {
  id: String
  // ... (name, avatar, follow status, etc.)
}

LeaderboardEntry {
  rank: int
  userId: String
  // ... (score, distance, etc.)
}
```

### Group
```dart
GroupModel {
  id: String
  name: String
  description: String
  category: String
  // ... (member count, created date, etc.)
}
```

### Subscription
```dart
SubscriptionPlan {
  id: String
  name: String
  price: double
  duration: String
  // ... (features, etc.)
}

UserSubscription {
  id: String
  planId: String
  startDate: String
  endDate: String
  active: bool
  // ... (renewal info, etc.)
}
```

### Support
```dart
SupportTicket {
  id: String
  subject: String
  description: String
  status: String
  // ... (created date, messages, etc.)
}
```

### Activity
```dart
ActivitySummary {
  period: String            // day|week|month|year
  totalDistance: double
  totalTime: int
  totalCalories: double
  // ... (avg speed, elevation, rides, etc.)
}

ActivityFeedEvent {
  id: String
  type: String
  description: String
  timestamp: String
  // ... (related ride/trip data, etc.)
}
```

### Transit
```dart
TransitStopModel {
  id: String
  name: String
  lat: double
  lng: double
  type: String              // bus|buggy
  // ... (routes, arrivals, etc.)
}

TransitTripModel {
  id: String
  vehicleId: String
  stopId: String
  boardTime: String
  // ... (route info, passengers, etc.)
}
```

---

## HTTP Methods by Feature

| Feature | GET | POST | PUT | DELETE |
|---------|-----|------|-----|--------|
| Auth | — | ✓ ✓ ✓ ✓ | — | ✓ |
| Profile | ✓ | ✓ | ✓ | ✓ |
| Ride | — | ✓ ✓ ✓ | — | — |
| Trips | ✓ ✓ | — | — | — |
| Stations | ✓ | — | — | — |
| Wallet | ✓ ✓ ✓ | ✓ ✓ | — | — |
| Social | ✓ ✓ ✓ ✓ ✓ | ✓ ✓ | — | — |
| Groups | ✓ ✓ ✓ | ✓ ✓ ✓ | — | — |
| Subscriptions | ✓ ✓ | ✓ ✓ | — | ✓ |
| Support | ✓ | ✓ ✓ | — | — |
| Activity | ✓ ✓ | — | — | — |
| Transit | ✓ ✓ | ✓ ✓ | — | — |
| Config | ✓ ✓ | — | — | — |

---

## Implementation Locations

```
lib/
├── core/network/
│   ├── api_client.dart            (Dio setup, interceptors)
│   ├── api_endpoints.dart         (All endpoint paths)
│   ├── api_result.dart            (Deprecated wrapper)
│   └── providers.dart             (Riverpod provider)
│
└── features/
    ├── auth/data/
    │   ├── repositories/auth_repository_impl.dart
    │   └── models/auth_user_model.dart
    ├── profile/data/
    │   ├── repositories/profile_repository_impl.dart
    │   ├── repositories/achievements_repository_impl.dart
    │   └── models/profile_model.dart
    ├── ride/data/
    │   ├── repositories/ride_repository_impl.dart
    │   └── models/ride_model.dart
    ├── trips/data/
    │   ├── repositories/trip_repository_impl.dart
    │   └── models/trip_model.dart
    ├── home/data/
    │   ├── repositories/home_repository_impl.dart
    │   └── models/station_model.dart
    ├── wallet/data/
    │   ├── repositories/wallet_repository_impl.dart
    │   └── models/transaction_model.dart
    ├── social/data/
    │   ├── repositories/social_repository_impl.dart
    │   └── models/social_models.dart
    ├── groups/data/
    │   ├── repositories/group_repository_impl.dart
    │   └── models/group_model.dart
    ├── subscription/data/
    │   ├── repositories/subscription_repository_impl.dart
    │   └── models/subscription_model.dart
    ├── support/data/
    │   ├── repositories/support_repository_impl.dart
    │   └── models/support_model.dart
    ├── activity/data/
    │   ├── repositories/activity_repository_impl.dart
    │   └── models/activity_model.dart
    └── transit/data/
        ├── repositories/transit_repository_impl.dart
        └── models/transit_model.dart
```

---

## Quick Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| 401 Unauthorized | Token expired | Auto-refresh triggered; if fails, user logged out |
| 404 Not Found | Invalid ID/path | Check endpoint path and ID parameters |
| Network timeout | Poor connection | Falls back to cache if available |
| CORS error | Browser block | Only affects web; mobile unaffected |
| Multipart upload fail | Invalid file | Check file exists and has correct type |

---

## Performance Tips

1. **Batch Requests:** Use `Future.wait()` for parallel independent calls
2. **Cache Aggressively:** Profile, wallet, auth data cached locally
3. **Pagination:** Use `page` param for large lists (trips, activity)
4. **Filter Early:** Use query params to reduce server response size
5. **Lazy Load:** Load related data on-demand, not upfront

---

**Last Updated:** March 2026  
**Total Endpoints:** 53  
**Features:** 13  
**HTTP Methods:** 5 (GET, POST, PUT, PATCH, DELETE)  
**Auth Type:** Bearer Token  
**Error Handling:** Custom AppError hierarchy with cache fallback
