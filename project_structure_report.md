# Mjollnir App Project Structure Report

## 1. Objective

This document provides a clear structural view of the repository, explains directory responsibilities, and records organization rules that help maintain scalability.

## 2. Top-Level Repository Layout

```
Mjollnir App/
├── lib/                     # Application source code
├── test/                    # Unit/widget tests
├── docs/                    # Project and engineering documentation
├── assets/                  # Images, icons, fonts, animations
├── android/                 # Android native host
├── ios/                     # iOS native host
├── macos/                   # macOS native host
├── windows/                 # Windows native host
├── linux/                   # Linux native host
├── web/                     # Web host files
├── pubspec.yaml             # Flutter dependencies + assets config
├── analysis_options.yaml    # Lint/static analysis configuration
└── README.md                # Project overview and setup
```

## 3. Application Code Layout (`lib/`)

```
lib/
├── main.dart                # App entry point and root wiring
├── core/                    # Shared infrastructure and reusable modules
└── features/                # Feature-first business modules
```

### 3.1 Core Layer (`lib/core/`)

| Folder | Responsibility |
|---|---|
| `config/` | Remote config models/repository, environment-level app configuration |
| `constants/` | App-wide constants for strings, colors, sizing, assets |
| `errors/` | Shared typed error classes |
| `network/` | API client abstraction, endpoint configuration, providers |
| `router/` | Route definitions and auth redirect logic |
| `storage/` | Secure and local persistence wrappers |
| `theme/` | Theme definitions and theme state provider |
| `utils/` | Generic helper classes/functions shared across features |
| `widgets/` | Reusable UI widgets used by multiple features |

### 3.2 Feature Layer (`lib/features/`)

Current feature modules:

- `activity/`
- `auth/`
- `groups/`
- `home/`
- `profile/`
- `ride/`
- `social/`
- `subscription/`
- `support/`
- `transit/`
- `trips/`
- `wallet/`

Each feature generally follows this shape:

```
features/<feature>/
├── data/
│   ├── models/              # DTO/model classes
│   └── repositories/        # Repository interfaces + implementations
└── presentation/
    ├── providers/           # Riverpod notifiers/providers and state classes
    ├── screens/             # Route-level screens/pages
    └── widgets/             # Feature-scoped reusable widgets (optional)
```

## 4. Test Code Layout (`test/`)

```
test/
├── core/                    # Tests for shared/core functionality
├── features/                # Feature-level provider/model/repository tests
└── widget_test.dart         # Baseline Flutter widget test scaffold
```

## 5. Documentation Layout (`docs/`)

The project maintains structured documentation by concern:

- App and navigation flow
- API flow and contracts
- Feature deep-dives
- State flow and provider map
- Developer setup/conventions
- Debug guidance
- Architecture-level reports

This documentation-first approach reduces onboarding time and makes architectural decisions auditable.

## 6. Asset Layout (`assets/`)

```
assets/
├── animations/
├── fonts/
├── icons/
└── images/
    └── logo/
```

Asset declarations are centralized in `pubspec.yaml` and typically mapped via constants in `lib/core/constants`.

## 7. Structural Dependency Rules

Recommended and currently followed at high level:

1. `core/` must not import anything from `features/`.
2. A feature may import from `core/`, but should avoid importing other features directly.
3. Presentation should access external systems through repositories, not direct network calls.
4. Shared UI primitives should live in `core/widgets`, not duplicated across features.
5. Endpoint and client configuration should stay in `core/network`.

## 8. Scalability Assessment

Strengths:

- Clear separation between shared infrastructure and business features.
- Predictable per-feature folder shape.
- Good discoverability for onboarding and maintenance.
- Cross-platform host folders remain cleanly separated from app logic.

Improvement opportunities:

1. Add explicit architecture guardrails in lint/docs for cross-feature imports.
2. Keep feature modules internally consistent (all include `data` + `presentation` subfolders).
3. Add ownership tags per feature/module for clearer maintenance accountability.
4. Introduce a generated dependency map in CI to prevent structure drift.

## 9. Conclusion

The project structure is mature and suitable for a medium-to-large Flutter codebase. The feature-first organization with a shared `core` layer supports modular development, easier testing, and smoother team onboarding.
