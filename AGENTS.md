# Yalla 5roga — Canonical Agent Instructions

This is the single source of project rules. Read it before every repository task.
Product authority remains [docs/PRODUCT_SCENARIOS.md](docs/PRODUCT_SCENARIOS.md).

## Project Overview

Yalla 5roga plans group outings and special events in Egypt: invitations,
multi-place voting, independent RSVP and GPS arrival, outing chat, discovery,
bookmarks, drafts and notifications. Application data belongs in Neon, never
Firebase. Verify implemented behavior in source before claiming it works.

- Application: `flutter/`, package `yalla_5roga`, entry `lib/main.dart` →
  `AppDependencies.create()` → `lib/app.dart`.
- API: `backend/`, entry `src/server.ts` → `src/app.ts`.
- Canonical docs: `docs/*.md`; evidence: `docs/audit/`; historical deep dives:
  `docs/system-design/`; tool setup: `docs/development/`.
- Locate code through [docs/PROJECT_STRUCTURE.md](docs/PROJECT_STRUCTURE.md).

## Technology Stack

- Flutter/Dart, Provider/ChangeNotifier, feature-first Clean Architecture,
  Dio/ApiClient, dartz Either, Equatable, SharedPreferences.
- Manual DI in AppDependencies/RepositoryFactory; imperative GetX navigation
  through GetMaterialApp. Do not introduce get_it, another state architecture,
  generated localization or declarative routing without an approved ADR.
- Material 3, Inter (English), Cairo (Arabic), manual L10n; light/dark themes.
- MapLibre (`maplibre_gl`), shared YallaMapView, geolocator and existing
  geocoding adapters. Do not restore the removed flutter_map renderer.
- Node.js, TypeScript, Express, Prisma, Neon PostgreSQL; pnpm backend tooling.
- Firebase Authentication for identity/OTP/custom sessions; FCM through the
  backend notification outbox/worker. Preserve existing media storage adapters.

## Flutter Architecture & Rules

`UI → Provider → domain Repository (Either) → data RemoteDataSource → ApiClient/Dio`.
Dependencies point `presentation → domain ← data`; reuse existing interfaces.

- Pages compose widgets; state, network calls and decisions belong in existing
  providers/services/repositories. Shared rendering takes data and callbacks.
- Shared components belong in `lib/core/widgets/`; feature-specific components
  stay in that feature's `presentation/widgets/`. Extract actual duplication,
  not speculative frameworks. No production mock/demo data layers.
- Presentation must not import Dio, http, Firebase or socket_io_client directly.
  SDK-specific adapters belong in data/core infrastructure.
- Register new app-wide providers in both AppDependencies and App.
- Use ApiConstants paths, existing payload helpers and snake_case mapping.
- Read RSVP/voting from outing-scoped providers; preserve optimistic rollback,
  server-returned choices and independent GPS arrival.
- Actual arrival starts at scheduled outing time only while the route is visible
  and foregrounded, with OS permission and the existing confirmed venue/window/
  radius/accuracy checks. Unverified people are not arrivals; permission/location
  failure must remain distinct. Stop route timers/listeners on leaving/background.
- Saved places/outings use backend APIs; preferences/snapshots are not their sole
  source of truth. Preserve media:// resolution and account-scoped image caching.
- Do not show raw exceptions, HTTP codes, tokens or backend stacks in UI; use
  existing failures, AppErrorFeedback, FailureMessageMapper and L10n.

## Backend Architecture & Rules

`Route → auth/validation middleware → Controller → UseCase → Repository/Datasource → Prisma`.

- Controllers adapt HTTP; use cases/services own business and authorization.
- Protect routes with authMiddleware unless intentionally public. Validate with
  existing Zod/validate middleware and use errorMiddleware/envelope conventions.
- Extend existing endpoints before inventing parallel routes.
- Use existing transactions/locks for create+owner RSVP, replacing candidates/
  ballots, voting closure, winner resolution and other atomic workflows.
- Backend owns deadlines, closure, winner, cryptographic tie-break, cancellation,
  authorization and notification triggers. Client animation only displays results.
- Groups support overlapping outings; writes/deduplication are outing-scoped.
- No group-level chat. Completed/cancelled/two-hour-closed outing chat is read-only;
  retain authorized history, message ownership and the one-minute edit window.
- Invitation acceptance/decline is explicit. Verified-phone linking of pending
  identities must never silently accept invitations or create membership.
- Group editing is group-owner only; outing editing/cancellation is creator only.
  Owner is resource-scoped (`created_by`), never a global authorization role.
- Record arrival for the authenticated eligible participant independently of RSVP;
  invalidate the current roster after commit. Do not store GPS coordinates in
  arrival records. WhatsApp requires consent and configured Business credentials;
  membership never depends on delivery success.

## Database & Prisma Rules

- Schema: `backend/prisma/schema.prisma`; migrations/seeds stay under Prisma.
  Neon is authoritative; Firebase UID is the corresponding `users.id`.
- Preserve all existing migrations, IDs, foreign keys, indexes and user data.
  Prefer additive migrations; no silent reset or destructive production migration.
- Multiple-place ballots use one row per `(outing_id, user_id, option_id)`;
  count distinct voters for participation. Do not restore single-choice uniqueness.
- Winner options must belong to their outing. RSVP (`outing_attendance`) is
  separate from votes and GPS presence (`outing_arrivals`). Creator remains Going.
- Preserve deadline/status indexes and current enums; obsolete `upcoming` and
  `not_voted` are not backend lifecycle/RSVP enum values.
- No production DB operations for file cleanup. Deployment requires explicit
  task authorization, target verification and the existing backup/rehearsal flow.

## API Contracts

- Consult [docs/API_CONTRACTS.md](docs/API_CONTRACTS.md) and existing Swagger
  definitions; never invent paths or tables. Preserve existing request/response
  contracts, `/api` prefixes and error envelopes.
- Chat REST history/send/read lives under `/api/outings/:outingId/…`.
  REST remains canonical; Socket.IO does not create a second write pipeline.
- Keep static routes ahead of dynamic ID routes. Update contracts and affected
  client adapters in the same task when an authorized contract changes.

## Authentication & Authorization

- Firebase verifies identity; Neon owns profile data and bcrypt application
  passwords. Phone/password login uses existing custom-token sessions; signup
  and recovery use Firebase phone OTP proof. Preserve account identity.
- Backend derives UID from verified Firebase tokens for REST and Socket.IO.
  Client-provided sender, role, UID, room or phone cannot grant authorization.
- Enforce current resource participation/ownership server-side even when UI hides
  controls. Pending-only invitees cannot vote/chat as accepted members.
- Restore only profiles matching the current Firebase account; one deferred
  users/sync follows cached boot. Ordinary reads/resume must not repeatedly sync
  accounts or force token refresh. Keep verified-phone proof and account epochs.
- Logout/account switches clear account-scoped state, pending actions and rooms;
  asynchronous callbacks from prior identities must not affect the new account.
- Never persist/log credentials, tokens, hashes, Authorization headers or private
  user rows in reports. Preserve sanitizers and expectedUserId guards.

## Socket.IO & Real-Time Rules

- One shared session socket on the API host at `/socket.io`; Firebase token in
  handshake. User/group/outing room audiences are authorized on the server.
- Group rooms carry domain invalidations, never group chat. Outing chat rooms
  are reference-counted and left after their last viewer closes.
- Keep the shared transport available for other active consumers; closing a
  chat is not a reason to break all application realtime updates.
- Dispose route-local subscriptions, timers, focus/animation/text controllers;
  cancel provider listeners on disposal and disconnect on logout/account switch.
- Keep bounded retries, generation guards, in-flight deduplication, debounce and
  targeted REST recovery. No unnecessary polling, per-screen sockets or sync loops.
- Message IDs/client UUIDs dedupe REST/socket/outbox delivery. Reconnect repairs
  gaps over REST; in-memory replay is not a durable distributed event log.
- Preserve the current single long-lived Node process topology; multi-instance
  Socket.IO/Redis changes require an ADR.

## Caching & Offline Rules

- Reuse existing CachePolicy/TTL/RequestDeduper, OfflineSnapshots, chat caches,
  ChatSendQueue and AppSyncProvider. Do not add a second cache/connectivity layer.
- Scope cached data to account and backend origin, retain size/retention bounds,
  ignore old-generation responses, and evict unauthorized snapshots.
- Cached views hydrate before authenticated REST revalidation. Foreground sync
  remains silent globally; chat owns its local connection/pending/failed feedback.
- Only existing durable chat sends and explicitly documented draft/notification
  action recovery replay. Do not queue votes, RSVP, GPS, membership, invitations,
  security, deletes or lifecycle commands as generic offline mutations.
- Preserve cached images, media refs, offline map limits and failure fallbacks.

## UI/UX & Reusable Widgets

The existing application and DESIGN.md are the design authority. Polish preserves
its visual language, product copy and features. No redesign or new dependency
without explicit approval.

1. Read the journey/Flutter docs, target screen, tokens and its existing controls.
2. Reuse AppTheme, AppPalette, AppColors, AppMotion, app_tokens, Responsive and
   core/widgets before adding local colors, dimensions, components or motion.
3. Preserve English/Arabic through manual L10n, logical directional APIs and
   Directionality. Use established Arabic-Indic formatters; mirror navigation.
4. Cover loading, empty, error, offline, keyboard, long text and narrow/wide/
   foldable layouts using Responsive content limits and safe areas.
5. Provide semantics for non-text controls, keyboard focus, readable contrast,
   textScaler resilience and at least 48dp effective touch targets unless an
   established component explicitly documents an intentional exception.
6. Keep purposeful hierarchy, concise localized copy and one primary action per
   task state. Avoid arbitrary gradients, duplicate/nested cards, decorative
   motion and generic AI visual tropes.
7. Use existing transitions, honor reduced motion and release animation resources.
8. Run permitted static checks; visually inspect theme/locale/size/input states
   only when allowed. Report every unexercised state; never claim visual sign-off
   from source inspection.

Use installed Dart/Flutter skills selectively and `$impeccable` for focused
critique/audit/polish/responsiveness/accessibility/motion; preserve existing design.
Use Dart MCP diagnostics/symbol lookup when available. Do not apply localization
or declarative-routing setup skills to this established manual L10n/GetX app.
For supplied Figma designs, inspect authenticated variables/components first;
screenshots alone do not establish its design system. Refero informs patterns,
never copied content or a replacement visual language. Configuration is not proof
that an MCP connection or hook is authenticated/enabled.

## Coding Standards

- Follow established feature/file naming, typed errors and layer boundaries.
- Remove verified dead code/imports and duplicate implementations only after
  checking usages (including tests, scripts, CI, configuration and documentation).
- Format modified Dart files; resolve introduced analyzer errors/warnings.
- Preserve working integrations and public compatibility exports with consumers.
- Keep scripts in existing root/backend scripts or Flutter tool directories;
  keep historical evidence separate from canonical architecture documentation.
- Prefer focused edits over repository-wide formatting or unnecessary renames.

## Testing & Verification Restrictions

- Run relevant checks after implementation, subject to the current task's
  explicit restrictions. Historical task restrictions are not permanent policy.
- **Phase 7/8 scope:** Flutter static analysis only; no Flutter launch, emulator,
  physical device, runtime/widget/integration tests or UI automation. Verify
  affected backend APIs through served Swagger/OpenAPI only. No production DB
  writes or unnecessary database operations. Do not hot reload for this audit.
- Use read-only/unauthenticated HTTP checks when no authorized disposable session
  exists; report authenticated and realtime/device behavior as unverified.
- Never run deployment/start scripts blindly: `backend` start deploys migrations.
  Import the Express app for isolated HTTP contract checks without starting jobs.
- Distinguish source evidence, analyzer output, HTTP results and runtime proof.

## Agent Workflow & Safety Rules

1. Read this file; identify affected layers. Read only relevant docs below.
2. Locate implementation via PROJECT_STRUCTURE; inspect those sources first,
   expanding only for dependencies. Do not scan/read everything by default.
3. Check git status and concurrent ownership before edits; preserve unrelated
   uncommitted changes. Do not commit, reset or overwrite others' work unasked.
4. Product rules come from PRODUCT_SCENARIOS; unresolved contradictions are
   compliance issues until owner-approved. Verify docs against current source.
5. Never introduce an architecture pattern conflicting with accepted ADRs.
6. Before deleting/moving, check references and unique content; update consumers
   in the same task. Do not delete files merely because they look unused.
7. Preserve env files, secrets, required tool/build configuration, production
   assets, all migrations/schema/seeds and user data. Inspect exact absolute
   targets before recursive filesystem operations; prefer nonrecursive cleanup.
8. Consolidate project rules here. Retain tool-specific loaders/references only
   when useful for the installed setup; do not duplicate policy in them.
   Installed skills/subagent workflows are tool packages, not project-rule copies.
9. Synchronize all directly affected docs in the same task and run permitted
   verification. Final reports include **Documentation Updates**, files/changes,
   whether diagrams changed, remaining inconsistencies and verification limits.

### Selective documentation entry points

| Task | Read first |
|---|---|
| Flutter UI | USER_SCENARIOS journey + FLUTTER_ARCHITECTURE + PROJECT_STRUCTURE |
| Provider/repository | FLUTTER_ARCHITECTURE + API_CONTRACTS if networked |
| Backend API | BACKEND_ARCHITECTURE + API_CONTRACTS |
| Database/Prisma | DATABASE_ARCHITECTURE + relevant BUSINESS_LOGIC |
| Auth/invitations | AUTHENTICATION_AND_AUTHORIZATION + USER_SCENARIOS + affected API/DB |
| Notifications | NOTIFICATIONS + related backend/API |
| Voting/attendance/lifecycle | USER_SCENARIOS + SYSTEM_DESIGN + BUSINESS_LOGIC; DB as needed |
| Cross-layer/system-wide | SYSTEM_ARCHITECTURE + SYSTEM_DESIGN + directly affected docs |

### Mandatory same-task documentation mapping

| Change | Update under docs/ |
|---|---|
| System components / technical workflows | SYSTEM_ARCHITECTURE / SYSTEM_DESIGN |
| Journeys / business rules | USER_SCENARIOS / BUSINESS_LOGIC and USER_SCENARIOS |
| Flutter / backend patterns | FLUTTER_ARCHITECTURE / BACKEND_ARCHITECTURE |
| Schema / API | DATABASE_ARCHITECTURE / API_CONTRACTS |
| Auth / notifications | AUTHENTICATION_AND_AUTHORIZATION / NOTIFICATIONS |
| Architecture decisions / folder layout | ARCHITECTURE_DECISIONS / PROJECT_STRUCTURE |
| Product scope | PROJECT_OVERVIEW / owner-approved PRODUCT_SCENARIOS |

Voting, invitations, attendance and lifecycle workflow changes also update
SYSTEM_DESIGN, BUSINESS_LOGIC and USER_SCENARIOS, plus API/DB docs if affected.
Update Mermaid diagrams when flows/ER relationships change. Label implemented,
partial, missing and unverified behavior explicitly; historical audits are evidence
at their recorded revision, not current product authority. Do not postpone docs.
