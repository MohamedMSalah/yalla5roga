# MapLibre implementation — 2026-11-14

Implemented in the current working tree. No deployment, application-data import, migration or commit was performed. Unrelated Home/theme/navigation edits present at entry were preserved.

## Shared rendering and workflows

DiscoverMapPanel and Create Outing's existing PickLocationPage both instantiate `YallaMapView`. The requested YallaMapStyle, YallaMapController, YallaMapMarkers, YallaMapClusters, YallaMapCameraManager and YallaMapPlaceSelection components live in `flutter/lib/core/maps/`. `flutter_map` and its raster renderer are removed; `app_map.dart` retains compatibility exports only. `maplibre_gl` resolves to 0.26.2. Web includes its matching GL JS engine and RTL text plugin; native builds remain unverified.

The centralized style has only a vector basemap source. Light land/buildings/outlines/water/parks/grass match the brief's exact colors; dark mode uses neutral counterparts. Rounded roads have distinct major/secondary/minor zoom-dependent widths. Buildings appear at z13; measured-height extrusion eases in at z16–17, capped at 80 m for restrained presentation. Named buildings use darker neutrals where metadata exists. Commercial POIs, house numbers and minor road labels are omitted. Districts, cities, main streets/bridges, landmarks and water/river names remain. Labels try both `name:ar/en` and `name_ar/en`, then source names. Geographic/name/height accuracy depends on provider data.

Only active, coordinate-valid records with a database ID enter catalog GeoJSON. Features retain Place ID/name/category/vibes/coordinates/image/status. Material category icons are rendered once into compact 2× style images per category and reused by native symbol layers. There is no Flutter widget per map pin. Native clustering uses a 52 px radius through z16, count labels, consistent stepped sizes and progressive two-level zoom on tap. Ordinary symbols use collision placement. Selected records leave the clustered source and render above it with a larger pin/ring and localized ordered indicators in multiple mode; they are not double-counted in clusters. Selected animation and camera motion honor reduced motion.

Discover uses a full-screen map, floating search/category/vibe/location controls, a virtualized horizontal snapping carousel, bookmarks/details/explicit planning actions and the existing floating bottom navigation. Pin/card focus synchronizes selection with its carousel card. Planning only opens the wizard; it does not create an outing.

The outing picker retains PickLocationProvider's existing candidate and immutable ordered selection, single/multiple confirmation, geographic search/center reticle/custom naming, add/remove/reorder, draft flow and cancellation without committing. Custom geographic candidates use the existing reticle; prior explicitly selected custom locations use separate numbered selection annotations, never generated database/category pins. The catalog owns reusable camera state across wizard/picker navigation. MapLibreMap owns/disposes each native controller; the reusable controller safely detaches and retains camera position. Theme/locale style changes use generation guards and preserve the camera. Accessible place cards provide a parallel selection flow; native renderer accessibility needs device inspection.

## Free provider and production configuration

Default: [OpenFreeMap](https://openfreemap.org/quick_start/), a free OpenMapTiles-compatible vector source. No account, API key, Stadia service or mandatory paid dependency is required. No map credentials were added.

| Public compile-time define | Default / purpose |
|---|---|
| `MAP_VECTOR_TILEJSON_URL` | `https://tiles.openfreemap.org/planet/latest`; replace with compatible self-hosted TileJSON |
| `MAP_GLYPHS_URL` | `https://tiles.openfreemap.org/fonts/{fontstack}/{range}.pbf` |
| `MAP_ATTRIBUTION` | OpenFreeMap · © OpenMapTiles · © OpenStreetMap contributors |
| `MAP_ATTRIBUTION_URL` | OpenFreeMap guide linking underlying data credits |
| `MAP_LIGHT_STYLE_URL` | Optional hosted vector style; otherwise generated Yalla light style |
| `MAP_DARK_STYLE_URL` | Optional hosted vector style; otherwise generated Yalla dark style |
| `MAP_OFFLINE_ALLOWED` | `true` for the default provider; disable if another provider disallows downloads |

Both public env examples and Flutter README document these defines. Changing TileJSON/glyph URLs preserves Yalla styling without changing screens. Hosted style URLs support `{language}`, replaced with ar/en; hosted overrides must preserve vector rendering, font assets, localization fallback and attribution. Legacy AppConfig OSM raster fields remain constructor-compatible but do not control rendering. Dart defines are public: never insert privileged credentials.

Native attribution remains available, and linked textual credit is placed above sheets/navigation. Application places retain their OSM/ODbL attribution. Configure the required credit when switching providers. Self-hosting requires the compatible vector schema and glyph assets, with no Flutter UI rewrite.

## Provider limits and offline maps

[OpenFreeMap's terms](https://openfreemap.org/tos/) currently permit offline downloads of **at most 3,000 tiles or 50 MB per download**, **at most four parallel requests**, and a **unique identifying User-Agent**. Contact the provider for larger downloads. The public service is supplied as-is; review terms when deploying or changing endpoints.

The Android/iOS download control explicitly saves the current area through MapLibre's native offline-region API using a persisted copy of the exact generated style. Web hides this unsupported native capability. Viewed tiles are not assumed to be available offline.

- Preflight rejects coverage above 2,500 tiles through z14 or across the antimeridian. Localized feedback advises zooming in/retrying.
- Native tile cap is 2,500; concurrency is four. Progress reports beyond 45 MiB or 2,500 required resources trigger failure/pack removal; downloads also fail after three minutes. These conservative limits leave headroom below provider limits.
- Requests identify the app as `Yalla5roga/1.0 (com.example.yalla_5roga)`. Only one Yalla-owned region is retained; a complete matching pack is reused. Unrelated packs are untouched.
- The saved area/style/locale defines coverage. Higher display zoom overzooms z14 geometry. Another theme/locale may require another pack; saving a different pack replaces the previous Yalla region.
- SDK/provider HTTP caching governs native resources. No guarantee is made for unsaved areas, all visited tiles, future source versions or every glyph/zoom. Places snapshots and images retain their existing separate caches.

## Networking, caching and errors

Existing Provider → repository → datasource → ApiClient/Dio → existing Neon-backed API remains the data path. The renderer makes no application HTTP calls. Map idle waits 350 ms after all gesture pointers lift, and the catalog provider debounces for another 350 ms. Movement/filter changes cancel pending Dio reads and reject late generations. Inactive tabs do not publish viewport API updates.

Viewport bounds combine with category/vibe filters. Discover database search spans bounds; clearing search restores the current viewport. Its Clear Filters removes category/vibe IDs. The outing picker retains the shared geographic/radius filter controls. Pages contain 50 rows, up to ten per viewport burst; explicit Load more continues from raw row offset instead of visible/deduplicated marker count. Query cache is bounded to 96 entries and known-place fallback to 3,000 rows. Existing account/origin snapshots and AppNetworkImage caches remain. Layers install once per style lifetime; changed GeoJSON/selection updates in place.

Localized API/permission recovery, cached content, an 18-second style watchdog, native-operation failure handling and an always-available refresh control support recovery. Downloads expose progress/failure separately. This plugin version has no individual tile-error callback, so detailed tile-failure diagnostics and native recovery behavior require later runtime validation.

## Verification

| Requested check | Evidence / limitation |
|---|---|
| Vector map/style | Four variants pass the official MapLibre style schema, exact light palette and vector-only assertions |
| Buildings, roads, Nile, parks, districts | Live Cairo/Nile/Zamalek/Al-Azhar tiles confirm underlying geometry/names; style layers/zoom thresholds checked |
| Height and bilingual data | Probe finds 71 buildings with height data, named waterways and Arabic/English/fallback names; configured Latin/Arabic glyph endpoints return data |
| Category pins, selected animation and clusters | Native source/layer/icon/collision/ring/tap-zoom code implemented; rendered behavior NOT RUN |
| Real database pins | No synthesized records. Active catalog API returned **zero rows**; populated pin/detail/search/filter interaction cannot be verified on this target |
| Shared Discover/Create Outing | Both adapters use YallaMapView with configured browse/single/multiple modes |
| Existing selection workflows | Existing picker/wizard commit path retained; raster test doubles migrated to MapLibre's platform boundary; tests NOT RUN |
| Caching and errors | Cancellable bounded queries, existing snapshots/images, retry controls and explicit native packs implemented; actual offline/native behavior NOT RUN |

- [Style/geographic results](MAPLIBRE_STYLE_RESULTS.json): **8 checks passed**, including four style variants and live provider geometry/glyph probes. This is not a rendered UI test.
- [Served Swagger/OpenAPI results](MAPLIBRE_OPENAPI_RESULTS.json): **19 passed**, **2 groups NOT_RUN** because active places are absent. Verification uses served OpenAPI and read-only HTTP routes, without fixtures, raw database verification, mutations or migrations.
- Whole-package Dart analysis: **44 unrelated existing findings (4 warnings, 40 info), no errors** in auth/chat/invites/notifications/interceptors. Targeted analysis of the changed map, catalog, networking, selection and maintained test/export files reports **No issues found**.
- Scoped Dart formatting and git whitespace checks were performed. No Flutter app, emulator or device tests were run. Phone/wide/foldable, keyboard/large text, light/dark/RTL visuals, native builds, marker hit testing/clustering/animation and offline interruption/recovery remain unverified.

## Documentation Updates

Updated `FLUTTER_ARCHITECTURE.md`, `SYSTEM_ARCHITECTURE.md`, `SYSTEM_DESIGN.md`, `USER_SCENARIOS.md`, `API_CONTRACTS.md`, `PROJECT_STRUCTURE.md`, `ARCHITECTURE_DECISIONS.md` (ADR-024), `DESIGN.md`, Flutter README and both env examples. Replaced current raster guidance; historical audit reports remain historical. Added the system-architecture map-flow Mermaid diagram and these configuration/evidence artifacts. No backend schema, endpoint, auth/notification flow or approved outing/voting/arrival rule changed, so their unrelated docs required no update. Remaining inconsistencies are limited to explicitly unverified native behavior and unavailable populated-catalog evidence.


## Discover carousel refinement — 2026-11-14

The later owner-approved Discover task replaces its draggable results sheet with the horizontal snapping carousel. Global bilingual database-place search replaces Discover geographic-name suggestions; the outing picker retains its existing geocoder/custom-place flow. Current source and validation are described in [Discover map-first](DISCOVER_MAP_FIRST.md). Native utility controls move above the carousel and selection focus accounts for both top and bottom floating chrome. The renderer/platform controller remains mounted during selection; only native data layers change.
