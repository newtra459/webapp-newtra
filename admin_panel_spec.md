# Mjollnir Admin Panel — Full Specification

> Give this document to any AI (GPT-4, Claude, Gemini, etc.) or developer to build the admin panel.
> It contains every piece of data the app reads from the backend, every entity the admin must manage, and every API endpoint the admin panel must implement.

---

## 1. What the Admin Panel Is

The Mjollnir Admin Panel is a web dashboard used by the Mjollnir operations team to:

1. **Control the live mobile app** without releasing a new app version — toggle features, tune settings, push config changes.
2. **Manage master data** — subscription plans, achievements, bikes, stations, transit routes.
3. **Manage users** — view, search, suspend, verify institution IDs.
4. **Monitor operations** — active rides, active transit trips, support tickets, wallet transactions.
5. **Publish content** — achievement definitions, subscription plan details, maintenance banners.

The mobile app calls `GET /config` on every launch and uses the returned data to show or hide entire features. The admin publishes changes once and all users see them immediately.

---

## 2. Tech Stack Recommendation

| Layer | Suggested |
|-------|-----------|
| Frontend | React + TypeScript + TailwindCSS, or Next.js |
| UI components | shadcn/ui or Ant Design |
| Charts | Recharts or Chart.js |
| Backend | Node.js / FastAPI / Django connected to the same DB as the mobile API |
| Auth | JWT with role-based access (Admin, Ops, Support, ReadOnly) |
| API format | REST — same base URL `https://api.mjollnir.app/v1` but admin endpoints under `/admin/` prefix |

---

## 3. Admin Roles

| Role | Access |
|------|--------|
| `super_admin` | Full access — all CRUD, config, user management |
| `ops` | Manage bikes, stations, transit, rides. No user deletion or config. |
| `support` | View users, manage support tickets, read-only on everything else |
| `readonly` | Dashboard + reports only |

---

## 4. Sidebar Navigation Structure

```
Dashboard               ← overview metrics
├── Users
│   ├── All Users
│   ├── Pending Verification
│   └── Suspended
├── Rides
│   ├── Active Rides
│   └── Ride History
├── Bikes
│   ├── All Bikes
│   └── Maintenance
├── Stations
├── Transit
│   ├── Vehicles
│   ├── Routes
│   └── Active Trips
├── Wallet & Billing
│   ├── Transactions
│   └── Refunds
├── Subscriptions
│   ├── Plans
│   └── Active Subscriptions
├── Achievements
├── Support Tickets
├── Groups
├── App Config          ← most important panel
│   ├── Feature Flags
│   ├── Locations
│   └── Global Settings
└── Admin Users
```

---

## 5. Dashboard Page

Show live / daily stats cards:

| Metric | Source |
|--------|--------|
| Active rides right now | `GET /admin/rides?status=active&count=true` |
| Active transit trips | `GET /admin/transit/trips?status=active&count=true` |
| Total users | `GET /admin/users?count=true` |
| New users today | `GET /admin/users?since=today&count=true` |
| Wallet transactions today | `GET /admin/wallet/transactions?since=today` |
| Open support tickets | `GET /admin/support/tickets?status=open&count=true` |
| Total rides today | `GET /admin/rides?since=today&count=true` |
| Revenue today | `GET /admin/wallet/revenue?since=today` |

Charts:
- Rides per day (last 30 days) — line chart
- New user signups per day (last 30 days) — bar chart
- Feature usage breakdown (ride vs transit vs both) — pie chart

---

## 6. App Config Panel

> This is the most critical section. The entire `GET /config` response the mobile app reads is controlled here.

### 6.1 Feature Flags

A toggle for each feature. When set to `false`, the feature tab/screen is hidden in the app for all users — no re-deploy needed.

**POST `PUT /admin/config/features`**

```json
{
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
}
```

UI: A card with 10 labeled toggles. "Save Changes" publishes immediately.

---

### 6.2 Global Settings

**`PUT /admin/config/settings`**

| Setting | Type | Default | What it controls |
|---------|------|---------|-----------------|
| `coin_conversion_rate` | `number` | `1.0` | Rupees value of one loyalty coin |
| `max_ride_duration_min` | `integer` | `120` | Auto-ends a ride after N minutes |
| `min_wallet_balance_for_ride` | `number` | `0.0` | Minimum wallet balance required to unlock a bike |
| `coins_enabled` | `boolean` | `true` | Globally enable/disable the loyalty coin system |
| `leaderboard_enabled` | `boolean` | `true` | Show/hide leaderboard across the app |
| `support_chat_mode` | `"ai" \| "human" \| "both"` | `"both"` | Which support chat option users see |
| `maintenance_message` | `string?` | `null` | Show a maintenance banner in the app. Set to `null` to clear. |

UI: A form with number inputs, toggles, a dropdown, and a text area. Show a live preview of the maintenance banner.

---

### 6.3 Locations (Campus / Zone Configuration)

Each location defines which vehicles are available and their payment model.

**Endpoints:**
- `GET /admin/config/locations` — list
- `POST /admin/config/locations` — create
- `PUT /admin/config/locations/:id` — update
- `DELETE /admin/config/locations/:id` — deactivate

**Location object:**
```json
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
    },
    {
      "mode": "bus",
      "payment_model": "subscription_included",
      "enabled": true
    },
    {
      "mode": "buggy",
      "payment_model": "pay_as_you_go",
      "enabled": true
    }
  ]
}
```

| `payment_model` value | Meaning |
|----------------------|---------|
| `subscription_included` | Free for active subscribers |
| `pay_as_you_go` | Always charged per use |
| `both` | Free for subscribers; paid for others |

UI: A list of location cards. Each card expands to show a table of vehicle modes with toggles for `enabled` and a dropdown for `payment_model`.

---

## 7. Users

### User Object (Full Admin View)
```json
{
  "id": "uuid",
  "user_number": "MJL-A1B2C3D4",
  "phone": "+919876543210",
  "first_name": "Rishwak",
  "last_name": "Sharma",
  "email": "rishwak@example.com",
  "user_type": "Student",
  "organization": "IIT Hyderabad",
  "status": "active",
  "created_at": "2026-01-15T09:00:00Z",
  "last_active": "2026-03-19T14:22:00Z",
  "total_rides": 42,
  "wallet_balance": 250.00,
  "active_subscription": "Campus Monthly",
  "profile_image_url": "https://cdn.mjollnir.app/avatars/uuid.jpg"
}
```

### Endpoints
- `GET /admin/users` — paginated list, supports filters: `user_type`, `status`, `org`, `search`
- `GET /admin/users/:id` — full user detail
- `PUT /admin/users/:id/status` — `{ "status": "active" | "suspended" }`
- `DELETE /admin/users/:id` — hard delete (requires `super_admin`)
- `GET /admin/users/:id/rides` — ride history for user
- `GET /admin/users/:id/transactions` — wallet transactions for user

### Filters on User List
- Search by name, phone, email, or `user_number`
- Filter by `user_type`: `All | General User | Student | Employee`
- Filter by `status`: `All | Active | Suspended`
- Filter by `organization`
- Sort by: `created_at | last_active | total_rides | wallet_balance`

| `user_type` | Notes |
|-------------|-------|
| `General User` | Public user |
| `Student` | Verified campus student, may get discounted plans |
| `Employee` | Campus staff |

---

## 8. Bikes

### Bike Object
```json
{
  "id": "BIKE-XY123",
  "qr_code": "BIKE-XY123",
  "type": "ebike",
  "battery_pct": 85,
  "status": "available",
  "location_id": "loc_001",
  "station_id": "stn_001",
  "last_seen_lat": 17.4577,
  "last_seen_lng": 78.2753,
  "last_seen_at": "2026-03-19T10:00:00Z",
  "total_rides": 312,
  "notes": ""
}
```

| `status` | Meaning |
|----------|---------|
| `available` | At a station, ready to use |
| `in_use` | Currently in an active ride |
| `maintenance` | Flagged for repair |
| `offline` | Not reporting GPS |

### Endpoints
- `GET /admin/bikes` — list, filters: `status`, `location_id`, `type`
- `POST /admin/bikes` — register a new bike
- `PUT /admin/bikes/:id` — update details / change status
- `DELETE /admin/bikes/:id` — decommission

### Admin Actions
- Mark bike as `maintenance` with optional notes
- Reassign bike to a different station
- View last 30 rides for a bike
- Download QR code for printing

---

## 9. Stations

### Station Object
```json
{
  "id": "stn_001",
  "name": "Main Gate Station",
  "location_id": "loc_001",
  "lat": 17.4580,
  "lng": 78.2760,
  "total_docks": 10,
  "active": true
}
```

### Endpoints
- `GET /admin/stations` — list
- `POST /admin/stations` — create
- `PUT /admin/stations/:id` — update
- `DELETE /admin/stations/:id` — deactivate

UI: A map view showing all station pins, plus a table view. Clicking a pin opens the station detail card.

---

## 10. Rides

### Active Ride Object
```json
{
  "id": "ride_abc123",
  "user_id": "uuid",
  "user_number": "MJL-A1B2C3D4",
  "user_name": "Rishwak Sharma",
  "bike_id": "BIKE-XY123",
  "started_at": "2026-03-19T09:15:00Z",
  "seconds": 840,
  "distance_km": 2.4,
  "current_lat": 17.4590,
  "current_lng": 78.2770,
  "ride_mode": 0,
  "is_ebike": true,
  "paid_with_coin": false,
  "status": "active"
}
```

### Endpoints
- `GET /admin/rides` — list, filters: `status` (`active | ended`), `user_id`, `bike_id`, `date_from`, `date_to`
- `GET /admin/rides/:id` — detail + route polyline
- `POST /admin/rides/:id/force-end` — emergency force-end a ride
- `POST /admin/rides/:id/refund` — issue a refund to the user's wallet

### Active Rides View
A live map showing all currently active rides as moving pins. Auto-refreshes every 30 seconds.

---

## 11. Subscriptions

### 11.1 Subscription Plans (Admin-managed)

The admin creates and edits the plans that users can purchase.

**Plan Object:**
```json
{
  "id": "plan_001",
  "name": "Campus Monthly",
  "price": "₹299",
  "price_value": 299,
  "duration": "30 days",
  "duration_days": 30,
  "coins": 10,
  "features": [
    "Unlimited cycle rides",
    "5 e-bike rides/day",
    "Bus access included"
  ],
  "category": "Student",
  "location_name": "IIT Hyderabad",
  "popular": true,
  "included_modes": ["bike", "ebike", "bus"]
}
```

| Field | Type | Notes |
|-------|------|-------|
| `price` | `string` | Display string e.g. `"₹299"` |
| `price_value` | `integer` | Actual numeric value for billing |
| `duration_days` | `integer` | Validity period |
| `coins` | `integer` | Loyalty coins awarded on activation |
| `features` | `string[]` | Bullet-point list shown in the app |
| `category` | `string` | `"Student" \| "Employee" \| "General"` |
| `included_modes` | `string[]` | `"bike" \| "ebike" \| "bus" \| "buggy"` |
| `popular` | `boolean` | Shows a "Popular" badge in the app |

**Endpoints:**
- `GET /admin/subscriptions/plans`
- `POST /admin/subscriptions/plans`
- `PUT /admin/subscriptions/plans/:id`
- `DELETE /admin/subscriptions/plans/:id` — hides from app, keeps history

### 11.2 Active User Subscriptions (Read-only)

```json
{
  "id": "sub_001",
  "user_id": "uuid",
  "user_name": "Rishwak Sharma",
  "plan_name": "Campus Monthly",
  "location_name": "IIT Hyderabad",
  "start_date": "2026-03-19",
  "end_date": "2026-04-18",
  "is_active": true
}
```

- `GET /admin/subscriptions` — list, filters: `plan_id`, `location`, `status`, `search`
- `POST /admin/subscriptions/:id/cancel` — cancel on behalf of user
- `POST /admin/subscriptions/:id/extend` — `{ "days": 7 }` to extend validity

### 11.3 Institution ID Whitelist

Manage which institution IDs are eligible for verified discounts:
- `GET /admin/subscriptions/institution-ids` — paginated list
- `POST /admin/subscriptions/institution-ids/upload` — bulk CSV upload
- `DELETE /admin/subscriptions/institution-ids/:id` — revoke

---

## 12. Achievements

The admin controls every achievement definition. The mobile app reads them and merges with user progress at `GET /profile/achievements`.

### Achievement Object
```json
{
  "id": "ach_001",
  "title": "Century Rider",
  "description": "Ride 100 km total",
  "category": "riding",
  "icon": "🏆",
  "color_hex": "#FFB300",
  "threshold_label": "Ride 100 km",
  "active": true
}
```

| Field | Type | Notes |
|-------|------|-------|
| `category` | `string` | `"riding" \| "social" \| "eco" \| "streak"` |
| `icon` | `string` | Emoji or icon key shown in app |
| `color_hex` | `string` | Badge background colour |
| `threshold_label` | `string` | Human-readable goal shown below badge |
| `active` | `boolean` | `false` = hidden from all users |

### Endpoints
- `GET /admin/achievements` — list all
- `POST /admin/achievements` — create new
- `PUT /admin/achievements/:id` — update title/icon/desc/color/threshold
- `PATCH /admin/achievements/:id/active` — `{ "active": false }` to hide
- `DELETE /admin/achievements/:id` — permanent delete

UI: A grid of achievement cards matching the in-app look. Each card has Edit and Toggle Active buttons.

---

## 13. Transit

### 13.1 Vehicles

```json
{
  "id": "veh_001",
  "name": "City Bus A",
  "number": "TS07XX1234",
  "type": "bus",
  "capacity_total": 30,
  "route_id": "route_001",
  "image_url": "https://cdn.mjollnir.app/vehicles/bus.png",
  "active": true
}
```

### 13.2 Routes / Stops

```json
{
  "id": "route_001",
  "name": "Route 1 · City Loop",
  "short_name": "R1",
  "type": "bus",
  "stops": [
    {
      "id": "stop_001",
      "name": "Main Gate Bus Stop",
      "lat": 17.4580,
      "lng": 78.2760,
      "order": 1
    }
  ]
}
```

### Endpoints
- CRUD for `/admin/transit/vehicles`
- CRUD for `/admin/transit/routes`
- CRUD for `/admin/transit/stops`
- `GET /admin/transit/trips` — active and past trips

---

## 14. Support Tickets

### Ticket Object
```json
{
  "id": "tkt_001",
  "user_id": "uuid",
  "user_name": "Rishwak Sharma",
  "category": "Billing",
  "subject": "Double charge on 18 March",
  "description": "I was charged twice for ride_abc123...",
  "status": "open",
  "created_at": "2026-03-19T10:45:00Z",
  "resolved_at": null,
  "admin_notes": ""
}
```

| `status` | Description |
|----------|-------------|
| `open` | Not yet reviewed |
| `in_progress` | Being handled |
| `resolved` | Fixed |
| `closed` | No action needed |

### Endpoints
- `GET /admin/support/tickets` — list, filters: `status`, `category`, `search`, `date_from`
- `GET /admin/support/tickets/:id`
- `PUT /admin/support/tickets/:id/status` — `{ "status": "resolved", "admin_notes": "Refund issued" }`
- `POST /admin/support/tickets/:id/refund` — issue wallet credit to user

---

## 15. Wallet & Transactions

### Transaction Object
```json
{
  "id": "txn_001",
  "user_id": "uuid",
  "user_name": "Rishwak Sharma",
  "icon": "add_circle_rounded",
  "title": "Top-up",
  "subtitle": "UPI · HDFC Bank",
  "amount": "₹100",
  "amount_value": 100.00,
  "type": "credit",
  "tag": "Added",
  "date": "2026-03-19T10:30:00Z"
}
```

| `type` | `tag` examples |
|--------|----------------|
| `credit` | `"Added"`, `"Refund"`, `"Coupon"`, `"Reward"` |
| `debit` | `"Ride"`, `"Transit"`, `"Subscription"` |

### Endpoints
- `GET /admin/wallet/transactions` — list, filters: `type`, `user_id`, `date_from`, `date_to`, `tag`
- `POST /admin/wallet/transactions/credit` — manual credit to a user: `{ "user_id": "...", "amount": 50, "reason": "Compensation" }`
- `GET /admin/wallet/revenue` — aggregate revenue stats

---

## 16. Groups

### Group Object
```json
{
  "id": "grp_001",
  "name": "Campus Cyclists",
  "description": "Official cycling club of IIT Hyderabad",
  "category": "Cycling",
  "members": 24,
  "total_distance": "1,240 km",
  "joined": true,
  "image_url": "https://cdn.mjollnir.app/groups/001.jpg",
  "created_by": "uuid",
  "created_at": "2026-01-05T08:00:00Z",
  "active": true
}
```

### Endpoints
- `GET /admin/groups` — list all groups
- `GET /admin/groups/:id` — detail + member list
- `PUT /admin/groups/:id` — edit name/description
- `PATCH /admin/groups/:id/active` — suspend/restore
- `DELETE /admin/groups/:id` — permanent delete
- `DELETE /admin/groups/:id/members/:userId` — remove a member

---

## 17. Complete API Routes the Admin Panel Must Implement

### Config
```
GET    /admin/config                     ← full current config
PUT    /admin/config/features            ← update feature flags
PUT    /admin/config/settings            ← update global settings
GET    /admin/config/locations           ← list locations
POST   /admin/config/locations           ← create location
PUT    /admin/config/locations/:id       ← update location
DELETE /admin/config/locations/:id       ← deactivate location
```

### Users
```
GET    /admin/users
GET    /admin/users/:id
PUT    /admin/users/:id/status
DELETE /admin/users/:id
GET    /admin/users/:id/rides
GET    /admin/users/:id/transactions
```

### Bikes
```
GET    /admin/bikes
POST   /admin/bikes
PUT    /admin/bikes/:id
DELETE /admin/bikes/:id
```

### Stations
```
GET    /admin/stations
POST   /admin/stations
PUT    /admin/stations/:id
DELETE /admin/stations/:id
```

### Rides
```
GET    /admin/rides
GET    /admin/rides/:id
POST   /admin/rides/:id/force-end
POST   /admin/rides/:id/refund
```

### Subscriptions
```
GET    /admin/subscriptions/plans
POST   /admin/subscriptions/plans
PUT    /admin/subscriptions/plans/:id
DELETE /admin/subscriptions/plans/:id
GET    /admin/subscriptions
POST   /admin/subscriptions/:id/cancel
POST   /admin/subscriptions/:id/extend
GET    /admin/subscriptions/institution-ids
POST   /admin/subscriptions/institution-ids/upload
DELETE /admin/subscriptions/institution-ids/:id
```

### Achievements
```
GET    /admin/achievements
POST   /admin/achievements
PUT    /admin/achievements/:id
PATCH  /admin/achievements/:id/active
DELETE /admin/achievements/:id
```

### Transit
```
GET    /admin/transit/vehicles
POST   /admin/transit/vehicles
PUT    /admin/transit/vehicles/:id
DELETE /admin/transit/vehicles/:id
GET    /admin/transit/routes
POST   /admin/transit/routes
PUT    /admin/transit/routes/:id
DELETE /admin/transit/routes/:id
GET    /admin/transit/stops
POST   /admin/transit/stops
PUT    /admin/transit/stops/:id
DELETE /admin/transit/stops/:id
GET    /admin/transit/trips
POST   /admin/transit/trips/:id/force-end
```

### Support
```
GET    /admin/support/tickets
GET    /admin/support/tickets/:id
PUT    /admin/support/tickets/:id/status
POST   /admin/support/tickets/:id/refund
```

### Wallet
```
GET    /admin/wallet/transactions
POST   /admin/wallet/transactions/credit
GET    /admin/wallet/revenue
```

### Groups
```
GET    /admin/groups
GET    /admin/groups/:id
PUT    /admin/groups/:id
PATCH  /admin/groups/:id/active
DELETE /admin/groups/:id
DELETE /admin/groups/:id/members/:userId
```

### Admin Auth
```
POST   /admin/auth/login               ← email + password
POST   /admin/auth/refresh
POST   /admin/auth/logout
GET    /admin/users-admin              ← list admin accounts
POST   /admin/users-admin              ← create admin account
PUT    /admin/users-admin/:id/role
DELETE /admin/users-admin/:id
```

---

## 18. Data Relationships

```
Location (campus/zone)
   └── has many Stations
   └── has many Vehicles (transit)
   └── has many SubscriptionPlans (by location_name)

Station
   └── has many Bikes (parked here)

User
   └── has many Rides
   └── has many Transactions
   └── has one active Subscription
   └── has many Achievements (progress tracked server-side)
   └── belongs to many Groups

Ride
   └── belongs to User
   └── belongs to Bike

TransitTrip
   └── belongs to User
   └── belongs to Vehicle
   └── belongs to Stop

SupportTicket
   └── belongs to User

Group
   └── has many Users (members)

SubscriptionPlan
   └── has many UserSubscriptions
   └── belongs to Location (by name)
```

---

## 19. Key Business Rules

| Rule | Details |
|------|---------|
| **Ride auto-end** | Backend auto-ends any ride exceeding `max_ride_duration_min` (configurable, default 120 min) |
| **Loyalty coins** | 1 coin = 1 free ride. Earned after every 10 wallet-paid rides. Expires in 30 days from earning. |
| **Coin conversion** | `coin_conversion_rate` rupees per coin (configurable). |
| **Wallet minimum** | Cannot start a ride if wallet balance < `min_wallet_balance_for_ride` |
| **501 handling** | 401 on mobile auto-refreshes token once, then logs user out |
| **Feature flags** | When a flag is `false`, the mobile app hides the entire feature tab/screen instantly on next launch |
| **Maintenance banner** | Non-null `maintenance_message` in settings shows a full-screen banner in the app |
| **Institution verification** | `POST /subscriptions/verify-id` checks against the admin-managed whitelist |
| **Support chat mode** | `"ai"` = only AI bot, `"human"` = only ticket form, `"both"` = user chooses |
| **Subscription coverage** | `payment_model: subscription_included` means active subscriber rides free. `pay_as_you_go` always charges. `both` = auto-detect. |

---

## 20. Mobile App Config Response Shape (What Admin Publishes)

This is the exact JSON the mobile app reads on every launch from `GET /config`. The admin panel's "Publish Config" button must produce this shape:

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
            { "mode": "bike",   "payment_model": "subscription_included", "enabled": true  },
            { "mode": "ebike",  "payment_model": "both",                  "enabled": true  },
            { "mode": "bus",    "payment_model": "subscription_included", "enabled": true  },
            { "mode": "buggy",  "payment_model": "pay_as_you_go",         "enabled": false }
          ]
        }
      ]
    },
    "settings": {
      "coin_conversion_rate":        1.0,
      "max_ride_duration_min":       120,
      "min_wallet_balance_for_ride": 0.0,
      "coins_enabled":               true,
      "leaderboard_enabled":         true,
      "support_chat_mode":           "both",
      "maintenance_message":         null
    }
  }
}
```

---

## 21. Suggested AI Prompt

Copy and paste the following prompt to an AI to start building:

---

```
Build a web admin panel for a bike-sharing and campus transit app called "Mjollnir".

The admin panel controls a Flutter mobile app. I will provide the full specification.

TECH STACK:
- Frontend: React + TypeScript + TailwindCSS
- UI: shadcn/ui components
- HTTP: Axios with JWT auth
- Charts: Recharts
- Maps (for bike/ride views): Leaflet or Google Maps

AUTH:
- Admin login via POST /admin/auth/login { email, password }
- Store JWT in httpOnly cookie or memory, refresh token in httpOnly cookie
- Role-based: super_admin > ops > support > readonly
- Protect all routes behind role checks

PAGES TO BUILD (in priority order):

1. LOGIN PAGE — email + password form

2. DASHBOARD — 8 metric cards (active rides, active transit trips, users, new users today,
   transactions today, open tickets, rides today, revenue today) + 2 charts (rides/day bar chart,
   new users/day line chart)

3. APP CONFIG PAGE (most important) — 3 sections:
   a) Feature Flags: 10 toggles (ride, transit, wallet, social, groups, subscriptions, support,
      activity, trips, profile) with a Save button that calls PUT /admin/config/features
   b) Global Settings: form with 7 fields (see spec) — PUT /admin/config/settings
   c) Locations: list + CRUD for campus/zone configs, each location has a vehicle table
      with enabled toggles and payment_model dropdowns

4. USERS PAGE — searchable, filterable table (name, phone, user_type, status, created_at columns)
   Click row → user detail drawer with rides, transactions, subscription, suspend/unsuspend button

5. SUBSCRIPTION PLANS PAGE — card grid showing each plan (matching the in-app look).
   Add/Edit/Delete plans. Fields: name, price_value, duration_days, coins, features (multi-line),
   category, location_name, popular toggle, included_modes checkboxes

6. ACHIEVEMENTS PAGE — card grid. Each card shows icon, title, description, category badge, color.
   Add/Edit/Toggle active/Delete. Color picker for color_hex, emoji picker for icon.

7. RIDES PAGE — table of all rides with status filter. Active rides tab shows live map.
   Force-end and Refund actions on each row.

8. BIKES PAGE — table with status badges. Add, edit, mark-maintenance, decommission actions.

9. STATIONS PAGE — split view: map on left, table on right. CRUD.

10. SUPPORT TICKETS PAGE — table with status badges. Click → detail panel with status dropdown
    and admin notes field. Refund button triggers wallet credit.

11. WALLET PAGE — transactions table. Manual credit form (select user, amount, reason).

12. TRANSIT PAGE — tabs for Vehicles, Routes, Stops, Active Trips.

13. GROUPS PAGE — table. Edit name/description, suspend, view members.

DATA SHAPES:
[Paste contents of docs/api_contract.md here]

FULL SPECIFICATION:
[Paste this entire document here]

DESIGN:
- Dark sidebar, light content area
- Primary brand color: #00A877 (green)
- Use shadcn/ui DataTable, Dialog, Sheet, Toast, Badge, Switch, Select components
- Show loading skeletons during fetches
- All mutations show a toast on success/error
- All delete actions require a confirmation dialog
```

---

## 22. Files in This Project to Give the AI

If building with a code-gen AI, also provide:

| File | Why |
|------|-----|
| `docs/api_contract.md` | Exact JSON shapes for every endpoint |
| `docs/api_flow.md` | Architecture diagrams |
| `lib/core/config/app_config_model.dart` | Exact config schema with field names |
| `lib/features/subscription/data/models/subscription_model.dart` | Plan + subscription shapes |
| `lib/features/profile/data/models/achievement_model.dart` | Achievement schema |
| `lib/features/home/data/models/station_model.dart` | Station schema |
| `lib/features/ride/data/models/ride_model.dart` | Ride schema |
| `lib/features/transit/data/models/transit_model.dart` | Transit schema |
| `lib/features/auth/data/models/auth_user_model.dart` | User schema |
| `lib/core/network/api_endpoints.dart` | All endpoint paths |
