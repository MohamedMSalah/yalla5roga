# Backend–Flutter Integration Report

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
