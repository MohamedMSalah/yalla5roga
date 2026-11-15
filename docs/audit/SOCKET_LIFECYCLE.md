# On-demand Socket.IO lifecycle — 2026-11-15

## Scope and implementation

The initial working tree was clean. This change retains one shared authenticated transport and the existing Provider/repository/cache architecture; it introduces no dependency, endpoint, schema/migration, deployment, polling loop or background worker.

| Consumer/state | Ownership and resource behavior (source evidence) |
|---|---|
| Signed-in startup; Home/Groups/Outings lists | No socket lease. Existing caches hydrate; startup and tab selection/return revalidate over REST. |
| Current group details/info/history | Idempotent route lease; only current group IDs enter group rooms. Existing initial loaders revalidate; returning to a covered route queues a targeted refresh. |
| Current outing details | Independent route lease; existing initial loader forces lifecycle refresh; returning queues targeted lifecycle/guest reads. |
| Chat open/reopen | Reference-counted room demand. Cache renders before forced REST history recovery; messages and connection subscriptions attach only with viewers. Existing REST send/mentions/edit/delete/read and durable UUID sends remain. |
| Chat covered/closed | Unsubscribe its viewer; last viewer cancels chat socket listeners and emits room leave. Local history stays cached. Another owner retains the transport. |
| Visible started arrivals | Own lease/listeners, released on route hiding/background/disposal; existing scheduled-start, permission and GPS gates remain. |
| Final consumer closes | Dispose transport/manager listeners and cancel join/auth retries; retain replay checkpoint for later same-account recovery. |
| Inactive/hidden/paused/detached or offline | Suspend transport regardless of demand; invalidate pending callbacks and cancel retries. Keep active intent/cursor for necessary foreground recovery. |
| Foreground/network return | Reconnect only with demand. Rejoin desired rooms, replay invalidations and recover active chat history over REST. |
| Logout/account switch | Clear ownership, desired rooms and cursor; existing account cache and queue cleanup remains. |

Socket-only reconnect recovery skips account/catalog/notification/draft recovery already handled by startup/resume/network recovery. Missing/expired replay still requests bounded REST fallback. Authentication retries and Socket.IO manager reconnect attempts each cap at five; outing joins retain their existing five delayed retries. Successful authentication cancels pending auth retry timers. Transport generations and per-room intent tokens prevent late token/acknowledgement callbacks from affecting replacement consumers.

Backend chat/group gateways invalidate pending authorization intent on leave/disconnect and check it before room join/acknowledgement. The installed Socket.IO `Socket._onclose` calls `_cleanup`/`leaveAll`, removes client/namespace references and disables subsequent joins. Gateways clear their own pending maps at disconnect. Read receipt fan-out skips participant lookup when there are no connected chat viewers, and still checks current authorization before delivery. Chat writes remain canonical REST operations; user/group/outing audience rules are preserved.

## Files and documentation

- Shared ownership/lifecycle: `flutter/lib/features/chat/data/datasources/outing_chat_socket_client.dart`, `flutter/lib/core/network/app_sync_provider.dart`, `flutter/lib/core/widgets/realtime_route.dart`.
- Consumers: chat page/provider; group details/info/history; outing details; arrival service/section; MainShell list visits.
- Backend: `backend/src/realtime/chat.gateway.ts`, `group.gateway.ts`, `chat-emitter.ts`.
- Canonical docs: SYSTEM_ARCHITECTURE, SYSTEM_DESIGN, FLUTTER_ARCHITECTURE, BACKEND_ARCHITECTURE, API_CONTRACTS, USER_SCENARIOS, PRODUCT_SCENARIOS and PROJECT_STRUCTURE.
- Diagrams: added the demand/foreground/network lifecycle diagram in SYSTEM_ARCHITECTURE. Existing database and business workflow diagrams are unchanged.

## Verification

- Dart SDK formatting: all 12 modified/new Dart files formatted. The first direct SDK run completed formatting but reported sandbox-denied telemetry metadata access; subsequent runs used `CI=true` and succeeded.
- Targeted Dart analysis of all 12 modified/new files: **PASS — No issues found**, exit 0. Introduced diagnostics found during iteration were resolved before this final run.
- Backend `pnpm exec tsc --noEmit`: **PASS**, exit 0.
- Served Swagger/OpenAPI: **188 PASS**, 111 documented operations, 93 protected operations. Existing route/spec parity, unique operation IDs/local references, served Swagger UI contracts and missing/malformed-token 401 envelopes passed. [Full results](SOCKET_LIFECYCLE_OPENAPI_RESULTS.json).
- Reused `backend/scripts/phase7-openapi-verification.ts`; copied its new output to the task-specific results and restored the historical Phase 7 report. The verifier imports Express without server/jobs/Socket.IO startup, overrides the database target to unreachable localhost, creates no fixtures and performs no application-data queries/writes. The first sandbox attempt blocked localhost HTTP (EACCES); the approved retry completed.
- `git diff --check`: **PASS**.
- No deployment, migration, commit or production database operation.

## Unverified behavior and remaining limits

**NOT RUN:** Flutter launch, hot reload, emulator/device, runtime/widget/integration tests or UI automation, as requested. Live Socket.IO connection counts, overlapping consumers, joins/leaves during authorization, retry timing, inactive/resume/offline transitions, cache rendering, missed-message recovery, mentions/edit/delete/read receipts and native push delivery have source/static evidence only. Swagger cannot prove Socket.IO or authenticated chat behavior; no authenticated disposable fixture was used. Theme/locale/size/input states were not exercised.

A future permitted device exercise should inspect server connection/room counts through idle lists, current details, chat open/close, overlapping owners, background/inactive, network loss, rapid leave/reopen and account switch; it should check cached history plus missed sends/edits/tombstones/read receipts on recovery. No battery/memory/bandwidth improvement was measured.

Older dated audits describe historical always-connected behavior; the canonical 2026-11-15 sections explicitly supersede it. No unresolved product/API/schema inconsistency was identified in this scope. The existing single-process replay journal remains bounded and non-durable; FCM stays independent of socket ownership.
