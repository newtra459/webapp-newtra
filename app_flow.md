# Mjollnir App — App Flow Documentation

> Screen-by-screen user journeys, navigation trees, and state transitions.  
> All diagrams use [Mermaid](https://mermaid.js.org/) syntax.  
> Render in VS Code with the **Markdown Preview Mermaid Support** extension,  
> or paste into [mermaid.live](https://mermaid.live).

---

## Table of Contents

1. [High-Level Navigation Map](#1-high-level-navigation-map)
2. [App Startup & Auth Guard](#2-app-startup--auth-guard)
3. [Authentication Flow](#3-authentication-flow)
4. [Main Shell Navigation](#4-main-shell-navigation)
5. [Home & Station Flow](#5-home--station-flow)
6. [Ride Flow (Shared Bike)](#6-ride-flow-shared-bike)
7. [Ride Flow (Own Bike — Record Mode)](#7-ride-flow-own-bike--record-mode)
8. [Ride Pricing Logic](#8-ride-pricing-logic)
9. [Trips & History Flow](#9-trips--history-flow)
10. [Wallet Flow](#10-wallet-flow)
11. [Profile & Account Flow](#11-profile--account-flow)
12. [Social & Community Flow](#12-social--community-flow)
13. [Groups Flow](#13-groups-flow)
14. [Activity Feed Flow](#14-activity-feed-flow)
15. [Subscription Flow](#15-subscription-flow)
16. [Transit Flow](#16-transit-flow)
17. [Support Flow](#17-support-flow)
18. [Account Deletion Flow](#18-account-deletion-flow)
19. [Feature Flags & Remote Config](#19-feature-flags--remote-config)
20. [Screen Inventory](#20-screen-inventory)

---

## 1. High-Level Navigation Map

```mermaid
flowchart TD
    SPLASH([Splash Screen])

    subgraph AUTH["Authentication (unauthenticated only)"]
        LOGIN[Login\nphone number entry]
        OTP[OTP Verification\n6-digit code]
        REG[Registration\n3-step onboarding]
    end

    subgraph SHELL["Main Shell — Bottom Navigation Bar"]
        HOME[Home\nmap + stations]
        BIKES[QR Scanner\nbike scan / record]
        COMMUNITY[Friends / Community]
        PROFILE[Profile]
    end

    subgraph DETAIL["Detail Screens (full-screen, no bottom bar)"]
        RIDE[Active Ride]
        SUMMARY[Ride Summary]
        TRIPS[Trip History]
        TRIP_D[Trip Detail]
        WALLET[Wallet]
        SUBS[Subscriptions]
        ACHIEVE[Achievements]
        LEADERBOARD[Leaderboard]
        USER_P[User Profile]
        GROUPS[Groups]
        GROUP_D[Group Detail]
        GROUP_C[Create Group]
        ACTIVITY[Activity Feed]
        SUPPORT[Support Hub]
        REPORT[Report Issue]
        AI_CHAT[AI Chat Support]
        EMAIL[Email Us]
        TRANSIT[Transit]
        T_BOARD[Transit Board]
        T_ACTIVE[Active Transit Trip]
        EDIT_P[Edit Profile]
        DEL_OTP[Delete Account OTP]
    end

    SPLASH -->|authenticated| HOME
    SPLASH -->|unauthenticated| LOGIN
    LOGIN --> OTP --> REG --> HOME

    HOME -->|tap station Start Ride| RIDE
    BIKES -->|QR scan success| RIDE
    RIDE -->|end ride| SUMMARY
    SUMMARY -->|done| HOME

    PROFILE -->|edit| EDIT_P
    PROFILE -->|achievements| ACHIEVE
    PROFILE -->|trips| TRIPS
    PROFILE -->|wallet| WALLET
    PROFILE -->|subscriptions| SUBS
    PROFILE -->|support| SUPPORT
    PROFILE -->|delete account| DEL_OTP

    TRIPS --> TRIP_D
    SUPPORT --> REPORT
    SUPPORT --> AI_CHAT
    SUPPORT --> EMAIL

    COMMUNITY -->|leaderboard| LEADERBOARD
    COMMUNITY -->|user tap| USER_P
    COMMUNITY -->|groups| GROUPS
    COMMUNITY -->|activity| ACTIVITY

    GROUPS --> GROUP_D
    GROUPS --> GROUP_C

    HOME -->|transit tab| TRANSIT
    TRANSIT --> T_BOARD
    TRANSIT --> T_ACTIVE
```

---

## 2. App Startup & Auth Guard

```mermaid
flowchart TD
    A([App Launch]) --> B[LocalStorage.init\nload SharedPrefs + SecureStorage]
    B --> C[ensureAppUserId\ngenerate MJL-XXXXXXXX if new install]
    C --> D[ProviderScope bootstraps\nRiverpod provider tree]
    D --> E[AuthStateNotifier reads\ncached JWT token synchronously]
    E --> F{Token present?}
    F -->|Yes| G[status = authenticated]
    F -->|No| H[status = unauthenticated]
    G --> I[GoRouter redirect:\n/splash → /home]
    H --> J[GoRouter redirect:\n/splash → /auth/login]
    D --> K[AppConfigRepository.fetchConfig\nGET /config — async, parallel]
    K -->|success| L[Cache config in SharedPrefs]
    K -->|network error| M[Use cached config or compile-time defaults]
```

**Auth guard rule (applied on every navigation event):**
- `unauthenticated` + route is not `/auth/*` → redirect to `/auth/login`
- `authenticated` + route is `/auth/*` → redirect to `/home`
- All other routes → pass through

---

## 3. Authentication Flow

### 3.1 Step-by-step screen flow

```mermaid
flowchart TD
    S([Splash Screen\n2.8s animated logo]) --> CHECK{isLoggedIn?}
    CHECK -->|true| HOME([/home])
    CHECK -->|false| LOGIN

    subgraph LOGIN_STEP["Step 1 — Login"]
        LOGIN[Enter mobile number\n+91 format] --> VALIDATE{Format valid?}
        VALIDATE -->|No| LOGIN
        VALIDATE -->|Yes| SEND[POST /auth/otp/send\nreturns request_id]
        SEND --> OTP_SCR[OTP Screen]
    end

    subgraph OTP_STEP["Step 2 — OTP Verification"]
        OTP_SCR --> OTP_IN[6-digit PIN entry\nauto-advances on fill]
        OTP_IN --> OTP_TIMER[30 s resend timer]
        OTP_TIMER -->|expired| RESEND[Resend OTP\nclears boxes, restarts timer]
        OTP_IN --> VERIFY[POST /auth/otp/verify]
        VERIFY -->|401 invalid| ERR[Show error, clear boxes]
        ERR --> OTP_IN
        VERIFY -->|200 OK| SAVE[Save token + refresh_token\nto FlutterSecureStorage]
        SAVE --> REG_CHECK{registration\ncomplete?}
        REG_CHECK -->|No| REG_SCR[Registration Screen]
        REG_CHECK -->|Yes| HOME2([/home])
    end

    subgraph REG_STEP["Step 3 — Registration (new users only)"]
        REG_SCR --> STEP1["Step 1 of 3\nFirst name, last name\nDate of birth, gender\nProfile photo (optional)"]
        STEP1 --> STEP2["Step 2 of 3\nEmail, Height/Weight\nUser type: University / Corporate / General\nOrganisation, Campus ID"]
        STEP2 --> STEP3["Step 3 of 3\nStreet address, city,\nstate, pincode, country"]
        STEP3 --> SUBMIT[POST /auth/register]
        SUBMIT -->|success| FLAGS["LocalStorage:\nregistration_complete = true\nuser_type, organisation saved"]
        FLAGS --> HOME3([/home])
    end
```

### 3.2 OTP Screen detail

| Element | Behaviour |
|---|---|
| Phone display | Masked: `+91 ××××1234` |
| 6 input boxes | Auto-focus next on digit entry; backspace moves to previous |
| Progress strip | Fills proportionally as digits are entered |
| Resend button | Disabled for 30 s; on tap clears all boxes, calls `/auth/otp/send` again |
| Error state | Boxes shake + turn red; error text appears below |

---

## 4. Main Shell Navigation

The bottom navigation bar is always visible on the four root routes. It is hidden on all detail screens.

```mermaid
flowchart LR
    subgraph BAR["Bottom Navigation Bar (ShellRoute)"]
        T1["🏠 Home\n/home"]
        T2["🚲 Bikes\n/bikes"]
        T3["👥 Community\n/community"]
        T4["👤 Profile\n/profile"]
    end
```

| Tab | Route | Screen | Purpose |
|---|---|---|---|
| Home | `/home` | `HomeScreen` | Map view, station list, start ride |
| Bikes | `/bikes` | `QrScannerScreen` | Scan QR or record personal ride |
| Community | `/community` | `FriendsScreen` | Social feed, leaderboard, groups |
| Profile | `/profile` | `ProfileScreen` | Account details, settings, wallet |

---

## 5. Home & Station Flow

```mermaid
flowchart TD
    H([HomeScreen]) --> MAP[Google Map\ndark style in dark theme]
    MAP --> LOC[Geolocator: get current position]
    LOC --> FETCH[GET /stations/nearby\n?lat=X&lng=Y]
    FETCH --> MARKERS[Render station markers\non map]
    FETCH --> LIST[Station list\nsorted by distance ≤10 shown]

    MAP -->|tap marker| DETAIL[Station detail panel]
    LIST -->|tap row| DETAIL

    DETAIL --> INFO["Station info:\nName, distance, walk time\nBikes available\nE-bikes available\nFree docks"]
    INFO --> RIDE_BTN[Start Ride button]
    RIDE_BTN -->|rideMode = shared| RIDE([/ride])

    MAP --> CTRL["Map controls:\nMap type toggle\n(normal/terrain/satellite/hybrid)"]
    MAP --> SEARCH[Search bar → filter stations]
    MAP --> RECENTER[Re-center button → jump to user position]
```

**Station model fields:** `id`, `name`, `distanceMetres`, `walkMinutes`, `bikesAvailable`, `ebikesAvailable`, `availableDocks`, `lat`, `lng`

---

## 6. Ride Flow (Shared Bike)

```mermaid
flowchart TD
    START([Enter /ride\nrideMode=shared]) --> INIT[RideNotifier.startRide\nPOST /rides/start\nbike_id, ride_mode=0]
    INIT --> ACTIVE[RideScreen — active state]

    ACTIVE --> MAP2[Google Map\ncurrent position + polyline route]
    ACTIVE --> STATS["Live stats panel:\nElapsed time MM:SS\nCurrent speed km/h\nDistance km\nMax speed"]
    ACTIVE --> BOTTOM["Bottom sheet:\nBike model + battery %\nDuration / Distance / Speed\nCalories / Elevation\nPause / End Ride"]

    BOTTOM -->|Pause| PAUSED[RideStatus.paused\nTimer frozen\nSpeed = 0]
    PAUSED -->|Resume| ACTIVE

    BOTTOM -->|End Ride| CONFIRM{Confirm dialog}
    CONFIRM -->|Cancel| ACTIVE
    CONFIRM -->|End| END_API[POST /rides/:id/end]
    END_API --> SUMMARY([/ride/summary])

    ACTIVE --> BG["App goes to background:\nRide persisted in LocalStorage\nTimers survive restart"]
    BG -->|restore| ACTIVE

    ACTIVE --> LOC2[Geolocator stream\nupdates every second\nPOST /rides/:id/location]
```

### Ride state machine

```mermaid
stateDiagram-v2
    [*] --> idle
    idle --> starting : startRide()
    starting --> active : API success
    starting --> error : API failure
    active --> paused : pauseRide()
    paused --> active : resumeRide()
    active --> ending : endRide()
    ending --> ended : API success
    ending --> error : API failure
    ended --> [*]
    error --> [*]
```

---

## 7. Ride Flow (Own Bike — Record Mode)

```mermaid
flowchart TD
    QR([QrScannerScreen]) --> TAB[Select "Record Ride" tab]
    TAB --> START_REC[RideNotifier.startRide\nPOST /rides/start\nrideMode=1, bikeId=null]
    START_REC --> RIDE_SCR[RideScreen\nSame UI as shared ride]
    RIDE_SCR --> NO_BIKE["Bike info panel:\nshows 'Your Bike'\nbattery % hidden"]
    RIDE_SCR --> END2[End Ride → POST /rides/:id/end]
    END2 --> SUM2([/ride/summary\nNo fare charged for own bike])
```

**Key difference:** `rideMode = 1` — fare calculation is skipped in the summary; only stats and eco metrics are shown.

---

## 8. Ride Pricing Logic

Applies to **shared bike rides** (`rideMode = 0`) only.

```mermaid
flowchart TD
    D([Duration in seconds]) --> MINS[Convert to minutes]
    MINS --> C1{≤ 10 min?}
    C1 -->|Yes| CANCEL[Cancellation fee\n₹50 flat]
    C1 -->|No| BASE["Base charge ₹100\n(covers 0–60 min)"]
    BASE --> EXT{Extra minutes\nbeyond 60?}
    EXT -->|0–5 min buffer| FREE1[No charge\n60–65 min buffer zone]
    EXT -->|6–30 min| TIER1[+50% of base = ₹50\n65–90 min]
    TIER1 --> BUF2{90–95 min?}
    BUF2 -->|Yes| FREE2[No charge\n90–95 min buffer]
    BUF2 -->|No, 95–120 min| TIER2[+100% of base = ₹100]
    TIER2 --> REPEAT[Pattern repeats\nevery 60 min block]
    CANCEL --> GST[+18% GST]
    FREE1 --> GST
    FREE2 --> GST
    TIER1 --> GST
    TIER2 --> GST
    REPEAT --> GST
    GST --> TOTAL[Final total]
    TOTAL --> COINS[Loyalty coins earned\nbased on distance]
```

**Ride summary breakdown line items:** Base fare → Extra charges → GST → **Total** → Coins earned

---

## 9. Trips & History Flow

```mermaid
flowchart TD
    PROFILE([ProfileScreen]) -->|tap Trips| TRIPS[TripsScreen]
    TRIPS --> FILTER["Filter / sort:\nDate range\nRide type (shared/own)\nDistance"]
    TRIPS --> LIST2[Paginated list of completed rides]
    LIST2 -->|tap a ride| DETAIL2[TripDetailScreen]
    DETAIL2 --> MAP3[Route map replay]
    DETAIL2 --> STATS2["Stats: duration, distance,\navg/max speed, calories, elevation"]
    DETAIL2 --> FARE["Fare breakdown\n(shared rides only)"]
    DETAIL2 --> ECO["Eco impact:\nCO₂ saved, trees equivalent"]
    DETAIL2 --> SHARE[Share ride card]
```

---

## 10. Wallet Flow

```mermaid
flowchart TD
    PROFILE2([ProfileScreen]) -->|tap Wallet| WALLET[WalletScreen]
    WALLET --> BAL["Balance card:\nRupee balance\nMjollnir coins"]
    WALLET --> HISTORY[Transaction history\nchronological list]
    WALLET --> ADD[Add Money\npayment gateway sheet]
    WALLET --> REDEEM[Redeem Coins\nconvert coins → rupees]
    ADD -->|success| WALLET
    REDEEM -->|confirm| WALLET
    HISTORY --> TX_ITEM["Transaction item:\ntype (topup/ride/redeem)\namount, date, reference"]
```

**Coin conversion rate** is set by `AppSettings.coinConversionRate` (from remote config).

---

## 11. Profile & Account Flow

```mermaid
flowchart TD
    P([ProfileScreen]) --> VIEW["View:\nAvatar, name, phone\nBio, city\nPeer rating (0–5★)\nSub-ratings: punctuality / safety / friendliness"]
    VIEW --> EDIT_BTN[Edit button → /profile/edit]
    EDIT_BTN --> EDIT[EditProfileScreen]
    EDIT --> FORM["Fields:\nFirst/last name, email\nDOB, gender\nHeight/weight (metric/imperial toggle)\nBio, city, saved locations"]
    FORM -->|Save| API_EDIT[PUT /profile]
    API_EDIT --> VIEW

    VIEW --> ACHIEVE_BTN[Achievements → /achievements]
    ACHIEVE_BTN --> ACHIEVE2[AchievementsScreen]
    ACHIEVE2 --> BADGES["Badges earned\nMilestones\nLevel / tier progress bar"]

    VIEW --> TRIPS_BTN[Trips → /trips]
    VIEW --> WALLET_BTN[Wallet → /wallet]
    VIEW --> SUBS_BTN[Subscriptions → /subscriptions]
    VIEW --> SUPPORT_BTN[Support → /support]
    VIEW --> LOGOUT[Log Out\nclears tokens + prefs\n→ /auth/login]
    VIEW --> DELETE[Delete Account → /auth/account/delete-verify]
```

---

## 12. Social & Community Flow

```mermaid
flowchart TD
    COM([FriendsScreen — /community]) --> FRIENDS[Friends list\navatar, name, last ride]
    COM --> SUGGEST[Suggested friends\nbased on campus/org]
    FRIENDS -->|tap user| USER_P2[UserProfileScreen\n/user-profile?id=X]
    SUGGEST -->|tap user| USER_P2
    USER_P2 --> FOLLOW[Follow / Unfollow]
    USER_P2 --> STATS3["Their stats:\nTotal rides, distance, coins\nAchievements"]

    COM --> LB_BTN[Leaderboard → /leaderboard]
    LB_BTN --> LB[LeaderboardScreen]
    LB --> TABS_LB["Tabs:\nGlobal (all users)\nFriends\nCampus/Org"]
    LB --> METRIC["Metric toggle:\nDistance / Rides / Time"]
    LB --> MY_RANK[My rank highlighted]

    COM --> ACT_BTN[Activity → /activity]
    COM --> GRP_BTN[Groups → /groups]
```

---

## 13. Groups Flow

```mermaid
flowchart TD
    GRP([GroupsScreen — /groups]) --> MY_GRP[My groups list]
    GRP --> DISCOVER[Discover groups\ncampus/org filtered]
    GRP --> CREATE_BTN[Create Group → /groups/create]

    CREATE_BTN --> CREATE[CreateGroupScreen]
    CREATE --> FORM2["Fields:\nGroup name\nDescription\nRules (optional)\nPrivacy: public/private"]
    FORM2 -->|Submit| API_GRP[POST /groups]
    API_GRP --> GRP_D2

    MY_GRP -->|tap| GRP_D[GroupDetailScreen\n/groups/detail?id=X]
    DISCOVER -->|tap| GRP_D
    GRP_D --> MEMBERS[Members list\nwith roles]
    GRP_D --> GRP_STATS["Group stats:\nTotal rides, distance\nTop rider"]
    GRP_D --> JOIN_LEAVE{Member?}
    JOIN_LEAVE -->|No| JOIN[Join Group → POST /groups/:id/join]
    JOIN_LEAVE -->|Yes| LEAVE[Leave Group → DELETE /groups/:id/members/me]
    GRP_D --> GRP_D2([Updated GroupDetailScreen])
```

---

## 14. Activity Feed Flow

```mermaid
flowchart TD
    ACT([ActivityScreen — /activity]) --> FEED[Chronological feed]
    FEED --> RIDE_ACT["Ride completed\nfriend's name, distance, route preview"]
    FEED --> ACHIEVE_ACT["Achievement unlocked\nfriend earned badge"]
    FEED --> SOCIAL_ACT[Follow / joined group events]
    FEED --> CHALLENGE_ACT[Challenge posted or completed]
    FEED --> REACT[Like / Cheer reaction]
    FEED --> LOAD_MORE[Infinite scroll — paginated]
```

---

## 15. Subscription Flow

```mermaid
flowchart TD
    PROFILE3([ProfileScreen]) -->|Subscriptions| SUBS2[SubscriptionScreen — /subscriptions]
    SUBS2 --> PLANS["Plan cards:\nFree (pay-as-you-go)\nMonthly Pass\nSemester Pass"]
    PLANS --> BENEFITS["Per plan:\nIncluded ride minutes\nPrice\nAuto-renewal badge\nBenefits list"]
    PLANS -->|tap plan| PURCHASE{Already subscribed?}
    PURCHASE -->|No| PAY[Payment sheet\nstripe / UPI]
    PAY -->|success| CONFIRM2[Subscription active\nbadge on profile]
    PURCHASE -->|Yes, tap again| MANAGE["Manage:\nCancel / Change plan"]
```

**Vehicle payment model** per `RemoteVehicleConfig`: `subscriptionIncluded`, `payAsYouGo`, or `both`.

---

## 16. Transit Flow

```mermaid
flowchart TD
    HOME2([HomeScreen]) -->|transit section| TRANSIT2[TransitScreen — /transit]
    TRANSIT2 --> ROUTES[Route explorer\nbus / metro lines]
    TRANSIT2 --> STOPS[Stop search / map pins]
    STOPS -->|tap stop| BOARD[TransitBoardScreen — /transit/board]
    BOARD --> ARRIVALS["Live arrivals:\nRoute, destination\nETA, delay indicator"]
    BOARD -->|board vehicle| T_ACT[TransitActiveTripScreen — /transit/active]
    T_ACT --> LIVE_MAP[Live map — vehicle position]
    T_ACT --> NEXT_STOP[Next stop panel]
    T_ACT --> ALIGHT[Alight — end transit trip]
    ALIGHT --> HOME3([/home])
```

---

## 17. Support Flow

```mermaid
flowchart TD
    PROFILE4([ProfileScreen]) -->|Support| SUP[SupportScreen — /support]
    SUP --> FAQ[FAQ accordion]
    SUP --> TICKETS[My tickets list]
    SUP --> REPORT_BTN[Report Issue → /support/report]
    SUP --> CHAT_BTN[AI Chat → /support/chat]
    SUP --> EMAIL_BTN[Email Us → /support/email]

    REPORT_BTN --> REPORT2[ReportIssueScreen]
    REPORT2 --> REPORT_FORM["Category selector\nDescription (text)\nAttachments (photos)\nBike ID (optional)"]
    REPORT_FORM -->|Submit| API_TICKET[POST /support/tickets]
    API_TICKET --> TICKETS

    CHAT_BTN --> AI_CHAT2[AiChatScreen]
    AI_CHAT2 --> MSG[Message thread\nAI responses]
    AI_CHAT2 --> ESCALATE[Escalate to human agent]

    EMAIL_BTN --> EMAIL2[EmailUsScreen]
    EMAIL2 --> EMAIL_FORM["Name, email,\nsubject, message"]
    EMAIL_FORM -->|Send| EMAIL_API[POST /support/contact]
```

---

## 18. Account Deletion Flow

```mermaid
flowchart TD
    PROFILE5([ProfileScreen]) -->|Delete Account| SEND_OTP[POST /auth/otp/send\nphone on file]
    SEND_OTP --> DEL_OTP_SCR[DeleteAccountOtpScreen\n/auth/account/delete-verify]
    DEL_OTP_SCR --> ENTER_OTP[Enter 6-digit OTP]
    ENTER_OTP --> CONFIRM_DEL{Confirm final dialog}
    CONFIRM_DEL -->|Cancel| PROFILE5
    CONFIRM_DEL -->|Delete| API_DEL[DELETE /auth/account\nbody: { otp }]
    API_DEL -->|success| CLEAR[Clear all tokens\n+ SharedPreferences]
    CLEAR --> LOGIN2([/auth/login])
```

---

## 19. Feature Flags & Remote Config

All features can be toggled server-side via `GET /config`. The app checks flags before rendering each tab or route.

| Flag | Controls |
|---|---|
| `ride` | Start Ride button + QR scanner tab |
| `transit` | Transit tab on Home |
| `wallet` | Wallet entry on Profile |
| `social` | Community tab |
| `groups` | Groups sub-section |
| `subscriptions` | Subscriptions entry on Profile |
| `support` | Support entry on Profile |
| `activity` | Activity feed entry |
| `trips` | Trips entry on Profile |
| `profile` | Edit Profile button |

If a flag is `false`, the corresponding entry point is hidden. Deep-linking to a disabled route redirects to `/home`.

Fallback order: **remote config → SharedPrefs cache → compile-time defaults**.

---

## 20. Screen Inventory

| Screen | Route | File | Auth required |
|---|---|---|---|
| Splash | `/splash` | `splash_screen.dart` | No |
| Login | `/auth/login` | `login_screen.dart` | No |
| OTP Verification | `/auth/otp` | `otp_screen.dart` | No |
| Registration | `/auth/register` | `registration_screen.dart` | No |
| Delete Account OTP | `/auth/account/delete-verify` | `delete_account_otp_screen.dart` | Yes |
| Home | `/home` | `home_screen.dart` | Yes |
| QR Scanner / Bikes | `/bikes` | `qr_scanner_screen.dart` | Yes |
| Friends / Community | `/community` | `friends_screen.dart` | Yes |
| Profile | `/profile` | `profile_screen.dart` | Yes |
| Active Ride | `/ride` | `ride_screen.dart` | Yes |
| Ride Summary | `/ride/summary` | `ride_summary_screen.dart` | Yes |
| Edit Profile | `/profile/edit` | `edit_profile_screen.dart` | Yes |
| Achievements | `/achievements` | `achievements_screen.dart` | Yes |
| Trips | `/trips` | `trips_screen.dart` | Yes |
| Trip Detail | `/trips/detail` | `trip_detail_screen.dart` | Yes |
| Wallet | `/wallet` | `wallet_screen.dart` | Yes |
| Subscriptions | `/subscriptions` | `subscription_screen.dart` | Yes |
| Leaderboard | `/leaderboard` | `leaderboard_screen.dart` | Yes |
| User Profile | `/user-profile` | `user_profile_screen.dart` | Yes |
| Groups | `/groups` | `groups_screen.dart` | Yes |
| Group Detail | `/groups/detail` | `group_detail_screen.dart` | Yes |
| Create Group | `/groups/create` | `create_group_screen.dart` | Yes |
| Activity Feed | `/activity` | `activity_screen.dart` | Yes |
| Support Hub | `/support` | `support_screen.dart` | Yes |
| Report Issue | `/support/report` | `report_issue_screen.dart` | Yes |
| AI Chat | `/support/chat` | `ai_chat_screen.dart` | Yes |
| Email Us | `/support/email` | `email_us_screen.dart` | Yes |
| Transit | `/transit` | `transit_screen.dart` | Yes |
| Transit Board | `/transit/board` | `transit_board_screen.dart` | Yes |
| Active Transit | `/transit/active` | `transit_active_trip_screen.dart` | Yes |

---

*See also:*  
- [api_contract.md](api_contract.md) — full API request/response schemas  
- [api_flow.md](api_flow.md) — API sequence diagrams  
- [developer_guide.md](developer_guide.md) — architecture & conventions
