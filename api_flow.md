# Mjollnir App — API Flow Diagrams

> All diagrams use [Mermaid](https://mermaid.js.org/) syntax.  
> Render in VS Code with the **Markdown Preview Mermaid Support** extension,  
> or paste into [mermaid.live](https://mermaid.live).

---

## 1. App Boot & Initialisation Sequence

```mermaid
sequenceDiagram
    autonumber
    participant OS as iOS / Android
    participant Main as main.dart
    participant LS as LocalStorage<br/>(SharedPrefs + SecureStorage)
    participant PS as ProviderScope<br/>(Riverpod)
    participant Auth as AuthStateNotifier
    participant Cfg as AppConfigRepository
    participant API as ApiClient<br/>(Dio)
    participant BE as Backend API<br/>api.mjollnir.app/v1

    OS->>Main: cold start
    Main->>LS: init() — SharedPreferences.getInstance()
    LS-->>LS: read JWT from FlutterSecureStorage → cache in memory
    LS-->>LS: migrate legacy token from SharedPrefs → SecureStorage (once)
    Main->>LS: ensureAppUserId() — generate MJL-XXXXXXXX if absent
    Main->>PS: ProviderScope wraps MjollnirApp
    PS->>Auth: AuthStateNotifier() — reads cached token synchronously
    alt token present
        Auth-->>PS: status = authenticated
    else no token
        Auth-->>PS: status = unauthenticated
    end
    PS->>Cfg: fetchConfig() on app launch
    Cfg->>API: GET /config
    API->>BE: GET /v1/config  [no auth needed]
    BE-->>API: { feature_flags, transport_config, … }
    API-->>Cfg: AppConfigModel
    alt network success
        Cfg->>LS: cache config JSON in SharedPrefs
    else network error
        Cfg->>LS: read cached config (fallback)
        LS-->>Cfg: cached JSON or compile-time defaults
    end
    PS->>PS: GoRouter evaluates redirect
    note over PS: /splash → /auth/login (unauth)<br/>or /splash → /home (auth)
```

---

## 2. Authentication Flow (OTP Login)

```mermaid
sequenceDiagram
    autonumber
    participant UI as LoginScreen / OtpScreen
    participant AFN as AuthFormNotifier<br/>(StateNotifier)
    participant AR as AuthRepository<br/>(AuthRepositoryImpl)
    participant AC as ApiClient
    participant BE as Backend API

    UI->>AFN: sendOtp(phone)
    AFN->>AFN: state = isLoading: true
    AFN->>AR: sendOtp(phone)
    AR->>AC: POST /auth/otp/send  { phone }
    AC->>BE: HTTP POST /v1/auth/otp/send
    BE-->>AC: { data: { request_id } }
    AC-->>AR: Response
    AR-->>AFN: requestId (String)
    AFN->>AFN: state = otpSent: true

    UI->>AFN: verifyOtp(otp)
    AFN->>AR: verifyOtp(phone, otp)
    AR->>AC: POST /auth/otp/verify  { phone, otp }
    AC->>BE: HTTP POST /v1/auth/otp/verify
    BE-->>AC: { data: { token, refresh_token, user } }
    AC-->>AR: Response
    AR-->>AFN: (token, refreshToken, user)
    AFN->>LS: saveToken(token) → FlutterSecureStorage
    AFN->>LS: saveRefreshToken(refreshToken) → FlutterSecureStorage
    AFN->>LS: saveAppUserId(user.userNumber)
    AFN->>ASN: setAuthenticated(token)
    note over ASN: status = authenticated
    ASN-->>Router: notifyListeners()
    Router-->>UI: redirect → /home
```

---

## 3. Authenticated Request Lifecycle (with Token Auto-Refresh)

```mermaid
sequenceDiagram
    autonumber
    participant N as StateNotifier<br/>(any feature)
    participant R as RepositoryImpl<br/>(any feature)
    participant AC as ApiClient
    participant DI as Dio Interceptor
    participant LS as LocalStorage
    participant BE as Backend API

    N->>R: any repository call (e.g. getProfile)
    R->>AC: apiClient.get(path)
    AC->>DI: onRequest interceptor
    DI->>LS: getToken() — synchronous memory read
    DI-->>AC: adds Authorization: Bearer <token>
    AC->>BE: HTTP GET /v1/<path>

    alt 200 OK
        BE-->>AC: { data: { … } }
        AC-->>R: Response
        R-->>N: parsed model
        N-->>N: state = success

    else 401 Unauthorized
        BE-->>DI: 401
        DI->>DI: _isRefreshing = true
        DI->>LS: getRefreshToken()
        DI->>BE: POST /v1/auth/refresh { refresh_token }
        alt refresh succeeds
            BE-->>DI: { data: { token, refresh_token } }
            DI->>LS: saveToken(newToken)
            DI->>LS: saveRefreshToken(newRefreshToken)
            DI->>BE: RETRY original request with new token
            BE-->>AC: 200 { data: { … } }
            AC-->>R: Response
            R-->>N: parsed model
        else refresh fails
            DI->>LS: clearAuth() — wipe both tokens from SecureStorage
            DI-->>AC: forward 401 error as NetworkError
            AC-->>R: throws NetworkError(401)
            R-->>N: rethrows AppError
            N-->>N: state = error
            note over N: AuthStateNotifier.logout() called<br/>→ router redirects to /auth/login
        end

    else Network error / timeout
        BE-->>DI: DioException (timeout / no connection)
        DI-->>AC: NetworkError.fromDioException(e)
        AC-->>R: throws NetworkError
        R-->>N: rethrows
        N-->>N: state = error (message shown in UI)
    end
```

---

## 4. Dependency Injection Architecture

```mermaid
graph TD
    subgraph CORE["core/network/"]
        ACP["apiClientProvider<br/><i>Provider&lt;ApiClient&gt;</i><br/>● Singleton<br/>● Dio under the hood<br/>● Auth interceptor baked in"]
    end

    subgraph FEATURE_REPOS["Feature Repository Providers"]
        AUTH["authRepositoryProvider"]
        PROFILE["profileRepositoryProvider"]
        RIDE["rideRepositoryProvider"]
        HOME["homeRepositoryProvider"]
        TRIPS["tripRepositoryProvider"]
        WALLET["walletRepositoryProvider"]
        SOCIAL["socialRepositoryProvider"]
        GROUPS["groupRepositoryProvider"]
        SUB["subscriptionRepositoryProvider"]
        ACT["activityRepositoryProvider"]
        SUP["supportRepositoryProvider"]
        TRANSIT["transitRepositoryProvider<br/><i>(via screen provider)</i>"]
    end

    subgraph FEATURE_STATE["Feature State Notifiers"]
        AUTH_N["AuthFormNotifier"]
        AUTH_S["AuthStateNotifier"]
        PROFILE_N["ProfileNotifier"]
        RIDE_N["RideNotifier"]
        HOME_N["HomeNotifier"]
        TRIPS_N["TripsNotifier"]
        WALLET_N["WalletNotifier"]
        SOCIAL_N["SocialNotifier"]
        GROUPS_N["GroupsNotifier"]
        SUB_N["SubscriptionNotifier"]
        ACT_N["ActivityNotifier"]
        SUP_N["SupportNotifier"]
    end

    ACP --> AUTH
    ACP --> PROFILE
    ACP --> RIDE
    ACP --> HOME
    ACP --> TRIPS
    ACP --> WALLET
    ACP --> SOCIAL
    ACP --> GROUPS
    ACP --> SUB
    ACP --> ACT
    ACP --> SUP
    ACP --> TRANSIT

    AUTH    --> AUTH_N
    PROFILE --> PROFILE_N
    RIDE    --> RIDE_N
    HOME    --> HOME_N
    TRIPS   --> TRIPS_N
    WALLET  --> WALLET_N
    SOCIAL  --> SOCIAL_N
    GROUPS  --> GROUPS_N
    SUB     --> SUB_N
    ACT     --> ACT_N
    SUP     --> SUP_N

    style ACP fill:#1e3a5f,color:#fff,stroke:#4a90d9
    style CORE fill:#0d2137,color:#aaa,stroke:#4a90d9
```

---

## 5. Full Request Data Flow (Single Feature — Ride Example)

```mermaid
flowchart TD
    subgraph UI["Presentation Layer"]
        QR["QRScannerScreen\nscans bike QR"]
        RS["RideScreen\nshows active ride"]
        RSUMM["RideSummaryScreen\nshows trip result"]
    end

    subgraph STATE["State Layer (Riverpod)"]
        RN["RideNotifier\nStateNotifier&lt;RideState&gt;"]
        RS_STATE["RideState\n{ status, ride, error }"]
    end

    subgraph REPO["Data Layer"]
        RR["RideRepository\n(abstract interface)"]
        RRI["RideRepositoryImpl\n(concrete)"]
    end

    subgraph NETWORK["Network Layer (core)"]
        AC["ApiClient\n(Dio wrapper)"]
        INT["DioInterceptor\nAdds Bearer token\nHandles 401 refresh"]
        ERR["NetworkError\n(AppError)"]
    end

    subgraph STORAGE["Storage Layer (core)"]
        SEC["FlutterSecureStorage\nJWT token"]
        SP["SharedPreferences\nrideId, wallet, config…"]
    end

    subgraph BACKEND["Backend  api.mjollnir.app/v1"]
        START["/rides/start"]
        LOC["/rides/:id/location"]
        END_EP["/rides/:id/end"]
    end

    QR -->|"startRide(bikeId)"| RN
    RN --> RRI
    RRI --> AC
    AC --> INT
    INT -->|"reads token"| SEC
    INT --> START
    START -->|"{ id, bike_id, started_at, … }"| INT
    INT --> AC
    AC --> RRI
    RRI -->|"RideModel"| RN
    RN -->|"saveActiveRideServerId"| SP
    RN --> RS_STATE
    RS_STATE --> RS

    RS -->|"updateLocation(lat,lng)"| RN
    RN --> RRI
    RRI --> AC
    AC --> LOC

    RS -->|"endRide(rideId)"| RN
    RN --> RRI
    RRI --> AC
    AC --> END_EP
    END_EP -->|"{ fare, duration, distance, … }"| RRI
    RRI --> RN
    RN --> RSUMM

    INT -.->|"DioException"| ERR
    ERR -.->|"throws NetworkError"| RN
    RN -.->|"state = RideStatus.error"| RS_STATE

    style NETWORK fill:#0d2137,color:#aaa,stroke:#4a90d9
    style STORAGE fill:#1a1a2e,color:#aaa,stroke:#7c3aed
    style BACKEND fill:#1e3a1e,color:#aaa,stroke:#22c55e
```

---

## 6. Error Handling Hierarchy

```mermaid
graph TD
    EX["Exception<br/>(Dart)"]
    AE["AppError<br/><i>sealed class</i><br/>message, code, originalError"]
    NE["NetworkError\n● connection timeout\n● send / receive timeout\n● 401 / 403 / 404 / 5xx\n● cancelled\n● no internet"]
    VE["ValidationError\n● field-level map\n● fromJson(response)"]
    AuthE["AuthenticationError\n● invalid credentials\n● session expired"]
    AuthZE["AuthorizationError\n● forbidden resource"]
    CE["CacheError\n● read / write failure"]
    FE["FileError\n● upload / download\n● multipart failure"]
    PE["ParseError\n● JSON decode failure"]
    GE["GenericError\n● catch-all fallback"]

    EX --> AE
    AE --> NE
    AE --> VE
    AE --> AuthE
    AE --> AuthZE
    AE --> CE
    AE --> FE
    AE --> PE
    AE --> GE

    NE -->|"fromDioException(e)"| NE
    AE -->|"ExceptionToAppError.toAppError()"| AE

    style AE fill:#1e3a5f,color:#fff,stroke:#4a90d9
    style NE fill:#3a1e1e,color:#fca5a5,stroke:#ef4444
    style VE fill:#3a2e1e,color:#fde68a,stroke:#f59e0b
```

---

## 7. Token Security & Storage Flow

```mermaid
flowchart LR
    subgraph BOOT["App Boot  main()"]
        INIT["LocalStorage.init()"]
        MIG["One-time migration\nSharedPrefs → SecureStorage"]
    end

    subgraph SECURE["FlutterSecureStorage\n(Keychain iOS / Keystore Android)"]
        JWT["auth_token"]
        RFT["refresh_token"]
    end

    subgraph MEMORY["In-Memory Cache\n(process lifetime only)"]
        MJWT["_cachedToken"]
        MRFT["_cachedRefreshToken"]
    end

    subgraph DIO["Dio Interceptor\n(sync read, no await)"]
        HDR["Authorization: Bearer …"]
    end

    INIT --> MIG
    MIG -->|"reads legacy token"| SECURE
    INIT -->|"await secureStorage.read"| SECURE
    SECURE --> MJWT
    SECURE --> MRFT
    MJWT -->|"getToken() — sync"| HDR
    MRFT -->|"getRefreshToken() — sync"| HDR

    subgraph WRITE["Token writes (async)"]
        W1["saveToken(t)"]
        W2["saveRefreshToken(r)"]
        W3["clearAuth()"]
    end

    W1 --> MJWT
    W1 --> SECURE
    W2 --> MRFT
    W2 --> SECURE
    W3 -->|"null both caches"| MJWT
    W3 -->|"delete both keys"| SECURE

    style SECURE fill:#1a1a2e,color:#c4b5fd,stroke:#7c3aed
    style MEMORY fill:#0d2137,color:#93c5fd,stroke:#3b82f6
```

---

## 8. Remote Config & Feature Flags Flow

```mermaid
sequenceDiagram
    autonumber
    participant App as App Launch
    participant CFG as AppConfigRepository
    participant API as ApiClient
    participant BE as Backend API
    participant LS as LocalStorage<br/>(SharedPrefs)
    participant UI as Any Screen / Feature

    App->>CFG: fetchConfig()
    CFG->>API: GET /config
    API->>BE: HTTP GET /v1/config

    alt Backend responds
        BE-->>API: AppConfigModel JSON<br/>{ feature_flags, transport_config, … }
        API-->>CFG: parsed AppConfigModel
        CFG->>LS: cache JSON in 'app_config_cache'
        CFG-->>App: AppConfigModel.live
    else Network failure
        CFG->>LS: read 'app_config_cache'
        alt Cache hit
            LS-->>CFG: cached JSON
            CFG-->>App: AppConfigModel.fromCache
        else Cache miss
            CFG-->>App: AppConfigModel.defaults (compile-time)
        end
    end

    UI->>CFG: cachedOrDefaults() [synchronous]
    note over UI,CFG: Screens can read config<br/>synchronously after boot
    CFG->>UI: FeatureFlags.walletEnabled<br/>FeatureFlags.subscriptionEnabled<br/>TransportConfig.maxRideDurationMin<br/>etc.
    note over UI: Feature enabled/disabled<br/>without re-deploy
```

---

## 9. Navigation & Route Guard Flow

```mermaid
flowchart TD
    SPLASH["/splash\nSplashScreen"]
    CHECK{AuthStateNotifier\nreads cached token}
    LOGIN["/auth/login\nLoginScreen"]
    OTP["/auth/otp\nOtpScreen"]
    REG["/auth/register\nRegistrationScreen"]
    SHELL["NavigationShell\nBottom Nav / Nav Rail"]

    HOME["/home\nHomeScreen"]
    BIKES["/home/bikes\nQR / Ride screen"]
    COMM["/community\nSocial / Groups"]
    PROF["/profile\nProfileScreen"]

    DEEP["Deep routes\n/trips, /wallet,\n/subscription,\n/support, /transit…"]

    SPLASH --> CHECK
    CHECK -->|"unauthenticated"| LOGIN
    CHECK -->|"authenticated\n+ registered"| SHELL
    CHECK -->|"authenticated\n+ NOT registered"| REG

    LOGIN -->|"sendOtp"| OTP
    OTP -->|"verifyOtp success"| CHECK
    REG -->|"register success"| SHELL

    SHELL --> HOME
    SHELL --> BIKES
    SHELL --> COMM
    SHELL --> PROF

    HOME --> DEEP
    PROF --> DEEP
    COMM --> DEEP

    REG2["Any protected route\nwithout auth"]
    REG2 -->|"GoRouter redirect"| LOGIN

    style SHELL fill:#1e3a5f,color:#fff,stroke:#4a90d9
    style CHECK fill:#3a2e1e,color:#fde68a,stroke:#f59e0b
```

---

## 10. API Endpoint Registry Structure

```mermaid
graph LR
    AE["ApiEndpoints\n(abstract final class)"]

    AE --> AUTH_EP["auth\n/auth/otp/send\n/auth/otp/verify\n/auth/register\n/auth/refresh\n/auth/account"]
    AE --> PROF_EP["profile\n/profile\n/profile/image\n/profile/achievements\n/profile/achievements/:id/acknowledge"]
    AE --> RIDE_EP["ride\n/rides/start\n/rides/:id/end\n/rides/:id/location"]
    AE --> TRIPS_EP["trips\n/trips\n/trips/:id"]
    AE --> STA_EP["stations\n/stations/nearby"]
    AE --> WAL_EP["wallet\n/wallet/balance\n/wallet/topup\n/wallet/withdraw\n/wallet/transactions\n/wallet/coupon"]
    AE --> SOC_EP["social\n/social/suggested\n/social/followers\n/social/following\n/social/follow/:id\n/social/unfollow/:id\n/social/leaderboard/riders\n/social/leaderboard/groups"]
    AE --> GRP_EP["groups\n/groups/mine\n/groups/discover\n/groups\n/groups/:id\n/groups/:id/join\n/groups/:id/leave"]
    AE --> SUB_EP["subscriptions\n/subscriptions/plans\nPOST /subscriptions\n/subscriptions/active\n/subscriptions/:id\n/subscriptions/verify-id"]
    AE --> SUP_EP["support\n/support/tickets\n/support/tickets/mine\n/support/chat"]
    AE --> ACT_EP["activity\n/activity/summary\n/activity/feed"]
    AE --> TRANS_EP["transit\n/transit/stops\n/transit/trips/board\n/transit/trips/active\n/transit/trips/:id/end"]
    AE --> CFG_EP["config\n/config\n/config/locations/:id"]

    ENV["ApiConfig\n● development  localhost:8080/v1\n● staging       staging-api.mjollnir.app/v1\n● production    api.mjollnir.app/v1\n\nTimeout: 30s connect / 30s receive"]

    ENV -.->|"baseUrl baked into ApiClient"| AE

    style AE fill:#1e3a5f,color:#fff,stroke:#4a90d9
    style ENV fill:#1e3a1e,color:#aaa,stroke:#22c55e
```
