# Yalla 5roga — Architecture Decision Records

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-07 |
| Documentation version | 1.0.0 |
| Rule | Only verified or explicitly approved decisions. No fictional ADRs. |

---

## ADR-001: Provider / ChangeNotifier for Flutter state

- **Status:** Accepted
- **Context:** Flutter app needs predictable feature state without introducing an undocumented second state framework as primary.
- **Decision:** Use `provider` + `ChangeNotifier` for app and feature state (`AuthProvider`, `OutingsProvider`, …).
- **Alternatives considered:** Bloc/Riverpod as primary (not adopted).
- **Consequences:** New features should expose ChangeNotifiers; GetX is limited to navigation/snackbars, not primary app state.

## ADR-002: Feature-first Clean Architecture (Flutter)

- **Status:** Accepted
- **Context:** Multiple domains (auth, groups, outings, chat, discover).
- **Decision:** `features/<name>/{data,domain,presentation}` + shared `core/`.
- **Consequences:** UI → Provider → Repository → DataSource; presentation must not import Dio/Firebase.

## ADR-003: Express + TypeScript backend

- **Status:** Accepted
- **Context:** Need REST API for mobile.
- **Decision:** Node.js Express TypeScript with routes/controllers/use cases.
- **Consequences:** Prefer extending use cases over ad-hoc route logic.

## ADR-004: Prisma + Neon PostgreSQL as application source of truth

- **Status:** Accepted
- **Context:** Need relational integrity for votes, membership, lifecycle.
- **Decision:** Neon PostgreSQL via Prisma; schema in `backend/prisma/schema.prisma`.
- **Consequences:** Firebase is not the app DB. Schema changes require migrations + `DATABASE_ARCHITECTURE.md` updates.

## ADR-005: Firebase Authentication only for identity

- **Status:** Accepted
- **Context:** Phone/password app access, Firebase identity, and stable account relationships.
- **Decision:** Firebase Auth for identity (UID + ID tokens) only; Neon is the sole application data store. Phone/password signup retains the phone OTP-verified Firebase UID after backend verification of its ID token. Firebase's phone credential is identity proof; application profiles and `password_hash` remain in Neon. Backend accepts verified Firebase phone OTP ID tokens and mints custom-token sessions for phone/password. Both keep the same Firebase UID. Legacy bare-UID accounts keep their IDs and can bind an unused OTP phone credential only after fresh server-verified OTP proof; registered identities are never merged. Retain the Firebase UID primary key for stable relations. PostgreSQL enforces E.164, uniqueness and NOT NULL on the phone lookup key so a phone change leaves existing relationships intact.
- **Consequences:** All protected routes use `authMiddleware`; user rows keyed by Firebase UID. Do not use Firestore/Realtime DB (or Firebase Auth profile fields) as the app database.

## ADR-006: Backend authority for voting lifecycle

- **Status:** Accepted (product-approved)
- **Context:** Clients must not invent winners or close polls unilaterally.
- **Decision:** Vote upsert, early close, deadline job, unique winner, tie-break RNG, zero-vote cancel run on backend (`vote-resolution.ts`). Flutter only displays server results/animations.
- **Consequences:** No client `finalize` flag as source of truth.

## ADR-007: One active vote per user (DB enforced)

- **Status:** Accepted
- **Context:** Prevent duplicate ballots.
- **Decision:** `outing_votes` PK `(outing_id, user_id)`; changes upsert.
- **Consequences:** Candidate changes clear votes in transactions.

## ADR-008: Attendance independent of voting

- **Status:** Accepted (product-approved)
- **Context:** RSVP must not skew place tallies.
- **Decision:** Separate `outing_attendance` table/enums; eligibility ignores attendance.
- **Consequences:** UI must not gate voting on attendance.

## ADR-009: Notification outbox worker

- **Status:** Accepted
- **Context:** Reliable async delivery for push/WhatsApp.
- **Decision:** Persist `notification_events`; in-process worker dispatches channels; idempotent `event_key`.
- **Alternatives considered:** Inline send only (insufficient for retries).
- **Consequences:** Do not claim push delivered solely because an in-app row exists.

## ADR-010: Manual Flutter DI

- **Status:** Accepted
- **Context:** Explicit wiring preferred over service locator.
- **Decision:** `AppDependencies.create()` + `RepositoryFactory`.
- **Consequences:** New providers registered in DI and `App`.

## ADR-011: HTTP chat (no WebSocket)

- **Status:** Superseded by ADR-013
- **Context:** Outing chat needed; realtime infra not introduced.
- **Decision:** REST list/send/read under `/api/outings/:outingId/messages` and `/read` (outing sub-resource; previously `/api/chat`).
- **Consequences:** Polling/refresh UX; do not document SignalR/WebSockets as implemented.

## ADR-012: Images as URL strings

- **Status:** Accepted (current)
- **Context:** No verified object-storage pipeline in-repo.
- **Decision:** Persist URL fields only.
- **Consequences:** Upload service would be a new ADR if added.

## ADR-013: Hybrid REST + Socket.IO outing chat

- **Status:** Accepted (current)
- **Context:** ADR-011 HTTP chat lacked live delivery; product approved Socket.IO after audit.
- **Decision:**
  - REST remains the canonical write/history/read path (`POST/GET …/messages`, `PATCH …/read`).
  - Socket.IO (same HTTP server, path `/socket.io`) delivers `outing:message` / `outing:read` to room `outing:{outingId}` after successful persistence.
  - Handshake auth = Firebase ID token (`auth.token`); identity is `decoded.uid` only.
  - `outing:join` requires server-side `assertChatParticipant`; never trust client room claims or sender IDs.
  - Flutter uses `socket_io_client` for delivery; sends via existing REST; dedupes by message `id`; recovers gaps with REST on reconnect.
  - No Redis adapter while the API remains a single long-lived Node process (current hosting). Multi-instance sticky sessions would need a new ADR.
- **Consequences:** Real-time UX without duplicate persistence; serverless hosts that cannot keep WebSockets are incompatible without topology change. Supersedes ADR-011.

---

## ADR-014: Offline snapshots and scoped realtime invalidation

- **Status:** Accepted (2026-11-11, requested offline-first workflow)
- **Decision:** Reuse SharedPreferences for bounded account/backend-scoped JSON snapshots and the existing chat cache. Cache hydration precedes authenticated REST catch-up. PostgreSQL remains authoritative; sockets deliver invalidations or canonical chat messages. One app-scoped `AppSyncProvider` owns network, lifecycle and socket recovery listeners.
- **Replay policy:** Only durable chat sends use the outbox, with a stable client UUID and existing PostgreSQL uniqueness over outing/sender/client UUID. Server authorization and chat-state checks remain enforced. Votes, attendance, GPS, invitations, membership, account/security changes, deletes and lifecycle commands require online success.
- **Consequences:** No new dependency, database or write route. No OS background worker or durable server event log. Resume/reconnect repairs lists and open details using REST. Preferences are bounded and unencrypted; logout purges the previous account's snapshots, chat cache and sends. ADR-013's single-process Socket.IO restriction remains.

When superseding a decision, mark the old ADR **Superseded** and add a new one — do not silently rewrite history.


## ADR-015: Stable inline mentions and bounded invalidation replay

- **Status:** Accepted (2026-11-11, owner-requested mention/realtime work).
- **Decision:** Extend ADR-013/014 using the same REST text field, Socket.IO connection, Provider coordinator, and offline send queue. Store mention IDs in URI-encoded inline text tokens and canonicalize labels from Neon. Use existing notification event keys and exact-message navigation. Keep a bounded in-memory, per-recipient invalidation replay buffer in the existing single-process deployment; fall back to stale caches and mounted resources when replay cannot cover the gap.
- **Consequences:** No dependency or schema migration. Older clients display raw stable tokens until updated. The buffer expires after ten minutes or 512 global invalidations and resets on backend restart. Multi-instance hosting still requires shared replay/state infrastructure and an ADR. General data refresh is silent and uses profile GET; account sync is limited to restoration/authentication/verified account changes.


## ADR-016: Centralized session synchronization on the existing socket

- **Status:** Accepted (2026-11-11, owner-requested centralized synchronization).
- **Decision:** Extend ADR-013/014/015 with authorized group rooms, a shared typed Flutter change envelope and acknowledged-only replay checkpoints. Reuse one DI-owned socket per signed-in app session. Apply complete attendance/chat rows directly; incomplete group/outing/voting events use targeted authenticated reads, and membership changes revalidate access-dependent lists. Keep REST writes and PostgreSQL business authority unchanged.
- **Consequences:** No dependency or migration. Replay and delivery remain best effort in one Node process. Attendance rows are version-merged; replay contains resource identifiers to recheck current authorization. Durable server publication, shared multi-instance adapters and background execution remain outside this change. See `audit/CENTRALIZED_REALTIME_SYNC.md`.

### ADR-005 clarification: recovery — 2026-11-11

The existing application password authority is Neon bcrypt, as verified in phone/password login and password change. Recovery updates that same credential after fresh server-verified Firebase phone proof; it must not set an unrelated Firebase password. Shared PostgreSQL digests provide five-minute single-use reset grants with atomic consumption/password update and proof replay rejection. Current Firebase phone must match the existing Neon UID/phone; unbound legacy accounts fail closed. Existing signup/sync proof contracts and sessions remain unchanged. This extends the established architecture, with no new password store or identity migration.
