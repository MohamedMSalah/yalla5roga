# Yalla 5roga production readiness

**Candidate for isolated staging. Public production remains blocked.** · 22 November 2026

## Remediation since a90c360

**Isolated staging verdict.** The backend and Flutter changes are ready for an isolated staging rollout after an operator provisions and verifies the expected Firebase, PostgreSQL, R2 and ingress targets. Local verification used disposable loopback PostgreSQL, Firebase fixture identities, synthetic R2 signing credentials and host Flutter tests.

**Public production verdict.** Hold release until staging demonstrates live Firebase session revocation and deletion, R2 anonymous access denial and catalog delivery, trusted HTTPS and WebSocket ingress, Linux signal handling, and signed mobile builds on physical devices. Public deployment also requires approval of shared-history retention and review of the four residual dependency advisories.

| Release blocker | Current status | Evidence and remaining work |
| --- | --- | --- |
| Flutter host failures | Resolved locally | The rerun reproduced 11 of the 12 reported failures. Chat now prefers the caller's current name over stale message metadata. Image eviction targets the private account key, keeps shared public cache files and drops an inaccessible private image when the authenticated API omits it. Corrected GPS status and button expectations, scrolled before selecting an occasion, exercised the actual bio and roster controls, tested invitation acceptance on the real group details route, and aligned diagnostics with actual request IDs and duplicate attribution. Native location, storage and rendering are staged device checks. |
| High dependency advisories | Resolved in the lockfile | All five high advisories cleared in both full and production audits. See the reachability review below. |
| Account deletion | Verified with disposable identities and database fixtures | A self-scoped 202 records an atomic cleanup, revokes application access, closes open sockets and schedules Firebase/R2 work. Tests cover ownership transfer, shared history, invitation and inbox cleanup, UID resurrection guard, separate provider failures, retries and completion. Provider deletion and backup/retention review remain staging gates. |
| Firebase and realtime | Verified at the SDK boundary and over loopback transports | Production REST requests and all handshakes check Firebase revocation. Established sockets recheck every 30 seconds with a five-second limit and close at expiry. Tests cover invalidation, rejection, refreshed reconnect, role joins and room cleanup. Live identity and TLS proxy behavior remain unverified. |
| R2 privacy | Application boundary verified | Separate bucket selection, curator-only catalog delivery, cross-account access and object-scoped GET/PUT signing passed locally. Only canonical place keys in the configured public catalog bucket get CDN URLs. Live bucket policies, signed URL enforcement, response headers, and legacy catalog backfill remain unverified. |
| Authenticated API coverage | Expanded | Served OpenAPI and disposable PostgreSQL now cover authenticated group, invitation, vote, RSVP, arrival, chat and notification writes, plus negative ownership cases and account deletion. Some operations still have boundary-only evidence. [Coverage matrix](PRODUCTION_API_COVERAGE.md) |
| Staging configuration, ingress and lifecycle | Local verification passed | Production startup rejects mismatched targets. A loopback HTTP test proves separate client buckets through a trusted proxy and rejects spoofed forwarding from an untrusted hop. Health and monitoring checks passed on the compiled artifact. External ingress, provider health, and Linux shutdown remain staging gates. [Exact staging verification steps](../development/PRODUCTION_DEPLOYMENT.md#staging-verification-and-android-release) |

### Remediation verification

| Check | Result |
| --- | --- |
| Backend frozen lockfile install, type check, production build | Passed. Prisma generation was also run explicitly. |
| Complete backend suite | 330 passed, 0 failed, 0 skipped, in 28 suites. |
| Backend contract target | 144 passed, 0 failed, 0 skipped, including the 114-operation boundary sweep and the authenticated workflows. |
| Flutter host suite | 203 passed, 0 failed. |
| Flutter analysis | 0 errors, 0 warnings, 37 pre-existing info-level findings. |
| Prisma | Schema validation passed. All 26 migrations applied to fresh loopback PostgreSQL and schema drift check passed. |
| Dependency audit, full and production | 0 critical, 0 high, 3 moderate, 1 low. |
| Compiled production-mode smoke | Six background components started on loopback. Liveness, readiness, protected diagnostics and metrics passed. Triggering the signal handler shut down with Socket.IO closed, Prisma disconnected and zero failed cleanup tasks. Actual Linux signal delivery and ingress drain remain staging checks. |

### Dependency reachability

| Original high finding | Production reachability and disposition |
| --- | --- |
| `effect` GHSA-38f7-945m-qr2g | Prisma CLI configuration dependency. The vulnerable Effect RPC path had no caller in the HTTP/Socket.IO runtime. Production audit included the CLI through the Prisma client peer. Scoped override pins 3.22.1. [Advisory](https://github.com/advisories/GHSA-38f7-945m-qr2g) |
| `effect` GHSA-7589-6fvf-x4pw | Same Prisma chain. No application import or user-supplied Effect schema compiler. Scoped override pins 3.22.1. [Advisory](https://github.com/advisories/GHSA-7589-6fvf-x4pw) |
| `deepmerge-ts` GHSA-ggr8-5vv4-36mx | The Prisma config loader can run during generation and migrations with repository-controlled input. Scoped override pins 8.0.0. Build, generation and migration rehearsal exercise this path. [Advisory](https://github.com/advisories/GHSA-ggr8-5vv4-36mx) |
| `@grpc/grpc-js` GHSA-m9gg-hp2v-232j | The affected version came through the Firebase client Firestore bundle. Source uses Firebase Auth and Firebase Admin only. Removed the umbrella package in favor of its pinned App/Auth components. The Admin dependency graph still has a patched gRPC release. [Advisory](https://github.com/advisories/GHSA-m9gg-hp2v-232j) |
| `re2js` GHSA-gg6h-894w-4m9c | The affected library came through client Firestore. Removed with the Firebase umbrella package. A fixture exercises concurrent custom-session exchange through the narrower SDK and verifies cleanup of the ephemeral apps. [Advisory](https://github.com/advisories/GHSA-gg6h-894w-4m9c) |

Moderate `glob` and `minimatch` remain through Swagger generation and optional Firebase Admin Firestore dependencies. Swagger initializes from repository-controlled file patterns in production, so that installed path still executes at startup. Moderate `uuid` and low `fast-xml-parser` remain through Firebase Admin's optional Google Cloud Storage graph. Application object traffic uses the AWS R2 client. Treat the installed optional graph as a residual supply-chain risk. Recheck it on release and before adding any Firestore/Cloud Storage use or configurable Swagger file patterns. [glob](https://github.com/advisories/GHSA-3g3m-2fjr-6pw4) · [minimatch](https://github.com/advisories/GHSA-g3hv-75wg-m249) · [uuid](https://github.com/advisories/GHSA-w5hq-g745-h8pq) · [fast-xml-parser](https://github.com/advisories/GHSA-474x-hrwr-fgx4)

### Open staging and public release checks

- Verify the provider boundary against separately provisioned resources. Use disposable Firebase identities and R2 objects, run the trusted-ingress and shutdown checks on the staging host, and capture results and build revisions. Confirm that pre-existing signed upload windows have elapsed before counting deletion of legacy objects as complete. [Staging runbook](../development/PRODUCTION_DEPLOYMENT.md)
- Sign the staging mobile build with the approved key and run the physical-device checklist below when authorized. Verify push, app links, real GPS, localization, offline cache behavior and release permissions.
- Review privacy and retention for shared outing details, backups, third-party delivery and copies held by other users. The deletion journal retains an account digest and timestamps to prevent replay. No live provider or hosting changes were made during remediation.

## Historical baseline at a90c360

The audit started on `main` at `fd8876a21ad873cddaf5f5d4f07c04bbc9652cfd`. GitHub reported that same branch tip before review. The worktree already had changes to the Home header, Flutter architecture and setup documentation, Flutter README, an Android Gradle report and untracked Kotlin build state. Those are excluded from the audit changes.

Local API contract coverage, database concurrency tests and a low-rate performance baseline provide evidence for staging preparation. Public release is held by unresolved mobile tests, device verification, external service and hosting verification, account-deletion semantics, and remaining dependency advisories. No public backend was started. See the [deployment and rollback runbook](../development/PRODUCTION_DEPLOYMENT.md) and [route and Flutter consumer matrix](PRODUCTION_API_COVERAGE.md).

## Findings and remediation

| Severity | Status | Affected file and root cause | Remediation and evidence |
| --- | --- | --- | --- |
| High | FIXED | `backend/src/routes/media/index.ts` mounted anonymous development upload and download routes whenever R2 credentials were absent, including production. The upload buffered bytes in process. | The production router excludes both routes. The production media service rejects missing storage with 503. See the production route inspection and isolated tests. |
| High | BLOCKED | `backend/src/services/media/r2-storage.adapter.ts` and `backend/src/config/media.ts` store public catalog and private user assets in the same bucket. Attaching a public R2 domain to that bucket can bypass application visibility controls. | The runbook calls for private access and a prefix-restricted gateway where public CDN URLs are needed. Verify anonymous access denial and signed PUT/GET scope against isolated R2. |
| High | BLOCKED | `backend/src/usecases/users/delete-user.usecase.ts` and `backend/src/datasources/users/user.datasource.ts` delete the Neon user only. Creator foreign keys may block profile deletion, and the Firebase identity remains. | Define retention, ownership transfer or anonymization, and Firebase/Neon cleanup as a coordinated workflow. Test authorized deletion against disposable accounts. |
| High | FIXED | `backend/pnpm-lock.yaml` originally had high advisories on reachable versions of Zod and Express's body-parser and on Joi. | Updated validators and patched transitive body-parser and qs. Registry audit moved from 18 to 14 advisories, including five remaining highs. |
| High | FAIL | Remaining lockfile issues include high advisories through Prisma CLI helpers effect/deepmerge-ts and unused Firebase SDK Firestore subpaths grpc/re2js. | Compatibility and code-path review found no Firebase Firestore imports. The audit still reports these dependencies. Resolve or risk-accept before public release. |
| High | BLOCKED | `backend/src/middleware/auth.middleware.ts` signed-token verification omitted revocation, including for Socket.IO connection. Existing sockets authenticate at the handshake. | Production enables Firebase revocation checks on HTTP and new socket connections. Authentication upstream failures with recognized transient codes return 503. Revocation of already connected sockets and live Firebase verification remain release work. [Firebase session documentation](https://firebase.google.com/docs/auth/admin/manage-sessions) |
| High | BLOCKED | `flutter/android/app/build.gradle.kts` previously used the debug signing configuration in release. | Release uses ignored `key.properties`. The signer, permit to publish for the application ID, Firebase SHA registration, device testing, APK packaging and final release URL are pending. |
| Medium | FIXED | `backend/package.json` chained migration DDL to every process start. `backend/src/app.ts` exposed Swagger and persisted Swagger auth in browser storage. | Migration has its own `pnpm db:deploy` command. Production excludes Swagger and development Swagger keeps auth in memory. Headers now disable framework advertisement and browser MIME sniffing. |
| Medium | FIXED | `backend/src/middleware/error.middleware.ts` returned 500 for oversized or unsupported bodies. | The new contract test asserts 400, 413 and 415, the error envelope, and response headers. Registration adds body error statuses to OpenAPI. |
| Medium | FIXED | `backend/src/realtime/socket-auth.ts` accepted tokens in URL queries. Socket.IO CORS covered polling, while WebSocket transport needed its own ingress origin check. | Accept handshake auth or the Authorization header, and enforce the configured browser origin when accepting new transports. The Flutter client supplies its token through the auth callback. |
| Medium | FIXED | `flutter/lib/core/media/media_url_resolver.dart` could apply a late signed-URL response after logout, and sent more than the API's 50-ID batch limit when many images resolved together. `api_client.dart` could replace a caller's explicit expected account. | Bind a batch to its originating account and session, discard late results, keep explicit account expectations, and cap every batch at 50. The targeted media regressions cover late results after cleanup and 51 simultaneous resolutions. |
| Medium | NOT TESTED | `backend/src/middleware/api-rate-limit.middleware.ts` used the reverse proxy IP by default behind ingress. | Set `TRUST_PROXY` to actual trusted ingress addresses or CIDRs and verify per-client buckets and untrusted forwarding on the chosen host. |
| Medium | FAIL | Flutter’s full host suite has outstanding failures across layout, navigation, location and offline tests. | The audit corrected notification deduplication fallback in `push_notification_payload.dart`, restored stale Socket.IO fake methods in sync tests, and aligned notification destination assertions with existing behavior. See the Flutter verification section. |
| Medium | NOT TESTED | `backend/src/realtime/data-changes.ts` retains replay in the process. Polling is enabled on the backend, while the current Flutter connection selects WebSocket. | Keep one process and confirm real TLS WebSocket through ingress. Run reset/reconciliation and missed-event cases with real clients. |
| Low | NOT TESTED | Several declared backend dependencies have no matching runtime import. Flutter has old compatibility constructors and paths. | Cross-repository usage and compatibility review remains open. No bulk removals were made. |

## Routes, ownership and integration

The route matrix lists the 114 production API operations, Swagger boundaries and static Flutter references. Every listed boundary received an HTTP response and satisfied its test assertions. Most protected route executions assert 401 for a missing token. The matrix marks that exact assertion. No authenticated success, ownership, pagination or concurrency pass can be inferred from a 401. Swagger and the registered API agreed in the isolated contract test.

The isolated suite also exercised group access and role checks, pending group membership and acceptance, reminder/outbox handling with substitute channels, request validation, voting write serialization and repeated tie resolution, chat deduplication, read and realtime scope, cache revision and viewport filtering, and password recovery with test identity fixtures. Some of this evidence is at the service or repository layer. The authenticated cross-account, empty/missing resource, write idempotency and true success-path matrix remains incomplete across the API. Real Firebase sessions, OTP/SMS, R2 writes, FCM/APNs, WhatsApp and external geocoder failure paths are **BLOCKED** pending isolated credentials and device coverage.

Base API URL, HTTPS validation for release builds, the debug-only development cleartext override, Dio timeouts and safe retry paths were reviewed in source. Public host/TLS, native deep link registration, Android/iOS capabilities and release package merging remain **NOT TESTED**. Flutter's version is `1.0.0+1`.

## Database

The verified Neon branch was PostgreSQL 18.7. The read-only catalog identified 40 public tables, 359 columns, 388 constraints, 128 indexes and 11 custom triggers before deployment. The checked aggregate invariants found zero invalid phone values, ownerless groups, invalid outing types or unused delivery-channel records. This is a scoped data audit. It does not establish comprehensive orphan, duplicate, lock-wait or production load coverage.

Before deployment, 24 migrations were applied and `20261121000000_outing_location_snapshot` was pending. Its exact SQL adds `outings.location_category_id`, `outings.location_address`, `outing_vote_options.category_id` and `outing_vote_options.address` as nullable columns. The backup captured 212,196 rows across 40 tables in a restricted directory. Recovery restored all data, foreign keys and indexes and matched every table checksum before rehearsing the pending SQL in an isolated database. The rehearsal transaction rolled back. The audit expanded backup support for the current custom triggers and records the session timezone for reproducible timestamp checksums.

**FIXED** after deployment. Readback verified all 25 applied migration checksums and all four nullable columns. Prisma reported no difference against Neon or the disposable database. The original diff flagged current voting round, vote-option FK naming and referential actions on voting, password recovery and place brand relationships. The updated model represents the installed relationships and actions. The deferred current-round constraint is defined in SQL migration history. Direct Neon catalog checks found zero unvalidated foreign keys and zero invalid indexes.

Two read-only Neon plans for the viewport page-selection query both used `idx_places_catalog_updated`. One district bounding box produced 101 rows after rejecting 792 candidates, with 113.183 ms database execution. A broader regional viewport returned 101 rows without removals in 0.233 ms. These are single executions of the page-selection portion, with different selectivity and unknown cache warmth. They exclude client latency and JSON relation aggregation. PostgreSQL **NOT TESTED** areas include production failover, pool saturation, timezone edge cases for legacy rows and production-scale concurrency.

## Observability and performance

Dio and Express propagate request and correlation IDs. Existing monitoring tracks sanitized method/template, origin category, trigger, attempts, latency, status, cache, body length when known, auth timing, Prisma operation counts and Socket.IO counters. SQL engine timings and counts are aggregate. The audit did not establish exact SQL statements per request or shared request IDs for all native map, signed-media, push and Socket.IO traffic. Production telemetry is optional and private monitoring uses its own bearer credential.

The existing request deduper, TTL cache, viewport cancellation and account-based snapshot rules remain in use. The benchmark produces intentionally repeated traffic, which the duplicate detector recorded for the licenses, viewport, groups and notifications routes. No real mobile duplicate rate was measured. A separate signing and privacy review is still required for locally cached account data and native backups. Source and local tests show Discover's private place data uses owner-scoped SQLite. Confirm by inspecting real network traffic while creating, editing and deleting private places and while switching accounts.

The before and after HTTP microbenchmarks ran on loopback with 45 samples per route and zero status mismatches. The requests below omit database work. The original and patched Express entry points used the available local dependency installation. Single runs on a shared workstation cannot establish an improvement.

| GET route and status | Before P50 / P95 / P99 (ms) | After P50 / P95 / P99 (ms) |
| --- | ---: | ---: |
| `/` · 200 | 1.09 / 2.61 / 3.88 | 1.83 / 2.75 / 3.88 |
| `/health/live` · 200 | 1.57 / 3.05 / 4.49 | 1.51 / 2.25 / 2.80 |
| `/api/places/licenses` · 200 | 5.48 / 14.48 / 21.05 | 5.53 / 7.96 / 9.86 |
| `/api/places/geojson` · 400 | 1.86 / 3.04 / 3.75 | 2.27 / 2.89 / 3.33 |
| `/api/groups/cuser` · 401 | 2.10 / 4.07 / 8.92 | 1.82 / 2.76 / 2.94 |
| `/api/notifications` · 401 | 2.18 / 5.14 / 7.67 | 2.07 / 3.37 / 3.57 |

The 45-second local k6 baseline used one VU and synthetic authentication, a disposable PostgreSQL database and chat writes. It completed 107 requests at 2.37 requests/s with 0 HTTP failures, 106 passing fixture assertions and P50/P95/P99 of 6.29/32.40/47.62 ms. Chat send had the slowest P95 at 55.11 ms across eight samples. Valid viewport had P95 7.63 ms across nine samples on a small catalog. The process consumed 1,468 ms of CPU, or 3.22% of one core, with 443 SQL statements. RSS was 206.86 MiB before and 33.45 MiB after the run and fluctuated substantially in this environment. These durations include loopback overhead. Cold start, live Neon latency, event loop lag, cache and duplicate rates and sustained production throughput were not measured. High-load profiles and restart or external failure simulation were not run. See the [existing observability and k6 commands](../development/OBSERVABILITY.md).

The compiled production entry point passed a loopback smoke test using disposable PostgreSQL and synthetic Firebase setup. Its startup report measured 129.29 ms after module loading, including 89.39 ms to connect to PostgreSQL and a 10.01 ms readiness query. RSS was 146.7 MiB and five background components started. Liveness, readiness and protected dependencies each returned 200. Linux signal handling remains untested.

## Verification and remaining release gates

- **Backend PASS** for frozen installation, Prisma validate, type check, production build, and the final isolated 324-test run in 28 suites with zero failed or skipped. Socket.IO tests covered authenticated fixture connections, browser origin enforcement, unauthorized joins, account-scoped replay, removed-member delivery, chat room behavior and stale reconciliation cursors. The production boundary tests also exercised removed docs/mock surfaces and verified that the Firebase SDK receives the revocation flag. Final ingress and real token revocation remain unverified.
- **Flutter FAIL** in the full host suite. The initial run had 159 passes and 40 failures, and the final run had 190 passes and 12 failures. All 32 focused notification, sync and snackbar tests and both new media regressions passed. Full analysis reported 37 info-level lints and zero warnings or errors. Targeted analysis passed for the changed notification, sync and media code. Remaining failures include GPS arrival, outing occasion selection, group roster and bio, invitation navigation, chat sender display, request diagnostics and a missing path-provider plugin in the host image-cache eviction test.
- **Dependency audit FAIL** after the targeted fixes. The registry reported zero critical, five high, five moderate and four low findings. Remaining high dependency paths were Prisma configuration and Firebase SDK Firestore subpaths.
- **Android configuration PASS** for Gradle's offline signing report. The release variant referenced the release signing configuration. Signing credentials were absent, so generating and validating a signed release APK is **BLOCKED**.
- **Lint BLOCKED** for an independent backend lint run. This checkout has no backend lint command or lint configuration. The TypeScript command provides a separate type check.
- **External services BLOCKED** for live Firebase identity/refresh/OTP, FCM/APNs, production R2 authorization, WhatsApp, Linux host, TLS proxy, and real mobile behavior. Source, fixture tests and successful initialization are narrower than these gates.
- **Secret scan PASS for checked patterns.** Tracked-path and content-pattern checks printed filenames only. The only private-key pattern hit was the PEM example in the backend environment template. This was a tracked-worktree check, not a full-history or provider-side scan.

## Manual device checklist

- Build with approved Android signing and the chosen HTTPS endpoint. Confirm app links and release permissions including opt-in notifications, contacts, location and camera. Validate iOS bundle ID, signing, APNs and associated domains if shipping iOS.
- Use two staging accounts for login, expired/revoked tokens, recovery, account switch, logout and stale notifications. Verify correct deep-link destinations, mark-all-read, actions and delivery foregrounded, backgrounded and terminated.
- Exercise group CRUD, owner/member access, duplicate and pending invites for unregistered phone numbers, last-owner checks, group changes while offline, and the approved account deletion procedure.
- Exercise creation from single and multiple branches, deadlines, multiple votes, tie flows, RSVP, actual GPS check-in, history, editing/cancellation and unavailable location. Verify server permissions and timezone display around date rollover.
- Exercise chat send/edit/delete/mentions and paginated ordering. Drop connectivity with queued messages, then reconnect, restart the backend in staging and confirm duplicate-free recovery, room authorization and visible refresh.
- Check MapLibre start-up, Arabic RTL and English LTR, light/dark themes, narrow and wide layouts, large text, cache-first viewport loading and slow-network cancellation. Test offline map install, download interruption, resume, eviction and private-place isolation across accounts.
- Measure cold launch and repeated tabs, detail navigation, search, map changes and resume on a physical device. Capture request IDs, cache status and repeat counts. Use the [operator guide](../development/OBSERVABILITY.md) for instrumentation.
