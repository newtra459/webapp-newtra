# Mjollnir API Contract

**Base URL:** `https://api.mjollnir.app/v1`  
**Content-Type:** `application/json`  
**Auth:** `Authorization: Bearer <token>` (all endpoints except Auth and Config)  
**Timeouts:** Connect 30 s · Receive 30 s

---

## Response Envelope

Every response follows the same wrapper:

```json
{
  "data": { ... },       // payload (object or array)
  "message": "...",      // optional human-readable note
  "code": "..."          // optional machine-readable code
}
```

Error responses:

```json
{
  "message": "Validation failed",
  "code": "VALIDATION_ERROR",
  "errors": {
    "phone": "Invalid format"
  }
}
```

---

## HTTP Status Codes

| Code | Meaning |
|------|---------|
| `200` | Success |
| `201` | Created |
| `400` | Bad request / validation error |
| `401` | Unauthenticated — token missing or expired |
| `403` | Forbidden — insufficient permissions |
| `404` | Resource not found |
| `422` | Unprocessable entity |
| `5xx` | Server error |

> **401 handling:** The client automatically retries once using `POST /auth/refresh`. If the refresh also fails, the user is logged out.

---

## Modules

1. [Auth](#1-auth)
2. [Profile](#2-profile)
3. [Ride](#3-ride)
4. [Trips](#4-trips)
5. [Stations](#5-stations)
6. [Wallet](#6-wallet)
7. [Social](#7-social)
8. [Groups](#8-groups)
9. [Subscriptions](#9-subscriptions)
10. [Support](#10-support)
11. [Activity](#11-activity)
12. [Transit](#12-transit)
13. [Config](#13-config)

---

## 1. Auth

> No `Authorization` header required on these endpoints.

---

### `POST /auth/otp/send`

Send a one-time password to the given phone number.

**Request**
```json
{
  "phone": "+919876543210"
}
```

**Response `200`**
```json
{
  "data": {
    "request_id": "req_abc123"
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `request_id` | `string` | Opaque token; pass back to `/auth/otp/verify` |

---

### `POST /auth/otp/verify`

Verify the OTP and receive auth tokens.

**Request**
```json
{
  "phone": "+919876543210",
  "otp": "123456"
}
```

**Response `200`**
```json
{
  "data": {
    "token": "eyJhbGci...",
    "refresh_token": "eyJhbGci...",
    "user": {
      "id": "uuid-string",
      "user_number": "MJL-A1B2C3D4",
      "phone": "+919876543210",
      "first_name": "Rishwak",
      "last_name": "Sharma",
      "email": "rishwak@example.com",
      "user_type": "General User",
      "organization": null
    }
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `token` | `string` | Short-lived JWT — store in Keychain/Keystore |
| `refresh_token` | `string` | Long-lived refresh token |
| `user.id` | `string` | Server UUID |
| `user.user_number` | `string` | Human-readable ID `MJL-XXXXXXXX` |
| `user.user_type` | `string` | `"General User"` \| `"Student"` \| `"Employee"` |
| `user.organization` | `string?` | Campus/org name; null for general users |

---

### `POST /auth/register`

Register profile details after first OTP verification.

**Request** — mirrors `AuthUserModel`
```json
{
  "id": "uuid-string",
  "user_number": "MJL-A1B2C3D4",
  "phone": "+919876543210",
  "first_name": "Rishwak",
  "last_name": "Sharma",
  "email": "rishwak@example.com",
  "user_type": "Student",
  "organization": "IIT Hyderabad"
}
```

**Response `201`**
```json
{
  "data": {
    "id": "uuid-string",
    "user_number": "MJL-A1B2C3D4",
    "phone": "+919876543210",
    "first_name": "Rishwak",
    "last_name": "Sharma",
    "email": "rishwak@example.com",
    "user_type": "Student",
    "organization": "IIT Hyderabad"
  }
}
```

---

### `POST /auth/refresh`

Exchange a refresh token for a new access token.

> No `Authorization` header needed.

**Request**
```json
{
  "refresh_token": "eyJhbGci..."
}
```

**Response `200`**
```json
{
  "data": {
    "token": "eyJhbGci...",
    "refresh_token": "eyJhbGci..."
  }
}
```

---

### `DELETE /auth/account`

Permanently delete the authenticated user's account.

**Request** — no body  
**Response `200`**
```json
{ "data": null, "message": "Account deleted" }
```

---

## 2. Profile

> All endpoints require `Authorization: Bearer <token>`.

---

### `GET /profile`

Fetch the current user's profile.

**Response `200`**
```json
{
  "data": {
    "id": "uuid-string",
    "first_name": "Rishwak",
    "last_name": "Sharma",
    "email": "rishwak@example.com",
    "phone": "+919876543210",
    "bio": "Eco rider · Level 5",
    "dob": "2000-03-14",
    "city": "Hyderabad",
    "gender": "Male",
    "height": "175",
    "weight": "70",
    "rating": 4.8,
    "total_ratings": 132,
    "punctuality_rating": 4.9,
    "safety_rating": 4.7,
    "friendliness_rating": 4.8,
    "profile_image_url": "https://cdn.mjollnir.app/avatars/uuid.jpg"
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `id` | `string?` | Server UUID |
| `first_name` | `string` | |
| `last_name` | `string` | |
| `email` | `string` | |
| `phone` | `string` | |
| `bio` | `string` | Free-text bio |
| `dob` | `string` | ISO date e.g. `"2000-03-14"` |
| `city` | `string` | |
| `gender` | `string` | `"Male"` \| `"Female"` \| `"Other"` |
| `height` | `string` | cm, as string |
| `weight` | `string` | kg, as string |
| `rating` | `number` | Aggregate peer rating 0–5 |
| `total_ratings` | `integer` | Number of ratings received |
| `punctuality_rating` | `number` | 0–5 |
| `safety_rating` | `number` | 0–5 |
| `friendliness_rating` | `number` | 0–5 |
| `profile_image_url` | `string?` | CDN URL; null if no photo |

---

### `PUT /profile`

Update the current user's profile. Same shape as `GET /profile` response `data`.

**Request** — full `ProfileModel` JSON (all fields)  
**Response `200`** — updated profile, same shape as `GET /profile`

---

### `POST /profile/image`

Upload a profile photo (multipart/form-data).

**Request** — `Content-Type: multipart/form-data`

| Field | Type | Notes |
|-------|------|-------|
| `image` | `file` | JPEG/PNG; filename: `profile_<timestamp>.jpg` |

**Response `200`**
```json
{
  "data": {
    "url": "https://cdn.mjollnir.app/avatars/uuid.jpg"
  }
}
```

---

### `DELETE /profile/image`

Remove the current profile photo.

**Request** — no body  
**Response `200`**
```json
{ "data": null }
```

---

### `GET /profile/achievements`

Fetch all achievement definitions merged with the user's progress.

**Response `200`**
```json
{
  "data": [
    {
      "id": "ach_001",
      "title": "Century Rider",
      "description": "Ride 100 km total",
      "category": "riding",
      "icon": "🏆",
      "color_hex": "#FFB300",
      "progress": 0.72,
      "unlocked": false,
      "unlocked_date": null,
      "threshold_label": "Ride 100 km",
      "active": true
    }
  ]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `category` | `string` | `"riding"` \| `"social"` \| `"eco"` \| `"streak"` |
| `icon` | `string` | Emoji or icon identifier |
| `color_hex` | `string` | Hex color e.g. `"#FFB300"` |
| `progress` | `number` | `0.0` – `1.0` |
| `unlocked` | `boolean` | `true` when `progress == 1.0` |
| `unlocked_date` | `string?` | ISO-8601; null if still locked |
| `active` | `boolean` | Whether admin has published this achievement |

---

### `POST /profile/achievements/:achievementId/acknowledge`

Mark an achievement as seen/acknowledged by the user.

**Path params**

| Param | Type | Example |
|-------|------|---------|
| `achievementId` | `string` | `"ach_001"` |

**Request** — no body  
**Response `200`**
```json
{ "data": null }
```

---

## 3. Ride

---

### `POST /rides/start`

Unlock a bike and begin a ride session.

**Request**
```json
{
  "bike_id": "BIKE-XY123",
  "ride_mode": 0,
  "is_ebike": true
}
```

| Field | Type | Required | Notes |
|-------|------|----------|-------|
| `bike_id` | `string` | ✓ | QR-scanned bike identifier |
| `ride_mode` | `integer` | ✓ | `0` = shared, `1` = own bike |
| `is_ebike` | `boolean` | | Defaults `true` |

**Response `200`**
```json
{
  "data": {
    "id": "ride_abc123",
    "bike_id": "BIKE-XY123",
    "ride_mode": 0,
    "is_ebike": true,
    "seconds": 0,
    "distance": 0.0,
    "current_speed": 0.0,
    "max_speed": 0.0,
    "calories": 0.0,
    "elevation": 0.0,
    "lat": 17.4577,
    "lng": 78.2753,
    "battery_pct": 85,
    "paid_with_coin": false
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `id` | `string` | Ride session ID — persist locally |
| `seconds` | `integer` | Elapsed seconds |
| `distance` | `number` | km |
| `current_speed` | `number` | km/h |
| `max_speed` | `number` | km/h |
| `calories` | `number` | kcal |
| `elevation` | `number` | metres |
| `battery_pct` | `integer` | 0–100 |
| `paid_with_coin` | `boolean` | Whether a loyalty coin was used |

---

### `POST /rides/:rideId/end`

End an active ride session.

**Path params**

| Param | Type | Example |
|-------|------|---------|
| `rideId` | `string` | `"ride_abc123"` |

**Request** — no body  
**Response `200`** — `RideModel` with final stats (same shape as `/rides/start` response)

---

### `POST /rides/:rideId/location`

Stream the rider's live GPS coordinates during an active ride.

**Path params**

| Param | Type | Example |
|-------|------|---------|
| `rideId` | `string` | `"ride_abc123"` |

**Request**
```json
{
  "lat": 17.4577,
  "lng": 78.2753
}
```

**Response `200`**
```json
{ "data": null }
```

---

## 4. Trips

---

### `GET /trips`

Paginated ride history for the current user.

**Query params**

| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `type` | `string` | | Filter: `"cycle"` \| `"bus"` \| `"buggy"` |

**Response `200`**
```json
{
  "data": [
    {
      "id": "trip_001",
      "date": "2026-03-19",
      "type": "cycle",
      "from": "Main Gate",
      "to": "Library Block",
      "distance": "3.2 km",
      "duration": "18 min",
      "start_time": "09:15",
      "end_time": "09:33",
      "calories": "120 kcal",
      "avg_speed": "10.6 km/h",
      "elevation": "+42 m",
      "co2": "0.8 kg",
      "payment_type": "subscription",
      "plan": "Campus Monthly",
      "price": null,
      "coins": 1,
      "vehicle": null,
      "buggy_number": null,
      "route_number": null,
      "passengers": null,
      "stops": null,
      "seat": null
    }
  ]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `type` | `string` | `"cycle"` \| `"bus"` \| `"buggy"` |
| `payment_type` | `string` | `"subscription"` \| `"paid"` \| `"own_bike"` |
| `coins` | `integer` | Loyalty coins earned on this trip |
| `vehicle`, `buggy_number`, `route_number` | `string?` | Bus/buggy-specific |
| `passengers`, `stops`, `seat` | `string?` | Transit-specific |

---

### `GET /trips/:tripId`

Full detail for a single past trip. Response shape is the same as a single item from `GET /trips`.

---

## 5. Stations

---

### `GET /stations/nearby`

Fetch stations close to a coordinate.

**Query params**

| Param | Type | Required | Notes |
|-------|------|----------|-------|
| `lat` | `number` | ✓ | WGS84 latitude |
| `lng` | `number` | ✓ | WGS84 longitude |

**Response `200`**
```json
{
  "data": [
    {
      "id": "stn_001",
      "name": "Main Gate Station",
      "distance": 0.35,
      "walk_min": 5,
      "bikes": 4,
      "ebikes": 2,
      "docks": 10,
      "lat": 17.4580,
      "lng": 78.2760
    }
  ]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `distance` | `number` | km from the requested coordinate |
| `walk_min` | `integer` | Estimated walk time in minutes |
| `bikes` | `integer` | Regular bikes available |
| `ebikes` | `integer` | E-bikes available |
| `docks` | `integer` | Free docking slots |

---

## 6. Wallet

---

### `GET /wallet/balance`

**Response `200`**
```json
{
  "data": {
    "balance": 250.00
  }
}
```

---

### `POST /wallet/topup`

Add funds to the wallet.

**Request**
```json
{ "amount": 100.00 }
```

**Response `200`**
```json
{
  "data": { "balance": 350.00 }
}
```

---

### `POST /wallet/withdraw`

Withdraw funds from the wallet.

**Request**
```json
{ "amount": 50.00 }
```

**Response `200`**
```json
{
  "data": { "balance": 300.00 }
}
```

---

### `GET /wallet/transactions`

**Response `200`**
```json
{
  "data": [
    {
      "id": "txn_001",
      "icon": "add_circle_rounded",
      "title": "Top-up",
      "subtitle": "UPI · HDFC Bank",
      "amount": "₹100",
      "type": "credit",
      "tag": "Added",
      "date": "2026-03-19T10:30:00Z"
    }
  ]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `type` | `string` | `"credit"` \| `"debit"` |
| `date` | `string` | ISO-8601 UTC timestamp |

---

### `POST /wallet/coupon`

Apply a promotional coupon code.

**Request**
```json
{ "code": "RIDE10" }
```

**Response `200`**
```json
{
  "data": {
    "message": "₹10 credited to your wallet"
  }
}
```

---

## 7. Social

---

### `GET /social/suggested`

Users the current user might want to follow.

**Response `200`**
```json
{
  "data": [
    {
      "id": "usr_001",
      "name": "Priya Nair",
      "type": "Student",
      "total_distance": "142 km",
      "rides": 38,
      "is_following": false
    }
  ]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `type` | `string` | `"Student"` \| `"Employee"` \| `"General"` |
| `total_distance` | `string` | Formatted, e.g. `"142 km"` |
| `is_following` | `boolean` | Whether the current user follows this person |

---

### `GET /social/followers`

Users who follow the current user. Same response shape as `/social/suggested`.

---

### `GET /social/following`

Users the current user follows. Same response shape as `/social/suggested`.

---

### `POST /social/follow/:userId`

Follow a user.

**Path params**

| Param | Type |
|-------|------|
| `userId` | `string` |

**Request** — no body  
**Response `200`** `{ "data": null }`

---

### `POST /social/unfollow/:userId`

Unfollow a user.  
Same as `/social/follow/:userId` — no body, `{ "data": null }` response.

---

### `GET /social/leaderboard/riders`

Individual rider leaderboard.

**Response `200`**
```json
{
  "data": [
    {
      "id": "usr_001",
      "name": "Priya Nair",
      "values": {
        "distance": "142 km",
        "rides": "38",
        "co2": "28 kg"
      },
      "is_me": false,
      "badge": "🥇",
      "members": 0
    }
  ]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `values` | `object<string, string>` | Metric key → formatted display string |
| `is_me` | `boolean` | True for the current user's entry |
| `badge` | `string?` | Emoji badge for top ranks |

---

### `GET /social/leaderboard/groups`

Group leaderboard. Same response shape — `members` indicates group size.

---

## 8. Groups

---

### `GET /groups/mine`

Groups the current user belongs to.

**Response `200`**
```json
{
  "data": [
    {
      "id": "grp_001",
      "name": "Campus Cyclists",
      "description": "Official cycling club of IIT Hyderabad",
      "category": "Cycling",
      "members": 24,
      "total_distance": "1,240 km",
      "joined": true,
      "image_url": "https://cdn.mjollnir.app/groups/001.jpg"
    }
  ]
}
```

---

### `GET /groups/discover`

Public groups available to join. Same response shape as `GET /groups/mine`.

---

### `POST /groups`

Create a new group.

**Request**
```json
{
  "name": "Eco Warriors",
  "description": "Zero-emission commuters",
  "category": "Eco"
}
```

**Response `201`** — single `GroupModel` object.

---

### `GET /groups/:groupId`

Full detail of a group. Same response shape as a single item from `GET /groups/mine`.

---

### `POST /groups/:groupId/join`

Join a group.  
**Request** — no body · **Response `200`** `{ "data": null }`

---

### `POST /groups/:groupId/leave`

Leave a group.  
**Request** — no body · **Response `200`** `{ "data": null }`

---

## 9. Subscriptions

---

### `GET /subscriptions/plans`

Available subscription plans for a location.

**Query params**

| Param | Type | Notes |
|-------|------|-------|
| `location` | `string` | Location/campus name (optional) |

**Response `200`**
```json
{
  "data": [
    {
      "id": "plan_001",
      "name": "Campus Monthly",
      "price": "₹299",
      "price_value": 299,
      "duration": "30 days",
      "duration_days": 30,
      "coins": 10,
      "features": ["Unlimited cycle rides", "5 e-bike rides/day"],
      "category": "Student",
      "location_name": "IIT Hyderabad",
      "popular": true,
      "included_modes": ["bike", "ebike"]
    }
  ]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `coins` | `integer` | Loyalty coins awarded on activation |
| `included_modes` | `string[]` | `"bike"` \| `"ebike"` \| `"buggy"` \| `"bus"` |

---

### `POST /subscriptions`

Activate a subscription plan.

**Request**
```json
{ "plan_id": "plan_001" }
```

**Response `200`**
```json
{
  "data": {
    "id": "sub_001",
    "plan_name": "Campus Monthly",
    "location_name": "IIT Hyderabad",
    "start_date": "2026-03-19",
    "end_date": "2026-04-18",
    "is_active": true
  }
}
```

---

### `GET /subscriptions/active`

Get the current user's active subscription, or `null`.

**Response `200`** — `UserSubscription` object or `{ "data": null }`

| Field | Type | Notes |
|-------|------|-------|
| `start_date` | `string` | ISO date |
| `end_date` | `string` | ISO date |
| `is_active` | `boolean` | Server-authoritative flag |

---

### `DELETE /subscriptions/:subscriptionId`

Cancel an active subscription.

**Request** — no body  
**Response `200`** `{ "data": null }`

---

### `POST /subscriptions/verify-id`

Verify an institution ID for discounted plans.

**Request**
```json
{
  "org": "IIT Hyderabad",
  "institution_id": "CS22B001"
}
```

**Response `200`**
```json
{
  "data": {
    "verified": true,
    "subscription": { ... }
  }
}
```

Returns `{ "data": { "verified": false } }` if the ID is not recognised.

---

## 10. Support

---

### `POST /support/tickets`

Create a support ticket.

**Request**
```json
{
  "category": "Billing",
  "subject": "Double charge on 18 March",
  "description": "I was charged twice for ride_abc123..."
}
```

**Response `201`**
```json
{
  "data": {
    "id": "tkt_001",
    "category": "Billing",
    "subject": "Double charge on 18 March",
    "description": "I was charged twice...",
    "status": "open",
    "created_at": "2026-03-19T10:45:00Z"
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `status` | `string` | `"open"` \| `"in_progress"` \| `"resolved"` \| `"closed"` |

---

### `GET /support/tickets/mine`

All tickets raised by the current user. Returns array of `SupportTicket`.

---

### `POST /support/chat`

Send a message to the AI chat assistant.

**Request**
```json
{ "message": "How do I top up my wallet?" }
```

**Response `200`**
```json
{
  "data": {
    "reply": "You can top up your wallet from the Wallet tab..."
  }
}
```

---

## 11. Activity

---

### `GET /activity/summary`

Aggregated ride statistics for the current user.

**Query params**

| Param | Type | Notes |
|-------|------|-------|
| `period` | `string` | `"week"` (default) \| `"month"` \| `"year"` |

**Response `200`**
```json
{
  "data": {
    "total_trips": 42,
    "total_distance": 186.5,
    "total_duration_min": 540,
    "total_calories": 4200.0,
    "total_co2": 37.3,
    "avg_speed": 12.4,
    "weekly_data": {
      "distance": [3.2, 5.1, 0.0, 8.4, 6.2, 4.0, 2.1],
      "calories": [120, 190, 0, 310, 230, 148, 80]
    },
    "monthly_data": {
      "distance": [42.0, 38.5, 50.0, 56.0],
      "calories": [1540, 1410, 1830, 2050]
    }
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `total_distance` | `number` | km |
| `total_duration_min` | `integer` | minutes |
| `total_calories` | `number` | kcal |
| `total_co2` | `number` | kg CO₂ saved |
| `avg_speed` | `number` | km/h |
| `weekly_data` / `monthly_data` | `object<string, number[]>` | Metric → array of values per time bucket |

---

### `GET /activity/feed`

Paginated activity feed (rides, badges, streaks).

**Query params**

| Param | Type | Notes |
|-------|------|-------|
| `page` | `integer` | Defaults to `1` |

**Response `200`**
```json
{
  "data": [
    {
      "id": "evt_001",
      "type": "ride",
      "title": "Morning Ride",
      "description": "Main Gate → Library · 3.2 km",
      "timestamp": "2026-03-19T09:33:00Z",
      "distance": 3.2,
      "duration_min": 18,
      "calories": 120.0,
      "coins_earned": 1,
      "icon_url": null
    }
  ]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `type` | `string` | `"ride"` \| `"bus"` \| `"buggy"` \| `"badge"` \| `"streak"` |
| `timestamp` | `string` | ISO-8601 UTC |
| `coins_earned` | `integer?` | Loyalty coins earned; null if not applicable |

---

## 12. Transit

---

### `GET /transit/stops`

Nearby transit stops (buses and buggies).

**Query params**

| Param | Type | Notes |
|-------|------|-------|
| `type` | `string?` | `"bus"` \| `"buggy"` — omit for all |
| `search` | `string?` | Search query for stop name / route |

**Response `200`**
```json
{
  "data": [
    {
      "id": "stop_001",
      "name": "Main Gate Bus Stop",
      "route": "Route 1 · City Loop",
      "route_short": "R1",
      "eta": "3 min",
      "capacity_occupied": 18,
      "capacity_total": 30,
      "next_etas": ["3 min", "12 min", "25 min"],
      "type": "bus",
      "distance": "0.2 km",
      "vehicle_name": "City Bus",
      "vehicle_number": "TS07XX1234",
      "vehicle_image_url": null,
      "lat": 17.4580,
      "lng": 78.2760
    }
  ]
}
```

---

### `POST /transit/trips/board`

Board a transit vehicle and start a trip session.

**Request**
```json
{
  "vehicle_id": "veh_001",
  "stop_id": "stop_001"
}
```

**Response `200`**
```json
{
  "data": {
    "id": "transit_trip_001",
    "stop_name": "Main Gate Bus Stop",
    "type": "bus",
    "route": "Route 1 · City Loop",
    "vehicle_name": "City Bus",
    "vehicle_number": "TS07XX1234",
    "vehicle_image_url": null,
    "start_time": "2026-03-19T09:15:00Z",
    "end_time": null,
    "elapsed_seconds": 0,
    "xp_earned": 0,
    "fare": null
  }
}
```

| Field | Type | Notes |
|-------|------|-------|
| `end_time` | `string?` | ISO-8601; null while trip is active |
| `xp_earned` | `integer` | XP awarded at end |
| `fare` | `number?` | Charged fare; null if subscription covered |

---

### `GET /transit/trips/active`

Get the currently active transit trip, or `null`.

**Response `200`** — `TransitTripModel` or `{ "data": null }`

---

### `POST /transit/trips/:tripId/end`

End an active transit trip.

**Path params**

| Param | Type |
|-------|------|
| `tripId` | `string` |

**Request** — no body  
**Response `200`** — `TransitTripModel` with final `elapsed_seconds`, `xp_earned`, and `fare`.

---

## 13. Config

> No `Authorization` header required.

---

### `GET /config`

Fetch full remote app configuration. Called on every app launch.

**Response `200`**
```json
{
  "data": {
    "features": {
      "ride":          true,
      "transit":       true,
      "wallet":        true,
      "social":        true,
      "groups":        true,
      "subscriptions": true,
      "support":       true,
      "activity":      true,
      "trips":         true,
      "profile":       true
    },
    "transport": {
      "locations": [
        {
          "id": "loc_001",
          "name": "IIT Hyderabad",
          "active": true,
          "vehicles": [
            {
              "mode": "bike",
              "payment_model": "subscription_included",
              "enabled": true
            },
            {
              "mode": "ebike",
              "payment_model": "both",
              "enabled": true
            }
          ]
        }
      ]
    },
    "settings": {
      "coin_conversion_rate": 1.0,
      "max_ride_duration_min": 120,
      "support_email": "support@mjollnir.app"
    }
  }
}
```

| Feature flag field | Type | Notes |
|-------------------|------|-------|
| `ride` … `profile` | `boolean` | `false` = feature hidden in-app; no re-deploy needed |

| `vehicles[].payment_model` | Meaning |
|---------------------------|---------|
| `subscription_included` | Free for subscribers |
| `pay_as_you_go` | Always charged per use |
| `both` | Subscribers ride free; others pay per use |

---

### `GET /config/locations/:locationId`

Per-location configuration (vehicles, payment models).

**Path params**

| Param | Type | Example |
|-------|------|---------|
| `locationId` | `string` | `"loc_001"` |

**Response `200`**
```json
{
  "data": {
    "id": "loc_001",
    "name": "IIT Hyderabad",
    "active": true,
    "vehicles": [ ... ]
  }
}
```

---

## Error Reference

| Error class | When thrown |
|-------------|-------------|
| `NetworkError` | Any HTTP failure, timeout, or no-internet |
| `NetworkError` code `"401"` | Unauthenticated (after refresh also fails) |
| `NetworkError` code `"403"` | Access forbidden |
| `NetworkError` code `"404"` | Resource not found |
| `NetworkError` code `"5xx"` | Server error |
| `ValidationError` | `400` / `422` with `errors` map |
| `AuthenticationError` | Login credential failure |
| `AuthorizationError` | Permission denied |
| `FileError` | Multipart upload failure |
| `GenericError` | Unexpected / parse errors |

All errors extend `AppError` and expose `.message` (user-facing string), `.code` (machine code), and `.originalError` (raw cause for logging).

---

## Changelog

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-03-19 | Initial contract — generated from live `dart` models and repository implementations |
