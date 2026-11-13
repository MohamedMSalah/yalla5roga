# Phase 3 outing planning implementation

Completed 2026-11-14 (Africa/Cairo). Scope: Outings tab, three-step creation, details composition, RSVP, multi-location voting, GPS feedback and history. Existing Material 3/theme/palette/Responsive, Provider, feature-first Clean Architecture, Dio, manual L10n and Socket.IO coordination remain.

## Delivered behavior

| Surface | Implementation |
| --- | --- |
| Outings | Shared OutingCard adapters for Active Votes and Upcoming, status labels, server-deadline countdowns, New Outing and History; reusable skeleton, empty, retry/error and local offline states; Responsive content-width limit. |
| Information | Optional uploaded cover, title, existing category/vibe, group selector, date/time and voting deadline; group context from Group Details remains preselected. |
| Locations | Existing full-screen searchable map picker, catalog/nearby pins, single/multiple selection, ordered current selection and explicit removal controls. |
| Review | Cover/title/category/group/schedule/locations/deadline summary, edit links to prior steps, existing create confirmation and canonical detail navigation. Route-local provider retains state; system Back returns to the preceding step. |
| Details | EventPage coordinates OutingOverview, OutingAttendanceWidget (RSVP), OutingVoteWidget, OutingArrivalsSection (actual attendance), OutingLocationSection and existing management. Save/Unsave labels, View Location and Chat retain existing service paths. |
| RSVP | Going/Maybe/Not Going immediately after attendance hydrates; selected state, persisted tallies, avatar stack and roster; creator remains Going; independent from place votes and arrivals. |
| Voting | Single fixed venue has one PlaceCard without a competition. Multiple options have unsent checkbox edits and an explicit atomic ballot submit. Counts, participation progress, option shares and deadline/results use server state. Confirmed location comes from the server. |
| GPS | Existing foreground service retains participant/window/accuracy/time/radius rules. Checking, verified, outside radius, denied permission, unavailable/error and closed-window feedback are distinct; retry gets a fresh fix. |
| History | Existing scheduled-start or terminal-status classification is preserved. Completed details and chat history remain readable, while the existing backend rejects new completed-chat messages. |

## Backend and migration

The owner explicitly approved multiple location votes and later requested Neon deployment. PUT /api/outings/:id/votes accepts 0–5 distinct option IDs and replaces only the authenticated caller's ballot. An outing-row lock protects validation, replacement and existing early resolution in one transaction. Distinct users determine participation; selected rows determine each option's tally. Highest-count winner, tied-leader owner RNG, zero-vote cancellation and creator venue confirmation remain server-owned. Existing POST adds an idempotent selection; DELETE removes one/all and shares the state/deadline lock.

Migration `20261113180000_multi_location_ballots` expands the vote primary key to (outing_id, user_id, option_id) without deleting data or replacing stable IDs/FKs. It was deployed using **Prisma Migrate**, never db push/reset. [Deployment readback](PHASE_3_DATABASE_DEPLOYMENT.json) verifies the live file checksum, finished migration, primary key and valid constraints. Prisma reports all 13 migrations applied.

Verified SQL target: project `rough-mountain-69896781`, branch `br-fragrant-heart-avfm4h2t`, database `neondb`, role `neondb_owner`. HTTPS metadata and PostgreSQL readback agree. Branch display names and Neon control-plane restore window were not independently queried. The normal TCP path timed out; Prisma deployment and database tests used a temporary loopback bridge to Neon's encrypted WebSocket endpoint. No credentials or connection strings are committed.

[Backup evidence](PHASE_3_DATABASE_BACKUP.json): 27 tables and 659 rows captured privately under ignored backend/.database-backups/. Restore recreated keys and FKs with identical per-table checksums, rehearsed the vote migration, then rolled back. Live votes were empty at backup and remained empty after deployment; a seeded old-format ballot in the isolated API schema verifies preservation of nonempty selections. Postdeployment checks found no remaining Phase 3 temporary schemas.

## Verification

- Dart format completed on changed files; final verification checks formatting without broad unrelated edits.
- Full `flutter analyze --no-pub`: **zero errors**; 5 warnings and 16 informational diagnostics remain in unrelated existing auth/network/chat/discover/invites/notifications/settings files. No Phase 3 diagnostic remains after cleanup.
- Dart MCP targeted analysis: no errors in outing presentation/data/domain and affected shared components/localization.
- Prisma Client generation and backend `pnpm exec tsc --noEmit`: passed.
- [OpenAPI HTTP results](PHASE_3_OPENAPI_RESULTS.json): **76 passed**. Uses real PostgreSQL in a disposable schema and actual outing routers, validators, controllers, use cases and repositories, with a controlled Firebase verifier. Includes migration preservation, multi-selection add/remove/clear, duplicate/foreign option rejection, outsider authorization, distinct voter counts, RSVP/vote independence, immediate RSVP, early unique winner, locked/expired voting, existing tie RNG authorization, single venue, edit/cancel authorization, saved state, completed chat read/send rejection, and accepted/outside/outsider GPS outcomes. The suite removed its schema in finally.
- [Swagger contract results](PHASE_3_OPENAPI_CONTRACT_RESULTS.json): generated served spec, atomic request/response shape and missing/invalid authentication for 14 affected operations passed. Existing tie-break 403/404/409 responses were documented after verification exposed the gap.
- The existing direct lifecycle regression source was updated to replace a full ballot when changing a selection. It was not executed: behavioral verification in this task was HTTP/OpenAPI only.

No Flutter app, emulator, device, widget/integration tests, hot reload or UI automation was launched. Phone/wide/foldable, light/dark, English/Arabic, keyboard and text-scaling rendering were not visually exercised. Physical GPS/permission interaction, actual Firebase token issuance, Socket.IO delivery, push/WhatsApp delivery and backend hosting rollout were not tested by this phase. Existing real-time wiring was verified in source; no second transport was added.

## Documentation Updates

PRODUCT_SCENARIOS and BUSINESS_LOGIC now record owner-approved multi-location ballots and distinct-voter closure. USER_SCENARIOS documents each new flow. API_CONTRACTS documents PUT/state fields and compatibility. DATABASE_ARCHITECTURE records the key migration/deployment. FLUTTER_ARCHITECTURE and BACKEND_ARCHITECTURE document component/use-case responsibilities. SYSTEM_DESIGN's voting sequence diagram was updated to full-ballot submission. ADR-021 records the atomicity/compatibility decision. PROJECT_STRUCTURE and DESIGN map the new components and verification artifacts. Remaining inconsistencies: no known Phase 3 code/contract mismatch; the unrelated analyzer findings and runtime coverage gaps above remain.
