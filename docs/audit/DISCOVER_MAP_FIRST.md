# Discover map-first redesign — 2026-11-14

## Delivered scope

The existing Discover tab now composes a full-screen Stack with the custom YallaMapView behind floating search, backend-driven multi-category/vibe chips, location/native map controls, a horizontal PageView carousel and the existing shell navigation. No separate map route, draggable results sheet, new dependency, application API, database mutation/migration, socket or polling loop was introduced.

DiscoverMapProvider extends PlaceCatalogProvider and owns one selectedPlaceId, user location and viewport/search policy. Existing repository/Dio cancellation, revision guards, bounded query caches, account/origin snapshots and AppNetworkImage caching remain the data/image path. A basemap failure triggers a catalog fallback so cached cards are not dependent on successful tiles. Permission denial retains manual exploration and localized guidance/settings.

Database search spans bounds and searches Arabic/English names through the existing API; it also retains the API's existing area/address matching. Floating results and cards use the same collection as pins. Search/filter changes debounce 350 ms; superseded calls cancel. Map idle retains the shared 350 ms settle plus catalog debounce. Viewport pages contain 50 rows, up to ten per burst, with lazy continuation near the carousel end and an explicit continuation/retry tile. Loaded places sort by user distance; this sorts loaded pages, not unloaded records. Search results without valid coordinates remain accessible as database cards but cannot have a geographic pin. Only valid active database coordinates enter native GeoJSON.

Pin/card/result selection focuses the map and carousel. Swipes retain native snapping and update selection/camera without starting another carousel animation. Programmatic scrolls suppress intermediate selection callbacks; selected identity is restored on carousel mount and after page additions. Selection focus records camera bounds without replacing its result set. Panning/cluster exploration resumes viewport loading; global searches survive pans. Clearing search uses current visible bounds.

Selected cards keep the minimum-48dp Create Outing Here action outside their scrolling details. Existing details/bookmarks remain. The action passes SuggestedPlace (including ID/coordinates/metadata) to CreateOutingPage; CreateOutingProvider already preselects it in the existing flow. Group selection, details, dates, voting, review and publication remain explicit. No creation mutation occurs from selecting a pin/card.

The mounted native map subtree is reused during selection, while native data/selection layers update. Controllers/listeners dispose with their existing owners. Scaffold.extendBody's actual MediaQuery bottom padding positions the carousel above the unchanged navigation, including scaled/wrapped labels. Camera focus accounts for top/bottom chrome; utility/location controls and attribution sit above cards. Search results/top chrome are constrained and scroll if necessary; card details scroll at small heights/large text. Keyboard visibility temporarily hides cards, and result selection restores the chosen card when they remount. Runtime smoothness/accessibility/layout remain unverified.

## Requirement verification

| # | Requirement | Evidence / scope |
|---|-------------|------------------|
| 1 | Full-screen MapLibre | DiscoverPage StackFit.expand; DiscoverMapView uses shared custom renderer; existing shell extendBody retained. Source only. |
| 2 | Floating search/filters | PositionedDirectional + SafeArea; shared MapSearchBar; backend definition chips; localized All/Clear Filters. Source only. |
| 3 | Horizontal floating cards | Lazy PageView.builder with viewportFraction .88 and native snapping, above actual nav inset. Source only. |
| 4 | Actual database identities | Existing active catalog query, status/coordinate guards and existing taxonomy/native clustering. API target currently has zero active rows. |
| 5 | Pin → card focus | Shared selectedPlaceId; selected native source/ring; selected-index scrolling. Source only. |
| 6 | Card → pin focus | Card/centered-page selection invokes shared camera focus; scroll-origin guards prevent feedback. Source only. |
| 7 | Explicit create handoff | Existing CreateOutingPage(suggestedPlace: place), provider constructor verified to convert/preselect it. No save/publish from Discover. Source only. |
| 8 | Smooth carousel | Virtualized snapping pages, peeking next card, cancellation guards and existing reduced-motion durations. Actual frame/gesture performance NOT RUN. |
| 9 | Synchronized filters | One catalog collection supplies pins/cards, backend category/vibe IDs, debounced updates and immediate matching-cache filtering. Source + empty HTTP contract checks. |
| 10 | Accessible bottom nav | Existing nav design/routes unchanged; carousel uses Scaffold-provided bottom padding. Actual safe-area/hit testing NOT RUN. |
| 11 | No redundant calls/rebuilds | Existing viewport dedupe/cancellation/cache; first idle supplies initial bounds; stable native map subtree and cached place conversions; selection suppresses bounds reads. Source only, no runtime request/frame tracing. |

## Validation

- Dart MCP analyze_files: **No errors** for Discover presentation, shared renderer/camera/controller and L10n. No Flutter test/run/build was performed.
- Dart SDK formatter: scoped files formatted successfully using --suppress-analytics. An initial formatter invocation formatted files but reported a sandbox telemetry write failure; the final suppressed-analytics invocation exited successfully.
- git diff --check: passed for the final working tree (pre-existing LF/CRLF notices are informational).
- `backend/scripts/discover-map-openapi-verification.ts`: **23 PASS, 2 NOT_RUN**, read-only HTTP selected from the served Swagger/OpenAPI document. Covers taxonomy (36 categories / 15 vibes), bilingual query acceptance, multiple category/vibe IDs, bounds, distance sorting parameters, pagination envelope and invalid-request statuses. [Results](DISCOVER_MAP_OPENAPI_RESULTS.json).
- **Data limit:** the configured target returned zero active places. Non-empty next-page and real-place detail/search/filter intersections could not be verified; empty response assertions do not prove real-match ordering or selection. No sample places/imports were added.
- Independent impeccable source review identified four search/carousel/viewport/cluster defects, all corrected. The follow-up review passed those specific fixes by source inspection; it was not whole-surface visual approval.
- No Flutter/emulator/device/widget/integration test, app launch or rendered verification. Phone, wide/foldable, light/dark, English/Arabic, real fonts, keyboard, large text, permissions, native map gestures and performance still require runtime verification. DTD discovery found no debug process. Automatic approval review rejected a hot-reload request because it conflicts with the owner's execution restriction; no hot reload ran and no workaround was attempted.

## Documentation Updates

Updated PRODUCT_SCENARIOS (owner-approved map-first interaction), USER_SCENARIOS (current journeys), FLUTTER_ARCHITECTURE (provider/component/controller ownership), PROJECT_STRUCTURE (new files), SYSTEM_DESIGN (search/viewport/selection workflow), SYSTEM_ARCHITECTURE (existing data path retained), API_CONTRACTS (query policy and verification), DESIGN (horizontal carousel within existing visual system), and MAPLIBRE_MAP (current composition). This report and the new OpenAPI JSON hold task evidence. Architecture diagrams remain valid and were not changed. No new product-rule or architectural inconsistency was identified in this scope; historical phase reports remain snapshots. Runtime and real non-empty catalog verification remain outstanding.

## Working tree boundary

The checkout already contained substantial uncommitted custom-map, navigation, home and documentation work at entry. Existing changes were preserved. This task adds the Discover components/provider/verifier and refines the shared catalog/renderer/camera and current documentation; it does not commit or deploy the mixed working tree.
