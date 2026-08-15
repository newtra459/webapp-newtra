# Mjollnir App — API Call Examples & Data Flow

**Concrete examples extracted from the actual codebase showing how each feature uses the API.**

---

## Table of Contents
1. [Authentication Flow](#authentication-flow)
2. [Profile Management](#profile-management)
3. [Ride Management](#ride-management)
4. [Trip History](#trip-history)
5. [Wallet Operations](#wallet-operations)
6. [Social Features](#social-features)
7. [Groups Management](#groups-management)
8. [Subscriptions](#subscriptions)
9. [Support System](#support-system)
10. [Activity & Analytics](#activity--analytics)
11. [Transit System](#transit-system)

---

## Authentication Flow

### Located: `lib/features/auth/data/repositories/auth_repository_impl.dart`

### 1. Send OTP (Step 1 of Login)
```dart
Future<String> sendOtp(String phone) async {
  final res = await _api.post(
    ApiEndpoints.auth.sendOtp,
    data: {'phone': phone},
  );
  return res.data['data']?['request_id'] as String? ?? '';
}
```

**Request:**
```json
POST /auth/otp/send
{
  "phone": "+919876543210"
}
```

**Response:**
```json
{
  "data": {
    "request_id": "req_123456789"
  },
  "status": "success"
}
```

---

### 2. Verify OTP (Step 2 of Login)
```dart
Future<({String token, String refreshToken, AuthUserModel user})> verifyOtp(
  String phone,
  String otp,
) async {
  final res = await _api.post(
    ApiEndpoints.auth.verifyOtp,
    data: {'phone': phone, 'otp': otp},
  );
  final data = res.data['data'] as Map<String, dynamic>;
  return (
    token: data['token'] as String? ?? '',
    refreshToken: data['refresh_token'] as String? ?? '',
    user: AuthUserModel.fromJson(data['user'] as Map<String, dynamic>? ?? {}),
  );
}
```

**Request:**
```json
POST /auth/otp/verify
{
  "phone": "+919876543210",
  "otp": "123456"
}
```

**Response:**
```json
{
  "data": {
    "token": "eyJhbGciOiJIUzI1NiIs...",
    "refresh_token": "eyJhbGciOiJIUzI1NiIs...",
    "user": {
      "id": "usr_123",
      "user_number": "MJL-ABC123",
      "phone": "+919876543210",
      "first_name": "John",
      "last_name": "Doe",
      "email": "john@example.com",
      "user_type": "General User",
      "organization": null
    }
  },
  "status": "success"
}
```

**Token Lifecycle:**
- Tokens automatically stored in `LocalStorage`
- Bearer token added to all subsequent requests
- Refresh token used for auto-refresh on 401

---

### 3. Register New User
```dart
Future<AuthUserModel> register(AuthUserModel user) async {
  final res = await _api.post(
    ApiEndpoints.auth.register,
    data: user.toJson(),
  );
  return AuthUserModel.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

**Request:**
```json
POST /auth/register
{
  "phone": "+919876543210",
  "first_name": "John",
  "last_name": "Doe",
  "email": "john@example.com",
  "user_type": "General User"
}
```

---

### 4. Auto Token Refresh (Interceptor)
```dart
// When 401 received:
Future<bool> _tryRefreshToken() async {
  final refresh = LocalStorage.getRefreshToken();
  if (refresh == null) return false;
  
  try {
    final response = await Dio(BaseOptions(baseUrl: baseUrl)).post(
      '/auth/refresh',
      data: {'refresh_token': refresh},
    );
    final newToken = response.data['data']?['token'] as String?;
    if (newToken != null) {
      await LocalStorage.saveToken(newToken);
      return true;
    }
  } catch (_) {
    // Refresh failed, logout user
    await LocalStorage.clearAuth();
  }
  return false;
}
```

---

## Profile Management

### Located: `lib/features/profile/data/repositories/profile_repository_impl.dart`

### 1. Get User Profile
```dart
Future<ProfileModel> getProfile() async {
  try {
    final response = await _apiClient.get(ApiEndpoints.profile.profile);
    final profile = ProfileModel.fromJson(response.data['data'] ?? response.data);
    _cachedProfile = profile;
    // Persist to local cache
    await LocalStorage.setString(_cacheKey, _encodeProfile(profile));
    return profile;
  } on AppError {
    // Fallback to cache on network failure
    final cached = getCachedProfile();
    if (cached != null) return cached;
    rethrow;
  }
}
```

**Request:**
```
GET /profile
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": {
    "id": "usr_123",
    "first_name": "John",
    "last_name": "Doe",
    "email": "john@example.com",
    "phone": "+919876543210",
    "bio": "Casual cyclist",
    "dob": "1995-05-15",
    "city": "Hyderabad",
    "gender": "M",
    "height": "180",
    "weight": "75",
    "rating": 4.5,
    "total_ratings": 42,
    "punctuality_rating": 4.8,
    "safety_rating": 4.7,
    "friendliness_rating": 4.3,
    "profile_image_url": "https://cdn.mjollnir.app/profile/usr_123.jpg"
  }
}
```

---

### 2. Update Profile
```dart
Future<ProfileModel> updateProfile(ProfileModel profile) async {
  try {
    final response = await _apiClient.put(
      ApiEndpoints.profile.profile,
      data: profile.toJson(),
    );
    final updated = ProfileModel.fromJson(response.data['data'] ?? response.data);
    _cachedProfile = updated;
    await LocalStorage.setString(_cacheKey, _encodeProfile(updated));
    return updated;
  } catch (e) {
    if (e is AppError) rethrow;
    throw GenericError('Failed to update profile: $e', originalError: e);
  }
}
```

**Request:**
```json
PUT /profile
Authorization: Bearer <token>
Content-Type: application/json

{
  "first_name": "Jonathan",
  "last_name": "Doe",
  "bio": "Serious cyclist & commuter",
  "city": "Bangalore",
  "height": "180",
  "weight": "75"
}
```

---

### 3. Upload Profile Photo
```dart
Future<String> uploadProfileImage(File image) async {
  try {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        image.path,
        filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });
    final response = await _apiClient.post(
      ApiEndpoints.profile.uploadImage,
      data: formData,
    );
    final imageUrl = response.data['data']?['url'] ?? response.data['url'] ?? '';
    if (_cachedProfile != null) {
      _cachedProfile = _cachedProfile!.copyWith(profileImageUrl: imageUrl);
      await LocalStorage.setString(_cacheKey, _encodeProfile(_cachedProfile!));
    }
    return imageUrl;
  } catch (e) {
    if (e is AppError) rethrow;
    throw FileError('Failed to upload image: $e', originalError: e);
  }
}
```

**Request:**
```
POST /profile/image
Authorization: Bearer <token>
Content-Type: multipart/form-data

[file data as multipart]
```

**Response:**
```json
{
  "data": {
    "url": "https://cdn.mjollnir.app/profile/usr_123_v2.jpg"
  }
}
```

---

## Ride Management

### Located: `lib/features/ride/data/repositories/ride_repository_impl.dart`

### 1. Start a Ride
```dart
Future<RideModel> startRide({
  required String bikeId,
  required int rideMode,
  bool isEBike = true,
}) async {
  final res = await _api.post(
    ApiEndpoints.ride.start,
    data: {
      'bike_id': bikeId,
      'ride_mode': rideMode,
      'is_ebike': isEBike,
    },
  );
  return RideModel.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

**Request:**
```json
POST /rides/start
Authorization: Bearer <token>
Content-Type: application/json

{
  "bike_id": "bike_a1b2c3d4",
  "ride_mode": 0,
  "is_ebike": true
}
```

**Response:**
```json
{
  "data": {
    "id": "ride_xyz123",
    "bike_id": "bike_a1b2c3d4",
    "ride_mode": 0,
    "is_ebike": true,
    "seconds": 0,
    "distance": 0.0,
    "current_speed": 0.0,
    "max_speed": 0.0,
    "calories": 0.0,
    "elevation": 0.0,
    "lat": 17.3850,
    "lng": 78.4867,
    "route_points": [],
    "battery_pct": 85,
    "paid_with_coin": false
  }
}
```

---

### 2. Update Ride Location (Live GPS)
```dart
Future<void> updateRideLocation(String rideId, double lat, double lng) async {
  await _api.post(
    ApiEndpoints.ride.updateLocation(rideId),
    data: {'lat': lat, 'lng': lng},
  );
}
```

**Request (called every 5 seconds):**
```json
POST /rides/ride_xyz123/location
Authorization: Bearer <token>
Content-Type: application/json

{
  "lat": 17.3852,
  "lng": 78.4870
}
```

---

### 3. End a Ride
```dart
Future<RideModel> endRide(String rideId) async {
  final res = await _api.post(ApiEndpoints.ride.end(rideId));
  return RideModel.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

**Request:**
```
POST /rides/ride_xyz123/end
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": {
    "id": "ride_xyz123",
    "seconds": 1847,
    "distance": 3.24,
    "current_speed": 0.0,
    "max_speed": 28.5,
    "calories": 145.2,
    "elevation": 32.0,
    "route_points": [[17.3850, 78.4867], [17.3851, 78.4868], ...],
    "battery_pct": 78,
    "paid_with_coin": true
  }
}
```

---

## Trip History

### Located: `lib/features/trips/data/repositories/trip_repository_impl.dart`

### 1. Get Trip List
```dart
Future<List<TripModel>> getTrips({String? filter}) async {
  final params = <String, dynamic>{};
  if (filter != null) params['type'] = filter;
  
  final res = await _api.get(
    ApiEndpoints.trips.list,
    queryParameters: params,
  );
  
  final list = res.data['data'] as List? ?? [];
  return list.map((e) => TripModel.fromJson(e as Map<String, dynamic>)).toList();
}
```

**Request:**
```
GET /trips?type=bike
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "trip_001",
      "type": "bike",
      "start_time": "2026-03-20T14:30:00Z",
      "end_time": "2026-03-20T15:15:00Z",
      "distance": 5.2,
      "duration_seconds": 2700,
      "calories": 210
    },
    {
      "id": "trip_002",
      "type": "bike",
      "start_time": "2026-03-19T08:15:00Z",
      "end_time": "2026-03-19T08:45:00Z",
      "distance": 2.8,
      "duration_seconds": 1800,
      "calories": 98
    }
  ]
}
```

---

### 2. Get Trip Detail
```dart
Future<TripModel> getTripDetail(String tripId) async {
  final res = await _api.get(ApiEndpoints.trips.detail(tripId));
  return TripModel.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

**Request:**
```
GET /trips/trip_001
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": {
    "id": "trip_001",
    "type": "bike",
    "mode": "shared",
    "start_location": { "lat": 17.3850, "lng": 78.4867, "name": "Hitech City" },
    "end_location": { "lat": 17.4230, "lng": 78.5120, "name": "Begumpet" },
    "start_time": "2026-03-20T14:30:00Z",
    "end_time": "2026-03-20T15:15:00Z",
    "distance": 5.2,
    "duration_seconds": 2700,
    "route_polyline": "...",
    "calories": 210,
    "average_speed": 6.9,
    "max_speed": 32.5,
    "elevation_gain": 45,
    "cost": 42,
    "payment_method": "wallet_coin"
  }
}
```

---

## Wallet Operations

### Located: `lib/features/wallet/data/repositories/wallet_repository_impl.dart`

### 1. Check Wallet Balance
```dart
Future<double> getBalance() async {
  try {
    final res = await _api.get(ApiEndpoints.wallet.balance);
    final balance = (res.data['data']?['balance'] as num?)?.toDouble() ?? 0.0;
    await LocalStorage.saveWalletBalance(balance);
    return balance;
  } catch (_) {
    return LocalStorage.getWalletBalance();  // Cache fallback
  }
}
```

**Request:**
```
GET /wallet/balance
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": {
    "balance": 2450.50,
    "currency": "INR",
    "last_updated": "2026-03-23T10:15:30Z"
  }
}
```

---

### 2. Top-up Wallet
```dart
Future<double> addMoney(double amount) async {
  final res = await _api.post(
    ApiEndpoints.wallet.topup,
    data: {'amount': amount},
  );
  final balance = (res.data['data']?['balance'] as num?)?.toDouble() ?? 0.0;
  await LocalStorage.saveWalletBalance(balance);
  return balance;
}
```

**Request:**
```json
POST /wallet/topup
Authorization: Bearer <token>
Content-Type: application/json

{
  "amount": 1000.00
}
```

**Response:**
```json
{
  "data": {
    "balance": 3450.50,
    "transaction_id": "txn_abc123",
    "timestamp": "2026-03-23T10:20:00Z"
  }
}
```

---

### 3. Apply Coupon Code
```dart
Future<String?> applyCoupon(String code) async {
  final res = await _api.post(
    ApiEndpoints.wallet.applyCoupon,
    data: {'code': code},
  );
  return res.data['data']?['message'] as String?;
}
```

**Request:**
```json
POST /wallet/coupon
Authorization: Bearer <token>
Content-Type: application/json

{
  "code": "SAVE50"
}
```

**Response:**
```json
{
  "data": {
    "message": "Coupon applied! ₹50 credited to wallet",
    "discount_amount": 50.00,
    "new_balance": 3500.50
  }
}
```

---

## Social Features

### Located: `lib/features/social/data/repositories/social_repository_impl.dart`

### 1. Get Friend Suggestions
```dart
Future<List<FriendModel>> getSuggested() async {
  final res = await _api.get(ApiEndpoints.social.suggested);
  final list = res.data['data'] as List? ?? [];
  return list.map((e) => FriendModel.fromJson(e as Map<String, dynamic>)).toList();
}
```

**Request:**
```
GET /social/suggested
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "usr_456",
      "first_name": "Alice",
      "last_name": "Smith",
      "avatar_url": "https://...",
      "bio": "MTB enthusiast",
      "following": false,
      "mutual_friends": 3
    }
  ]
}
```

---

### 2. Follow/Unfollow User
```dart
Future<void> follow(String userId) async {
  await _api.post(ApiEndpoints.social.follow(userId));
}

Future<void> unfollow(String userId) async {
  await _api.post(ApiEndpoints.social.unfollow(userId));
}
```

**Request:**
```
POST /social/follow/usr_456
Authorization: Bearer <token>
```

---

### 3. Get Leaderboards
```dart
Future<List<LeaderboardEntry>> getRiderLeaderboard() async {
  final res = await _api.get(ApiEndpoints.social.leaderboardRiders);
  final list = res.data['data'] as List? ?? [];
  return list.map((e) => LeaderboardEntry.fromJson(e as Map<String, dynamic>)).toList();
}
```

**Request:**
```
GET /social/leaderboard/riders
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": [
    {
      "rank": 1,
      "user_id": "usr_001",
      "name": "Arjun Kumar",
      "avatar": "https://...",
      "total_distance": 2450.5,
      "total_rides": 156,
      "this_week_distance": 142.3,
      "this_week_rides": 12
    },
    {
      "rank": 2,
      "user_id": "usr_123",
      "name": "You",
      ...
    }
  ]
}
```

---

## Groups Management

### Located: `lib/features/groups/data/repositories/group_repository_impl.dart`

### 1. Create a Group
```dart
Future<GroupModel> createGroup({
  required String name,
  required String description,
  required String category,
}) async {
  final res = await _api.post(
    ApiEndpoints.groups.create,
    data: {
      'name': name,
      'description': description,
      'category': category,
    },
  );
  return GroupModel.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

**Request:**
```json
POST /groups
Authorization: Bearer <token>
Content-Type: application/json

{
  "name": "Morning Riders - Hyderabad",
  "description": "Group for early morning bike rides in and around Hyderabad",
  "category": "commute"
}
```

**Response:**
```json
{
  "data": {
    "id": "grp_123",
    "name": "Morning Riders - Hyderabad",
    "description": "Group for early morning bike rides...",
    "category": "commute",
    "creator_id": "usr_123",
    "member_count": 1,
    "created_at": "2026-03-23T10:30:00Z"
  }
}
```

---

### 2. Discover & Join Groups
```dart
Future<List<GroupModel>> discoverGroups() async {
  final res = await _api.get(ApiEndpoints.groups.discover);
  final list = res.data['data'] as List? ?? [];
  return list.map((e) => GroupModel.fromJson(e as Map<String, dynamic>)).toList();
}

Future<void> joinGroup(String groupId) async {
  await _api.post(ApiEndpoints.groups.join(groupId));
}
```

**Request (Join):**
```
POST /groups/grp_456/join
Authorization: Bearer <token>
```

---

## Subscriptions

### Located: `lib/features/subscription/data/repositories/subscription_repository_impl.dart`

### 1. Get Subscription Plans
```dart
Future<List<SubscriptionPlan>> getPlans({String? locationName}) async {
  final params = <String, dynamic>{};
  if (locationName != null) params['location'] = locationName;
  
  final res = await _api.get(
    ApiEndpoints.subscriptions.plans,
    queryParameters: params,
  );
  
  final list = res.data['data'] as List? ?? [];
  return list.map((e) => SubscriptionPlan.fromJson(e as Map<String, dynamic>)).toList();
}
```

**Request:**
```
GET /subscriptions/plans?location=Hyderabad
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "plan_basic",
      "name": "Basic",
      "price": 499,
      "duration_days": 30,
      "currency": "INR",
      "benefits": [
        "Unlimited rides",
        "₹50 monthly bonus",
        "Priority support"
      ]
    }
  ]
}
```

---

### 2. Subscribe to Plan
```dart
Future<UserSubscription> subscribe(String planId) async {
  final res = await _api.post(
    ApiEndpoints.subscriptions.subscribe,
    data: {'plan_id': planId},
  );
  return UserSubscription.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

---

### 3. Verify Institution ID (Auto-allocation)
```dart
Future<UserSubscription?> verifyInstitutionId({
  required String org,
  required String institutionId,
}) async {
  final res = await _api.post(
    ApiEndpoints.subscriptions.verifyId,
    data: {'org': org, 'institution_id': institutionId},
  );
  final data = res.data['data'] as Map<String, dynamic>?;
  final verified = data?['verified'] as bool? ?? false;
  if (!verified) return null;
  
  final subJson = data?['subscription'] as Map<String, dynamic>?;
  return subJson == null ? null : UserSubscription.fromJson(subJson);
}
```

**Request:**
```json
POST /subscriptions/verify-id
Authorization: Bearer <token>
Content-Type: application/json

{
  "org": "IIIT-Hyderabad",
  "institution_id": "IIIT123456"
}
```

---

## Support System

### Located: `lib/features/support/data/repositories/support_repository_impl.dart`

### 1. Create Support Ticket
```dart
Future<SupportTicket> createTicket(SupportTicket ticket) async {
  final res = await _api.post(
    ApiEndpoints.support.createTicket,
    data: ticket.toJson(),
  );
  return SupportTicket.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

**Request:**
```json
POST /support/tickets
Authorization: Bearer <token>
Content-Type: application/json

{
  "subject": "Bike unlock issue",
  "description": "I scanned the QR code on bike_abc123 but it didn't unlock",
  "category": "technical",
  "attachments": []
}
```

---

### 2. Send Chat Message
```dart
Future<String> sendChatMessage(String message) async {
  final res = await _api.post(
    ApiEndpoints.support.chat,
    data: {'message': message},
  );
  return res.data['data']?['reply'] as String? ?? '';
}
```

**Request:**
```json
POST /support/chat
Authorization: Bearer <token>
Content-Type: application/json

{
  "message": "How do I unlock a bike?"
}
```

**Response:**
```json
{
  "data": {
    "reply": "To unlock a bike: 1. Press the unlock button on the bike 2. Scan the QR code..."
  }
}
```

---

## Activity & Analytics

### Located: `lib/features/activity/data/repositories/activity_repository_impl.dart`

### 1. Get Activity Summary
```dart
Future<ActivitySummary> getSummary({String period = 'week'}) async {
  final res = await _api.get(
    ApiEndpoints.activity.summary,
    queryParameters: {'period': period},
  );
  return ActivitySummary.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

**Request:**
```
GET /activity/summary?period=week
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": {
    "period": "week",
    "total_rides": 8,
    "total_distance": 42.5,
    "total_time_seconds": 12600,
    "total_calories": 1850,
    "average_speed": 12.1,
    "max_speed": 35.2,
    "elevation_gain": 280,
    "co2_saved": 8.5,
    "cost_savings": 420
  }
}
```

---

### 2. Get Activity Feed
```dart
Future<List<ActivityFeedEvent>> getFeed({int page = 1}) async {
  final res = await _api.get(
    ApiEndpoints.activity.feed,
    queryParameters: {'page': page},
  );
  
  final list = res.data['data'] as List? ?? [];
  return list
      .map((e) => ActivityFeedEvent.fromJson(e as Map<String, dynamic>))
      .toList();
}
```

**Request:**
```
GET /activity/feed?page=1
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "event_001",
      "type": "ride_completed",
      "title": "Completed 5.2 km ride",
      "description": "Rode from Hitech City to Begumpet",
      "timestamp": "2026-03-23T15:30:00Z",
      "ride_id": "ride_xyz123"
    },
    {
      "id": "event_002",
      "type": "achievement_unlocked",
      "title": "Reached 100 km milestone",
      "description": "You've cycled 100 km total!",
      "timestamp": "2026-03-20T10:15:00Z"
    }
  ]
}
```

---

## Transit System

### Located: `lib/features/transit/data/repositories/transit_repository_impl.dart`

### 1. Get Nearby Transit Stops
```dart
Future<List<TransitStopModel>> getNearbyStops({
  String? type,
  String? search,
}) async {
  final params = <String, dynamic>{};
  if (type != null) params['type'] = type;
  if (search != null && search.isNotEmpty) params['search'] = search;
  
  final res = await _api.get(
    ApiEndpoints.transit.stops,
    queryParameters: params,
  );
  
  final list = res.data['data'] as List? ?? [];
  return list
      .map((e) => TransitStopModel.fromJson(e as Map<String, dynamic>))
      .toList();
}
```

**Request:**
```
GET /transit/stops?type=bus&search=hitech
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": [
    {
      "id": "stop_001",
      "name": "Hitech City Bus Stop",
      "lat": 17.3850,
      "lng": 78.4867,
      "type": "bus",
      "next_vehicles": [
        {
          "route_number": "201",
          "direction": "Mehdipatnam",
          "arrives_in": 5
        }
      ]
    }
  ]
}
```

---

### 2. Board a Vehicle (Start Transit Trip)
```dart
Future<TransitTripModel> boardVehicle({
  required String vehicleId,
  required String stopId,
}) async {
  final res = await _api.post(
    ApiEndpoints.transit.board,
    data: {'vehicle_id': vehicleId, 'stop_id': stopId},
  );
  return TransitTripModel.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

**Request:**
```json
POST /transit/trips/board
Authorization: Bearer <token>
Content-Type: application/json

{
  "vehicle_id": "bus_001_201",
  "stop_id": "stop_001"
}
```

**Response:**
```json
{
  "data": {
    "id": "transit_trip_001",
    "vehicle_id": "bus_001_201",
    "route_number": "201",
    "boarded_at": "2026-03-23T16:45:00Z",
    "start_stop": "Hitech City Bus Stop",
    "current_location": { "lat": 17.3850, "lng": 78.4867 },
    "passengers_count": 28
  }
}
```

---

### 3. End Transit Trip
```dart
Future<TransitTripModel> endTrip(String tripId) async {
  final res = await _api.post(ApiEndpoints.transit.endTrip(tripId));
  return TransitTripModel.fromJson(res.data['data'] as Map<String, dynamic>);
}
```

**Request:**
```
POST /transit/trips/transit_trip_001/end
Authorization: Bearer <token>
```

**Response:**
```json
{
  "data": {
    "id": "transit_trip_001",
    "ended_at": "2026-03-23T17:15:00Z",
    "end_stop": "Begumpet Bus Stop",
    "duration_seconds": 1800,
    "distance": 8.5,
    "fare": 25,
    "payment_status": "automatic_coin_deduction"
  }
}
```

---

## Error Handling Pattern

All repositories use this error handling pattern:

```dart
try {
  // API call
  final res = await _api.get(endpoint);
  // Process response
  return Model.fromJson(res.data['data']);
} on AppError {
  // Known error type - rethrow
  rethrow;
} catch (e) {
  // Unknown error - wrap and rethrow
  throw GenericError('Failed to fetch: $e', originalError: e);
}
```

**Error types:**
- `NetworkError` — Network I/O failure
- `AuthError` — 401/403 authentication
- `ValidationError` — 400 validation
- `NotFoundError` — 404 missing
- `ServerError` — 5xx server error
- `GenericError` — Unknown error

---

**Last Updated:** March 2026  
**Examples Count:** 20+  
**Features Covered:** All 13 modules
