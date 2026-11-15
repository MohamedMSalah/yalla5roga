# Cairo / Giza ingestion — 2026-11-14

## Phase 1 audit (completed before implementation)

Live target verified read-only: Neon project `rough-mountain-69896781`, branch
`br-fragrant-heart-avfm4h2t`, database `neondb`, schema `public`, role
`neondb_owner`. Local NODE_ENV is development; this is the existing application
database, not a disposable database. The owner explicitly requested the initial
import into this configured database after target verification and dry-run.

Full column/default/nullability, constraint, FK and index inventory:
[PLACES_INGESTION_BEFORE.json](PLACES_INGESTION_BEFORE.json).

| Table | Existing rows | Findings |
|---|---:|---|
| places | 0 | UUID identity; category FK; source tuple unique; coordinate and active partial indexes; source check permits manual/OSM only; source_id limited to 32 chars |
| place_categories | 36 | Stable text PK, bilingual names, group/icon, legacy outing-vibe projection |
| vibes | 15 | Stable text PK, bilingual names/icon; active/order fields |
| place_vibes | 0 | Composite place/vibe PK, restrictive FKs; source but no confidence |
| place_images | 0 | UUID PK, place FK cascade, URL/caption/order; no rights/source metadata |
| place_hours | 0 | UUID PK, unique place/day, nullable time columns; cannot represent split shifts |
| place_prices | 0 | UUID PK, place FK cascade, label/amount/currency; no source metadata |
| place_sync_runs | 2 | Counters, coverage/progress JSON, completeness/dry-run; no explicit source/processed count |
| place_sync_logs | absent | Missing in both schema and live database; must add, not recreate |
| place_status_changes | 0 | Place FK restrictive; optional run UUID, old/new state and evidence JSON |

An additional existing `place_sync_lock` table provides the fenced worker lease.
Outings, vote options, saved places and media reference the canonical places UUID.
The implementation must preserve these identities and all existing associations.

Existing importer: `services/places/places-sync.ts`, `osm.ts`, `taxonomy.ts`, CLI
and external GitHub Actions/systemd scheduling. It uses public Overpass, retains
all selected records in memory, writes dry-run history, and cannot ingest Overture.
It protects curator-managed rows and advances absence only on complete cycles.
The existing public catalog has bbox/category/vibes/search/offset, taxonomy,
version and details endpoints; details currently omits embedded hours/images/prices.
There is no GeoJSON endpoint or cursor/bounds aliases. Catalog SQL returns p.*,
including internal source evidence; this needs an explicit public projection.

Flutter already has shared repository/datasource, dynamic bilingual filters,
350ms camera debounce, cancellation, bounded viewport paging, account/origin
offline snapshots, MapLibre native clustering/category sprites, pin/card focus,
and preselected outing creation. Keep those flows and basemap unchanged. Existing
attribution mentions OSM only and must include Overture for the new source.

## Source references

- https://docs.overturemaps.org/blog/2026/09/23/release-notes/ (legacy categories removed)
- https://docs.overturemaps.org/schema/reference/places/place/
- https://docs.overturemaps.org/getting-data/cloud-sources/
- https://docs.overturemaps.org/attribution/
- https://download.geofabrik.de/africa/egypt.html
- https://docs.osmcode.org/pyosmium/latest/user_manual/03-Working-with-Geometries/

Implementation and verification results are appended after execution. No Flutter
app/emulator/device tests will run, per the owner's instruction.

## Current operation (owner update 2026-11-15)

**Manual imports only.** The owner removed weekly synchronization. The GitHub
workflow, systemd service/timer, scheduler-only `/sync/worker` route, secret and
seven-day due gate are removed. No background places schedule is installed by this
task. `place_sync_runs`, diagnostics, source evidence and the fenced lease remain
for explicit imports/synchronizations. Runtime API deployment and any previously
installed external host schedules are separate from editing this checkout.

From `backend/`:

```sh
python -m venv .places-data/venv
.places-data/venv/bin/python -m pip install -r scripts/places-requirements.txt
pnpm places:sync --initial --source=overture --dry-run
pnpm places:sync --initial --source=overture --reuse
pnpm places:sync --initial --source=osm --dry-run
pnpm places:sync --initial --source=osm --reuse
pnpm places:sync --sync --source=overture
pnpm places:sync --sync --source=osm
pnpm places:sync --source=overture --city=cairo --limit=100 --dry-run
pnpm places:sync --source=osm --city=giza --limit=100 --dry-run
pnpm places:sync --source=overture --manifest=/path/to/immutable.manifest.json --resume=RUN_UUID
pnpm places:sync --status --source=overture
```

On Windows the local interpreter is `.places-data/venv/Scripts/python.exe`.
`--initial` has no implicit limit. `--limit` counts source records, including
rejections. `--reuse` reuses a verified artifact rather than fetching a new release.
Use the original immutable manifest for resume. Batch size is configurable (1–1000);
source query threads are capped at four, database writes and image requests are
serialized. Retries use exponential backoff. SIGINT/SIGTERM preserve checkpoints.
Disk-backed PBF parsing and NDJSON batches avoid retaining Egypt in memory.

The default target guard checks this repository's verified Neon project, branch,
database and schema before writes. `PLACES_EXPECTED_TARGET` permits a deliberately
reviewed alternate target; never change it simply to bypass a failed check.
`--dry-run` performs **zero database writes**, including no locks, taxonomy seed or
run rows. Its result is printed/local; real runs record acquisition failures too.

## Data policy

- Exact current Overture tokens and hierarchy map to 44 stable bilingual categories;
  23 existing/new vibe definitions preserve older identifiers. Unmapped/low-confidence
  records are logged for review, not forced into unrelated categories.
- Existence confidence defaults to at least 0.7. Catalog `active` means a validated
  selectable listing, not open-now. Missing source operating status remains null
  in provenance. Only explicit source evidence establishes closure.
- Cross-source deduplication requires compatible categories, matching normalized
  names, a configurable distance and independent contact/address evidence. Distinct
  house numbers prevent merging nearby branches. Ambiguous multiple matches remain
  separate. Source aliases do not enrich another source's canonical metadata.
- Source/license/release/raw evidence live separately in `place_source_records`.
  OSM-derived data retains ODbL attribution/obligations; permissive upstream notices
  remain available at `/api/places/licenses` and under `backend/licenses/`.
  Apache/Foursquare notices identify Overture/application transformations. Unknown
  licenses fail closed. Private application/user data is never part of catalog
  redistribution. No Google scraping, paid Places API or paid inference is used.
- Simple explicit weekday hours populate the existing relation. Unknown, 24/7,
  overnight, holiday and split-shift expressions remain raw; this schema cannot
  represent them faithfully. Unknown prices stay null. Only explicit free entry or
  numeric EGP charges produce price rows. Commons images require verified reusable
  rights and attribution. Missing photos retain existing fallback behavior.
- Partial/failed/dry runs never advance absence; the same release cannot count
  twice. Three distinct complete source releases default to unverified review,
  never automatic permanent closure. Manual rows, manual relations and all
  outing/vote/bookmark UUID references remain protected.

## Verification evidence

- `PLACES_INGESTION_INTEGRATION_RESULTS.json`: 14 passing real Prisma/HTTP scenarios
  in an automatically removed, uniquely named schema. Covers no-write dry-run,
  idempotency, alias matching, hours/prices, manual protection, references, closure,
  distinct-release absence, interruption/resume, lease exclusion and Swagger APIs.
- 15 focused backend unit checks pass; TypeScript compilation passes.
- Targeted Dart analysis reports no issues for the three attribution files.
  A first CLI attempt reported a telemetry-file access failure after analysis;
  rerunning with `--suppress-analytics` exited successfully. No Flutter application,
  emulator, widget/device test or hot reload ran, as requested.
- Both additive migrations are deployed: `20261114050000_places_free_ingestion`
  and `20261114051000_places_unknown_price_absence`. Each was backed up and rehearsed
  in a rolled-back schema. First deployment's global row fingerprint differed due
  to concurrent chat/notification/attendance writes; the readback proves identical
  catalog/outings/voting/saved relations and matching deployed SQL checksum.
  The second deployment passed scoped preservation checks.
- Concurrent unrelated Flutter/docs edits appeared during this task. They are
  outside this import's file inventory and must not be included in its commits.

Actual application import counts and read-only Swagger results are recorded after
the real import in the companion results JSON, rather than inferred from dry-run.


## Completed application import — 2026-11-15

Both full initial imports completed successfully against the verified application
Neon target: **11,617 canonical places**, comprising **7,790 Cairo** and **3,827 Giza**.
Overture contributed 9,008 and OSM added 2,609. There were **42 strong duplicate
matches skipped** (13 Overture, 29 OSM), retained as separate provenance identities,
and **zero failed records**. Default active listings contain 11,607 places; nine
source-evidenced temporary closures and one permanent closure remain historical.

All 44 category and 23 vibe definitions are populated, with 22,860 place-vibe joins,
546 actual weekday-hours rows and 11 evidenced admission-price rows. No eligible
accepted POI had a directly linked Commons image with verified reuse evidence:
the three File: references belong to excluded non-outing categories. Category-only
references and arbitrary image URLs were not converted into guessed photos.
`place_images` therefore remains empty, with existing fallback behavior retained.

The application-schema replay check processed 1,000 source records from each
source and inserted **zero** new places. Overture updated three metadata rows and
OSM updated none; canonical identities remained unchanged. Limited checks never
advance absence. Source-less city guesses were cleared from imported records;
administrative province counts use source_region and do not invent venue city data.

Read-only served Swagger/HTTP verification passed **26 checks**, including populated
bbox/category/vibe/name searches, keyset pagination, GeoJSON, detailed relations,
existing nearby API with nullable unknown prices, private sync history, source
notices, all-record administrative inclusion, migration checksums and preserved
original outings/references. See [live results](PLACES_INGESTION_LIVE_RESULTS.json),
[14 isolated integration scenarios](PLACES_INGESTION_INTEGRATION_RESULTS.json), and
[task-owned file inventory](PLACES_INGESTION_FILES.json). Fifteen focused unit checks,
TypeScript compilation, Python compilation and targeted Dart analysis pass.

**Scheduling limitation:** automatic scheduling is removed from this checkout,
including GitHub/systemd configuration and the scheduler-only backend route/gate.
The existing remote main-branch workflow was inspected through the GitHub connector.
Its deletion returned 403 “Resource not accessible by integration”; Git credential
access was unavailable. The remote file is **not confirmed removed**. The owner
was asked to disable “Places weekly synchronization” in GitHub Actions or grant
workflow-write access. Do not claim the remote schedule is disabled until verified.
No application code was pushed/deployed by this task; new API operations require
the normal backend deployment. Imported rows are already in the real database.

**Documentation Updates:** the 12 canonical docs listed in the inventory now cover
current sources, schema, manual-only operation, contracts, rules and unchanged
Flutter integration. System flow and catalog ER diagrams were updated. Older dated
zero-catalog/Overpass/weekly audit statements are historical and superseded here;
remote scheduling removal remains the material outstanding configuration issue.
