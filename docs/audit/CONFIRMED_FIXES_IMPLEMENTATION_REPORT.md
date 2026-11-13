# Confirmed fixes implementation and OpenAPI verification

Date: 2026-11-13, Africa/Cairo. Work was performed in the existing local working tree, preserving prior uncommitted changes. No reset, revert, commit, dependency addition, database migration or application-data mutation was performed.

**Assessment: implementation and static validation are complete for the existing API shapes; runtime release acceptance remains incomplete. Do not release on the strength of missing-auth checks.**

| Phase | Result |
|---|---|
| 1. Contracts/security | Implemented; pre-existing curator/user-directory fixes retained |
| 2. Lifecycle/access/arrival | Implemented or confirmed present and preserved |
| 3. Draft integration | Existing four APIs wired through the existing cache/repository/provider; limitations below |
| 4. Flutter actions | Source wiring complete; no runtime/UI verification |
| 5. Documentation | Updated canonical rules, workflows and historical route labels |
| 6. OpenAPI | Structural checks complete; available non-mutating HTTP checks complete; authenticated scenarios NOT VERIFIED |

## Backend outcomes

- Invitation list returns authenticated account history OR pending unlinked rows matching the current Firebase-verified phone. The controller never trusts typed profile/body/query identity. Explicit decisions return persisted status; conflicting decisions serialize before membership creation, which remains transactional and duplicate-safe.
- All new group invitations remain pending. Verified signup/login/sync only links identity. Existing memberships remain intact. The owner requested this change, so PRODUCT_SCENARIOS and the affected canonical docs supersede the previous automatic-link membership behavior. Direct owner member-add remains separate and cannot assign owner, including direct use-case calls.
- Missing invitation response schemas/tag were already present in the working tree and were retained; all invitation refs resolve. Signup accepts phone or phoneNumber with validator-aligned bounds/pattern. Request initial outing status is no longer documented or accepted as a lifecycle decision. Notification event definitions and existing userId path parameter names are preserved/aligned.
- Notifications always default to 20, cap at 100, filter by authenticated user in PostgreSQL, and use opaque ownership-checked cursors with stable created_at/ID ordering. Native database cursor traversal preserves sub-millisecond ordering. The data envelope and next_cursor alias remain compatible; pagination.nextCursor is added.
- A dedicated outing-access check replaces chat authorization for general outing reads. Creator edit/cancel/remove permissions remain enforced. Initial status derives from options/venue. Existing cancellation fan-out and stable dedupe keys were already present and preserved; its payload now includes title and group/outing navigation IDs. Existing Socket.IO publication remains in the controller.
- Arrival handling already enforced identity, participation, confirmed venue, bounded coordinates/accuracy, sample age, server time window, distance and upsert. This was preserved and its negative-only mock signal made explicit. False/omitted is_mocked is not GPS attestation. No external provider was added.
- Global HTTP API limiting is 300 requests/IP/minute, independent of Socket.IO. Existing stricter login/signup and recovery limits remain. 429 uses the normal error envelope and Retry-After; arbitrary forwarded headers are not trusted.
- Existing catalog curator guards protect every catalog mutation, including PUT hours. PLACES_CURATOR_UIDS is unset in this environment and ordinary authenticated writes therefore fail closed. The 403 business case was not exercised without an identity.
- Existing user directory restrictions and phone-free summary projections were retained after checking direct callers. Self-profile remains at the registered /api/users/cuser route; no /me alias was invented. Authorized roster phones and verified invitation matching remain available.

## Flutter integration matrix

Every new action uses existing endpoint constants, authenticated ApiClient, data source, repository, Provider and composed UI; screens contain no direct Dio calls.

| Existing endpoint | UI/state integration | Cache/realtime |
|---|---|---|
| GET/POST /api/outings/drafts | Existing Saved Outings draft list and Create Outing save/load | Existing account/origin-scoped preferences cache; pending changes survive restart |
| PATCH/DELETE /api/outings/drafts/:id | Existing form save and saved-draft removal | Stable UUID Idempotency-Key prevents duplicate creates; If-Match checks updated_at under row lock; serialized reconnect/resume recovery; conflicts preserved without automatic overwrite |
| PATCH /api/outings/:id | Creator Edit action; prefilled title, cover, schedule and draft venue; standalone EditOutingForm | Merge committed response into affected provider and existing offline collection; preserve ordering; no extra refresh request required |
| POST /api/outings/:id/cancel | Creator-only confirmed Cancel action | Committed row updates details/history and offline list; existing scoped socket event retained |
| DELETE /api/groups/:id | Owner Group Info Delete action with confirmation | Invalidates repository cache, removes persisted group snapshot/list entry, refreshes outings and returns safely to root |
| DELETE /api/groups/:id/members/:userId | Existing confirmed Leave Group preserved | Existing backend supports self-removal and protects last owner |
| DELETE /api/outings/:id/guests/:userId | Creator participant management with confirmation and guest names | Refreshes guest list and affected snapshot; coalesced guest reads; guest snapshots reuse existing offline cache |
| POST /api/outings/:id/invitations/accept or decline | Explicit pending invitation controls in Outing Details | Refreshes affected state; decline removes access/cache; no automatic accept |
| Existing notification/invitation actions | Legacy generic invitations carrying outing IDs route to the outing, not group invitations; explicit notification actions select the correct endpoint | Persisted status checked before displaying success; existing invalidations retained |
| GET /api/notifications | Existing full inbox/unread behavior retained by following bounded pages | Cursor-repeat guard; no polling |

Server-returned suggested_by_user_id remains available for display; it is not sent in requests. Write invocation binds the existing expected-user option so token refresh/account switching does not change the actor of an in-flight mutation. Existing L10n, RTL inheritance, themes, Responsive, cover/map/form widgets and alert/snackbar patterns are reused. Chat remains text-only; mentions, identity, edit/delete and Socket.IO were not replaced.

## Validation and observed HTTP results

- Backend TypeScript: `tsc --noEmit` passed.
- Scoped Dart analysis: no issues found, including a final check of the offline collection changes.
- `git diff --check` passed under the repository's normal line-ending configuration.
- No Flutter tests, launch, emulator, device tests, rendering or hot reload. DTD discovery reported no running debug/DTD process; none was started.
- Verification imported the actual generated Swagger spec and compared it with the existing served Swagger initializer. No new endpoint was introduced. The loopback listener used the current Express app without workers; no identities/credentials were created or guessed, and no authenticated writes or fixture seeding occurred.
- Final result: **94 PASS, 0 FAIL, 15 NOT VERIFIED scenario groups**. Exact per-operation checks are in [CONFIRMED_FIXES_OPENAPI_RESULTS.json](CONFIRMED_FIXES_OPENAPI_RESULTS.json).
- Structural result: **95 production API routes documented, 97 operations, 97 unique operation IDs, 820 resolved reference occurrences, no unresolved refs or path-parameter/registration mismatches**. The two documented system operations explain the difference between route and operation counts. Development mock-storage routes are excluded from the production count.
- PASS coverage includes missing-auth rejection on protected operations; invalid empty signup/login requests; actual Swagger UI/spec serving; process/database health; public place list and nearby query; global and authentication rate limits with consistent 429/Retry-After.
- An intermediate run observed /health returning 500 because Neon was temporarily unreachable. The final /health request returned 200. This intermittent connectivity is retained here as a risk rather than hidden by the successful rerun.
- An early verification-client run used lowercase PATCH, producing transport failures. The client was corrected to send uppercase methods and rerun; these were not backend route failures.
- Initial sandbox loopback access was blocked by EACCES. The same no-mutation verification ran successfully with the granted execution override.

NOT VERIFIED:

- getPlace: no existing public place available
- listPlaceHours: no existing public place available
- listPlaceImages: no existing public place available
- listPlacePrices: no existing public place available
- AUTH successful signup/session/profile
- GROUPS create/invite/accept/decline/membership/owner protection/deletion
- INVITATIONS verified-phone discovery/history/concurrent decisions
- OUTINGS create/update/cancel/list/creator permissions
- DRAFTS CRUD/idempotency/version conflict
- VOTING proposals/votes/state/closure
- ATTENDANCE RSVP/check-in/location/access
- CHAT authenticated REST/access
- PLACES curator success/ordinary-user 403
- NOTIFICATIONS pagination/read/read-all/cancellation
- MEDIA presign/confirm/delete authorization

No existing public catalog row was returned for detail/hour/image/price checks, so these were not fabricated or seeded. Successful signup/session, user-specific authorization, invitation phone matching/history/concurrency, lifecycle mutations, voting, attendance, notification paging and R2 business cases require supplied test identities/records. Missing-auth rejection is not a substitute. Swagger browser Execute interaction, Socket.IO delivery and physical FCM/WhatsApp delivery were not exercised.

## Documentation updates

Canonical docs now match explicit invitation decisions, server lifecycle authority, bounded notification reads, trusted identity/authorization, versioned draft recovery, new UI composition, and current route shapes. SYSTEM_DESIGN includes an updated invitation/draft workflow diagram. SYSTEM_ARCHITECTURE and ARCHITECTURE_DECISIONS document the existing 512-entry/10-minute in-memory journal, epoch/sequence reconciliation, reset behavior, single-process deployment and absence of a Redis adapter. No Redis was introduced.

Affected system-design documents are explicitly labeled historical, including stale chat, invitation-decline, FCM-token and unregistered POST /outings/hydrate references. Historical JSON results/scripts are left untouched and labeled by the directory README. Older unrelated audit PASS claims are not evidence for this task.

Remaining limitations/inconsistencies are explicit: draft guest-phone selections have no field in the existing backend draft contract and remain local-only; older unscoped preferences are retained without silently assigning them to an account. No database field/schema was invented. Conflicting drafts remain locally preserved and paused; a richer conflict-resolution workflow is not implemented. Version headers are optional for compatibility, so older clients that omit If-Match retain their existing overwrite behavior. Distributed journal/rate limiting and location attestation are not implemented.

## Files changed in this task, grouped by phase

Paths may have already contained unrelated uncommitted work; this inventory does not imply authorship of their entire diff. Shared files appear in the first directly relevant phase.

### 1. Backend contracts, invitation security and bounded reads

- `backend/src/config/swagger.ts`
- `backend/src/app.ts`
- `backend/src/middleware/api-rate-limit.middleware.ts`
- `backend/src/middleware/error.middleware.ts`
- `backend/src/controllers/invitations/user-invitations.controller.ts`
- `backend/src/routes/invitations/index.ts`
- `backend/src/datasources/groups/group-invitation.datasource.ts`
- `backend/src/services/groups/claim-pending-invitations.ts`
- `backend/src/usecases/groups/claim-group-invitations.usecase.ts`
- `backend/src/usecases/groups/invite-to-group.usecase.ts`
- `backend/src/usecases/groups/add-group-member.usecase.ts`
- `backend/src/validators/groups/group.validator.ts`
- `backend/src/routes/groups/group.invitations.routes.ts`
- `backend/src/controllers/notifications/notification.controller.ts`
- `backend/src/datasources/notifications/notification.datasource.ts`
- `backend/src/validators/notifications/notification.validator.ts`
- `backend/src/routes/notifications/notification.inbox.routes.ts`

### 2. Outing lifecycle, access and arrival validation

- `backend/src/controllers/outings/outing.controller.ts`
- `backend/src/services/outings/outing-access.ts`
- `backend/src/usecases/outings/create-outing.usecase.ts`
- `backend/src/usecases/outings/arrivals.usecase.ts`
- `backend/src/validators/outings/outing.validator.ts`
- `backend/src/services/notifications/outing-notifier.ts`

### 3. Existing draft API and offline recovery

- `backend/src/types/outings/outing.types.ts`
- `backend/src/repositories/outings/i-outing.repository.ts`
- `backend/src/repositories/outings/outing.repository.ts`
- `backend/src/datasources/outings/outing.datasource.ts`
- `backend/src/usecases/outings/drafts.usecase.ts`
- `backend/src/routes/outings/outing.drafts.routes.ts`
- `flutter/lib/core/constants/api_constants.dart`
- `flutter/lib/core/di/repository_factory.dart`
- `flutter/lib/core/di/app_dependencies.dart`
- `flutter/lib/core/network/app_sync_provider.dart`
- `flutter/lib/core/cache/offline_snapshots.dart`
- `flutter/lib/features/outings/data/datasources/saved_outings_local_datasource.dart`
- `flutter/lib/features/outings/data/datasources/saved_outings_remote_datasource.dart`
- `flutter/lib/features/outings/data/repositories/saved_outings_repository_impl.dart`
- `flutter/lib/features/outings/domain/entities/saved_outing.dart`
- `flutter/lib/features/outings/presentation/providers/create_outing_provider.dart`
- `flutter/lib/features/outings/presentation/providers/saved_outings_provider.dart`
- `flutter/lib/features/outings/presentation/pages/create_outing_page.dart`
- `flutter/lib/features/outings/presentation/pages/saved_outings_page.dart`

### 4. Flutter endpoint actions, navigation and state

- `flutter/lib/core/network/api_client.dart`
- `flutter/lib/core/localization/l10n.dart`
- `flutter/lib/features/outings/data/datasources/outings_remote_datasource.dart`
- `flutter/lib/features/outings/domain/repositories/outings_repository.dart`
- `flutter/lib/features/outings/data/repositories/outings_repository_impl.dart`
- `flutter/lib/features/outings/presentation/providers/outings_provider.dart`
- `flutter/lib/features/outings/presentation/pages/event_page.dart`
- `flutter/lib/features/outings/presentation/pages/edit_outing_page.dart`
- `flutter/lib/features/outings/presentation/widgets/edit_outing_form.dart`
- `flutter/lib/features/outings/presentation/widgets/outing_management_actions.dart`
- `flutter/lib/features/groups/data/datasources/groups_remote_datasource.dart`
- `flutter/lib/features/groups/domain/repositories/groups_repository.dart`
- `flutter/lib/features/groups/data/repositories/groups_repository_impl.dart`
- `flutter/lib/features/groups/presentation/providers/groups_provider.dart`
- `flutter/lib/features/groups/presentation/pages/group_info_page.dart`
- `flutter/lib/features/groups/presentation/widgets/group_info_actions_section.dart`
- `flutter/lib/features/notifications/data/datasources/notifications_remote_datasource.dart`
- `flutter/lib/features/notifications/data/services/interactive_notification_handler.dart`
- `flutter/lib/features/notifications/domain/entities/push_notification_payload.dart`
- `flutter/lib/features/notifications/presentation/navigation/push_notification_navigator.dart`
- `flutter/lib/features/invitations/data/datasources/invitations_remote_datasource.dart`
- `flutter/lib/features/invitations/presentation/providers/invitations_provider.dart`

### 5. Documentation updates

- `docs/API_CONTRACTS.md`
- `docs/BUSINESS_LOGIC.md`
- `docs/USER_SCENARIOS.md`
- `docs/PRODUCT_SCENARIOS.md`
- `docs/AUTHENTICATION_AND_AUTHORIZATION.md`
- `docs/NOTIFICATIONS.md`
- `docs/SYSTEM_DESIGN.md`
- `docs/SYSTEM_ARCHITECTURE.md`
- `docs/ARCHITECTURE_DECISIONS.md`
- `docs/DATABASE_ARCHITECTURE.md`
- `docs/FLUTTER_ARCHITECTURE.md`
- `docs/BACKEND_ARCHITECTURE.md`
- `docs/PROJECT_STRUCTURE.md`
- `docs/system-design/07-critical-business-workflows.md`
- `docs/system-design/api-contract-matrix.md`
- `docs/system-design/flutter-backend-consistency.md`
- `docs/system-design/improvement-roadmap.md`
- `docs/system-design/integration-test-results.md`
- `docs/system-design/integration-verification-report.md`
- `docs/system-design/openapi-contract-freeze.md`
- `docs/system-design/phase-a-smoke-checklist.md`
- `docs/system-design/README.md`

### 6. Swagger/OpenAPI verification

- `backend/scripts/confirmed-fixes-openapi-verification.ts`
- `docs/audit/CONFIRMED_FIXES_OPENAPI_RESULTS.json`
- `docs/audit/CONFIRMED_FIXES_IMPLEMENTATION_REPORT.md`

Pre-existing confirmed fixes retained without new edits include place.crud.routes.ts/place.meta.routes.ts and their trusted curator guard, list-users.usecase.ts and services/auth/to-public-user.ts, the persisted-status invitation use cases, and CancelOutingUseCase's deduplicated notification fan-out. These were checked at their direct owning sources rather than re-audited globally.

## Release readiness

**Not release-ready yet.** Compile/static checks and the available OpenAPI HTTP checks pass, but the authenticated business matrix and mobile behavior are unverified. Required next evidence is authorized test identities for the listed workflows, curator configuration for legitimate catalog operations, permitted mobile/offline/multi-device verification, and stable deployment connectivity. The local-only/legacy draft boundaries above need an explicit migration/product decision if cross-device preservation of those values is required.

## Owner-requested Neon and Git synchronization follow-up — 2026-11-13

Live Prisma Migrate status confirmed that the configured Neon database already has all 12 repository migrations applied. Read-only migration-history verification found no pending migrations, failed/rolled-back applied entries, or SQL checksum mismatches. The existing media-assets migration is already deployed. No new migration or application-data mutation was needed. The first pooled-endpoint check failed; the existing backend's direct-connection normalization succeeded. Backend TypeScript was rechecked successfully; Flutter tests and app launches remained prohibited. The current working-tree commit candidates were checked for credential patterns and sensitive filenames; none were found, and staged whitespace checks passed.
