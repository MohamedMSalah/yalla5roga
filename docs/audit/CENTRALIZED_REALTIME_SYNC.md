# Centralized realtime synchronization

Date: 2026-11-11. Scope: extend the existing architecture in the working tree; preserve unrelated changes. No schema migration or dependency added.

## Audit and implementation

- One `OutingChatSocketClient` is constructed in `AppDependencies`; one `io.io(...)` creation site is guarded by the existing connection/completer/session state. Chat, arrivals and `AppSyncProvider` reuse it. Backend `attachRealtime` still creates one Socket.IO server on the existing HTTP listener.
- Firebase authenticates the transport. The server assigns `user:{uid}`. Existing `outing:{id}` joins retain participant authorization. New `group:{id}` joins validate UUIDs and query Neon membership. Flutter synchronizes group subscriptions from its loaded list and restores them on reconnect. Domain fan-out uses server-resolved user rooms so list screens receive updates without opening a detail room. Room occupancy alone never grants domain access.
- Existing post-commit publication covers group create/update/delete; add/remove/claim membership; pending invitation changes; outing create/update/delete; guest add/remove/accept/decline; vote options, vote/unvote, closure, tie break, venue confirmation, cancellation and completion. Chat REST persists before live delivery. No event is sent from inside an uncommitted Prisma transaction.
- Attendance now publishes the committed row before the follow-up roster read. Its audience excludes pending-only guests. Direct application updates Provider state, datasource snapshot, repository TTL snapshot and bounded offline attendance data. `updated_at` guards against older live/REST rows; authoritative attendance denial drops cached in-memory rows. Pending local RSVP keeps its existing overlay and rollback behavior.
- Incomplete group events fetch that group, including newly created IDs. Group details update the list TTL cache. Incomplete outing events fetch one outing, including unknown/new IDs; they no longer force a full feed read. Membership changes retain broader list/active-chat reconciliation because permissions span resources.
- One coordinator listener coalesces dirty IDs for 250 ms. Complete attendance and chat payloads do not trigger GET requests. Duplicate attendance rows do not notify widgets. No invalidation handler writes through REST, emits another event or starts periodic polling. Redundant controller publications after vote resolution/tie break/venue confirmation were removed.
- Live events are deduplicated by server epoch/sequence, but only reconciliation acknowledgement advances the recovery checkpoint. This closes the reconnect race where a new live event could acknowledge earlier missed events. Replay includes original event cursors. Attendance replay contains an outing identifier, requiring current REST authorization rather than exposing historical rows.
- Account generations protect initialization, recovery, sync and send completions. Socket callbacks and queued domain events carry/check their session generation. Logout clears rooms, desired subscriptions, cursor/dedupe state, feature state, snapshots and pending sends. An old completion cannot clear a new session's recovery lock.
- Both chat messages and read receipts filter current recipients even if a socket remains in a previously authorized room. Rejected group/outing rejoin also leaves that stale room. Existing REST chat sends, client UUID deduplication, history and offline send queue remain intact.

## Event contracts

All events use the existing `/socket.io` transport and Firebase session. REST routes and envelopes are unchanged.

| Event | Payload / behavior |
| --- | --- |
| `group:join`, `group:leave` | C→S `{groupId: UUID}`; ack `{ok,room?,error?}`. Join checks current group membership. |
| `outing:join`, `outing:leave` | Existing C→S `{outingId: UUID}`; participant-authorized chat rooms. |
| `data:changed` | S→C `{kind,id?,payload?,cursor:{epoch,sequence}}`. Existing `group`, `membership`, `outing`, `outings`, `profile`, `inbox` remain invalidations. |
| `data:changed` attendance | `kind:"attendance"`, `id:outingId`, `payload:{user_id,status,updated_at}`. Status is `going`, `not_going` or `maybe`. Complete row applies directly when the outing is loaded; missing/invalid data falls back to a targeted read. |
| `data:reconcile` | C→S last acknowledged cursor or `{}`; ack `{ok:true,reset,cursor,changes}`. Replay entries include original cursors. Attendance becomes an `outing` hint without historical payload. |
| `outing:message`, `outing:read` | Existing complete canonical chat message/read payloads; current-recipient filtering. |
| `outing:arrival_changed` | Existing verified-arrival roster invalidation; does not trigger a new GPS sample. |

Live dedupe memory is capped at 1,024 cursor keys. Server replay remains capped at 512 global events / ten minutes. Neither client cursor nor server replay is persisted across restarts; reset invokes existing bounded REST recovery.

## Files changed in this task

Paths are relative to the repository root; many already had unrelated changes at entry.

Backend:

- `backend/src/realtime/data-changes.ts`: complete attendance contract, attendance-specific audience, safe identifier-only replay and replay cursors.
- `backend/src/realtime/group.gateway.ts`: authorized group room joins/leaves.
- `backend/src/realtime/socket-server.ts`, `rooms.ts`: register group gateway and canonical group room name.
- `backend/src/realtime/chat.gateway.ts`: leave stale room on denied rejoin.
- `backend/src/realtime/chat-emitter.ts`, `backend/src/usecases/chat/mark-chat-read.usecase.ts`: filter read receipts using current membership.
- `backend/src/controllers/outings/outing.controller.ts`: attendance row publication; remove duplicate resolution emissions.

Flutter:

- `flutter/lib/core/network/realtime_change.dart`: event envelope and acknowledged replay checkpoint/deduplication.
- `flutter/lib/core/network/app_sync_provider.dart`: direct attendance routing, targeted unknown group/outing recovery and session-generation guards.
- `flutter/lib/features/chat/data/datasources/outing_chat_socket_client.dart`: group room subscriptions, session-guarded callbacks and replay handling on the shared socket.
- `flutter/lib/features/outings/domain/repositories/outings_repository.dart`: direct attendance update interface.
- `flutter/lib/features/outings/data/repositories/outings_repository_impl.dart`: keep TTL snapshot aligned with live attendance.
- `flutter/lib/features/outings/data/datasources/outings_remote_datasource.dart`: versioned attendance merge, offline persistence and authorization-denial cleanup.
- `flutter/lib/features/outings/presentation/providers/outings_provider.dart`: direct row application and change-only notification.
- `flutter/lib/features/groups/data/repositories/groups_repository_impl.dart`: align list cache with targeted detail reads; invalidate denied entries.
- `flutter/lib/core/localization/l10n.dart`: remove a duplicate `forgotPassword` getter that prevented test compilation; retain the existing canonical getter/copy.

Tests:

- `backend/tests/realtime-commit.test.ts`, `realtime-group-gateway.test.ts`: new post-commit and room-authorization checks.
- `backend/tests/realtime-recovery.test.ts`: replay cursor and historical attendance privacy checks.
- `flutter/test/realtime_cursor_test.dart`: new reconnect race/account-boundary checks.
- `flutter/test/app_sync_provider_test.dart`: direct payloads, targeted/burst recovery, account switching and stale queued events.
- `flutter/test/outings_hydrate_optimization_test.dart`: direct attendance, zero extra HTTP/rebuilds, old/new REST versions, cold offline restoration and attendance access denial.
- `flutter/test/group_account_linking_test.dart`: targeted group details cannot be undone by a stale list cache or trigger another list GET.

Documentation:

- `docs/API_CONTRACTS.md`, `AUTHENTICATION_AND_AUTHORIZATION.md`: event envelopes, rooms, audiences and replay authorization.
- `docs/FLUTTER_ARCHITECTURE.md`, `BACKEND_ARCHITECTURE.md`: transport ownership, event application, cache and publication paths.
- `docs/SYSTEM_ARCHITECTURE.md`: explicit single-client transport in the architecture diagram.
- `docs/SYSTEM_DESIGN.md`, `USER_SCENARIOS.md`, `BUSINESS_LOGIC.md`: synchronization/recovery behavior without changing product rules.
- `docs/ARCHITECTURE_DECISIONS.md`: ADR-016 extends existing socket/offline/replay decisions.
- `docs/PROJECT_STRUCTURE.md` and this report: new files and verification map.

## Verification

- Backend targeted regression run: **35 tests passed**, covering realtime, commit ordering, group rooms, chat retries, resource authorization, voting concurrency and outing lifecycle. Fixture-backed lifecycle/concurrency tests used their existing disposable rows and cleanup.
- Final focused realtime/chat rerun: **9 tests passed**.
- TypeScript: `tsc --noEmit` passed after the final backend changes.
- Flutter: **41 tests passed** across synchronization, cursor races, hydration, offline snapshots, group account linking/roster, durable chat queue, message merge and English/Arabic chat rendering regressions.
- Targeted Flutter analysis: **no issues found** across twelve touched implementation/test paths. Mechanical brace fixes applied only to touched files.
- Socket test clients initially received sandbox `EACCES` on localhost; the same tests passed with local loopback permission. Flutter required access to the installed SDK cache/test networking.
- DTD discovery/connection succeeded, but no running app was attached. Hot reload was attempted and unavailable. No device, deployment, background OS, phone/wide/foldable, light/dark, or end-to-end two-phone exercise was performed. No screen layout was redesigned; existing English/Arabic chat and roster widget regressions were included.

## Remaining limitations

- Realtime publication is best effort after commit, not atomically persisted in a domain event outbox. A crash or audience lookup failure between commit and publication can lose an event. Restart/expired-cursor recovery repairs lists and mounted resources using REST; this is not an exactly-once delivery guarantee.
- Replay and adapter state are process-local. Horizontal scaling needs shared Socket.IO/replay infrastructure and an architectural decision. No deployment configuration was changed.
- Complete direct Provider updates are currently chat messages and attendance rows. Other domain events intentionally contain identifiers and use targeted REST reads; membership changes can require both lists and active chats. The existing read-receipt stream remains available. No general domain serialization framework was introduced.
- Offline snapshots remain bounded SharedPreferences data, not an encrypted application database. Non-chat writes still require connectivity. The OS is not guaranteed to run synchronization in the background.
- Domain delivery continues through authorized user-room fan-out. Group rooms are subscription scopes; the server does not trust room occupancy to deliver sensitive group data. Stale room occupancy is harmless to payload authorization and is removed on denied rejoin/read fan-out or normal subscription reconciliation.
- Older clients do not understand the new complete attendance kind. Deploy the updated Flutter client with the backend for live attendance application; REST behavior is preserved.

Documentation diagrams updated: the system architecture transport node. Remaining known documentation limits: device/deployment validation and multi-instance topology are still unverified; no new product-rule inconsistency was identified.
