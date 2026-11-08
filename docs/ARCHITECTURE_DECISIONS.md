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
- **Context:** Mobile social/phone auth + secure API calls.
- **Decision:** Firebase Auth for identity (UID + ID tokens) only; Neon is the sole application data store. Email/password signup creates a bare Firebase UID with no profile fields; name/email/phone/`password_hash` live in Neon. Backend verifies ID tokens and mints custom-token sessions for email/password.
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

When superseding a decision, mark the old ADR **Superseded** and add a new one — do not silently rewrite history.
