# Mjollnir App — Feature-Level Documentation

> Deep-dive reference for every feature module: screens, state, data models, API endpoints, and notable behaviours.

---

## Table of Contents

1. [Auth](#1-auth)
2. [Home](#2-home)
3. [Ride](#3-ride)
4. [Trips](#4-trips)
5. [Wallet](#5-wallet)
6. [Profile](#6-profile)
7. [Social](#7-social)
8. [Groups](#8-groups)
9. [Activity](#9-activity)
10. [Subscription](#10-subscription)
11. [Transit](#11-transit)
12. [Support](#12-support)

---

## 1. Auth

**Folder:** `lib/features/auth/`  
**Purpose:** Phone-number OTP login, 3-step registration, and account deletion with OTP confirmation.

### Screens

| Screen | Route | Description |
|---|---|---|
| `SplashScreen` | `/splash` | Animated logo (fade + scale, 2.8 s); auto-redirects to `/home` or `/auth/login` based on stored token |
| `LoginScreen` | `/auth/login` | Phone number input; validates format; calls `sendOtp()` |
| `OtpScreen` | `/auth/otp` | 6-digit PIN entry; 30 s resend timer; progress strip; masked phone display (`+91 ××××1234`) |
| `RegistrationScreen` | `/auth/register` | 3-step form for new users (see steps below) |
| `DeleteAccountOtpScreen` | `/auth/account/delete-verify` | 6-digit OTP to confirm account deletion |

**Registration steps:**

| Step | Fields |
|---|---|
| 1 | First name, last name, date of birth, gender, profile photo (optional) |
| 2 | Email, height, weight (metric/imperial toggle), user type (University / Corporate / General), organisation, campus/employee ID |
| 3 | Street address, city, state, pincode, country |

### State

**`AuthFormState`** — local form state for login/OTP screens

| Field | Type | Description |
|---|---|---|
| `phone` | `String` | Entered phone number |
| `isLoading` | `bool` | Waiting for API response |
| `error` | `String?` | Current error message |
| `otpSent` | `bool` | Whether OTP has been dispatched |

**`AuthState`** — global auth status read by the router

| Field | Type | Description |
|---|---|---|
| `status` | `AuthStatus` | `unknown` / `authenticated` / `unauthenticated` |
| `token` | `String?` | JWT access token |
| `registrationComplete` | `bool` | Whether the user has completed registration |

**`AuthStateNotifier` methods**

| Method | Action |
|---|---|
| `setAuthenticated(token)` | Saves token to `FlutterSecureStorage`, sets status → `authenticated` |
| `logout()` | Clears all tokens and prefs → router redirects to `/auth/login` |
| `checkAuthStatus()` | Reads cached token; used on cold start |

### Data Model

**`AuthUserModel`**

| Field | Type |
|---|---|
| `id` | `String` |
| `userNumber` | `String` — `MJL-XXXXXXXX` |
| `phone` | `String` |
| `email` | `String?` |
| `firstName` | `String` |
| `lastName` | `String` |
| `userType` | `String` — `University` / `Corporate` / `General` |
| `organisation` | `String?` |
| `registrationComplete` | `bool` |

### API Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| `POST` | `/auth/otp/send` | `{ phone }` | `{ request_id }` |
| `POST` | `/auth/otp/verify` | `{ phone, otp }` | `{ token, refresh_token, user }` |
| `POST` | `/auth/register` | full user object | `{ user }` |
| `POST` | `/auth/refresh` | `{ refresh_token }` | `{ token, refresh_token }` |
| `DELETE` | `/auth/account` | `{ otp }` | `204` |

### Notable Behaviours

- On OTP resend, all 6 boxes are cleared and the 30 s timer restarts.
- On 3 failed OTP attempts the error state persists; user must request a new OTP.
- Auto-refresh: `ApiClient` interceptor silently retries with a new token on `401`; if refresh also fails, `logout()` is called.
- `MJL-XXXXXXXX` user ID is generated on first launch and persisted in `SharedPreferences` regardless of auth state.

---

## 2. Home

**Folder:** `lib/features/home/`  
**Purpose:** Map view of nearby bike stations; entry point for starting a shared ride.

### Screens

| Screen | Route | Description |
|---|---|---|
| `HomeScreen` | `/home` | Google Map + station list |

**HomeScreen UI elements:**

| Element | Behaviour |
|---|---|
| Google Map | Dark style in dark theme; station markers from API |
| Map type switcher | Normal / Terrain / Satellite / Hybrid |
| Search bar | Filters displayed stations by name |
| Re-centre button | Jumps camera to user's current GPS position |
| Station list | Sorted by distance; max 10 shown; pull-to-refresh |
| Station detail panel | Slides up on marker/row tap; shows availability + "Start Ride" button |

### State

**`HomeState`**

| Field | Type |
|---|---|
| `stations` | `List<StationModel>` |
| `selectedStation` | `StationModel?` |
| `isLoading` | `bool` |
| `error` | `String?` |

**`HomeNotifier` methods**

| Method | Action |
|---|---|
| `loadStations(lat, lng)` | `GET /stations/nearby?lat=X&lng=Y`; sorts by distance |
| `selectStation(station)` | Updates `selectedStation` for detail panel |
| `clearSelection()` | Closes detail panel |

### Data Model

**`StationModel`**

| Field | Type |
|---|---|
| `id` | `String` |
| `name` | `String` |
| `distanceMetres` | `double` |
| `walkMinutes` | `int` |
| `bikesAvailable` | `int` |
| `ebikesAvailable` | `int` |
| `availableDocks` | `int` |
| `lat` | `double` |
| `lng` | `double` |

### API Endpoints

| Method | Path | Params | Response |
|---|---|---|---|
| `GET` | `/stations/nearby` | `?lat&lng` | `{ stations[] }` |

---

## 3. Ride

**Folder:** `lib/features/ride/`  
**Purpose:** QR scanning to unlock shared bikes; real-time GPS ride tracking; own-bike recording; fare calculation; ride summary.

### Screens

| Screen | Route | Description |
|---|---|---|
| `QrScannerScreen` | `/bikes` | Camera QR scan or "Record Ride" mode toggle |
| `RideScreen` | `/ride` | Live ride: GPS map, stats, pause/resume/end |
| `RideSummaryScreen` | `/ride/summary` | Post-ride stats, route replay, fare breakdown, eco impact |

**QrScannerScreen tabs:**

| Tab | Behaviour |
|---|---|
| Scan Bike | Live camera with animated scan line + corner brackets; flash toggle; detects active ride → redirects to `/ride` to prevent duplicate start |
| Record Ride | Starts own-bike recording immediately (no QR needed) |
| History | Recent rides shortlist |

**RideScreen panels:**

| Panel | Contents |
|---|---|
| Top bar | Elapsed time MM:SS, current speed, distance, max speed |
| Map | Google Map, current position dot, polyline route |
| Bottom sheet | Bike model (MJ-042), battery %; stats grid; Pause / Resume / End Ride buttons |

**RideSummaryScreen sections:**

| Section | Contents |
|---|---|
| Hero header | Total time + distance + celebration animation |
| Route map | Replay of full GPS polyline |
| Stats grid (2×3) | Duration, distance, avg speed, max speed, calories, elevation |
| Eco card | CO₂ saved, trees planted equivalent |
| Fare breakdown | Base fare, extra charges, GST (18%), total, coins earned |
| Actions | Share, save, go home |

### State

**`RideStatus` enum**

```
idle → starting → active → paused → ending → ended / error
```

**`RideState`**

| Field | Type |
|---|---|
| `status` | `RideStatus` |
| `ride` | `RideModel?` |
| `error` | `String?` |

**`RideNotifier` methods**

| Method | API call | Notes |
|---|---|---|
| `startRide(bikeId, rideMode, isEBike)` | `POST /rides/start` | Persists ride params to `LocalStorage` for crash recovery |
| `updateLocalMetrics(distance, speed, calories, elevation, lat, lng)` | None | Updates in-memory state only |
| `pauseRide()` | None | Freezes timer; speed = 0 |
| `resumeRide()` | None | Restarts timer |
| `endRide()` | `POST /rides/:id/end` | Navigates to `/ride/summary` |
| `sendLocationUpdate(lat, lng)` | `POST /rides/:id/location` | Called every ~1 s from Geolocator stream |

### Data Model

**`RideModel`**

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | Server-assigned |
| `rideMode` | `int` | `0` = shared, `1` = own bike |
| `isEBike` | `bool` | |
| `seconds` | `int` | Elapsed seconds |
| `distance` | `double` | km |
| `currentSpeed` | `double` | km/h |
| `maxSpeed` | `double` | km/h |
| `calories` | `double` | |
| `elevation` | `double` | metres gained |
| `lat` | `double` | Current position |
| `lng` | `double` | Current position |
| `routePoints` | `List<LatLng>` | Full GPS polyline |
| `bikeId` | `String?` | null for own-bike |
| `batteryPct` | `int?` | null for own-bike |
| `paidWithCoin` | `bool` | |

### Fare Calculation (`RidePricing`)

Applies to **shared-bike rides only** (`rideMode == 0`).

| Duration | Charge |
|---|---|
| 0 – 10 min | ₹50 flat (early cancellation) |
| 0 – 60 min | ₹100 base |
| 60 – 65 min | Free buffer |
| 65 – 90 min | +₹50 (50% of base) |
| 90 – 95 min | Free buffer |
| 95 – 120 min | +₹100 (100% of base) |
| > 120 min | Pattern repeats every 60 min block |
| All fares | +18% GST |

`RidePricing.calculate(durationSeconds)` returns a `RideBill` with itemised line items.

### API Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| `PUT` | `/rides/start` | `{ bike_id, ride_mode, is_ebike }` | `{ ride }` |
| `POST` | `/rides/:id/end` | `{}` | `{ ride, fare }` |
| `POST` | `/rides/:id/location` | `{ lat, lng }` | `204` |

### Notable Behaviours

- Ride state is persisted to `LocalStorage` on every update; survives app kill/restart — user is returned to the active ride screen on relaunch.
- Own-bike rides (`rideMode = 1`) show no fare breakdown in the summary.
- If a QR scan is triggered while a ride is already active, the scanner redirects to `/ride` instead of starting a new one.

---

## 4. Trips

**Folder:** `lib/features/trips/`  
**Purpose:** Paginated history of all completed rides; per-trip detail identical to the ride summary.

### Screens

| Screen | Route | Description |
|---|---|---|
| `TripsScreen` | `/trips` | Filterable / sortable list of past rides |
| `TripDetailScreen` | `/trips/detail` | Full summary: route map, stats, fare, eco impact |

**TripsScreen filters:**

| Filter | Options |
|---|---|
| Date range | Any / This week / This month / Custom |
| Ride type | All / Shared / Own bike |
| Sort by | Date (newest) / Distance / Duration |

### State

**`TripsState`**

| Field | Type |
|---|---|
| `trips` | `List<TripModel>` |
| `selectedTrip` | `TripModel?` |
| `isLoading` | `bool` |
| `error` | `String?` |
| `currentPage` | `int` |
| `hasMore` | `bool` |

**`TripsNotifier` methods**

| Method | Action |
|---|---|
| `loadTrips()` | Fetches page 1; replaces list |
| `loadMore()` | Appends next page (infinite scroll) |
| `selectTrip(trip)` | Sets `selectedTrip` for detail view |

### Data Model

**`TripModel`** — superset of `RideModel` with post-ride fields

| Extra field | Type | Notes |
|---|---|---|
| `endTime` | `DateTime` | |
| `fare` | `double?` | null for own-bike trips |
| `coinEarned` | `int` | |
| `co2Saved` | `double` | kg |
| `routePoints` | `List<LatLng>` | Stored polyline for map replay |

### API Endpoints

| Method | Path | Params | Response |
|---|---|---|---|
| `GET` | `/trips` | `?page&type&from&to` | `{ trips[], hasMore }` |
| `GET` | `/trips/:id` | — | `{ trip }` |

---

## 5. Wallet

**Folder:** `lib/features/wallet/`  
**Purpose:** Rupee balance management and Mjollnir loyalty coin ledger.

### Screens

| Screen | Route | Description |
|---|---|---|
| `WalletScreen` | `/wallet` | Balance cards, transaction history, add money, redeem coins |

**WalletScreen sections:**

| Section | Contents |
|---|---|
| Balance card | Rupee balance + coin count |
| Transaction list | Chronological; type icon (top-up / ride debit / coin redemption) |
| Add Money | Payment gateway bottom sheet |
| Redeem Coins | Converts coins → rupees at `AppSettings.coinConversionRate` |

### State

**`WalletState`**

| Field | Type |
|---|---|
| `balance` | `double` — rupees |
| `coins` | `int` |
| `transactions` | `List<WalletTransaction>` |
| `isLoading` | `bool` |
| `error` | `String?` |

**`WalletNotifier` methods**

| Method | Action |
|---|---|
| `loadWallet()` | `GET /wallet`; caches balance in `LocalStorage` on success |
| `addMoney(amount)` | `POST /wallet/topup` |
| `redeemCoins(coins)` | `POST /wallet/redeem` |

### Data Model

**`WalletTransaction`**

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | |
| `type` | `String` | `topup` / `ride` / `redeem` |
| `amount` | `double` | positive = credit, negative = debit |
| `date` | `DateTime` | |
| `reference` | `String?` | ride ID or payment ref |

### API Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| `GET` | `/wallet` | — | `{ balance, coins, transactions[] }` |
| `POST` | `/wallet/topup` | `{ amount }` | `{ balance }` |
| `POST` | `/wallet/redeem` | `{ coins }` | `{ balance, coins }` |

### Notable Behaviours

- Balance is cached in `LocalStorage`; displayed immediately on screen open while the network call is in flight.
- `coinConversionRate` is fetched from remote config (`GET /config`); applied at runtime so the conversion ratio can be changed server-side.

---

## 6. Profile

**Folder:** `lib/features/profile/`  
**Purpose:** User profile view and edit; rating display; achievements; settings (logout, delete account).

### Screens

| Screen | Route | Description |
|---|---|---|
| `ProfileScreen` | `/profile` | View-only profile with navigation to sub-sections |
| `EditProfileScreen` | `/profile/edit` | Editable form (all personal fields) |
| `AchievementsScreen` | `/achievements` | Badges, milestones, level/tier progress |

**ProfileScreen sections:**

| Section | Contents |
|---|---|
| Avatar + header | Profile photo, name, user number, phone |
| Rating | Peer rating (0–5 ★); sub-ratings: punctuality, safety, friendliness |
| Bio + location | Free-text bio, city |
| Quick links | Trips, Wallet, Subscriptions, Support |
| Settings | Logout, Delete Account |

**EditProfileScreen fields:**

| Field | Notes |
|---|---|
| First / last name | |
| Email | |
| Date of birth | Date picker |
| Gender | Dropdown |
| Height / Weight | Metric ↔ imperial toggle |
| Bio | Multi-line, max 200 chars |
| City | |
| Saved locations | Up to 3 named locations (Home, Work, Other) |
| Profile photo | `image_picker` → `POST /profile/image` |

### State

**`ProfileState`**

| Field | Type |
|---|---|
| `user` | `ProfileModel?` |
| `isLoading` | `bool` |
| `isSaving` | `bool` |
| `error` | `String?` |

**`ProfileNotifier` methods**

| Method | Action |
|---|---|
| `loadProfile()` | `GET /profile`; caches in `LocalStorage` |
| `updateProfile(data)` | `PUT /profile` |
| `uploadPhoto(file)` | `POST /profile/image` (multipart) |

### Data Models

**`ProfileModel`**

| Field | Type |
|---|---|
| `id` | `String` |
| `userNumber` | `String` — `MJL-XXXXXXXX` |
| `firstName`, `lastName` | `String` |
| `phone` | `String` |
| `email` | `String?` |
| `bio` | `String?` |
| `avatarUrl` | `String?` |
| `city` | `String?` |
| `rating` | `double` — 0–5 |
| `punctualityRating` | `double` |
| `safetyRating` | `double` |
| `friendlinessRating` | `double` |
| `totalRides` | `int` |
| `totalDistance` | `double` |
| `level` | `int` |
| `tier` | `String` |

**`AchievementModel`**

| Field | Type |
|---|---|
| `id` | `String` |
| `title` | `String` |
| `description` | `String` |
| `iconUrl` | `String` |
| `earnedAt` | `DateTime?` — null if not yet earned |
| `progress` | `double` — 0.0–1.0 |

### API Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| `GET` | `/profile` | — | `{ user }` |
| `PUT` | `/profile` | user fields | `{ user }` |
| `POST` | `/profile/image` | multipart `image` | `{ url }` |
| `GET` | `/profile/achievements` | — | `{ achievements[] }` |

---

## 7. Social

**Folder:** `lib/features/social/`  
**Purpose:** Friends list, friend discovery, leaderboard, and visiting another user's public profile.

### Screens

| Screen | Route | Description |
|---|---|---|
| `FriendsScreen` | `/community` | Friends list + suggested users |
| `LeaderboardScreen` | `/leaderboard` | Global / friends / campus ranking |
| `UserProfileScreen` | `/user-profile` | Read-only view of another user's profile |

**FriendsScreen:**

| Section | Contents |
|---|---|
| Friends list | Avatar, name, last ride date; tap → `UserProfileScreen` |
| Suggested friends | Based on same campus/organisation; Add button |

**LeaderboardScreen:**

| Control | Options |
|---|---|
| Scope tabs | Global / Friends / Campus |
| Metric toggle | Distance / Rides / Time |
| My rank | Highlighted row with sticky positioning |

**UserProfileScreen:**

| Section | Contents |
|---|---|
| Header | Avatar, name, user number |
| Stats | Total rides, distance, coins, achievements count |
| Follow / Unfollow | Optimistic UI update; background API call |
| Recent rides | Last 3 ride cards |

### State

**`SocialState`**

| Field | Type |
|---|---|
| `friends` | `List<SocialUserModel>` |
| `suggestions` | `List<SocialUserModel>` |
| `leaderboard` | `List<LeaderboardEntry>` |
| `selectedUser` | `SocialUserModel?` |
| `isLoading` | `bool` |
| `error` | `String?` |

**`SocialNotifier` methods**

| Method | Action | Update strategy |
|---|---|---|
| `loadFriends()` | `GET /social/friends` | Replace list |
| `loadSuggestions()` | `GET /social/suggestions` | Replace list |
| `loadLeaderboard(scope, metric)` | `GET /leaderboard` | Replace list |
| `followUser(userId)` | `POST /social/follow` | Optimistic; rollback on error |
| `unfollowUser(userId)` | `DELETE /social/follow/:id` | Optimistic; rollback on error |

### Data Models

**`SocialUserModel`**

| Field | Type |
|---|---|
| `id` | `String` |
| `userNumber` | `String` |
| `displayName` | `String` |
| `avatarUrl` | `String?` |
| `isFollowing` | `bool` |
| `totalRides` | `int` |
| `totalDistance` | `double` |
| `organisation` | `String?` |

**`LeaderboardEntry`**

| Field | Type |
|---|---|
| `rank` | `int` |
| `userId` | `String` |
| `displayName` | `String` |
| `avatarUrl` | `String?` |
| `value` | `double` — metric value (km / rides / hours) |
| `isMe` | `bool` |

### API Endpoints

| Method | Path | Params / Body | Response |
|---|---|---|---|
| `GET` | `/social/friends` | — | `{ friends[] }` |
| `GET` | `/social/suggestions` | — | `{ suggestions[] }` |
| `GET` | `/leaderboard` | `?scope&metric` | `{ entries[], myRank }` |
| `GET` | `/social/users/:id` | — | `{ user }` |
| `POST` | `/social/follow` | `{ userId }` | `204` |
| `DELETE` | `/social/follow/:id` | — | `204` |

---

## 8. Groups

**Folder:** `lib/features/groups/`  
**Purpose:** Campus / organisation groups with shared stats, member management, and admin controls.

### Screens

| Screen | Route | Description |
|---|---|---|
| `GroupsScreen` | `/groups` | My groups + discover groups |
| `GroupDetailScreen` | `/groups/detail` | Group feed, members, stats, join/leave |
| `CreateGroupScreen` | `/groups/create` | Form to create a new group |

**GroupsScreen:**

| Tab | Contents |
|---|---|
| My Groups | Groups the user has joined; category-coloured badges |
| Discover | All campus/org groups; searchable |

**GroupDetailScreen tabs:**

| Tab | Contents |
|---|---|
| Feed | Activity events from group members |
| Members | Member list with roles (Admin / Member) |
| Stats | Total rides, total distance, top rider |

**Admin controls** (visible to group creator):

| Control | Action |
|---|---|
| Privacy toggle | Public ↔ Private |
| Delete group | Requires confirmation dialog |

**CreateGroupScreen fields:**

| Field | Notes |
|---|---|
| Group name | Required |
| Description | Optional, multi-line |
| Category | Picker: Cycling / Running / Commute / Campus / Corporate / Other |
| Privacy | Public / Private toggle |
| Cover image | Optional, image picker |

### State

**`GroupsState`**

| Field | Type |
|---|---|
| `myGroups` | `List<GroupModel>` |
| `discoverGroups` | `List<GroupModel>` |
| `selectedGroup` | `GroupModel?` |
| `isLoading` | `bool` |
| `error` | `String?` |

**`GroupsNotifier` methods**

| Method | Action | Update strategy |
|---|---|---|
| `loadGroups()` | Fetches both my + discover lists | Replace |
| `joinGroup(groupId)` | `POST /groups/:id/join` | Optimistic |
| `leaveGroup(groupId)` | `DELETE /groups/:id/members/me` | Optimistic |
| `createGroup(data)` | `POST /groups` | Prepends to `myGroups` |
| `deleteGroup(groupId)` | `DELETE /groups/:id` | Removes from `myGroups` |

### Data Model

**`GroupModel`**

| Field | Type |
|---|---|
| `id` | `String` |
| `name` | `String` |
| `description` | `String?` |
| `category` | `String` |
| `coverUrl` | `String?` |
| `memberCount` | `int` |
| `totalRides` | `int` |
| `totalDistance` | `double` |
| `isJoined` | `bool` |
| `isAdmin` | `bool` |
| `privacy` | `String` — `public` / `private` |
| `organisation` | `String?` |

### API Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| `GET` | `/groups/mine` | — | `{ groups[] }` |
| `GET` | `/groups/discover` | `?search` | `{ groups[] }` |
| `GET` | `/groups/:id` | — | `{ group, members[], feed[] }` |
| `POST` | `/groups` | group fields | `{ group }` |
| `DELETE` | `/groups/:id` | — | `204` |
| `POST` | `/groups/:id/join` | — | `204` |
| `DELETE` | `/groups/:id/members/me` | — | `204` |

---

## 9. Activity

**Folder:** `lib/features/activity/`  
**Purpose:** Personal riding analytics (charts + stats) with time period selection, and a social activity feed.

### Screens

| Screen | Route | Description |
|---|---|---|
| `ActivityScreen` | `/activity` | Stats charts + social feed |

**ActivityScreen layout:**

| Section | Contents |
|---|---|
| Period selector | Week / Month / 3 Months / Year / Custom date picker |
| Line chart | One of 6 metrics plotted over selected period |
| Metric tabs | Trips / Distance / Duration / Calories / CO₂ / Speed |
| Stats grid | 6 summary cards with category-coloured pills |
| Social feed | Chronological friend events (see below) |

**Feed event types:**

| Type | Description |
|---|---|
| `ride_completed` | Friend finished a ride — shows distance, route preview |
| `achievement_unlocked` | Friend earned a badge |
| `joined_group` | Friend joined a group |
| `challenge_created` | New challenge posted |
| `challenge_completed` | Friend completed a challenge |

### State

**`ActivityState`**

| Field | Type |
|---|---|
| `summary` | `ActivitySummary?` |
| `feed` | `List<ActivityFeedEvent>` |
| `selectedPeriod` | `String` — `week` / `month` / `3m` / `year` |
| `isLoading` | `bool` |
| `error` | `String?` |

**`ActivityNotifier` methods**

| Method | Action |
|---|---|
| `setPeriod(period)` | Updates `selectedPeriod`; re-fetches summary |
| `loadFeed(page)` | `GET /activity/feed?page=N`; appends for infinite scroll |

### Data Models

**`ActivitySummary`**

| Field | Type |
|---|---|
| `totalTrips` | `int` |
| `totalDistance` | `double` — km |
| `totalDurationMin` | `int` |
| `totalCalories` | `double` |
| `totalCo2` | `double` — kg saved |
| `avgSpeed` | `double` — km/h |
| `weeklyData` | `Map<String, double>` — date → value |
| `monthlyData` | `Map<String, double>` |

**`ActivityFeedEvent`**

| Field | Type |
|---|---|
| `id` | `String` |
| `type` | `String` — event type (see above) |
| `title` | `String` |
| `description` | `String` |
| `timestamp` | `DateTime` |
| `distance` | `double?` |
| `durationMin` | `int?` |
| `calories` | `double?` |
| `coinsEarned` | `int?` |
| `iconUrl` | `String?` |

### API Endpoints

| Method | Path | Params | Response |
|---|---|---|---|
| `GET` | `/activity/summary` | `?period` | `{ summary }` |
| `GET` | `/activity/feed` | `?page` | `{ events[], hasMore }` |

---

## 10. Subscription

**Folder:** `lib/features/subscription/`  
**Purpose:** Plan discovery, purchase, institution ID verification, and subscription management.

### Screens

| Screen | Route | Description |
|---|---|---|
| `SubscriptionScreen` | `/subscriptions` | Plan browsing, purchase, manage active subscription |

**SubscriptionScreen layout:**

| Element | Behaviour |
|---|---|
| User type banner | Detected from `LocalStorage`: Student / Employee / General User |
| Location filter | Filters plans to campus/org from stored `organisation` |
| Category tabs | Campus / Corporate / Public / Top-up |
| Plan cards | Name, price, duration, included modes, "Popular" badge |
| Active subscription | Displayed at top if present; "Cancel" action |
| Institution ID modal | Appears for plans that require employee/student ID verification |

### State

**`SubscriptionState`**

| Field | Type |
|---|---|
| `plans` | `List<SubscriptionPlan>` |
| `activeSub` | `UserSubscription?` |
| `isLoading` | `bool` |
| `isVerifying` | `bool` |
| `error` | `String?` |

**`SubscriptionNotifier` methods**

| Method | Action |
|---|---|
| `loadPlans(locationName?)` | `GET /subscriptions/plans` |
| `getActiveSubscription()` | `GET /subscriptions/active` |
| `subscribe(planId)` | `POST /subscriptions` → payment sheet |
| `cancelSubscription(subscriptionId)` | `DELETE /subscriptions/:id` |
| `verifyInstitutionId(org, institutionId)` | `POST /subscriptions/verify-institution` |

### Data Models

**`SubscriptionPlan`**

| Field | Type |
|---|---|
| `id` | `String` |
| `name` | `String` |
| `price` | `String` — display string e.g. `"₹299/month"` |
| `priceValue` | `double` |
| `duration` | `String` — display e.g. `"1 Month"` |
| `durationDays` | `int` |
| `coins` | `int` — bonus coins on activation |
| `features` | `List<String>` |
| `category` | `String` — `campus` / `corporate` / `public` / `topup` |
| `locationName` | `String` — maps to `TransportRegistry` key |
| `popular` | `bool` |
| `includedModes` | `List<String>` — `bike` / `ebike` / `buggy` / `bus` |

**`UserSubscription`**

| Field | Type |
|---|---|
| `id` | `String` |
| `planName` | `String` |
| `locationName` | `String` |
| `startDate` | `DateTime` |
| `endDate` | `DateTime` |
| `isActive` | `bool` |
| `daysRemaining` | `int` — computed property |

### API Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| `GET` | `/subscriptions/plans` | `?location` | `{ plans[] }` |
| `GET` | `/subscriptions/active` | — | `{ subscription? }` |
| `POST` | `/subscriptions` | `{ planId }` | `{ subscription }` |
| `DELETE` | `/subscriptions/:id` | — | `204` |
| `POST` | `/subscriptions/verify-institution` | `{ org, institutionId }` | `{ verified }` |

### Notable Behaviours

- Plans are grouped by `locationName` using `TransportRegistry.forLocation()` to show only vehicles available at the user's campus.
- Institution ID verification is required for campus and corporate plans; the modal blocks purchase until verification succeeds.
- 31+ pre-seeded locations in the mock repository spanning IITs, NITs, BITS Pilani, IT parks, and public trail routes.

---

## 11. Transit

**Folder:** `lib/features/transit/`  
**Purpose:** Real-time campus shuttle / bus board; board a vehicle; track an active transit trip.

### Screens

| Screen | Route | Description |
|---|---|---|
| `TransitScreen` | `/transit` | Nearby stops list (buses and buggies) |
| `TransitBoardScreen` | `/transit/board` | QR scan to board a vehicle |
| `TransitActiveTripScreen` | `/transit/active` | Live in-progress transit trip |

**TransitScreen:**

| Element | Behaviour |
|---|---|
| Type tabs | Buggy / Bus; animated tab indicator with type colour (#FF8F00 for bus, primary for buggy) |
| Search | Filters stops by name or route |
| Active trip card | Shown at top when a trip is in progress; taps → `/transit/active` |
| Stop rows | Route, ETA, capacity bar, distance |

**TransitBoardScreen:**

| Element | Behaviour |
|---|---|
| QR overlay | Animated scan line + corner bracket corners; grid background |
| Flash toggle | Camera torch on/off |
| Boarded sheet | Slides up after successful scan; shows vehicle name, type, route |

**TransitActiveTripScreen:**

| Section | Contents |
|---|---|
| Timer card | Elapsed time MM:SS |
| Stats | Boarded at (time), XP earned |
| Vehicle info | Name, number, type, "On Board" badge |
| Payment card | Shows ₹0 if subscription covers this mode |
| End Trip button | Calls `endTrip()` → navigates to `/home` |

### State

Transit uses **no dedicated Riverpod provider**. Active trip state is persisted directly via `LocalStorage` and re-read on screen init.

### Data Models

**`TransitStopModel`**

| Field | Type |
|---|---|
| `id` | `String` |
| `name` | `String` |
| `route` | `String` |
| `routeShort` | `String` |
| `eta` | `int` — minutes |
| `capacityOccupied` | `int` |
| `capacityTotal` | `int` |
| `nextEtas` | `List<int>` — next 3 ETAs in minutes |
| `type` | `String` — `bus` / `buggy` |
| `distance` | `double` — km |
| `vehicleName` | `String` |
| `vehicleNumber` | `String` |
| `vehicleImageUrl` | `String?` |
| `lat` | `double` |
| `lng` | `double` |

**`TransitTripModel`**

| Field | Type |
|---|---|
| `id` | `String` |
| `stopName` | `String` |
| `type` | `String` — `bus` / `buggy` |
| `route` | `String` |
| `vehicleName` | `String` |
| `vehicleNumber` | `String` |
| `vehicleImageUrl` | `String?` |
| `startTime` | `String` — ISO 8601 |
| `endTime` | `String?` |
| `elapsedSeconds` | `int` |
| `xpEarned` | `int` |
| `fare` | `double?` |

### API Endpoints

| Method | Path | Params / Body | Response |
|---|---|---|---|
| `GET` | `/transit/stops` | `?type&search` | `{ stops[] }` |
| `POST` | `/transit/trips/board` | `{ vehicleId, stopId }` | `{ trip }` |
| `GET` | `/transit/trips/active` | — | `{ trip? }` |
| `POST` | `/transit/trips/:id/end` | — | `{ trip }` |

---

## 12. Support

**Folder:** `lib/features/support/`  
**Purpose:** Help centre with FAQ, AI-powered live chat, issue ticket submission, and email contact.

### Screens

| Screen | Route | Description |
|---|---|---|
| `SupportScreen` | `/support` | Quick actions + FAQ accordion |
| `ReportIssueScreen` | `/support/report` | Ticket submission form |
| `AiChatScreen` | `/support/chat` | AI chat with escalation to human |
| `EmailUsScreen` | `/support/email` | Contact form |

**SupportScreen:**

| Element | Contents |
|---|---|
| Quick action cards | Report Issue / Live Chat / Email Us |
| My tickets | List of open/resolved tickets |
| FAQ accordion | 3 sections: Getting Started / Payments & Subscriptions / Troubleshooting |

**ReportIssueScreen fields:**

| Field | Notes |
|---|---|
| Category | Dropdown: Bike / App Bug / Payment / Account / Other |
| Subject | Short text |
| Description | Multi-line |
| Attachments | Up to 3 photos via `image_picker` |
| Bike ID | Optional; pre-filled if coming from an active ride |

**AiChatScreen:**

| Element | Behaviour |
|---|---|
| Message thread | Bubbles (user right, AI left) |
| Typing indicator | Shown while waiting for AI response |
| Escalate button | Converts session to human-agent ticket |

**EmailUsScreen fields:** Name, email, subject, message (free-form).

### State

Only a **repository provider** is registered (no `StateNotifier`). Screens manage local state internally with `StatefulWidget`.

### Data Model

**`SupportTicket`**

| Field | Type |
|---|---|
| `id` | `String` |
| `category` | `String` |
| `subject` | `String` |
| `description` | `String` |
| `status` | `String` — `open` / `in_progress` / `resolved` / `closed` |
| `createdAt` | `DateTime` |

### API Endpoints

| Method | Path | Body | Response |
|---|---|---|---|
| `POST` | `/support/tickets` | ticket fields | `{ ticket }` |
| `GET` | `/support/tickets` | — | `{ tickets[] }` |
| `POST` | `/support/chat` | `{ message }` | `{ reply }` |
| `POST` | `/support/contact` | `{ name, email, subject, message }` | `204` |

---

*See also:*  
- [app_flow.md](app_flow.md) — user journey diagrams for every feature  
- [api_contract.md](api_contract.md) — full request/response schemas  
- [api_flow.md](api_flow.md) — API sequence diagrams  
- [developer_guide.md](developer_guide.md) — conventions and adding a new feature
