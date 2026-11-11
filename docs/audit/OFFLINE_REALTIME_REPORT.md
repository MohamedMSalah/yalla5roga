# Offline and realtime handling — 2026-11-11

## Audit and implementation

The initial working tree already contained an in-progress offline/realtime implementation alongside unrelated work. This task audited and extended those files in place. Existing foundations were Dio/TTL caching with request coalescing, SharedPreferences profile/chat storage, Provider, REST chat UUID deduplication and an authenticated Socket.IO client/server. No dependencies, schema migrations or generic command replay mechanism were added by this task.

Implemented and verified paths:

- Account/API-origin-scoped, bounded JSON snapshots for groups, rosters, outings, voting state/options and attendance. Startup uses a cache-only hydration pass followed by foreground backend synchronization. Matching cached profile restore requires a Firebase session. Credentials are excluded from persisted profile JSON.
- Group member profiles are retained with loaded rosters; chat uses its existing bounded local datasource. Access denials evict resource snapshots. Session generations prevent late responses from repopulating outing state after logout.
- Durable chat outbox, stable UUID retries, one concurrent drain, exponential retry, visible pending/failed delivery, canonical/socket-echo deduplication, permanent state/authZ conflict handling and previous-account cleanup. Only chat sends support replay.
- One app-scoped lifecycle/connectivity/socket coordinator, debounced affected-ID sets, targeted outing refresh, open group/chat recovery and recipient-scoped invalidations. Vote resolution and outing completion publish changes after persistence.
- Transient allowlisted GET failures can serve saved data while requesting a later backend catch-up; unexpected recovery errors cannot escape timer callbacks. Disposal/logout prevents late notifications and sends from updating current-account UI.
- A bounded in-memory server invalidation journal supports recipient-scoped `data:reconcile`; process restart, retention expiry or invalid cursor requests REST reset. Chat content is recovered through REST rather than the journal.
- Background synchronization is silent, respecting the explicitly requested removal of global banners in the concurrent sync/chat task. Connection status and pending/failed delivery remain local to chat.

## Validation

Executed during this task:

- Final combined Flutter regression run: **37 passed** across offline snapshots, chat queue, coordinator, account-linking, message merging/request deduplication, chat sender rendering, group roster, outing hydration and outing schedule tests. Coverage includes slow-backend cached startup, deferred account-sync deduplication, offline/reconnect/resume, targeted vote refresh, capped retry recovery, logout/session isolation and disposal. No global status strip is delivered.
- Backend lifecycle, resource authorization and two-client socket delivery: **24 passed**. Backend chat conflict, scoped socket delivery and cursor recovery: **6 passed**. Socket tests use local fixture identities; they do not authenticate two real Firebase users or drive two devices.
- Backend `tsc --noEmit`: passed. Lifecycle/authZ tests emitted fixture notification foreign-key warnings while their assertions passed; successful assertions do not prove notification delivery.
- Flutter analyzer: **zero errors, four warnings and 25 info/style findings** (29 total, nonzero exit). Findings span auth, network, chat and existing invite/discover code. This is not a clean analyzer result.
- DTD discovery and hot reload attempted: no running debug app/DTD was available. Physical phone, emulator, foldable, keyboard, screen-reader and real two-user end-to-end UI checks were not run. Widget tests cover rendering/interaction, not device visual acceptance.

## Limits

- Local preference storage is unencrypted and bounded: snapshots at most 200 entries per account/origin, up to 512 KiB each; chat at most 100 messages across each of 20 outings; outbox at most 100 pending and 30 retained failed sends. Images and arbitrary standalone user profiles are not downloaded for offline use.
- No OS background worker. Queued sends resume in the foreground. Connectivity reports network-interface availability; it cannot prove backend reachability. Transport failure uses saved reads and retry state.
- Catch-up performs at most five delayed retry attempts before retaining dirty state for a fresh foreground/network/server trigger. Chat pending-send retry is separate. Immediate cached startup and one-time deferred account-sync deduplication are covered by regression tests.
- History recovery fetches the latest chat page. A long disconnection can require loading older history; the client does not promise an exhaustive automatic download of all intervening messages.
- Offline data can reflect old membership until an authenticated revalidation learns of revocation. Server authorization remains authoritative. Logout discards the previous account's cached data and unsent messages.
- Socket delivery/journal remain single-process and best effort. There is no durable distributed event log or Redis adapter; restarts/expiry require REST recovery. Changes whose audience lookup fails may only be discovered by later REST revalidation.
- Votes, RSVP, arrivals, invitations, membership, account/security changes, deletion and lifecycle commands remain online-only.

## Documentation Updates

Updated `ARCHITECTURE_DECISIONS` (ADR-014), `FLUTTER_ARCHITECTURE`, `BACKEND_ARCHITECTURE`, `SYSTEM_ARCHITECTURE`, `SYSTEM_DESIGN`, `API_CONTRACTS`, `AUTHENTICATION_AND_AUTHORIZATION`, `BUSINESS_LOGIC`, `USER_SCENARIOS`, `PRODUCT_SCENARIOS` (current implementation only) and `PROJECT_STRUCTURE`. The system architecture diagram now includes snapshots, outbox and coordinator. No database diagram change is required. Historical audit reports remain historical; device acceptance remains unverified. Coordinated with the concurrent sync/chat task to preserve silent background synchronization, profile GETs and deferred account synchronization.
