# Yalla 5roga — Project Structure Map

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-08 (API request optimization) |
| Documentation version | 1.0.0 |
| Purpose | Help agents locate files without full-repo scans |

## Repository root

```
yalla5roga/
  AGENTS.md                 # AI entrypoint
  README.md
  docs/                     # Canonical architecture + product docs
  .cursor/rules/            # Cursor modular rules
  scripts/                  # Dev helpers (e.g. physical Android)
  flutter/                  # Mobile app
  backend/                  # Express API + Prisma
```

## Where to start for common tasks

| Task | Read docs | Inspect first |
|------|-----------|---------------|
| Flutter UI | FLUTTER_ARCHITECTURE, USER_SCENARIOS | `flutter/lib/features/<feature>/presentation/` |
| Provider / repo | FLUTTER_ARCHITECTURE, API_CONTRACTS | `…/presentation/providers`, `…/data/` |
| Backend API | BACKEND_ARCHITECTURE, API_CONTRACTS | `backend/src/routes/**`, matching controller/usecase |
| Voting / lifecycle | SYSTEM_DESIGN, BUSINESS_LOGIC, USER_SCENARIOS | `vote-resolution.ts`, `voting.usecase.ts`, jobs |
| Schema | DATABASE_ARCHITECTURE | `backend/prisma/schema.prisma` |
| Auth | AUTHENTICATION_AND_AUTHORIZATION | `auth.middleware.ts`, Flutter `features/auth/` |
| Notifications | NOTIFICATIONS | `jobs/notification-worker.job.ts`, `services/notifications/` |
| Product behavior | PRODUCT_SCENARIOS | — |

---

## `docs/`

| File | Responsibility |
|------|----------------|
| `PRODUCT_SCENARIOS.md` | Approved product behavior (authority) |
| `PROJECT_OVERVIEW.md` | Product + stack overview |
| `SYSTEM_ARCHITECTURE.md` | Component communication |
| `SYSTEM_DESIGN.md` | Workflow-level technical design |
| `USER_SCENARIOS.md` | User journeys + QA matrix |
| `FLUTTER_ARCHITECTURE.md` | Flutter patterns |
| `BACKEND_ARCHITECTURE.md` | Express patterns |
| `DATABASE_ARCHITECTURE.md` | Schema |
| `API_CONTRACTS.md` | Endpoints |
| `BUSINESS_LOGIC.md` | Rules vs implementation |
| `AUTHENTICATION_AND_AUTHORIZATION.md` | AuthN/Z |
| `NOTIFICATIONS.md` | FCM/outbox |
| `ARCHITECTURE_DECISIONS.md` | ADRs |
| `PROJECT_STRUCTURE.md` | This map |
| `audit/` | Compliance reports |
| `system-design/` | Historical deep dives (prefer canonical docs above when conflict) |

---

## `flutter/`

```
flutter/lib/
  main.dart, app.dart, firebase_options.dart
  core/
    di/app_dependencies.dart, repository_factory.dart
    network/api_client.dart, dio_interceptors.dart, api_payload.dart,
      request_deduper.dart, diagnostics/, performance_interceptor.dart
    cache/cache_policy.dart, cached_remote.dart, ttl_cache.dart
    constants/api_constants.dart
    theme/, localization/, widgets/, monitoring/, config/
  features/
    auth/          # login/signup/social/OTP
    groups/        # groups CRUD + members
    outings/       # create, list, vote, attendance, saved, drafts UI
    chat/          # outing chat (REST + Socket.IO)
    discover/      # places + saved places DS
    notifications/ # inbox + FCM
    invites/       # deep links
    shell/, home/, splash/, setting/
```

### Feature dependency direction

`presentation` → `domain` ← `data`. `data` → `core/network`. Features should not import each other’s `data` layers casually; share via providers/DI.

### Key Flutter files

| Concern | Path |
|---------|------|
| Boot DI | `lib/core/di/app_dependencies.dart` |
| Error handling | `lib/core/error/` (`failures`, `exceptions`, `exception_mapper`, `failure_message_mapper`, `error_blueprint_logger`, `app_error_feedback`) |
| Remote guard | `lib/core/network/remote_guard.dart` |
| Request dedupe / diagnostics | `lib/core/network/request_deduper.dart`, `lib/core/network/diagnostics/` |
| TTL cache helpers | `lib/core/cache/` |
| API paths | `lib/core/constants/api_constants.dart` |
| Profile editing | `features/setting/presentation/pages/edit_profile_page.dart`, `change_password_page.dart`, and profile sheets |
| Nearby search | `features/discover/presentation/pages/discover_page.dart` → Discover provider/repository → `backend/src/services/places/nearby-search-bounds.ts` |
| Default group and outing artwork | `flutter/assets/covers/`, `lib/core/widgets/planning_cover.dart` |
| Outing API | `features/outings/data/datasources/outings_remote_datasource.dart` |
| API request audit | `docs/audit/FLUTTER_API_REQUEST_OPTIMIZATION_REPORT.md` |
| Vote UI | `features/outings/presentation/widgets/outing_vote_widget.dart` |
| Attendance UI | `…/outing_attendance_widget.dart` |
| Create outing (+ multi-place suggest) | `…/pages/create_outing_page.dart`, `…/providers/create_outing_provider.dart` |
| Create group | `features/groups/presentation/pages/create_group_page.dart` |
| Device contacts picker | `features/groups/presentation/pages/pick_device_contacts_page.dart` |
| Remote image_url helper | `lib/core/utils/remote_image_url.dart` |
| Auth | `features/auth/presentation/providers/auth_provider.dart` |
| Deep links | `features/invites/presentation/providers/invite_deep_link_provider.dart` |
| Outing chat REST | `features/chat/data/datasources/outing_chat_remote_datasource.dart` |
| Outing chat Socket.IO | `features/chat/data/datasources/outing_chat_socket_client.dart` |
| Chat message upsert/dedupe | `features/chat/domain/outing_chat_message_merge.dart` |

Tests: `flutter/test/` (when present). Project-local Cursor notes: `flutter/.cursor/rules/project-context.mdc` (may lag root docs — prefer root `docs/` + `AGENTS.md`).

### Physical Android device (local backend)

| Concern | Path |
|---------|------|
| Emulator env (default) | `flutter/.env` via `--dart-define-from-file=.env` (`API_BASE_URL=http://10.0.2.2:3000`) |
| Device env (gitignored) | `flutter/.env.device` — generated; use launch config **Yalla 5roga (physical device)** |
| Device env example | `flutter/.env.device.example` |
| Root IDE launch | `.vscode/launch.json` — **Yalla 5roga (dev)** / **(physical device)**; must pass `--dart-define-from-file` (do not use a bare `flutter` launch) |
| Flutter IDE launch | `flutter/.vscode/launch.json` — same configs when the Flutter folder is the workspace |
| LAN IP helper | `scripts/dev-physical-android.ps1` (`-PrepareOnly` or full `flutter run`) |
| Debug cleartext HTTP | `flutter/android/app/src/debug/AndroidManifest.xml` (`usesCleartextTraffic`) |
| Device testing report | `docs/audit/PHYSICAL_DEVICE_TESTING_REPORT.md` |

Backend binds with `HOST` (default `0.0.0.0`) in `backend/src/server.ts` so LAN devices can reach `PORT` (default 3000).

---

## `backend/`

```
backend/src/
  server.ts, app.ts
  routes/           # HTTP mounts
  controllers/
  usecases/
  services/         # vote-resolution, access, notifiers, channels
  realtime/         # Socket.IO auth, chat gateway, emitters
  repositories/, datasources/
  middleware/       # auth, validate, error
  validators/       # Zod
  jobs/             # deadline, completion, notification worker
  config/           # prisma, firebase, swagger, notifications
backend/prisma/schema.prisma
backend/tests/
backend/scripts/    # probes (flutter-client-scenario, outing-chat-realtime-audit)
```

### Key backend files

| Concern | Path |
|---------|------|
| Route index | `src/routes/index.ts` |
| Outing routes | `src/routes/outings/` (crud, drafts, saved, participants, voting, chat) |
| Group routes | `src/routes/groups/` (crud, members, invitations) |
| User routes | `src/routes/users/` (profile, sync, fcm) |
| Voting logic | `src/usecases/outings/voting.usecase.ts` |
| Resolution | `src/services/outings/vote-resolution.ts` |
| Eligibility | `src/services/outings/outing-participants.ts` |
| Create outing | `src/usecases/outings/create-outing.usecase.ts` |
| Attendance | `src/usecases/outings/attendance.usecase.ts` |
| Auth middleware | `src/middleware/auth.middleware.ts` |
| Outing chat realtime | `src/realtime/` (`socket-server`, `chat.gateway`, `chat-emitter`) |
| Schema | `prisma/schema.prisma` |

---

## Cross-layer modification checklist

1. API path/body change → update route + validator + Flutter `ApiConstants`/datasource + `API_CONTRACTS.md`.
2. Schema change → Prisma migration + `DATABASE_ARCHITECTURE.md` + affected business docs.
3. Lifecycle/voting change → backend services + Flutter UI refresh paths + `SYSTEM_DESIGN.md` / `USER_SCENARIOS.md` / `BUSINESS_LOGIC.md`.
4. Never change architecture pattern without ADR entry.
