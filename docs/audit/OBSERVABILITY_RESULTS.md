# Observability and performance results

Measured on 2026-11-21 in the Windows checkout using Node 24, loopback HTTP and a disposable PostgreSQL 18 instance with all 25 repository migrations. PostgreSQL fixtures used injected Firebase identity/session verification. The [operator guide](../development/OBSERVABILITY.md) contains commands and the pending device checklist.

## Coverage

The backend suite passed 321 tests with the disposable database enabled. Dart analysis passed on the changed paths and all 16 focused headless Flutter tests passed.

- Express registered 114 production API operations and 116 when the two optional development mock-storage routes were enabled. The 114 production registrations matched the served Swagger document. The [consumer inventory](API_CONSUMERS.md) lists every method and path with its Flutter source evidence or review status.
- Every documented production API operation executed an asserted public or protected boundary case. The suite checks statuses and documented response shapes. Most protected operations in that matrix exercise 401. Successful and forbidden paths are verified separately for the seeded group, outing, notification, catalog and chat workflows.
- Positive registered-app cases cover group creation/list/detail/roster, user sync/profile, outing creation/list/detail, vote option creation/list/deletion and voting state, notifications, chat history and idempotent send, plus seven public catalog paths. Additional rollback, password recovery, login/signup, multi-round voting and constraints execute in isolated feature tests.
- The live Socket.IO fixture verified handshake rejection, authorized group and outing joins, explicit leave, disconnect cleanup and event counters. The fixture also exercised protected telemetry acceptance and rejection of raw resource paths.
- The API startup smoke verified public liveness and readiness, authenticated dependency status and graceful cleanup. One cold local start recorded 65.47 ms to connect, a 5.75 ms probe and 92.23 ms initialization after imports. Those values describe this process and its local PostgreSQL instance.

## Confirmed causes and changes

| Area | Cause | Change |
| --- | --- | --- |
| Places license bundle | Four synchronous disk reads on every request | Cache the immutable bundle for the process lifetime |
| Outing detail | Outing row read twice plus membership and guest lookups for a group member | One parameterized query returns the authorized row and preserves 403/404 distinctions |
| Vote closure | One update per candidate and materialization of each vote row | Aggregate votes in PostgreSQL and persist tallies in one bulk write within the existing row-locked transaction |
| Flutter 401 retry | Refresh cleanup returned the future it was completing | Fix cleanup, coalesce token reads/refresh while in flight and reuse the refreshed token on the replay |
| Group navigation | Detail always forced a network request, while the Provider could bypass repository expiry on other entries | Use the existing detail TTL on navigation and revalidate on manual refresh or invalidation |
| List caching | A targeted detail refresh could renew the whole group or outing feed. An invalidation could be undone by an in-flight fetch. | Preserve the original expiry when patching a list and guard cache writes with a revision |
| Profile and lifecycle | Profile refresh requested a token immediately before the interceptor did. Authenticated resume could request catalog recovery twice. | Share ordinary token reads, skip the unique-phone lookup when the verified phone already matches the stored account, and route resume recovery through the existing coordinator |
| Discover | Obsolete noncompact searches and viewport pages could remain in flight. Cancelled reads could return an empty success. | Propagate cancellation to Dio and prevent obsolete results from writing authoritative cache coverage |
| API contract | Vote-option writes could return an undocumented 403. The replace operation described a single option. | Document the observed status and options-array request |
| Diagnostics | Auth debug output, per-request Prisma query output and duplicate client logs carried unnecessary detail | Use scoped IDs, bounded structured observations and sanitized dependency messages |

Existing chat and outing idempotency, account-scoped caches, targeted attendance events, Socket.IO coalescing and debounced recovery are retained. No endpoint or index was removed. No schema migration was added.

## Before and after HTTP benchmark

One client, 25 warm-up requests and 45 measured calls per path. Times are P50 / P95 / P99 in milliseconds. All observed statuses matched expectation. A 45-sample P99 is effectively the maximum and is descriptive.

| GET path | Status | Pre-change | After, monitoring on | After, monitoring off |
| --- | ---: | ---: | ---: | ---: |
| `/` | 200 | 0.830 / 1.914 / 3.596 | 0.806 / 1.453 / 2.059 | 1.193 / 1.732 / 2.131 |
| `/health/live` | 200 | New path | 0.880 / 1.977 / 2.554 | 0.646 / 0.998 / 1.259 |
| `/api/places/licenses` | 200 | 5.813 / 7.396 / 20.569 | 2.973 / 4.664 / 16.760 | 2.527 / 3.607 / 3.669 |
| `/api/places/geojson` | 400 | 0.985 / 1.676 / 2.111 | 1.025 / 1.851 / 2.215 | 0.816 / 1.577 / 1.946 |
| `/api/groups/cuser` | 401 | 0.757 / 1.153 / 1.530 | 0.894 / 1.793 / 1.873 | 0.698 / 1.140 / 1.318 |
| `/api/notifications` | 401 | 0.610 / 0.925 / 1.275 | 1.033 / 2.189 / 2.454 | 1.041 / 1.447 / 2.291 |

License throughput improved from 165.12 to 289.23 requests/s with monitoring enabled. Process CPU used 265 ms before and 171 ms after for the measurements at that endpoint. The after-run P95 delta from enabling monitoring was −0.28 to +1.06 ms across the probe set. Separate Windows process runs include scheduling and GC variation. RSS at the end was 317.35 MiB with monitoring and 311.23 MiB with monitoring off. These are observed run differences. Device and production overhead remain unmeasured.

The database benchmark compared the former group-member outing lookup and refetch with the consolidated lookup against identical fixtures. It verified equal returned rows and alternated 200 samples per variant after warm-up.

| Outing detail lookup | Prisma operations per read | P50 / P95 / P99 |
| --- | ---: | ---: |
| Former access check and refetch | 4 | 4.166 / 5.299 / 6.080 ms |
| Consolidated | 1 | 0.704 / 1.184 / 1.558 ms |

The measurement above covers the read use case. The k6 runs below measured end-to-end HTTP on the current implementation.

## k6 workflow results

k6 2.4.0, 45 seconds per run, 150 ms think time, ten seeded user identities and optional chat writes enabled. Throughput includes one setup health request. CPU and RSS are for the backend process.

| Run | Requests/s | Errors | HTTP P50 / P95 / P99 | SQL statements | CPU, % of one core | RSS start → end |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 VU | 14.55 | 0 / 656 | 3.51 / 20.63 / 42.72 ms | 2,832 | 8.38% | 222.64 → 174.38 MiB |
| 10 VUs | 137.92 | 0 / 6,226 | 4.96 / 32.43 / 67.90 ms | 27,815 | 72.42% | 238.13 → 392.85 MiB |

All 655 and 6,225 workflow status assertions passed respectively. The 1-VU per-endpoint tail samples are small. The 10-VU run recorded 514–523 samples per endpoint. Chat send and voting-state had the largest P95 in that run.

| Operation | 1 VU P50 / P95 / P99 (ms) | 10 VUs P50 / P95 / P99 (ms) |
| --- | ---: | ---: |
| GET `/api/groups/cuser` | 2.78 / 4.43 / 7.78 | 3.15 / 8.82 / 67.41 |
| GET `/api/outings/cuser` | 3.16 / 4.81 / 8.02 | 3.92 / 10.31 / 27.23 |
| GET `/api/places/recommendations` | 0.87 / 1.55 / 20.78 | 0.99 / 4.37 / 20.91 |
| GET `/api/groups/:id` | 3.27 / 4.54 / 4.81 | 3.61 / 11.52 / 17.74 |
| GET `/api/groups/:id/members` | 5.48 / 8.03 / 16.13 | 7.07 / 20.65 / 39.56 |
| GET `/api/outings/:id` | 2.11 / 4.08 / 23.18 | 2.09 / 8.50 / 13.07 |
| GET `/api/outings/:id/voting-state` | 6.82 / 17.35 / 47.91 | 11.76 / 44.66 / 77.89 |
| GET `/api/places` | 3.23 / 4.97 / 18.84 | 3.88 / 14.43 / 47.37 |
| GET `/api/places/geojson` | 2.51 / 4.03 / 5.46 | 3.50 / 14.96 / 23.73 |
| GET `/api/notifications` | 3.41 / 5.88 / 9.67 | 7.77 / 20.28 / 32.44 |
| GET `/api/outings/:outingId/messages` | 5.48 / 8.17 / 61.40 | 6.98 / 24.94 / 80.26 |
| POST `/api/outings/:outingId/messages` | 20.46 / 53.04 / 100.12 | 28.95 / 80.70 / 135.52 |

All k6 configurations parsed. Three additional 12-second read-only load checks used 300 ms think time. Their request mix and duration differ from the 45-second workload.

| Short read check | Requests/s | Errors | HTTP P50 / P95 / P99 | SQL statements | CPU, % of one core | RSS start → end |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 25 VUs | 166.45 | 0 / 2,051 | 5.07 / 52.78 / 157.74 ms | 5,861 | 59.58% | 234.11 → 294.92 MiB |
| 50 VUs | 317.27 | 0 / 3,905 | 7.34 / 99.57 / 151.39 ms | 11,185 | 110.37% | 226.58 → 357.25 MiB |
| 100 VUs | 532.47 | 0 / 6,556 | 34.28 / 161.57 / 280.49 ms | 18,864 | 184.21% | 230.71 → 394.04 MiB |

## Verification limits

- Every documented API operation passed its boundary case. The other success and failure combinations are pending beyond the inventory and workflow assertions. External Firebase account actions, actual OTP exchange, push, WhatsApp and R2 were outside the local fixtures.
- The k6 authentication profile and full-duration stress, spike and sustained profiles remain unmeasured. The tests used no production or shared database traffic. Neon warm-up, hosted network latency, per-client network overhead and production capacity are pending.
- Grafana provisioning and scrape files are supplied for Docker. Containerized rendering and scraping require Docker and were pending in the Windows verification environment.
- Flutter device measurements, navigation visuals, real network cancellation and live-device reconnect are pending. Headless tests and source checks exercise related logic; the manual checklist covers device collection.
