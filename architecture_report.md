# Mjollnir App Architecture Report

## 1. Purpose

This report documents the current technical architecture of the Flutter application and highlights strengths, risks, and improvement opportunities.

## 2. Architecture Summary

The app follows a feature-first layered architecture:

- Presentation layer per feature (screens, widgets, Riverpod providers)
- Data layer per feature (repository interfaces and implementations, models)
- Shared core infrastructure (`core/`) for network, storage, routing, theming, config, constants, and shared widgets

There is no separate domain/use-case layer. Most business logic is implemented inside Riverpod `StateNotifier` classes.

## 3. High-Level Module Map

### Core (`lib/core`)

- `config`: Remote config model and repository
- `constants`: App colors, sizes, assets, strings
- `errors`: Typed app/network error hierarchy
- `network`: API client, endpoint config, provider wiring
- `router`: Route definitions and auth redirect logic
- `storage`: Secure/local persistence wrappers
- `theme`: Theme mode and theme provider
- `utils`: Shared utility classes
- `widgets`: Reusable app-wide UI components

### Features (`lib/features`)

- `auth`, `home`, `ride`, `trips`, `wallet`, `profile`, `social`, `groups`, `activity`, `subscription`, `support`, `transit`

Each feature generally contains:

- `data/models`
- `data/repositories`
- `presentation/providers`
- `presentation/screens`
- `presentation/widgets` (where needed)

## 4. Runtime Data Flow

Typical request lifecycle:

1. User action in a `ConsumerWidget`
2. Widget triggers a `StateNotifier` method via `ref.read(...notifier)`
3. Notifier updates immutable state (`copyWith`) and calls repository methods
4. Repository implementation calls `ApiClient` (Dio)
5. Result/error returns to notifier
6. Notifier updates state; UI rebuilds through `ref.watch(...)`

## 5. State Management

- Framework: `flutter_riverpod`
- Primary pattern: `StateNotifierProvider<Notifier, State>`
- Common state fields: loading/status enum, payload model(s), error message
- State is immutable-like through `copyWith`

Assessment:

- Good consistency in provider usage across features
- Predictable and scalable for medium/large app scope
- Business logic concentration in notifiers can become hard to test if methods grow large

## 6. Navigation Architecture

- Framework: `go_router`
- Router is provided centrally and listens to auth state
- Redirect logic ensures authenticated routes are protected

Assessment:

- Centralized route control is clean and maintainable
- Auth-based redirect is correctly placed at router level

## 7. Networking

- Client: `dio` via shared `ApiClient`
- Token handling: bearer token injection from storage
- Unauthorized handling: refresh attempt and request retry path
- Error model: typed errors in core error hierarchy

Assessment:

- Shared client and typed errors are strong foundations
- Retry and refresh logic placement is appropriate for cross-feature reuse

## 8. Persistence

- `FlutterSecureStorage` for sensitive auth/token data
- `SharedPreferences` for lightweight cached flags/config/preferences

Assessment:

- Correct security split for sensitive vs non-sensitive data
- Local cache fallback exists in config-related flows

## 9. Error Handling and Observability

Current behavior:

- Typed error hierarchy exists and is used in network paths
- Many provider methods convert exceptions to user-facing state error text
- Several infrastructure catches silently swallow exceptions for fallback behavior
- No dedicated app logging module is currently present

Risks:

- Production diagnosis is harder without structured logs
- Silent catches can hide recurring backend/device issues

## 10. Strengths

- Clear feature-first separation
- Strong shared core boundaries
- Consistent Riverpod provider architecture
- Reusable network and storage abstractions
- Good documentation coverage in `docs/`

## 11. Risks and Technical Debt

- Missing domain/use-case layer can blur business boundaries over time
- Some notifier methods may become too broad as complexity grows
- Logging/telemetry gap reduces debuggability and support velocity
- Silent catch blocks can reduce reliability transparency

## 12. Recommendations

Short term:

1. Introduce a logging abstraction in `core/utils` with environment-aware log levels
2. Replace silent catches with fallback + warning logs
3. Standardize provider error mapping (user message vs diagnostic detail)

Medium term:

1. Extract complex business operations into feature use-case classes
2. Add repository and notifier unit tests for critical flows (auth, ride lifecycle, wallet)
3. Define architecture guardrails (feature boundaries, import rules)

Long term:

1. Add telemetry pipeline (crash + structured events)
2. Add offline-first strategy for ride/trip critical data where applicable

## 13. Overall Verdict

The codebase is well-structured for current scale and has strong foundations in feature modularization, routing, state management, and shared infrastructure. The highest-value architectural improvement is observability: introducing structured logging and reducing silent failure paths.
