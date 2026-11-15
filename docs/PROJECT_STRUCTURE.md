# Yalla 5roga — Project Structure Map

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-15 (Phase 7/8 static structure and reference audit) |
| Documentation version | 1.1.0 |
| Purpose | Help agents locate files without full-repo scans |

## Repository root

```
yalla5roga/
  AGENTS.md                 # AI entrypoint
  README.md
  skills-lock.json          # Agent skills lockfile
  docs/                     # Canonical docs + audit/ + development/ + system-design/
  .agents/                  # Installed agent skills (Flutter + Impeccable)
  .codex/                   # Codex MCP & hooks configuration
  .cursor/rules/            # One reference to root AGENTS.md; tool skills/hooks retained
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
| Shared map infrastructure | `flutter/lib/core/widgets/yalla_map_view.dart`, `flutter/lib/core/maps/yalla_map_*.dart`, `flutter/lib/core/utils/map_location.dart` |
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

Tests: `flutter/test/` (execution depends on task restrictions). Root `AGENTS.md` is the canonical project policy; `.cursor/rules/global.mdc` references it. Open the monorepo root. The former Flutter-local Cursor policy was merged and removed in Phase 8.

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


## Phase 1 design foundation — 2026-11-13

- `flutter/lib/core/theme/app_tokens.dart`: shared spacing, radii, geometry, typography and shadow tokens; existing `app_colors.dart`, `app_palette.dart`, `app_theme.dart` and `app_motion.dart` remain the theme entry points.
- `flutter/lib/core/widgets/{group_card,outing_card,place_card,invitation_card}.dart`: feature-independent cards; existing feature card widgets remain domain adapters.
- `flutter/lib/core/widgets/app_{text_field,search_field,page_header,section_header,error_state,offline_indicator,bottom_sheet}.dart`: foundation controls and presentation helpers; field/section aliases reuse existing implementations.
- `flutter/lib/features/invitations/presentation/widgets/{group_invitation_card,invitations_states}.dart`: extracted invitation presentation pieces.
- `DESIGN.md`: Phase 1 visual contract and reusable component map.
- `docs/audit/PHASE_1_FOUNDATION.md`: scope, changed-file inventory, static validation and runtime limits.

## Phase 2 dashboard/group presentation — 2026-11-13

- `flutter/lib/features/home/presentation/widgets/home_nearby_section.dart`: real nearby preview, permission guidance and catalog fallback using existing services.
- `flutter/lib/features/groups/presentation/widgets/{create_group_fields,group_invitee_picker,group_details_header,group_name_editor,group_history_links,group_invitation_history}.dart`: focused group presentation.
- `flutter/lib/features/groups/presentation/pages/group_history_page.dart`: group-scoped invitation and outing history.
- `flutter/lib/features/groups/domain/entities/group_invitation_record.dart`: additive group roster history projection.
- `flutter/lib/features/invitations/presentation/widgets/invitations_list.dart` and `presentation/invitation_l10n.dart`: status filtering and localized history labels.
- `backend/scripts/phase2-openapi-verification.ts`: read-only Swagger/OpenAPI contract checks; results in `docs/audit/PHASE_2_OPENAPI_RESULTS.json`.
- `docs/audit/PHASE_2_UI_UX.md`: task inventory, component reuse, checks and runtime limits.


## Phase 3 outing presentation and ballots — 2026-11-14

- `flutter/lib/core/widgets/app_step_progress.dart`: localized reusable wizard progress.
- `flutter/lib/core/widgets/place_card.dart`: existing image card plus inline selectable/progress variant.
- `flutter/lib/features/outings/presentation/widgets/{outing_overview,outing_location_section}.dart`: extracted detail sections; existing RSVP, GPS, voting and management widgets retain feature responsibilities.
- Existing create step/provider files now place deadlines in Information and expose review edit links/removable selections.
- `backend/prisma/migrations/20261113180000_multi_location_ballots/migration.sql`: row-preserving vote PK expansion.
- `backend/scripts/phase3-openapi-{contracts,verification}.ts`: Swagger/HTTP checks; verification uses disposable schemas only.
- `backend/scripts/phase3-database-{backup,readback}.ts`: private logical backup, rollback-only restore/migration rehearsal and read-only postdeployment checks.
- `docs/audit/PHASE_3_*.{md,json}`: implementation, API, backup and deployment evidence. Private backup rows remain ignored under `backend/.database-backups/`.

## Phase 4 Discover / Special Event additions — 2026-11-14

- `flutter/lib/core/maps/{location_repository,location_search_provider}.dart`: shared geocoding contract and cancellable geographic search. Existing outing repository path re-exports the contract.
- `flutter/lib/core/widgets/{map_controls,vibe_picker}.dart`: shared map search, markers, preview/selection cards, current-location and vibe controls. Outing's old VibePicker path remains a compatibility export.
- `flutter/lib/features/discover/presentation/widgets/{discover_map_panel,discover_results}.dart`: feature map and result composition; DiscoverPage retains discovery actions, filters and nearby state.
- `flutter/lib/features/outings/presentation/pages/special_event_page.dart` and `widgets/special_event_fields.dart`: dedicated event entry and occasion/audience controls over the shared creation wizard.
- `backend/prisma/migrations/20261114000000_special_event_occasions/migration.sql`: additive occasion enum and optional-group special-event constraint.
- `backend/scripts/phase4-openapi-verification.ts`: served Swagger/OpenAPI HTTP verification in an automatically removed disposable schema.
- `docs/audit/PHASE_4_UI_UX.md` and `PHASE_4_OPENAPI_RESULTS.json`: implementation and verification evidence.


## Voting deadline selector — 2026-11-14

- flutter/lib/features/outings/domain/entities/voting_deadline.dart: shared client duration/instant policy.
- flutter/lib/features/outings/presentation/widgets/voting_deadline_selector.dart: feature-local Hours/Days selector.
- Existing CreateOutingProvider, create/review widgets, Outing entity/datasource and post-create EventPage: state, request-time timestamp and canonical confirmation.
- backend/src/services/outings/voting-deadline.ts: shared create deadline validation/resolution.
- backend/prisma/migrations/20261114010000_voting_deadline_durations/migration.sql: existing field/check range expansion.
- backend/scripts/voting-deadline-{openapi-verification,database}.ts: disposable-schema HTTP coverage and backed-up scoped deployment.
- flutter/test/voting_deadline_test.dart: focused policy/provider/request tests; no widget tests.
- docs/audit/VOTING_DEADLINE_*.{md,json}: implementation, API and deployment evidence.


## RSVP and countdown updates — 2026-11-14

- Existing attendance use case, controller and outing-participants service: full accepted roster and read-only no_response defaults.
- Existing Flutter outing datasource/RSVP widgets: profile-backed roster and account-scoped default persistence.
- flutter/lib/features/outings/domain/entities/vote_countdown.dart: pure remaining-time arithmetic.
- flutter/lib/features/outings/presentation/widgets/vote_countdown_text.dart: extracted 1-second, lifecycle-aware countdown, re-exported by outing_vote_widget.dart for compatibility.
- Existing core OutingCard: optional footer for inline countdown placement.
- flutter/test/rsvp_countdown_test.dart and backend/scripts/rsvp-countdown-openapi-verification.ts: headless logic/cache tests and disposable-schema API checks.
- docs/audit/RSVP_COUNTDOWN_*.{md,json}: scope and verification evidence.


## Phase 5 chat / notifications — 2026-11-14

- `flutter/lib/features/chat/presentation/widgets/{message_bubble,chat_date_separator}.dart`; existing composer/picker expose MessageComposer/MentionSuggestions names with compatibility aliases.
- `flutter/lib/core/widgets/{connection_indicator,notification_card}.dart`: shared rendering/callback components.
- `flutter/lib/features/invitations/presentation/widgets/outing_invitation_target.dart`: specific outing invitation entry, reached by the existing notification navigator.
- `flutter/ios/Runner/AppDelegate.swift`: APNs chat-action/cold-start bridge; existing notification service and handler process responses.
- `backend/src/usecases/chat/mutate-message.usecase.ts`: owner-authorized message edit/tombstone deletion through existing repository/datasource.
- `backend/scripts/phase5-openapi-verification.ts`, `docs/audit/PHASE_5_OPENAPI_RESULTS.json`, `docs/audit/PHASE_5_UI_UX.md`: HTTP-only verification and task evidence.


## GitHub / Neon synchronization — 2026-11-14

- `backend/scripts/neon-sync-deploy.ts`: target/checksum audit; explicit `--apply` backs up all public rows, rehearses keys/indexes/FKs and exact reviewed pending migrations in a rolled-back schema with an isolated occasion enum, then uses Prisma migrate deploy and verifies rows/history. Only the reviewed special-event/deadline migrations are permitted.
- `docs/audit/NEON_GITHUB_SYNC_{READBACK,DEPLOYMENT}.json`: public deployment metadata; private row backups remain ignored under `backend/.database-backups/`.


## Phase 6 settings / onboarding / auth presentation — 2026-11-14

- `flutter/lib/core/widgets/stat_card.dart`: shared localized value/label renderer.
- `flutter/lib/features/setting/presentation/widgets/settings_{account,preferences,support,about}_section.dart`, `settings_section.dart`: focused sections over existing SettingsTile/SettingsList; `delete_account_action.dart` shares destructive confirmation.
- `flutter/lib/features/auth/presentation/widgets/{auth_scaffold,signup_photo_picker}.dart`: bounded auth form and optional avatar selection.
- `flutter/lib/features/splash/presentation/providers/onboarding_provider.dart`, `widgets/onboarding_content.dart`: local first-run completion and three-step presentation.
- Existing auth datasource/repository/provider connect the already-documented self-profile DELETE; existing saved provider/pages add feedback and details navigation.
- `backend/scripts/phase6-openapi-verification.ts`, `docs/audit/PHASE_6_OPENAPI_RESULTS.json`, `docs/audit/PHASE_6_UI_UX.md`: read-only Swagger/HTTP checks, file inventory and verification limits.


## Android system push files — 2026-11-14

- `backend/src/services/notifications/{persist-notification,group-notifier,outing-events,notification-preferences,resolve-push}.ts`: transactional producers, preferences and current authorized display resolution, over existing tables.
- `backend/src/usecases/notifications/notification-state.usecase.ts`: summary/preference/system-payload orchestration through existing notification repository/datasource.
- `backend/src/jobs/notification-reminders.job.ts`: paged, locked and idempotent reminder enqueue, invoked by existing notification worker.
- Existing mutation datasources/use cases, PushChannel, notification dispatcher/worker and scoped realtime publisher contain the integrations.
- `flutter/lib/features/notifications/data/services/{notification_action_dispatcher,notification_background_runtime}.dart`: account-bound action drafts/retry and background bootstrap; existing local/FCM services handle native display.
- `flutter/lib/features/notifications/domain/repositories/notification_preferences_repository.dart`: narrow preference interface implemented by the existing notification repository.
- Existing chat page/provider/message list/bubble handle exact-message focus, while existing DI/AppSync/notification Provider connect resume and account boundaries.
- `backend/prisma/migrations/20261114030000_android_system_notifications/migration.sql`: additive JSON fields, token capability and event enum values; deployed to the application schema by the subsequent owner-authorized release task.
- `backend/scripts/android-push-openapi-verification.ts` and `docs/audit/ANDROID_PUSH_OPENAPI_RESULTS.json`: served OpenAPI/HTTP fixtures in an automatically removed disposable Neon schema, with controlled Firebase/FCM network boundaries.
- `docs/audit/ANDROID_SYSTEM_PUSH.md`: complete task inventory, verification and Android manual checklist.

Notification rollout compatibility: the existing token registration accepts notificationVersion=2 from updated clients; existing Android registrations default to 1 and retain OS-visible delivery. The additive migration includes this token capability field alongside inbox metadata and user preferences.

### Release build / notification migration deployment — 2026-11-14

- `backend/scripts/deploy-notification-migration.ts`: read-only audit by default; `--apply` checks the exact Neon target and migration checksums, backs up all public rows privately, restores tables/keys/indexes/FKs, rehearses the reviewed additive notification SQL against an isolated enum in a rolled-back schema, deploys with Prisma Migrate, and verifies original application-column checksums plus new schema attributes.
- `docs/audit/NOTIFICATION_MIGRATION_{READBACK,DEPLOYMENT}.json`: deployment metadata only; private row snapshots stay ignored under `backend/.database-backups/`.
- `docs/audit/RELEASE_APK_NEON_DEPLOYMENT.md`: build error fix, release artifacts, migration verification and practical limitations.


## Places management files — 2026-11-14

- `backend/prisma/migrations/20261114040000_places_catalog_sync/migration.sql`: additive catalog/lifecycle/taxonomy/run schema and bilingual definitions.
- `backend/src/{controllers,datasources,repositories,usecases}/places/catalog.*.ts`, `validators/places/catalog.validator.ts`, existing place CRUD and `routes/places/place.catalog.routes.ts`: one extended catalog API.
- `backend/src/services/places/{taxonomy,osm,places-sync,place-selection,catalog-notifications}.ts`: source rules, import/lease, selection checks and cross-process invalidations.
- `backend/src/config/places-openapi.ts`, `backend/src/cli/places-sync.ts`: Swagger augmentation and deployable/manual worker.
- Former `.github/workflows/places-sync.yml` and `backend/deploy/places-sync.{service,timer}`: removed on 2026-11-15; imports are manual only.
- `backend/scripts/{deploy-places-migration,places-openapi-verification,places-import-verification,places-osm-probe,places-source-health,places-live-readback}.ts`, `backend/tests/places-catalog.test.ts`: target-checked deployment, isolated lifecycle/HTTP checks and source/import evidence.
- `flutter/lib/features/discover/domain/entities/place_catalog.dart`, `presentation/providers/place_catalog_provider.dart`, `flutter/lib/core/widgets/place_catalog_filters.dart`: shared dynamic definitions, query/offline policy and widgets used by Discover/Create Outing/map picker.
- Existing canonical Place/SuggestedPlace, datasource/repository, ApiClient snapshots, AppSync, socket client, Discover and create/location views contain the integrations.
- `docs/audit/PLACES_MANAGEMENT.md` and `PLACES_*.json`: operation/deployment/verification evidence. Private row backups remain ignored under `backend/.database-backups/`.


## Saved place cards and filter — 2026-11-14

Added discover/presentation/widgets/save_place_button.dart and saved_places_list.dart. Existing Discover provider/repository/datasource, shared PlaceCard, Discover cards and SavedOutingsPage contain bookmark/filter integration.


## MapLibre vector maps — 2026-11-14

- `flutter/lib/core/widgets/yalla_map_view.dart`: shared native renderer, interaction, hit testing, attribution, selection animation and offline control.
- `flutter/lib/core/maps/yalla_map_{style,controller,camera_manager,markers,clusters,place_selection}.dart`: provider-independent style and map responsibilities.
- `flutter/lib/core/maps/yalla_map_offline*.dart`: bounded native downloads and conditional local style persistence; web excludes dart:io.
- DiscoverMapPanel and PickLocationPage adapt their existing providers to the shared widget. PlaceCatalogProvider retains camera state, bounded viewport pagination and cancellation; existing DiscoverRepository/remote datasource/ApiClient retain the networking layers.
- `flutter/tool/verify_yalla_map_style.dart`, `backend/scripts/maplibre-{style,openapi}-verification.*`: pure style export, official style/data checks and read-only served Swagger HTTP verification.
- `docs/audit/MAPLIBRE_MAP.md`, `MAPLIBRE_{OPENAPI_RESULTS,STYLE_RESULTS,STYLES}.json`: configuration, limits, evidence and unverified states.


## Discover map-first composition — 2026-11-14

- `flutter/lib/features/discover/presentation/providers/discover_map_provider.dart`: Discover selection, location, current-bounds/search policy over existing PlaceCatalogProvider/repository.
- `flutter/lib/features/discover/presentation/widgets/discover_{map_view,floating_search_bar,filter_chips,place_carousel,place_card,map_controls,selected_place_action}.dart`: seven focused map-first components. The older DiscoverMapPanel adapter remains compatible; DiscoverPage now composes DiscoverMapView directly.
- `backend/scripts/discover-map-openapi-verification.ts`: read-only served Swagger/OpenAPI verification; `docs/audit/DISCOVER_MAP_{FIRST.md,OPENAPI_RESULTS.json}` records implementation and API evidence.


## Home / group leave / Settings checks — 2026-11-14

Existing `HomeNearbySection`, `MainShell`, `AppPermissions`, `SettingsAccountSection`, `SettingsPreferencesSection`, `AppSwitch`, `NotificationsProvider`, `LocalNotificationsService`, `GroupsProvider`, `GroupInfoPage` and `GroupInfoActionsSection` hold the scoped UI/provider changes. Existing group delete use case/repository/interface/datasource thread the caller into its transactional guard. `backend/scripts/home-group-settings-openapi-verification.ts` verifies served OpenAPI-selected HTTP operations in a removed disposable schema; `docs/audit/HOME_GROUP_SETTINGS_{UPDATES.md,OPENAPI_RESULTS.json}` records evidence and limits.


## Reviewed Neon / GitHub release verification — 2026-11-14

`backend/scripts/review-neon-release.ts` verifies the known Neon target, complete migration history and checksums, refuses pending SQL, runs Prisma migrate deploy for the already-migrated state, and compares schema/history/application-row fingerprints. `docs/audit/NEON_RELEASE_SYNC_RESULTS.json` records metadata/checksums only; `NEON_GITHUB_RELEASE.md` describes the release scope and validation. No private rows or credentials are included.


## Arrival start / notification action checks — 2026-11-14

Existing `OutingArrivalsSection` and `OutingArrivalService` implement the scheduled start and GPS window gates. Existing `NotificationsPage`, `AppPageBar` and manual `L10n` place/localize the mark-all action. `backend/scripts/notifications-arrival-openapi-verification.ts` checks before/during/after-window APIs and mark-all persistence through served Swagger/OpenAPI in a removed disposable schema; `docs/audit/NOTIFICATIONS_ARRIVAL_{UPDATES.md,OPENAPI_RESULTS.json}` records scope and limits.


Notifications/loading/arrival source verification (2026-11-15): existing NotificationsPage/AppPageBar and OutingArrivalsSection/OutingArrivalService implement the app-bar action, removed indeterminate loading bars and scheduled arrival gate. See docs/audit/NOTIFICATIONS_ARRIVAL_UPDATES.md and NOTIFICATIONS_ARRIVAL_OPENAPI_RESULTS.json for scoped evidence and execution limits.


## Official Cairo/Giza ingestion — 2026-11-15

- `backend/scripts/places_sources.py`, `places-requirements.txt`: official Overture/Geofabrik acquisition, administrative clipping and immutable checksummed NDJSON artifacts; ignored working data under `backend/.places-data/`.
- Existing `src/cli/places-sync.ts` and `services/places/places-sync.ts` expose one manual orchestration path in `bulk-sync.ts`; no automatic schedule remains.
- `services/places/{import-normalization,import-store,import-ancillary,overture-taxonomy,place-vibe-classifier,catalog-cursor,public-place,data-licenses}.ts`: focused validation, transactional persistence, conservative inference, pagination and public/licensing projections. Existing `osm.ts`, taxonomy and catalog layers are reused.
- Existing catalog controller/usecase/repository/datasource/routes and OpenAPI augmentation add bounded GeoJSON, cursor/bounds aliases, complete details and license notices.
- `backend/prisma/migrations/2026111405{0000_places_free_ingestion,1000_places_unknown_price_absence}/`: deployed compatible source/evidence/unknown-price additions. `backend/licenses/`: official redistribution text/notices.
- `backend/scripts/{deploy-places-ingestion,places-ingestion-readback,places-ingestion-verification}.ts`, `tests/places-ingestion.test.ts`, existing catalog tests: target-checked migration, schema/readback, isolated Prisma/Swagger and pure logic checks.
- `.github/workflows/places-sync.yml` and `backend/deploy/places-sync.{service,timer}` were removed by owner request. The former `/sync/worker` route and due-only options are removed too.
- Three Flutter attribution files retain the shared MapLibre/client integration; no new app data path or renderer.
- `docs/audit/PLACES_INGESTION*.{md,json}`: schema inventory, migration evidence, file inventory, actual import and Swagger results.


## Phase 7/8 polish and organization — 2026-11-15

- `AGENTS.md`: consolidated project rules. `.cursor/rules/global.mdc` only references the canonical file. `backend/.specify/memory/constitution.md` preserves the workflow lookup path with a reference; installed skills, templates, hooks, manifests and MCP settings remain tool-owned.
- `docs/development/AI_UI_UX_SETUP.md`: moved tool setup guide; `docs/audit/UI_UX_AUDIT_AND_HOME_REDESIGN.md`: moved historical source audit. Canonical journey/Flutter links were updated.
- `flutter/lib/features/outings/presentation/widgets/outing_schedule_field.dart`: feature-local date/time renderer composed by CreateOutingBasicsStep; existing callbacks and schedule rules remain in the wizard/provider.
- Shared SegmentedTabs, CustomTextField and MarqueeText hold accessibility/text-scaling fixes; existing auth/group/chat/settings/outings adapters use the existing semantic palette.
- Unreferenced `splash_preview.dart` and group `cards/active_vote_tile.dart` were removed. Current onboarding and GroupOutingsList remain the live implementations. Referenced compatibility exports (`app_map.dart`, existing widget aliases) remain.
- `scripts/audit-project-structure.py`: read-only source import, screen, canonical-rule and moved-document reference audit. `backend/scripts/phase7-openapi-verification.ts`: Swagger-served HTTP/auth boundary audit with an unreachable DB target. Existing `validate-api-docs.ts` distinguishes the two explicitly documented local storage transports from JSON application API operations.
- `docs/audit/PHASE_7_8_FINAL_REPORT.md`, `PHASE_7_*` and `PHASE_8_*`: scope, evidence, move/source hashes, structure results and unverified states. No Prisma files, production assets, secrets or application interfaces were moved by this task.

The dated feature entries above preserve historical context; they are not evidence that removed deployment schedules exist in the current checkout. In particular, the places scheduling alternatives listed in the 2026-11-14 section are absent in the in-progress places-ingestion changes that preceded this audit.
