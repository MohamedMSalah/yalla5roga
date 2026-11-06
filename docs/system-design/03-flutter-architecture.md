# 2.3 Flutter Architecture

Verified against `flutter/lib/main.dart`, `app.dart`, `core/di/*`, `core/network/*`, `features/*`.

## Feature-first Clean Architecture

```mermaid
flowchart TB
  subgraph Presentation
    SCR["Pages / Widgets"]
    PR["Providers — ChangeNotifier"]
  end

  subgraph Domain
    ENT["Entities / Enums"]
    IREPO["Repository interfaces"]
    FAIL["Failure — dartz Either"]
  end

  subgraph Data
    RIMPL["RepositoryImpl"]
    RDS["Remote DataSources — Dio"]
    LDS["Local DataSources — SharedPreferences"]
    FBS["FirebaseAuthService / FcmMessagingService"]
    GEO["GeocodingHttpRepository — Nominatim"]
    MOD["Models — fromJson / toJson"]
  end

  subgraph Core
    DI["AppDependencies + RepositoryFactory"]
    API["ApiClient + AuthInterceptor"]
    CFG["AppConfig — dart-define"]
    L10N["L10n / LocaleProvider"]
    TH["ThemeProvider"]
  end

  SCR --> PR --> IREPO
  PR --> ENT
  RIMPL -.implements.-> IREPO
  RIMPL --> RDS
  RIMPL --> LDS
  RIMPL --> FBS
  RDS --> API
  RDS --> MOD
  DI --> API
  DI --> RIMPL
  API --> CFG
  GEO --> CFG
```

## Boot sequence

```mermaid
sequenceDiagram
  participant M as main.dart
  participant C as AppConfig
  participant FB as Firebase.initializeApp
  participant DI as AppDependencies.create
  participant A as AuthProvider.restoreSession
  participant App as App / GetMaterialApp

  M->>C: initializeFromEnvironment
  M->>FB: init if configured
  M->>DI: SharedPreferences, Dio, repos, providers
  DI->>A: restoreSession
  Note over A: Requires Firebase session AND cached_user
  M->>App: runApp(MultiProvider)
  Note over App: MainShell if authenticated else SplashPage
  App->>App: _PushBootstrap — deferred FCM init
```

## Feature modules (actual)

| Feature | Layers | Remote | Local |
|---------|--------|--------|-------|
| auth | full | Dio register/profile + Firebase | prefs user/token |
| groups | full | Dio CRUD/members/leave | — |
| outings | full | Dio list/create/votes/attendance | — |
| outings/saved | full | — | prefs saved + drafts |
| chat | full | Dio messages/read | prefs message cache |
| discover | full | Dio places | — |
| notifications | full | Dio feed/read + FCM receive | — |
| home / shell / splash / setting | presentation | via other providers | theme/locale prefs |

## Live Dio inventory (relative to `API_BASE_URL`)

Defined in `ApiConstants` and called from datasources:

1. `POST /auth/register`
2. `PATCH /user/profile`
3. `GET /notifications`
4. `POST /notifications/read`
5. `POST /notifications/{id}/read`
6. `GET|POST /groups`, `GET|PUT /groups/{id}`
7. `POST /groups/{id}/members`, `DELETE …/members/{memberId}`
8. `POST /groups/{id}/leave`
9. `GET|POST /outings`
10. `POST /outings/{id}/votes`
11. `POST /outings/{id}/attendance`
12. `GET|POST /outings/{id}/chat/messages`
13. `POST /outings/{id}/chat/read`
14. `GET /places`, `GET /places/{id}`

**Live only:** `RepositoryFactory` returns API-backed repositories. The former `USE_MOCK_DATA` / `lib/core/mock` demo stack has been removed.

## Architectural notes vs workspace docs

- Project context docs mention an `unread` feature module; **no `lib/features/unread` exists** — only `ApiConstants.unreadCounts`.
