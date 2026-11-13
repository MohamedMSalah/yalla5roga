# Yalla 5roga — Project Structure Map

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-12 (Project structure audit & cleanup) |
| Documentation version | 1.0.1 |
| Purpose | Help agents locate files without full-repo scans |

## Repository root

```
yalla5roga/
  AGENTS.md                 # AI entrypoint
  README.md
  skills-lock.json          # Agent skills lockfile
  docs/                     # Canonical architecture + product docs + audits
  .agents/                  # Installed agent skills (Flutter + Impeccable)
  .codex/                   # Codex MCP & hooks configuration
  .cursor/rules/            # Cursor modular rules
  .vscode/                  # Workspace launch configurations
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
| Media storage | BACKEND_ARCHITECTURE §14, FLUTTER_ARCHITECTURE §14 | `backend/src/services/media/`, `flutter/lib/core/media/` |
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
| `audit/` | Compliance & verification reports (e.g. `SWAGGER_INTEGRATION_TEST_REPORT.md`, `PASSWORD_RECOVERY_REPORT.md`, `MEDIA_STORAGE_REPORT.md`) |
| `audit/database/` | Database schema refactoring plans, migration reports, audit catalogs (`DATABASE_SCHEMA_AUDIT.md`, `DATABASE_SCHEMA_REFERENCE.md`, `DATABASE_MIGRATION_REPORT.md`, `DATABASE_REFACTORING_PLAN.md`) |
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
      offline_snapshots.dart # bounded account/origin snapshots
    network/app_sync_provider.dart # foreground/realtime recovery
    media/ # media:// refs, direct upload, signed-URL resolver, account-scoped cache
    constants/api_constants.dart
    theme/, localization/, widgets/, monitoring/, config/
  features/
    auth/          # phone/password login, signup OTP and session restore
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
| Shared map infrastructure | `flutter/lib/core/widgets/app_map.dart`, `flutter/lib/core/utils/map_location.dart` |
| Outing map selection | `flutter/lib/features/outings/presentation/pages/pick_location_page.dart` and its route-local provider |
| Nearby map | `features/discover/presentation/pages/discover_page.dart` → Discover provider/repository → `backend/src/services/places/nearby-search-bounds.ts` |
| Active Votes | `features/outings/presentation/widgets/lists/active_votes_list.dart` → Outings tab |
| Outing history | Settings → `features/outings/presentation/pages/outing_history_page.dart` → current-user outing snapshot |
| Default group and outing artwork | `flutter/assets/covers/`, `lib/core/widgets/planning_cover.dart` |
| Outing API | `features/outings/data/datasources/outings_remote_datasource.dart` |
| API request audit | `docs/audit/FLUTTER_API_REQUEST_OPTIMIZATION_REPORT.md` |
| Vote UI | `features/outings/presentation/widgets/outing_vote_widget.dart` |
| Attendance UI | `…/outing_attendance_widget.dart` |
| Physical arrival | `OutingArrivalsSection` owns route lifecycle. `OutingArrivalService` verifies GPS via `backend/src/usecases/outings/arrivals.usecase.ts`. The existing Socket.IO transport invalidates the roster. |
| Special-event invite copy | `backend/src/services/whatsapp/special-event-invitation.ts` |
| Create outing (+ multi-place suggest) | `…/pages/create_outing_page.dart`, `…/providers/create_outing_provider.dart` |
| Create group | `features/groups/presentation/pages/create_group_page.dart` |
| Pending group invitations | `features/invitations/` (`presentation/pages/invitations_page.dart`, `presentation/providers/invitations_provider.dart`, repository/remote datasource). Opened from Settings, group-invite push and deep links. Accept/Decline via `/api/invitations/*` |
| Device contacts picker | `features/groups/presentation/pages/pick_device_contacts_page.dart` |
| Remote image_url helper | `lib/core/utils/remote_image_url.dart` (accepts http(s) + `media://`) |
| Media references / upload / delivery | `flutter/lib/core/media/` (`media_reference.dart`, `media_upload_service.dart`, `media_url_resolver.dart`, `media_url_store.dart`) |
| Media backend | `backend/src/config/media.ts`, `services/media/`, `routes/media/`, `jobs/media-cleanup.job.ts` |
| Auth | `features/auth/presentation/providers/auth_provider.dart` |
| Deep links | `features/invites/presentation/providers/invite_deep_link_provider.dart` |
| Outing chat REST | `features/chat/data/datasources/outing_chat_remote_datasource.dart` |
| Outing chat Socket.IO | `features/chat/data/datasources/outing_chat_socket_client.dart` |
| Chat message upsert/dedupe | `features/chat/domain/outing_chat_message_merge.dart` |
| Durable chat sends | `features/chat/data/datasources/chat_send_queue.dart` |
| Scoped change events | `backend/src/realtime/data-changes.ts` |

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
  services/         # vote-resolution, access, notifiers, channels, media storage
  realtime/         # Socket.IO auth, chat gateway, emitters
  repositories/, datasources/
  middleware/       # auth, validate, error
  validators/       # Zod
  jobs/             # deadline, completion, notification worker, media cleanup
  config/           # prisma, firebase, swagger, notifications, media/R2
backend/prisma/schema.prisma
backend/tests/
backend/scripts/    # probes and the real Firebase/Neon backend-full-integration suite
```

### Key backend files

| Concern | Path |
|---------|------|
| Media storage | `src/config/media.ts`; adapters + lifecycle in `src/services/media/`; routes in `src/routes/media/` |
| Route index | `src/routes/index.ts` |
| Optional geocoding | `backend/src/routes/places/place.geocoding.routes.ts` → `backend/src/services/places/geocoding.ts` |
| Outing routes | `src/routes/outings/` (crud, drafts, saved, participants, voting, chat) |
| Group routes | `src/routes/groups/` (crud, members, invitations) |
| User routes | `src/routes/users/` (profile, sync, fcm) |
| Voting logic | `src/usecases/outings/voting.usecase.ts` |
| Resolution | `src/services/outings/vote-resolution.ts` |
| Eligibility | `src/services/outings/outing-participants.ts` |
| Create outing | `src/usecases/outings/create-outing.usecase.ts` |
| Attendance | `src/usecases/outings/attendance.usecase.ts` |
| Auth middleware | `src/middleware/auth.middleware.ts` |
| Verified phone identity and legacy OTP repair | `src/services/phone/phone-identity.ts`; auth signup/login and `usecases/users/sync-user.usecase.ts` |
| Group account-linking regression checks | `backend/tests/group-account-linking.test.ts`, `group-membership.database.test.ts`, `flutter/test/group_account_linking_test.dart`; read-only audit `backend/scripts/group-membership-audit.ts` |
| Outing chat realtime | `src/realtime/` (`socket-server`, `chat.gateway`, `chat-emitter`) |
| Schema | `prisma/schema.prisma` |

---

## Cross-layer modification checklist

1. API path/body change → update route + validator + Flutter `ApiConstants`/datasource + `API_CONTRACTS.md`.
2. Schema change → Prisma migration + `DATABASE_ARCHITECTURE.md` + affected business docs.
3. Lifecycle/voting change → backend services + Flutter UI refresh paths + `SYSTEM_DESIGN.md` / `USER_SCENARIOS.md` / `BUSINESS_LOGIC.md`.
4. Never change architecture pattern without ADR entry.

Outing feature verification uses `backend/scripts/backend-full-integration.ts`. The `--custom-session-features` mode runs the overlapping-outing, RSVP, venue, arrival and chat scenarios with disposable Firebase custom-token identities when the full OTP fixture set is unavailable.


## Chat and realtime verification additions — 2026-11-11

- `backend/src/services/chat/chat-mentions.ts`: stable-ID mention validation and canonicalization.
- `backend/src/realtime/data-changes.ts`: domain invalidations and bounded authenticated replay.
- `backend/scripts/chat-openapi-verification.ts`: disposable-fixture API checks selected by OpenAPI operation IDs; no Flutter execution.
- `docs/audit/CHAT_REALTIME_OPENAPI_VERIFICATION.md`: current task API results and runtime verification limits.


## Centralized realtime additions — 2026-11-11

- `backend/src/realtime/group.gateway.ts`: group room authorization on the existing Socket.IO server.
- `flutter/lib/core/network/realtime_change.dart`: shared event envelope, bounded deduplication and acknowledged replay checkpoint.
- `backend/tests/realtime-group-gateway.test.ts`, `realtime-commit.test.ts`: group authorization and post-commit publication checks.
- `flutter/test/realtime_cursor_test.dart`: reconnect race and account-boundary regression checks.
- `docs/audit/CENTRALIZED_REALTIME_SYNC.md`: event contracts, scoped file changes, validation and remaining limits.

## Password recovery files — 2026-11-11

- `flutter/lib/features/auth/presentation/pages/password_recovery_page.dart` and `providers/password_recovery_provider.dart`: route-local recovery form/state.
- Existing auth repository/datasources and `FirebaseAuthService`: API and isolated OTP proof adapters.
- `backend/src/usecases/auth/password-recovery.usecase.ts`: recovery orchestration.
- `backend/src/repositories/auth/password-recovery.repository.ts`: Prisma grants, rate limits and transactional password replacement.
- `backend/src/routes/auth/index.ts`, auth controller/validator: HTTP/OpenAPI contracts.
- `backend/prisma/migrations/20261111180000_password_recovery/migration.sql`: additive security-state tables.
- `backend/tests/password-recovery.api.test.ts`: real HTTP/OpenAPI checks with disposable PostgreSQL schema and controlled Firebase boundary.
- `docs/audit/PASSWORD_RECOVERY_REPORT.md`: file list, verification and deployment/authentication limitations.

## Confirmed integration additions — 2026-11-13

- `backend/src/middleware/api-rate-limit.middleware.ts`: bounded global HTTP API limit.
- `backend/scripts/confirmed-fixes-openapi-verification.ts`: generated-spec checks and OpenAPI-driven, non-mutating HTTP verification.
- `flutter/lib/features/outings/presentation/pages/edit_outing_page.dart`, `widgets/edit_outing_form.dart`, `widgets/outing_management_actions.dart`: focused editing and existing endpoint actions.
- Draft persistence extends existing saved-outings datasource/repository/provider files; no second draft service exists.
- `docs/audit/CONFIRMED_FIXES_IMPLEMENTATION_REPORT.md` and `CONFIRMED_FIXES_OPENAPI_RESULTS.json`: scoped changes, runtime results and remaining verification limits.
