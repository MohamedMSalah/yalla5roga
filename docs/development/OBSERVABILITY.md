# Observability and API verification

## Backend and dashboards

Configure the isolated [device profile](ENVIRONMENT_CONFIGURATION.md) and run `pnpm dev:device` from the repository root or backend. The startup report includes the actual listener, LAN addresses, routes, initialization, database probing and memory. Prometheus and Grafana are optional. Private metrics remain disabled without their own token.

| Surface | Local URL | Access |
| --- | --- | --- |
| Swagger UI | [localhost:3000/api-docs/](http://localhost:3000/api-docs/) | Firebase auth applies when executing protected API operations |
| OpenAPI JSON | [localhost:3000/api-docs/openapi.json](http://localhost:3000/api-docs/openapi.json) | Available in development and test |
| Grafana | [localhost:3300](http://localhost:3300) | `admin` and the configured local password |
| Prometheus | [localhost:9090](http://localhost:9090) | Bound to loopback in Compose |
| Liveness | [localhost:3000/health/live](http://localhost:3000/health/live) | Public process state |
| Readiness | [localhost:3000/health/ready](http://localhost:3000/health/ready) | Public coarse dependency state |
| Dependencies and metrics | `/health/dependencies` and `/metrics` | Separate monitoring bearer credential, 24+ characters |

Set a private `MONITORING_TOKEN` and `GRAFANA_ADMIN_PASSWORD` in the device profile. From the repository root, start the optional stack with the same bearer used by the API:

```powershell
pnpm monitoring:device
pnpm dev:device
```

Prometheus uses the host API port 3000 from Docker. Edit `monitoring/prometheus.yml` if the API uses another port. On Docker Desktop, the host API must listen on an address reachable by the container. The scraper uses the credential file and retains up to seven days or 750 MB of samples. Each hosting platform controls retention for Pino stdout separately. Keep private monitoring behind an internal ingress or TLS and rotate the monitoring credential independently of Firebase credentials.

## Measurement semantics

- Express records completion or early close once using a monotonic clock. `X-Request-ID` identifies an attempt, `X-Correlation-ID` groups attempts, and `Server-Timing: app;dur=…` measures elapsed time up to response headers. The final elapsed server metric includes response production through finish or close. Body bytes use the declared content length when available.
- AsyncLocalStorage associates Prisma Client operations and selected auth, authorization, service, transaction and external call spans with the request. Each sum can include overlapping or nested work. Prisma engine events supply aggregate SQL statement counts and durations. Per-request counts measure Prisma Client operations, which can issue multiple SQL statements. Pool acquisition timeouts are observable through P2024. The Prisma configuration exposes no live pool occupancy gauge.
- Process CPU seconds, RSS, heap, uptime, cumulative event-loop P99, active requests, errors, potential duplicates, sockets and background job outcomes are scraped from memory. A scrape reads the last database probe and its age. Startup and readiness perform a shared TTL-cached `SELECT 1`. The compatibility endpoint `/health` retains its existing 200/500 response envelope.
- Flutter measures Dio attempt duration and reports server header duration and the difference as an estimated transport/client overhead. The estimate includes client scheduling, authentication preparation or response decoding when those run inside the attempt. It can be omitted when timings are unavailable or inconsistent. Repository cache, snapshot and deduplication events have their own bounded diagnostics.
- Socket.IO emits aggregate connection, room, event, join overlap and listener metrics using fixed event labels. Acknowledgment timing measures server handler time until it sends the ACK. Reconnect counts are estimated from a recent authenticated disconnect and connection for the same account. Existing authorization, room cleanup, message deduplication and reconciliation remain authoritative.
- Potential duplicates group equivalent account-scoped requests by method, endpoint, target and query within a bounded monotonic window. Retry, explicit refresh, search, viewport and pagination triggers are excluded from generic alerts. Detection is advisory. Existing stable idempotency keys protect supported writes such as outing creation, draft creation and chat sends.
- Production defaults to JSON and logs anomalous HTTP completions. Set `OBS_HTTP_LOG_SAMPLE` for routine completion sampling. `OBS_DUPLICATE_WINDOW_MS` defaults to 2000. API request bands start at 250, 500 and 1000 ms. Threshold overrides use `OBS_ENDPOINT_THRESHOLDS` keyed by method and actual route template. `OBS_DB_WARN_MS` and `OBS_DB_CRITICAL_MS` default to 100/500 ms.
- Grafana exposes environment, endpoint, method, status and time selection. The latency panel requires 50 selected-range samples for P50/P95 and 200 for P99. Histogram percentiles are estimates. Compare startup and the first database connection separately from warmed measurements.
- Firebase Performance reuses a single metric per Dio attempt on the normalized URL. Repository timings are available via client `API_DIAGNOSTICS` and `API_DIAGNOSTICS_LOG`. Both default off for release. For Grafana comparisons set `OBS_MOBILE_TELEMETRY=1` and `API_TELEMETRY_SAMPLE=0.01` in the selected profile before building. The authenticated receiver permits only known route templates, strict numeric samples and at most 12 samples per batch. It caps submissions per account and IP. Metric labels omit device and account identifiers.

## Isolated API tests and workloads

From `backend`:

```powershell
pnpm test
pnpm test:contract
pnpm audit:routes
```

The default run skips database-dependent assertions. For the full suite, start the disposable database or supply a separate loopback PostgreSQL instance and a fresh database named `yalla_test*`. The test guard refuses remote targets and overrides Prisma's default environment inputs before fixtures run.

Replace `<test-user>` and `<test-password>` with the credentials for that disposable local database, as configured in `monitoring/compose.test.yml`; never use shared cloud credentials here.

```powershell
docker compose -f monitoring/compose.test.yml up -d
$env:YALLA_TEST_DATABASE_URL = 'postgresql://<test-user>:<test-password>@127.0.0.1:55432/yalla_test_local?sslmode=disable'
$env:DATABASE_URL = $env:YALLA_TEST_DATABASE_URL
$env:DIRECT_URL = $env:YALLA_TEST_DATABASE_URL
pnpm exec prisma migrate deploy
pnpm test
pnpm test:contract
pnpm benchmark:database
```

Run `pnpm benchmark:http` with `NODE_ENV=production` and `OBS_HTTP_LOG_SAMPLE=0` to compare warmed no-database paths. Repeat with `OBSERVABILITY_ENABLED=0` for a monitoring-overhead check. The live rate limit is kept intact, so the benchmark uses 45 samples per path.

With k6 on PATH or specified by `K6_EXECUTABLE`, `pnpm load:local` starts an ephemeral HTTP server against the disposable PostgreSQL fixture. It seeds group memberships, an outing and catalog records. It substitutes synthetic Firebase session verification in that process. It prints latency percentiles per exercised endpoint, request throughput, CPU, RSS and database statement count. `LOAD_SCENARIO` supports `baseline`, `concurrent`, `load`, `stress`, `spike`, and `sustained`. For constant workloads, use `VUS` of 1, 10, 25, 50 or 100 and optional `DURATION`. Set `WRITE_FIXTURES=1` to exercise chat writes. Direct `k6 run monitoring/load/workflows.js` requires fixture IDs and tokens, `ALLOW_DISPOSABLE_LOAD=1`, a local API and its monitoring credential. The `authentication` profile additionally uses synthetic login credentials from a dedicated Firebase test environment and honors the credential rate limit. The API must attest to `OBS_ISOLATED_LOAD_TEST=1` and a loopback test database before any workload starts.

Use the following matrix one scenario at a time against disposable loopback PostgreSQL. Obtain explicit approval before any significant load against a shared or hosted environment.

| Virtual users | Command from backend |
| --- | --- |
| 1 | `LOAD_SCENARIO=baseline VUS=1 DURATION=45s pnpm load:local` |
| 10 | `LOAD_SCENARIO=concurrent VUS=10 DURATION=1m pnpm load:local` |
| 25 | `LOAD_SCENARIO=load VUS=25 DURATION=3m pnpm load:local` |
| 50 | `LOAD_SCENARIO=sustained VUS=50 DURATION=3m pnpm load:local` |

In PowerShell set each variable with `$env:LOAD_SCENARIO`, `$env:VUS` and `$env:DURATION` before invoking `pnpm load:local`.

## Manual mobile verification

Device measurements are **pending**. Capture an attempt count, request and correlation IDs, cache outcome and timings with developer diagnostics. Run the same account/data scenario twice when comparing cold and warm behavior.

| Journey | What to verify |
| --- | --- |
| Cold start | Cached account views appear, followed by one deferred sync for a restored online account. Capture the first meaningful screen and the first REST/Socket.IO handshake. |
| Login and user sync | Observe one valid login/session path. Exercise an expiring ID token and confirm a new request ID under the same operation ID for the retry. Confirm phone verification still propagates fresh claims. |
| Tab navigation | Switch Home, Groups, Outings, Discover and Settings repeatedly. Look for TTL hits and one request per legitimate refresh. |
| Reopen details | Open and close the same group within its TTL and after expiry. Manually refresh and verify it revalidates. Verify revoked access evicts affected snapshots. |
| Cache expiry | Follow a stored list through expiry, invalidation, a new request and an offline fallback. Check account isolation after logout and a second login. |
| Discover viewport and search | Pan rapidly, replace a search and paginate. Confirm obsolete requests cancel, current pages render, and a partial cancelled region never becomes complete. |
| Socket updates and reconnect | Exercise attendance, voting, notifications and chat. Verify membership checks, live state updates, chat room cleanup and targeted catch-up after forced disconnect. |
| Background and resume | Pause during active sync, then resume. Observe one recovery sequence and preserved dirty work across backoff. |
| Offline and poor network | Load cached views, observe bounded retries and ensure queued chat sends retain one stable message ID until acknowledged. |

See the [measured results](../audit/OBSERVABILITY_RESULTS.md) and [endpoint/consumer inventory](../audit/API_CONSUMERS.md).
