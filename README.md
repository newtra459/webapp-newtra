# Mjollnir — Smart Mobility Platform

A Flutter application for campus and corporate micro-mobility — shared bikes, e-bikes, and personal ride recording with live GPS tracking, social features, and a loyalty wallet.

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
- [Running the App](#running-the-app)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Key Dependencies](#key-dependencies)
- [Documentation](#documentation)

---

## Overview

Mjollnir lets university and corporate users:

- Locate and unlock shared bikes / e-bikes at nearby stations via QR scan
- Record rides on their own bike for stats and eco tracking
- Track rides in real time with live GPS, speed, distance, and elevation
- Earn loyalty coins redeemable against future rides
- Connect with friends, compete on leaderboards, and join campus groups
- Manage a in-app wallet and choose from subscription plans

---

## Features

| Feature | Description |
|---|---|
| OTP Authentication | Phone-number login with 6-digit OTP, no password |
| Home Map | Google Maps with live bike-station markers and availability |
| QR Scanner | Scan bike QR code to start a shared ride instantly |
| Live Ride Tracking | GPS polyline, speed, distance, calories, elevation |
| Own-Bike Recording | Record personal rides — same stats, no fare |
| Ride Summary | Route replay, fare breakdown, eco impact (CO₂, trees) |
| Trips History | Filterable log of all past rides with detail view |
| Wallet | Rupee balance, Mjollnir coins, top-up, coin redemption |
| Subscriptions | Free / Monthly / Semester plans with per-plan ride minutes |
| Social | Friends list, leaderboard (global / friends / campus) |
| Groups | Campus and organization groups with shared stats |
| Activity Feed | Friend rides, achievements, challenges |
| Transit | Live bus / metro board, active transit trip tracking |
| Support | FAQ, AI chat, issue reporting, email contact |
| Remote Config | Feature flags and vehicle config fetched from server |

---

## Prerequisites

| Tool | Minimum version |
|---|---|
| Flutter SDK | 3.x (Dart `^3.11.1`) |
| Xcode | 15+ (iOS builds) |
| CocoaPods | latest |
| Android Studio | latest (Android builds, optional) |

---

## Getting Started

```bash
# 1. Enter the project directory
cd "Mjollnir App"

# 2. Fetch Dart / Flutter dependencies
flutter pub get

# 3. Install iOS CocoaPods (macOS only)
cd ios && pod install && cd ..

# 4. Run code generation (models, serializers)
dart run build_runner build --delete-conflicting-outputs
```

---

## Running the App

```bash
# iOS Simulator
flutter run -d <simulator-udid>

# List available simulators / devices
flutter devices

# Release build (iOS)
flutter build ios --release

# Release build (Android)
flutter build apk --release
```

---

## Project Structure

```
lib/
├── main.dart                  # Entry point — ProviderScope + app init
├── core/
│   ├── config/                # Remote config models & repository
│   ├── constants/             # API endpoints, string constants
│   ├── errors/                # Network error types
│   ├── network/               # Dio ApiClient with auth interceptor
│   ├── router/                # GoRouter definition & redirect logic
│   ├── storage/               # LocalStorage (SecureStorage + SharedPrefs)
│   ├── theme/                 # Light / dark ThemeData
│   ├── utils/                 # Shared helpers
│   └── widgets/               # Shared UI components
└── features/
    ├── auth/                  # Login, OTP, registration, delete account
    ├── home/                  # Map, station list, start-ride entry
    ├── ride/                  # QR scanner, active ride, ride summary
    ├── trips/                 # Trip history & detail
    ├── wallet/                # Balance, transactions, top-up
    ├── profile/               # Profile view/edit, achievements
    ├── social/                # Friends, leaderboard, user profiles
    ├── groups/                # Campus groups
    ├── activity/              # Activity feed
    ├── subscription/          # Plan selection & management
    ├── transit/               # Bus/metro schedule & live tracking
    └── support/               # Help, AI chat, issue reporting
```

Each feature follows the same layered structure:

```
feature/
├── data/
│   ├── models/        # JSON-serializable data classes
│   └── repositories/  # API calls → domain models
└── presentation/
    ├── providers/     # Riverpod StateNotifier + state classes
    └── screens/       # ConsumerWidget UI screens
```

---

## Architecture

- **State management** — [Riverpod](https://riverpod.dev/) `StateNotifier` pattern; all state is immutable (`copyWith`)
- **Navigation** — [GoRouter](https://pub.dev/packages/go_router) with shell route for bottom nav and auth redirect guard
- **Network** — [Dio](https://pub.dev/packages/dio) with automatic `Authorization: Bearer` injection and silent token refresh on 401
- **Storage** — `FlutterSecureStorage` for JWTs; `SharedPreferences` for config cache and user prefs
- **Responsive layout** — [ScreenUtil](https://pub.dev/packages/flutter_screenutil) with 375×812 base; text scale clamped 0.85–1.25×
- **Feature flags** — all 10 features can be toggled server-side via `GET /config`

---

## Key Dependencies

| Package | Purpose |
|---|---|
| `flutter_riverpod` | State management & DI |
| `go_router` | Declarative navigation |
| `dio` | HTTP client |
| `google_maps_flutter` | Maps and station markers |
| `geolocator` | Real-time GPS |
| `mobile_scanner` | QR code scanning |
| `flutter_secure_storage` | Encrypted JWT storage |
| `shared_preferences` | Lightweight key-value storage |
| `flutter_screenutil` | Responsive dimensions |
| `lottie` | Animation playback |
| `fl_chart` | Ride stats charts |
| `hive` | Local data caching |
| `freezed` | Immutable model code generation |

---

## Documentation

| File | Contents |
|---|---|
| [`docs/app_flow.md`](docs/app_flow.md) | Screen-by-screen user journeys, navigation tree, state machines |
| [`docs/api_flow.md`](docs/api_flow.md) | API sequence diagrams for all major flows |
| [`docs/api_contract.md`](docs/api_contract.md) | Full API request / response schemas |
| [`docs/architecture_report.md`](docs/architecture_report.md) | Current architecture assessment, risks, and improvement roadmap |
| [`docs/project_structure_report.md`](docs/project_structure_report.md) | Repository layout, module boundaries, and structure governance |
| [`docs/developer_guide.md`](docs/developer_guide.md) | Setup, conventions, adding a new feature end-to-end |
