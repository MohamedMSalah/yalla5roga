# Backend–Flutter Integration Report

## 2026-11-09 Swagger and Flutter API audit

| Check | Result |
|-------|--------|
| Swagger UI | Phone/password login returned HTTP 200 and a Firebase ID token. Authorize applied that token. The Swagger Execute request to the current-user endpoint sent the matching bearer header and returned HTTP 200. |
| Configured database before deployment | Health, current-user groups, saved outings, drafts, places, nearby, saved places and notifications returned HTTP 200. The Flutter outings feed returned HTTP 500. A read-only schema check confirmed that the arrival migration had not been applied. The current Prisma outing model requires the missing request-key column. |
| Full HTTP sweep | Exercised 84 of 84 Swagger operations against temporary schemas built from all five migrations. 83 returned a 2xx response in a fixture case after rechecks. Group-invite decline was exercised as a 403 authorization case. |
| Flutter against the configured database | Production Dio clients passed login, profile parsing, password verification, groups, catalog and nearby lookup. The production outing data source reproduced the HTTP 500. All 74 Flutter regression tests passed. |
| Flutter against the migrated fixture | Production Dio clients passed the outings feed, special-event create, idempotent replay, manual invite URL parsing and arrival write/list. The fixture used supplied coordinates to test the API contract. |
| Regression suites | Flutter 74/74. Backend subset 78/82. Four sync-user tests still expect fields from the former email profile contract. |
| Isolated feature checks | Place discovery returned the fixture at distance zero. Vote casting and owner tie-break passed after pinning raw SQL to the fixture schema. Socket.IO authenticated, joined and left the fixture outing. Arrival checks rejected a far point, accepted an in-range point and kept one arrival on retry. Special-event create reused the same outing on retry and returned a manual WhatsApp link with a Google Calendar URL. |

### Reproduced defects

| Case | Observed behavior |
|------|-------------------|
| Current-user outings on the configured database | The pending arrival migration caused HTTP 500 before deployment. After deploying, the authenticated request returned HTTP 200. |
| Delete a group with a related group outing | HTTP 500. The foreign key clears the outing’s group ID, which violates the outing type constraint. Deleting an empty group returned HTTP 200. |
| Delete the same vote twice | The first deletion returned HTTP 200. The repeated deletion returned HTTP 500 with Prisma P2025 because the vote row was already absent. |
| List places with featured=false | HTTP 200 omits non-featured places. The controller treats the query-string value "false" as truthy. |

The first fixture run used Prisma's schema option for ORM queries. Raw SQL still resolved to the public schema, which explained the initial nearby result and the vote/tie-break 404s. The recheck pinned the isolated connection pool’s search path before retrying. Temporary schemas and fixture Firebase identities were removed. Native Firebase session behavior, real WhatsApp delivery and device GPS still require separate verification.

### Neon deployment follow-up

Prisma applied the three pending migrations for constraint hardening, phone/password migration history, and outing arrivals on 2026-11-09. Migration status reports the schema is up to date. Read-only Neon checks verified the arrival table and its keys, the outing request-key column, and the valid unique index. The existing authorized Swagger session returned HTTP 200 for database health, the current-user outings feed, and an outing arrival list.

## 2026-11-08 audit (historical)

| Metadata | Value |
|----------|-------|
| Date | 2026-11-08 |
| Scope | Post-refactor audit: all Flutter HTTP clients vs Express routes + live scenario probes |
| Backend | Live Express + Neon (`127.0.0.1:3000` / `0.0.0.0:3000`) |
| Flutter static | `ApiConstants` + datasources/repositories/providers |
| Device/UI | Attempted; **not completed** (see § Device) |

## Overall verdict

- **Path alignment after refactor:** Chat and FCM Flutter paths match the new backend mounts. No live `/api/chat` or `/api/user/fcm-token` remain in Flutter.
- **Flutter-shaped HTTP scenarios (Firebase ID token + Neon):** **31/31 passed** via `backend/scripts/flutter-client-scenario-probe.ts` (re-run after Socket.IO).
- **Outing real-time chat (Socket.IO):** **PASS** — two authenticated clients exchanged messages over Socket.IO without polling; REST remains the write path. See §8.
- **Flutter chat lifecycle/reliability:** **PASS with manual follow-ups** — code audit + unit tests + regression probe; two-device UI still manual. See §9.
- **On-device / emulator UI scenarios:** Emulator launch attempted earlier; interactive two-user device chat remains **manual QA** (see §9 checklist).

---

## 1. Endpoint matrix (Flutter live calls vs backend)

41 live `ApiClient` call sites across Auth, Groups, Outings, Voting, Participants, Saved Outings, Chat, Notifications, FCM, Discover. All use `Authorization: Bearer <Firebase ID token>` via `AuthInterceptor` (login/signup usually unauthenticated).

| Feature | Flutter paths used | Backend match | Notes |
|---------|-------------------|---------------|-------|
| Auth login/signup | `POST /api/auth/login`, `/signup` | Match | Unchanged |
| Sync / profile | `POST /api/users/sync`, `PATCH/GET /api/users/cuser` | Match | Canonical sync preserved |
| Groups | `/api/groups`, `/cuser`, `/:id`, members, invitations | Match | |
| Outings | `/cuser`, `POST /`, vote-options, votes, voting-state, tie-break, attendance, guests | Match | |
| Saved outings | `/api/outings/saved`, `/:id/save` | Match | Neon verified |
| Chat | `/api/outings/:id/messages`, `/:id/read` | Match (new) | Provider enriches `isMine` from `sender_id` |
| Notifications | list + mark read | Match | |
| FCM | `/api/users/cuser/fcm-token` (+ DELETE by token) | Match (new) | Neon verified |
| Discover | `GET /api/places`, `/:id` | Match | Public list OK |
| Saved places | constants + datasource exist | Match paths | **Not wired in `RepositoryFactory` / DI** |

### Outdated / mismatched findings

| Item | Severity | Action taken |
|------|----------|--------------|
| Live Chat/FCM old URLs | Was breaking after refactor | Already fixed in `ApiConstants` |
| Unused `unreadCounts` → `/api/user/unread-counts` | Stale dead constant (no backend route) | **Removed** from `api_constants.dart` |
| Unused helpers (`outingCancel`, invite accept/decline, etc.) | Low — defined, unused | Left; backend routes still exist |
| Saved places DS unwired | Product gap, pre-existing | Documented; not invented wiring |

---

## 2. Feature-by-feature executed results

Script: `pnpm exec tsx scripts/flutter-client-scenario-probe.ts`  
Auth: Firebase Admin custom token → Identity Toolkit ID token → Bearer (same pattern as Flutter).

| Feature | Scenarios executed | Result | Persistence / notes |
|---------|-------------------|--------|----------------------|
| Firebase auth | Token exchange + Bearer APIs | **Pass** | |
| Users sync/profile | sync, GET cuser | **Pass** | Neon user |
| Groups | create, cuser, get, members, patch | **Pass** | |
| Outings | create (group outing), cuser | **Pass** | |
| Voting | add option, list, cast, list votes, voting-state | **Pass** | Neon vote row = 1 |
| Participants | GET/PUT attendance | **Pass** | Neon attendance going = 1 |
| Chat | send, list, assert `sender_id`, mark read | **Pass** | Neon `chat_messages` = 1; Flutter `isMine` via provider |
| Saved outings | save, list | **Pass** | Neon `saved_outings` = 1 |
| Notifications | list, mark all read | **Pass** | HTTP only (inbox may be empty) |
| FCM | register, Neon assert, unregister | **Pass** | Neon token row |
| Discover | GET places | **Pass** | |
| Regression | old `/api/chat/...`, `/api/user/fcm-token` | **Pass** (404) | |

**31 passed / 0 failed** for this probe set.

---

## 3. Response / model notes (not assumed from HTTP 200 alone)

- Chat list returns Prisma rows (`sender_id`, `created_at`, …). Flutter `ChatMessageModel` tolerates snake_case; `OutingChatProvider._withMine` sets `isMine` from `senderId == currentUser`. Asserted `sender_id` present on list payload.
- Vote cast uses Flutter body `{ option_id }` — accepted; Neon row verified.
- Attendance uses `{ status: "going" }` — Neon verified.
- A bare backend 200 without Neon checks was **not** treated as full pass for chat/save/vote/FCM.

---

## 4. Device / emulator attempts

| Attempt | Result |
|---------|--------|
| `flutter run` on `SM A566B` + `.env.device` | Gradle `assembleDebug` started; run **aborted** before install |
| Later `adb devices` / `flutter devices` | Physical device **gone** |
| `flutter emulators --launch Pixel_6a` | Aborted |
| Direct `emulator.exe -avd Pixel_6a` | Process started; **never** appeared as `emulator-#### device` within wait window |

**Untested on UI:** login, group invite UX, vote UI, attendance UI, chat screen, saved list UI, notification inbox UI, FCM register from real Messaging SDK.

---

## 5. Files modified (this audit phase)

| File | Change |
|------|--------|
| `flutter/lib/core/constants/api_constants.dart` | Removed stale `unreadCounts` |
| `backend/scripts/flutter-client-scenario-probe.ts` | Added Flutter-shaped scenario + Neon probe |
| `docs/audit/BACKEND_FLUTTER_INTEGRATION_REPORT.md` | This report |

(Prior refactor already updated Chat/FCM constants, route modules, Swagger, and canonical docs.)

---

## 6. Untested / residual risks

1. Full Flutter UI on emulator/device after sign-in.
2. Saved places end-to-end (datasource unwired).
3. Guest invite / invitation accept-decline from the app (constants unused).
4. `clearVotes` DELETE path exists but vote UI may not clear `cuserOptionIds` (pre-existing).
5. Title length / validation edge cases in create outing UI vs Zod `max(20)`.

---

## 7. Breaking changes (refactor) — regression checked

| Change | Probe |
|--------|-------|
| Chat moved under `/api/outings/:id/...` | New paths Pass; old `/api/chat` → 404 |
| FCM moved to `/api/users/cuser/fcm-token` | New paths Pass + Neon; old `/api/user/fcm-token` → 404 |

---

## 8. Outing Real-Time Chat Verification

| Metadata | Value |
|----------|-------|
| Date | 2026-11-08 |
| Verdict | **PASS — hybrid REST + Socket.IO** |
| Probe script | `backend/scripts/outing-chat-realtime-audit.ts` (**19/19**, `realtimePass: true`) |
| ADR | ADR-011 superseded by **ADR-013** |

### Hosting compatibility (checked before implementation)

| Finding | Decision |
|---------|----------|
| No Docker/K8s/serverless deploy manifests in-repo; API is a long-lived Express Node process (`server.ts` listen) | Compatible with persistent Socket.IO WebSockets on the same port |
| Single process + in-process jobs (no horizontal socket farm) | **No Redis** adapter introduced |
| Serverless/request-scoped hosts that cannot keep upgrades | Documented as incompatible without a future topology ADR |

### Summary checklist

| Requirement | Result |
|-------------|--------|
| Backend Socket.IO server | **Pass** (`attachRealtime` on `http.Server`) |
| Flutter `socket_io_client` | **Pass** (`OutingChatSocketClient`) |
| Firebase ID token on socket connect | **Pass** (invalid token → `connect_error`) |
| Outing rooms + membership gate | **Pass** (`outing:{id}`; stranger join `FORBIDDEN`) |
| Real-time send/receive | **Pass** (A↔B without REST poll) |
| Neon persistence via Prisma | **Pass** |
| Reconnect + REST missed recovery | **Pass** |
| No duplicate persistence (`clientMessageId`) | **Pass** (1 row) |
| REST chat regression probe | **Pass** (`flutter-client-scenario-probe.ts`) |

### WebSocket technology used

**Socket.IO v4** (`socket.io` 4.8.x server, `socket.io-client` for Node probe, Flutter `socket_io_client` 3.1.x). Path: `/socket.io`. Transports: websocket (+ polling fallback on server).

### Backend implementation files

| Role | Path |
|------|------|
| HTTP + Socket bootstrap | `backend/src/server.ts` |
| Socket attach | `backend/src/realtime/socket-server.ts` |
| Firebase socket auth | `backend/src/realtime/socket-auth.ts` |
| Join/leave gateway | `backend/src/realtime/chat.gateway.ts` |
| Post-persist emit | `backend/src/realtime/chat-emitter.ts` |
| Room helper | `backend/src/realtime/rooms.ts` → `outing:{outingId}` |
| REST routes (unchanged contract) | `backend/src/routes/outings/outing.chat.routes.ts` |
| Persist then emit | `send-message.usecase.ts`, `mark-chat-read.usecase.ts` |
| Access control | `backend/src/services/chat/chat-access.ts` |

### Flutter implementation files

| Role | Path |
|------|------|
| Socket client | `flutter/lib/features/chat/data/datasources/outing_chat_socket_client.dart` |
| Provider subscribe/dedupe/reconnect REST | `outing_chat_provider.dart` |
| Page join/leave | `outing_chat_page.dart` |
| DI wiring | `flutter/lib/core/di/app_dependencies.dart` |
| REST send/history (canonical write) | `outing_chat_remote_datasource.dart` |

### Authentication mechanism

| Layer | Behavior |
|-------|----------|
| REST | Bearer Firebase ID token; `sender_id = req.user.uid` |
| Socket handshake | `auth.token` → Admin `verifyIdToken` → `socket.data.uid` |
| Join | Server `assertChatParticipant` only |
| Client userId / senderId | Never trusted for identity or room permission |

### Room naming convention

`outing:{outingId}`

### Socket events

| Event | Direction | Notes |
|-------|-----------|-------|
| `outing:join` | C→S | Ack `{ ok, room }` / `{ ok:false, error }` |
| `outing:leave` | C→S | Leave room |
| `outing:message` | S→C | After REST persist |
| `outing:read` | S→C | After REST mark-read |

### Message persistence behavior

- **Only** `POST /api/outings/:id/messages` writes `chat_messages`.
- Socket emit is delivery-only after successful Prisma create (idempotent retries reuse same id via `clientMessageId`).
- Flutter upserts by message `id` so REST response + socket echo do not duplicate UI rows.

### Two-user real-time test results

**PASS.** Probe outing `0784881c-b985-4782-95f6-f5a88229c60f` (users `chat-rt-audit-a` / `chat-rt-audit-b`):

| Step | Result |
|------|--------|
| Both sockets connect with Firebase tokens | Pass |
| Both join `outing:{id}` | Pass |
| A REST send → B receives `outing:message` (no GET) | Pass |
| B REST send → A receives `outing:message` (no GET) | Pass |
| Neon rows for both messages | Pass (`matched=2`) |

### Reconnection test results

| Step | Result |
|------|--------|
| B disconnect; A sends while B offline | Pass |
| B reconnect + rejoin + REST GET recovers missed | Pass |

Flutter: on socket reconnect, `OutingChatProvider` force-refreshes REST history for active rooms.

### Security test results

| Check | Result |
|-------|--------|
| Invalid Firebase token connect | Rejected (`connect_error`) |
| Stranger socket join | `FORBIDDEN` |
| Stranger REST list | 403 |
| REST regression suite | Pass |

### Flutter emulator / device

| Attempt | Result |
|---------|--------|
| `flutter devices` at verification time | Windows/Chrome/Edge only (no phone) |
| `flutter emulators --launch Pixel_6a` | Launched in-session; interactive two-user UI chat not completed as Pass evidence |
| Static analyze chat + DI | Clean after `use_build_context_synchronously` fix |

**Socket path is proven by authenticated Socket.IO clients.** Treat full UI two-device chat as follow-up manual QA.

### Architecture separation (implemented)

| Concern | Implementation |
|---------|----------------|
| History | REST GET |
| Persist | REST POST only |
| Mark read | REST PATCH (+ `outing:read` emit) |
| Live delivery | Socket.IO room emit |
| Dedupe | Server id + Flutter upsert; `clientMessageId` unique |

---

## 9. Flutter Outing Chat lifecycle & reliability audit

| Metadata | Value |
|----------|-------|
| Date | 2026-11-08 |
| Scope | Post–Socket.IO Flutter lifecycle (foreground, rooms, dedupe, reconnect, token, cleanup, prod) |
| Architecture changes | Reliability hardening only — no Redis / no transport rewrite |

### Automated evidence

| Suite | Result |
|-------|--------|
| `flutter test test/outing_chat_message_merge_test.dart` (+ `app_config_test.dart`) | **16 passed** (dedupe, local_* purge, ordering, production https rules) |
| `flutter analyze` on chat + DI | **No issues** |
| `outing-chat-realtime-audit.ts` (re-run) | **19/19**, `realtimePass: true` |

### Checklist (1–10)

| # | Focus | Code status | Automated | Manual (2 devices) |
|---|--------|-------------|-----------|--------------------|
| 1 | Foreground/background | `OutingChatPage` `WidgetsBindingObserver` → `recoverAfterResume()` (socket recover + REST force refresh) | Partial (unit/static) | **Required** — background 30s+, resume, confirm live + history |
| 2 | Join/leave across outings | Page `subscribe` / `unsubscribe`; desired-room set kept across transient join failures; leave on dispose | Static review | **Required** — open A → back → open B; no cross-room bleed |
| 3 | Duplicate socket listeners | Single provider subscription; `enableForceNew` + dispose/clearListeners; reuse socket on reconnect instead of stacking | Static review | Optional — log `[OutingChatSocket] connected` once per process reconnect |
| 4 | Duplicate message rendering | `upsertOutingChatMessage` by id + drop matching `local_*` | **Unit PASS** | Spot-check send while online (REST + echo) |
| 5 | Rapid-send ordering | Per-outing `isSending` serializes sends; sort `sentAt` then `id` | **Unit PASS** | Hammer send on one device; peer order matches |
| 6 | Network interruption | Socket.IO reconnection enabled; on connect → rejoin + debounced REST recovery | Probe reconnect PASS | **Required** — airplane mode toggle mid-chat |
| 7 | Firebase token expiry / re-auth | `setAuthFn` force-refresh on (re)connect; unauthorized `connect_error` schedules one recreate | Static + invalid-token probe | **Required** — long idle (~1h) then send/receive |
| 8 | App restart missed recovery | Cold start `subscribe` → REST history before join | Static | **Required** — kill app, relaunch into same outing |
| 9 | Dispose / logout cleanup | Page leave room; `clear()` on settings logout disconnects socket; provider dispose cancels subs | Static | Logout while chat open — no zombie connects |
| 10 | Production / secure config | Socket uses `API_BASE_URL`; production `AppConfig` rejects http/loopback → `wss` | **app_config_test PASS** | Staging/prod smoke with https host |

### Fixes applied in this audit (targeted)

- Explicit Socket.IO reconnection + auth retry on unauthorized connect errors.
- Desired-room set no longer dropped on `ACK_TIMEOUT` (only `FORBIDDEN` / `UNAUTHORIZED`).
- Resume recovery path on chat page.
- Shared upsert/dedupe helper + unit tests.
- Debounced REST recovery after reconnect to avoid double fetches.

### Manual two-device QA checklist (not executed this session)

1. Two signed-in participants, same outing chat open.
2. A sends → B sees without pull-to-refresh; B replies → A sees.
3. A backgrounds app → B sends → A resumes → message present (socket and/or REST).
4. Toggle network off/on on one device; confirm rejoin + no duplicates.
5. Navigate outing A ↔ B quickly; rooms correct.
6. Force-stop app; reopen chat; history complete; live works again.
7. Production/staging build against https API; confirm no cleartext WS.

---

## Documentation Updates

- This file: overall verdict + **§8** Socket.IO PASS + **§9** Flutter lifecycle/reliability audit.
- ADR-011 superseded; **ADR-013** added (earlier in session).
- Updated: `SYSTEM_ARCHITECTURE`, `SYSTEM_DESIGN`, `BACKEND_ARCHITECTURE`, `FLUTTER_ARCHITECTURE`, `API_CONTRACTS`, `AUTHENTICATION_AND_AUTHORIZATION`, `USER_SCENARIOS` (CHAT-07), `BUSINESS_LOGIC`, `PROJECT_OVERVIEW`, `PROJECT_STRUCTURE`.
- Code: backend realtime stack; Flutter socket client reliability hardening; `outing_chat_message_merge.dart` + unit tests.
- No Redis / extra infra introduced.


## Interactive maps and atomic outing creation

Discover and Create Outing Step 2 share the FlutterMap surface and foreground GPS helper. Discover filters and previews catalog places. The outing picker keeps draft selection local to the route and returns an ordered list on confirmation. A group vote sends the list in the create request. Prisma commits the outing, candidates and owner attendance in one transaction and uses the existing request key for retries. There is no new database migration.

### Files changed for the map work

- Flutter shared infrastructure: `lib/core/widgets/app_map.dart`, `lib/core/utils/map_location.dart`, `lib/core/config/app_config.dart`, `lib/core/constants/{app_constants,api_constants}.dart`, `lib/core/di/repository_factory.dart`, `lib/core/network/api_client.dart`, and `lib/core/localization/l10n.dart`.
- Flutter screens and data: `discover/presentation/pages/discover_page.dart`; `outings/presentation/pages/{pick_location_page,create_outing_page}.dart`; `outings/presentation/providers/{pick_location_provider,create_outing_provider}.dart`; `outings/presentation/widgets/create_outing_location_step.dart`; `outings/domain/entities/{place,place_location}.dart`; `outings/domain/repositories/location_repository.dart`; `outings/data/repositories/geocoding_http_repository.dart`; `outings/data/datasources/outings_remote_datasource.dart`. Feature paths are under `flutter/lib/features/`.
- Backend: `src/routes/places/{index,place.geocoding.routes}.ts`, `src/services/places/geocoding.ts`, `src/config/swagger.ts`, `src/types/outings/outing.types.ts`, `src/validators/outings/outing.validator.ts`, `src/usecases/outings/create-outing.usecase.ts`, and `src/datasources/outings/outing.datasource.ts`.
- Tests: Flutter `test/map_selection_test.dart` and `test/create_outing_basics_layout_test.dart`. Backend `tests/{map-outing-create,map-geocoding,outing-lifecycle,voting-concurrency}.test.ts`.
- Configuration and documentation: backend and Flutter environment examples, `API_CONTRACTS.md`, `BACKEND_ARCHITECTURE.md`, `BUSINESS_LOGIC.md`, `DATABASE_ARCHITECTURE.md`, `FLUTTER_ARCHITECTURE.md`, `PROJECT_STRUCTURE.md`, `SYSTEM_ARCHITECTURE.md`, `SYSTEM_DESIGN.md`, `USER_SCENARIOS.md`, and this report.

### Automated validation

- `flutter test --no-pub` passed all 82 tests. Coverage includes catalog search, cancellation and stale responses, single picker navigation and denial, multi-selection ordering, draft round-trips, camera idle and disposal, and the Discover filter and preview.
- `flutter analyze --no-pub` reported zero errors and 20 existing warnings and informational diagnostics.
- Backend TypeScript check passed. The backend suite passed 107 of 111 tests after applying the five existing migrations to a disposable PostgreSQL instance. All map tests passed, including concurrent retry, ordered and nullable values, duplicate handling, and rollback on a failed option insert. Four existing profile-sync tests still expect email behavior absent from the current auth flow.

### Deployment and manual checks

1. Deploy the backend before the new Flutter build. Verify the provider-disabled response, then enable the optional Pelias-compatible service only after checking language coverage, quota, storage terms, and attribution.
2. On Android and iOS, verify precise and approximate location, permission denial, settings recovery, offline tile retries, gestures and camera performance on representative devices.
3. Verify the two languages and themes, large text and TalkBack or VoiceOver, rotation, foldable layouts and the keyboard. Configure the optional dark basemap if the release requires dark raster tiles.
4. On a staging account, publish and reopen one fixed outing and one group vote. Check catalog UUIDs, manually named pins, nullable coordinates, candidate order and repeat submission with the same request key.
