# Places management delivery — 2026-11-14

The implementation spans Prisma/Neon, the existing places APIs, an external scheduled worker, Discover, Create Outing and its shared map picker. The additive migration is deployed. **The live initial import is blocked by OSM source availability/freshness; this deployment is not yet validated with a populated live catalog.** No place data was fabricated or imported from rejected responses.

## Delivered behavior

- 36 stable bilingual categories in seven groups; 15 bilingual vibes; multi-vibe place relationships with mapping provenance. The four existing outing-vibe values remain compatible with outing/history/voting contracts.
- OSM administrative areas EG-C/EG-GZ cover Cairo/Giza rather than matching district names. Queries include supported indexed tag families and lifecycle prefixes. Names/coordinates/contact/address/hours and source metadata are normalized; unavailable fields remain absent. Existing cover images, fallback rendering, structured weekday hours and prices are preserved. Unknown OSM prices are not presented as an inferred cost level.
- Parameterized batched upserts match `(source,source_type,source_id)`. A leased/fenced PostgreSQL lock coordinates API and CLI workers; place-row locks serialize curator overrides. Fetches validate before the atomic place/mapping/status commit. Per-request retry/backoff, request spacing, mirror failover, Retry-After handling and persisted progress/errors are included.
- Source metadata retains raw tags under `source_tags.tags` and source version/edit time under `source_tags.meta`. Older OSM object versions cannot overwrite newer observations. Source snapshots must be no older than 48 hours, have a plausible timestamp, identify exactly one administrative area and pass final count validation without runtime remarks. Successful coverage/snapshot timestamps are logged.
- Explicit demolition/removal/retirement can permanently close an identity; ambiguous disuse or `opening_hours=closed/off` is temporary. Current supported tags can reopen it. Three consecutive complete successful covered absences mark an otherwise available place unverified. Partial/dry/failed imports never advance absence. Curator-managed and source=manual rows are protected. DELETE archives; outing/vote/saved/media references remain.
- Existing `GET /api/places` keeps its array envelope and adds pagination/attribution, category/vibe/search/status/nearby/bbox/distance filters. Taxonomy, catalog revision and protected sync/status/history routes extend the existing router. Curators retain the existing Firebase/allowlist authorization. The external worker uses a separate server-only secret.
- Discover and Create Outing share definitions, filter/query policy, grouped selection chips, distance/search, pagination, availability metadata and offline snapshots. Filters survive wizard/map navigation. Catalog list and available map markers use the same results; existing selected places remain marked. Existing custom pins and geographic search are retained. Historical details refresh status and disable planning at unavailable venues. Backend mutation transactions reject permanently closed catalog IDs.
- Existing image widgets/cache, Provider/ChangeNotifier, Dio, manual L10n, GetX navigation and theme/responsive tokens remain. Snapshot query keys are canonical and bounded by the existing account/origin cache quotas. Previously loaded records support offline filtering. Transactional PostgreSQL NOTIFY/LISTEN forwards catalog invalidations across worker/API processes through the existing socket; revision checks on reconnect/resume repair gaps without Flutter polling.

## Deployment and live results

| Check | Result |
|---|---|
| Additive migration | `20261114040000_places_catalog_sync` applied through Prisma Migrate |
| Configured Neon target | Existing configured project/branch/database verified before deployment |
| Safety rehearsal | Private logical backup; restore with keys/indexes/FKs and exact migration in a rolled-back schema |
| Existing rows | All 663 original rows across 27 tables preserved by original-column checksums |
| Taxonomy | 36 active categories; 15 active vibes |
| Initial live import | Two attempted 1,000-place validation runs failed safely; **0 imported, 0 updated, 0 closed** |
| Source failures | HTTP 502/504, timeouts, and snapshots dated June/July 2026, stale against 2026-11-14 |
| Existing outings | All 4 original outings retained with identical values |
| Last successful full sync | None yet; due remains true and no lease remains held after failed imports |

The first lightweight source probe returned 6,897 Cairo amenity elements and 1,079 normalized candidates, but subsequent import attempts could not obtain consistently complete/fresh source responses. That preliminary result is not counted as an imported dataset. Read-only freshness probes also tried the documented official server hosts and another global mirror; no reliable source was established during this task.

Evidence: [migration deployment](PLACES_MIGRATION_DEPLOYMENT.json), [initial import](PLACES_INITIAL_IMPORT.json), [source probe](PLACES_OSM_PROBE.json), [source health](PLACES_SOURCE_HEALTH.json), [live readback](PLACES_LIVE_READBACK.json). Private row backups are ignored under `backend/.database-backups/`; they are not public audit artifacts.

## Commands

From `backend/`, with its environment configured:

```sh
# Current persisted due/lease/last-run state
pnpm places:sync --status

# Explicit validation, default limit 1,000 split across Cairo/Giza
pnpm places:sync --initial --dry-run
pnpm places:sync --initial

# Another explicit validation limit (never enables absence accounting)
pnpm places:sync --limit 250

# Unlimited full synchronization; no implicit 1,000-place ceiling
pnpm places:sync

# External scheduler mode: seven days since last committed full success
pnpm places:sync --due-only

# Production artifact, after pnpm build; does not require tsx/dev dependencies
node dist/cli/places-sync.js --due-only

# Import with preservation/readback report
pnpm exec tsx scripts/places-import-verification.ts
pnpm exec tsx scripts/places-import-verification.ts --full

# Safe deployment readback; --apply is only needed on an undeployed target
pnpm exec tsx scripts/deploy-places-migration.ts

# Controlled fixtures in a temporary Neon schema, cleaned up afterward
pnpm exec tsx scripts/places-openapi-verification.ts
```

Dry runs persist only a run log and projected counters, without changing places, mappings, missing counts or lifecycle history. A limited real validation may upsert its selected records with explicit source evidence, but remains `partial` and never changes the full-success/due timestamp. A full failure rolls back all place changes, logs failure separately and remains due for catch-up. `updated_count` counts matched source upserts, including refreshed observation timestamps.

## Environment

| Variable | Purpose |
|---|---|
| `DATABASE_URL` | Existing Neon application credential; migrations/importer reuse the configured source of truth |
| `PLACES_CURATOR_UIDS` | Existing comma-separated Firebase UID allowlist for catalog writes/sync administration; unset fails closed |
| `PLACES_SYNC_WORKER_SECRET` | Random secret of at least 32 characters, only on backend and external scheduler |
| `OSM_OVERPASS_URLS` | Operator-configured comma-separated HTTPS Overpass endpoints, in preference order; use a reachable fresh source before retrying the live import |
| `OSM_OVERPASS_URL` | Optional single-endpoint compatibility override when `OSM_OVERPASS_URLS` is absent |
| `OSM_USER_AGENT` | Identifiable operator/app user agent; configure contact information |
| `OSM_REQUEST_INTERVAL_MS` | Request spacing, default 3,000 ms and minimum 2,000 ms; Retry-After/backoff can increase it |
| `PLACES_INITIAL_IMPORT_LIMIT` | Default 1,000; applies only to explicit `--initial`, never scheduled/full runs |
| `NODE_ENV=production` | Existing production configuration; avoids development query logging |

No OSM/worker/database credential belongs in Flutter. Source endpoints are operator configuration, not user-supplied API parameters.

## Weekly activation and catch-up

Choose one deployment configuration; the database lease also protects accidental duplicate triggers:

1. **GitHub Actions:** `.github/workflows/places-sync.yml` checks hourly at minute 17 UTC. Set repository secrets `PLACES_SYNC_API_URL` to the HTTPS API origin and `PLACES_SYNC_WORKER_SECRET` to the matching backend secret. Merge/deploy the workflow on the default branch and enable scheduled workflows. The hourly check runs the import only when seven days have elapsed since the last successful full commit. A failed/unavailable API or missed trigger remains due for the next trigger. The first due run is unlimited. The hourly trigger bounds normal catch-up delay to one hour (plus scheduler availability), rather than rounding a completed seven-day cycle up to an eighth day. Not-due calls make no Overpass requests.
2. **systemd:** install `backend/deploy/places-sync.service` and `.timer`, adjust the deployment directory/user and `/etc/yalla5roga/backend.env`, build the backend and run `systemctl enable --now places-sync.timer`. `OnCalendar=hourly` checks the persisted seven-day deadline; `Persistent=true` catches missed host schedules. Verify with `systemctl list-timers places-sync.timer` and `journalctl -u places-sync.service`.

The protected HTTP worker runs synchronously. If the host/proxy cannot allow its duration, deploy the standalone CLI/systemd configuration. HTTP interruption does not remove the fenced lease or allow duplicate commits. One direct PostgreSQL LISTEN connection per API process is required for cross-process catalog invalidation; the persistent catalog version repairs missed signals after reconnect. The existing chat journal remains process-local.

**Activation was not performed against a hosting account or GitHub repository during this task.** Deployment still requires publishing/restarting the new backend code, setting the server/scheduler secret and operator source configuration, enabling one external schedule, and completing a fresh limited import followed by an unlimited full run. No successful live weekly cycle is claimed.

## Verification

- Prisma schema validation and TypeScript compilation passed.
- 12 focused backend taxonomy, normalization, lifecycle evidence, spatial validation and geocoding tests passed.
- Served Swagger/HTTP and real Prisma/Neon lifecycle checks passed in an isolated schema. [Detailed results](PLACES_OPENAPI_RESULTS.json) cover insertion/update/deduplication, closure/reopening, manual protection, limited/dry/failed-run safety, three-cycle absence, concurrent/expired leases, seven-day due gate, filters/pagination/auth/logs and preservation of existing outing rows. The OSM and Firebase network boundaries in this fixture suite are controlled; this is distinct from the failed live source import.
- A broader backend test run reported 175 tests: 157 passed, 14 failed, 2 cancelled and 2 skipped. Failures included sandbox-denied loopback/database access and existing notification-pagination/realtime assertions in the shared checkout. It is not a passing full-suite claim; [raw run](PLACES_BACKEND_TEST_RUN.txt).
- Dart static analysis covers all changed Flutter paths. Flutter runtime, widget/emulator/device tests and visual phone/wide/light/dark/English/Arabic checks were not run, per the owner's test restriction. Runtime layout/interaction coverage remains unverified.
- During cleanup, an overly broad formatting command affected unrelated backend files. Formatting-only files were restored only when their content matched formatted HEAD, and mixed-change files were checked for canonical equivalence while restoring prior formatting. Existing code changes were retained; no commit/push was made.

## Documentation Updates

Updated `PRODUCT_SCENARIOS`, `PROJECT_OVERVIEW`, `SYSTEM_ARCHITECTURE`, `SYSTEM_DESIGN`, `USER_SCENARIOS`, `FLUTTER_ARCHITECTURE`, `BACKEND_ARCHITECTURE`, `DATABASE_ARCHITECTURE`, `API_CONTRACTS`, `BUSINESS_LOGIC`, `AUTHENTICATION_AND_AUTHORIZATION`, `ARCHITECTURE_DECISIONS` (ADR-023) and `PROJECT_STRUCTURE`, plus this guide and audit artifacts. The system-architecture diagram now includes the external scheduler, validated OSM import, Neon transaction and cross-process invalidation path.

Remaining limitations are the blocked live catalog import, deployment/scheduler activation and unexercised Flutter runtime states. The old four-value outing enum is intentional compatibility, not a second category/vibe taxonomy.

Source references: [Overpass query language](https://wiki.openstreetmap.org/wiki/Overpass_API/Overpass_QL), [public instance/operator list](https://wiki.openstreetmap.org/wiki/Overpass_API), [ambiguous closed hours](https://wiki.openstreetmap.org/wiki/Tag:opening_hours%3Dclosed), [OSM attribution guidance](https://osmfoundation.org/wiki/Licence/Attribution_Guidelines), [OSM copyright/ODbL](https://www.openstreetmap.org/copyright).
