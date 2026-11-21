# Home and Discover place performance

## Findings

- On startup, app dependency construction and recovery could start a complete catalog sync in 500-record batches. The shell independently warmed the general and featured catalog paths. Home additionally read location, rebuilt a combined place pool, and shuffled it in widget build. These were separate read paths for content that only showed six cards.
- Discover’s provider retired request generations, but its repository dropped the cancellation future and force-refresh flag. In-flight HTTP work could continue after the viewport moved. The nominal zoom limits of 400, 200 and 100 all produced a 100-row request. Following pages accumulated without a Discover state cap.
- The viewport query originally returned full catalog summaries. A repeated Provider notification reordered/copy-converted card data after every successful load. The map already used native clustering and a stable MapLibre controller. The card images already used fixed-size decoded thumbnails and the shared image cache. There was no confirmed listener leak or measured device-side image bottleneck in this pass.

## Implementation

- Home loads a small, public recommendation list. PostgreSQL starts at a random UUID pivot and reads up to 24 active rows via ordered primary-key ranges, wrapping if necessary. With foreground location permission, the nearby sample uses the existing coordinate index and randomly selects from up to 96 area candidates within 5 km of a coarse center. The service caches each sample for 900 seconds by default, configurable with `PLACE_RECOMMENDATIONS_TTL_SECONDS`. The endpoint defaults to eight cards with one cover reference per place. Flutter shows its in-memory or origin-scoped disk snapshot first, coalesces refreshes, and updates independently of the rest of Home. General recommendations stay visible while location resolves. Nearby results and their location keys stay in memory. Both use the same lazy list and size-constrained images.
- Discover requests compact place/card rows using visible bounds and current category, vibe, and search filters. At zooms below 11, below 15, and at 15+, it requests 64, 48, and 32 rows respectively and retains up to 128 results. A 32-entry viewport/filter/page cache expires after five minutes. Downloaded regions and pinned images remain explicit offline data. Startup no longer downloads the whole catalog. A still-mounted viewport reuses matching pages, and previously visible results remain while a new viewport loads. The server resolves branch counts once per brand in each page.
- Native idle settles before requesting viewport data. Near-equivalent movements and repeated pending loads are suppressed. Superseded requests cancel at Dio and stale generations cannot update results. Wrapped longitude bounds work across the antimeridian in the backend and the offline store. MapLibre retains the existing style, native clustered GeoJSON and selection layer. Full details load on detail navigation. Existing branch navigation, lazy carousels and the outing creation action are retained.

## Local measurements

| Measurement | Full response or alternative | Optimized |
| --- | ---: | ---: |
| Same 40 viewport IDs, uncompressed JSON | 35,627 bytes | 18,627 bytes |
| Same responses, median warmed Node JSON parse | 0.130 ms | 0.067 ms |
| Eight recommendations, uncompressed JSON | — | about 1.2 KB |
| Local PostgreSQL, 120,000 places, recommendation sample of 24 | 126.114 ms / 2,678 shared hits for a full random sort | 0.603 ms / 27 shared hits for the bounded sample and cover lookup |
| Local PostgreSQL, indexed narrow viewport | — | 0.217 ms / 17 shared hits |

The random-sort column is a comparison strategy, not the previous Home implementation. Node parse times do not measure Dart decoding. The viewport plan used the existing active coordinate index. See the [read indexing audit](DATABASE_READ_PERFORMANCE.md) for the catalog ordering plans and migration definitions.

## Changed files

- Backend catalog route, controller, use case, repository, datasource, query validator and OpenAPI configuration under `backend/src`. The recommendation TTL is documented in `backend/.env.example`. Antimeridian and sample coalescing tests are in `backend/tests/places-catalog.test.ts`.
- Flutter Home recommendation section and featured-place list under `flutter/lib/features/home` and `flutter/lib/features/discover`. The Discover feature updates its remote datasource, local store, repository, filter entity, catalog/map providers and map/carousel widgets. Shared changes cover TTL policy, cache hydration, map bounds normalization, dependency construction and shell startup.
- The API, database, system design and Flutter architecture documents describe the new read paths. The existing map and data models required no diagram changes.

## Verification limits

Served Swagger exercised recommendation size, cache reuse, invalid limits, light/full viewport parity, both sides of the date line, malformed bounds, paging precision, Arabic search, radius sorting, cover fallbacks, GeoJSON and brand branches against local PostgreSQL. Source inspection established the new request paths and feature-count caps. Device-side API counts, actual cancellation during panning, clustered pin interaction, offline rendering, image decode, rebuild/raster timing, memory and sustained frame rate still need profiling. No Flutter app, emulator or physical device was launched.

Home makes one cold general recommendation request and at most one additional area request when location resolves. Fresh cache entries avoid both requests. Discover can fetch categories and vibes on a cold cache, then requests its first compact page as soon as valid viewport bounds are available. Subsequent loads follow settled camera changes, filter changes, or requested pages. These are code-path expectations. The sample contains one cover URL per place and uses display-sized decoding. CDN transfer savings for image originals remain unmeasured. Deploy the updated backend API before releasing Flutter clients that use the recommendation endpoint.
