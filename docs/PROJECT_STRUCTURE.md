# Yalla 5roga — Project Structure Map

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-07 |
| Documentation version | 1.0.0 |
| Purpose | Help agents locate files without full-repo scans |

## Repository root

```
yalla5roga/
  AGENTS.md                 # AI entrypoint
  README.md
  docs/                     # Canonical architecture + product docs
  .cursor/rules/            # Cursor modular rules
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
    network/api_client.dart, dio_interceptors.dart, api_payload.dart
    constants/api_constants.dart
    theme/, localization/, widgets/, monitoring/, config/
  features/
    auth/          # login/signup/social/OTP
    groups/        # groups CRUD + members
    outings/       # create, list, vote, attendance, saved, drafts UI
    chat/          # outing chat
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
| API paths | `lib/core/constants/api_constants.dart` |
| Outing API | `features/outings/data/datasources/outings_remote_datasource.dart` |
| Vote UI | `features/outings/presentation/widgets/outing_vote_widget.dart` |
| Attendance UI | `…/outing_attendance_widget.dart` |
| Create outing | `…/providers/create_outing_provider.dart` |
| Auth | `features/auth/presentation/providers/auth_provider.dart` |
| Deep links | `features/invites/presentation/providers/invite_deep_link_provider.dart` |

Tests: `flutter/test/` (when present). Project-local Cursor notes: `flutter/.cursor/rules/project-context.mdc` (may lag root docs — prefer root `docs/` + `AGENTS.md`).

---

## `backend/`

```
backend/src/
  server.ts, app.ts
  routes/           # HTTP mounts
  controllers/
  usecases/
  services/         # vote-resolution, access, notifiers, channels
  repositories/, datasources/
  middleware/       # auth, validate, error
  validators/       # Zod
  jobs/             # deadline, completion, notification worker
  config/           # prisma, firebase, swagger, notifications
backend/prisma/schema.prisma
backend/tests/
```

### Key backend files

| Concern | Path |
|---------|------|
| Route index | `src/routes/index.ts` |
| Outing routes | `src/routes/outings/outing.routes.ts` |
| Voting logic | `src/usecases/outings/voting.usecase.ts` |
| Resolution | `src/services/outings/vote-resolution.ts` |
| Eligibility | `src/services/outings/outing-participants.ts` |
| Create outing | `src/usecases/outings/create-outing.usecase.ts` |
| Attendance | `src/usecases/outings/attendance.usecase.ts` |
| Auth middleware | `src/middleware/auth.middleware.ts` |
| Schema | `prisma/schema.prisma` |

---

## Cross-layer modification checklist

1. API path/body change → update route + validator + Flutter `ApiConstants`/datasource + `API_CONTRACTS.md`.
2. Schema change → Prisma migration + `DATABASE_ARCHITECTURE.md` + affected business docs.
3. Lifecycle/voting change → backend services + Flutter UI refresh paths + `SYSTEM_DESIGN.md` / `USER_SCENARIOS.md` / `BUSINESS_LOGIC.md`.
4. Never change architecture pattern without ADR entry.
