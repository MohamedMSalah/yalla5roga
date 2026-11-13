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

- **Status:** Superseded by ADR-021 (owner-approved multi-location ballots, 2026-11-14)
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

- **Status:** Superseded by ADR-017 (2026-11-12). Historical context: no verified object-storage pipeline existed when this ADR was written.
- **Context:** No verified object-storage pipeline in-repo.
- **Decision:** Persist URL fields only.
- **Consequences:** Image fields remain strings; ADR-017 adds a stable reference scheme and an object-storage pipeline without changing the column types.

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
- **Replay policy:** Only durable chat sends use the chat outbox (form-draft recovery uses the separate existing draft cache, per ADR-019), with a stable client UUID and existing PostgreSQL uniqueness over outing/sender/client UUID. Server authorization and chat-state checks remain enforced. Votes, attendance, GPS, invitations, membership, account/security changes, deletes and lifecycle commands require online success.
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

## ADR-017: Cloudflare R2 media pipeline with stable `media://` references

- **Status:** Accepted (2026-11-12).
- **Context:** Profile/group/outing/chat images need private, authorization-checked delivery, while place images should be cacheable and public. The app must keep working offline, preserve existing rows/default artwork, and not move binaries into Neon or through the API. Cloudflare credentials are not available yet.
- **Decision:**
  - Object storage is Cloudflare R2 behind a `MediaStorageAdapter`. Provider selection is env-only: complete `R2_*` credentials → `r2`; otherwise an in-memory mock adapter for local development. Real credentials can be added later without code changes.
  - The backend owns upload intents, ownership/purpose/MIME/size checks, HEAD verification before `ready`, signed GET URLs, deletion, and orphan cleanup. Binaries upload directly from Flutter to storage using a presigned PUT.
  - Neon stores only `media_assets` metadata (object key, bucket, MIME, size, visibility, purpose, owner, optional entity links, timestamps). Entity image columns remain `VarChar` strings.
  - Entity image fields accept legacy absolute http(s) URLs or the stable reference `media://<asset-uuid>`. No schema change is required for existing rows/default covers.
  - Visibility is fixed by purpose: `place` → public CDN when `R2_PUBLIC_BASE_URL` is configured; all other purposes → private signed GET URLs. View checks mirror entity participation rules.
  - Flutter caches by stable asset id (`media_public_<id>`, `media_private_<uid>_<id>`), persists delivery-URL metadata per account for offline rendering, revalidates private URLs in the background, and evicts account-scoped state on logout/account switch. Signed URLs never become cache identities.
  - Covers may be uploaded before the entity row exists; attachment authorization is enforced when the create/update persists the reference.
- **Consequences:** No binaries in Neon and backward-compatible APIs. Real deployment still needs the R2 bucket, API token/keys, bucket CORS for direct PUT, and a CDN custom domain; until then the mock provider serves local development and public assets remain `media://` references. Multi-instance API nodes rely on R2 as shared storage; the cleanup job remains in-process.

## ADR-018: Server-configured place catalog curators

- **Status:** Accepted (2026-11-13, Phase 1 security hardening).
- **Context:** Place catalog mutations (place, hours, images, prices) were available to any authenticated user. The product authorization model has no global Admin/Curator role — only group roles and outing owners — so introducing a database role would change product scope and require owner approval.
- **Decision:** Gate every place catalog write behind `requirePlaceCurator`, which compares the verified Bearer UID with the comma-separated server-only `PLACES_CURATOR_UIDS` environment variable. Reads stay unchanged. The allowlist fails closed when missing or empty, and no client or profile field can grant curator status.
- **Consequences:** Ordinary authenticated users receive 403 for catalog writes. Deployment must set `PLACES_CURATOR_UIDS` to operate the catalog; local development can list a developer UID. This can later be replaced by an owner-approved database role without changing route structure.

## ADR-019 — Explicit invitation decisions and bounded recovery (2026-11-13)

- **Status:** Accepted by the owner's confirmed-fixes implementation request; supersedes automatic group invitation acceptance wherever described earlier.
- **Decision:** New group invitations always remain pending until an explicit recipient decision. Firebase-verified identity linking associates inbox rows only. Acceptance transactionally inserts a member with duplicate protection; decline preserves history. Ordinary member creation cannot assign owner.
- **Drafts:** Extend the existing remote/repository/provider/local-cache path, not a second draft service. Reuse draft UUIDs for POST idempotency and existing updated_at for optional If-Match checks under row locks. Persist pending changes and conflict state locally by account/origin. Do not automatically overwrite a newer server copy. Local-only phone-contact selections remain cached because the existing draft schema lacks that field; no schema was invented for this task.
- **Realtime:** Retain the existing **512-entry**, **10-minute** in-memory invalidation journal and authenticated epoch/sequence `data:reconcile`. Invalid/expired/restarted cursors reset provider snapshots through REST. This remains **single-process**, with **no Redis adapter** or durable shared journal. No Redis is added.
- **HTTP:** Reuse Express middleware for a bounded single-process 300 requests/IP/minute API limiter; preserve stricter auth/recovery limits and the consistent error envelope. Do not trust arbitrary proxy headers. Notification reads default to 20 with a maximum of 100 and ownership-filtered opaque cursors.
- **Consequences:** No route or operation-ID rename and no database migration. Live authenticated business acceptance, multi-device draft conflict UI, mobile theme/RTL/responsive checks, and distributed deployment remain unverified. Source/static validation is not runtime proof.


## ADR-020: Modern Social presentation foundation (2026-11-13)

- **Status:** Accepted (owner-approved Phase 1 request).
- **Decision:** Extend the existing Material 3/AppTheme/AppPalette/Responsive foundation with a violet light/dark semantic palette, centralized geometry/type/shadow tokens and existing AppMotion helpers. Keep Cairo/Inter and manual L10n. Arabic is the new-install default; persisted English remains supported.
- **Composition:** Reusable cards accept presentation values, cover widgets and callbacks in core/widgets; feature widgets adapt entities, Provider selections and localized values. Keep existing card constructor contracts, tab indexes and imperative GetX navigation/deep-link handlers. No dependency or state-management pattern is added.
- **Navigation:** Retain the existing lazy mounted tabs and floating pill shell. Use a filled active pill, directional short reveal, reduced-motion handling and exclusion of inactive content from input/focus/semantics/tickers.
- **Scope:** The shared foundation and small adapters only. Feature-screen redesign and broad legacy page decomposition belong to later phases. No runtime/visual approval is inferred from static analysis.


## ADR-021: Atomic multi-location ballots (2026-11-14)

- **Status:** Accepted; owner explicitly approved backend/schema work for multiple votes during Phase 3.
- **Decision:** Expand outing_votes PK to (outing_id, user_id, option_id), preserving rows and existing FKs. PUT /votes replaces a caller’s complete selection under the same outing lock used for lifecycle resolution. Count distinct voters for participation. Keep existing highest-count winner, owner RNG tie-break, zero-vote cancellation and creator-confirmed venue rules.
- **Compatibility:** Existing POST adds a single idempotent selection; DELETE removes one/all. GET voting-state keeps legacy my_option_id and adds my_option_ids/voted_count. Flutter submits all checkbox edits together, avoiding premature early closure after the first selected option.
- **Consequences:** Requires a Prisma migration and coordinated API/client release. No dependency, Clean Architecture layer, Provider or realtime protocol is replaced. Unsent local checkbox edits reset if the candidate identity/order changes.
