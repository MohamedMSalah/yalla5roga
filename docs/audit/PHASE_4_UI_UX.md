# Phase 4 — Discover, shared maps and Special Events

Date: 2026-11-14 (Africa/Cairo).

## Implemented

- Discover composes focused map and result widgets: nearby OSM pins, horizontal All/Food/Activities/Outdoor/Movies filters, catalog name/area search, cancellable/debounced geographic search, location action, image/area/price/distance cards, selected previews, details and Create Outing navigation.
- Pin/card selection uses AppMap's existing camera animation and reduced-motion behavior. Selecting a card returns the map to view. Manual search remains available with denied foreground permission; the existing Cairo fallback remains usable. Physical user position and searched-area center are separate.
- Shared map chrome lives in `flutter/lib/core/widgets/map_controls.dart`: MapSearchBar, MapPlaceMarker, MapPlacePreview, MapVibeFilters, MapCurrentLocationButton and MapSelectedLocationCard. Shared VibePicker lives in core with its old import path re-exported. The geocoding interface moves to core/maps with a compatibility export; no data adapter or DI registration is replaced.
- PickLocationPage uses shared chrome/cards and preserves single/multiple selection, named pins, ordering/removal, limits, reverse geocoding, attribution and cancellation. Search filters apply to catalog categories without inventing categories for geographic hits.
- Home opens SpecialEventPage, which reuses the existing Provider/wizard, image picker/upload, date/time fields, map picker, review/edit, draft, submission/loading and success navigation. SpecialEventFields handles the four localized occasion choices and optional group/audience controls. Busy submission blocks form interaction. Final submission revalidates the basics and venue.
- Birthday, Wedding, Celebration and Other persist as actual special_event outings. Optional groups are sent through the existing group_id field and validated against accepted membership. No-group events keep app/phone guest invitations. Existing guests remain selected when the group changes. Regular outings still require a group and occasion=none.
- Prisma adds celebration/other to the existing enum. The additive migration permits optional-group special events while preserving existing row IDs and foreign keys. Backend type is derived from occasion, not group presence. Existing DTOs alias the generated Prisma enum; existing Flutter repository/saved/draft decoders resolve enum names and therefore support the new values without a parallel DTO layer.
- Existing flutter_map/OpenStreetMap tiles/attribution, Provider, Dio, cache/realtime architecture, design tokens, English/Arabic and media resolution remain in place. No dependencies were added.

## Implementation files

New: core/maps/{location_repository,location_search_provider}.dart; core/widgets/{map_controls,vibe_picker}.dart; discover/presentation/widgets/{discover_map_panel,discover_results}.dart; outings/presentation/pages/special_event_page.dart; outings/presentation/widgets/special_event_fields.dart; backend/prisma/migrations/20261114000000_special_event_occasions/migration.sql; backend/scripts/phase4-openapi-verification.ts.

Adapted: DiscoverPage and DiscoverPlaceDetailsPage (the exact selected nearby entity is passed into details); outing location picker; creation provider/page/basics/review; occasion enum and label/cover helpers; outing overview; Home quick actions; L10n; backend Prisma enum, create/update use cases, validator, Swagger component schemas and create route documentation. Other pre-existing/concurrent Phase 3 and voting-deadline edits were retained and are not claimed as Phase 4 changes.

## Verification

- Prisma Client generation: PASS.
- TypeScript `tsc --noEmit`: PASS.
- Targeted Dart static analysis covering shared controls/maps, Discover changes, outing presentation, Home entry and localization: PASS, no issues.
- `git diff --check`: PASS.
- Swagger/OpenAPI HTTP suite: **107 PASS** rows; see [machine-readable results](PHASE_4_OPENAPI_RESULTS.json). It serves Swagger UI, checks its embedded specification, resolves operations by operationId, checks declared response schemas/statuses and exercises production routes/use cases against real PostgreSQL in a generated disposable schema. Firebase verification uses a controlled fixture boundary; it is not a live Firebase authentication test.
- Coverage includes all four occasions both independent/group-associated; accepted member creation; pending-group-invite/outsider denial; missing/invalid auth and missing groups; privacy and group association/removal; invalid occasion/schedule/venue/options; ordinary group outing regression; all four draft create/update/list round-trips; idempotent phone-invitation retries, phone deduplication and opt-in; app invitation acceptance and RSVP. Existing Birthday/Wedding rows are inserted before migration, then read through OpenAPI afterward to verify their IDs, occasions and venues survive.
- All disposable schemas were removed. Delivery workers were not started, and physical WhatsApp/FCM delivery is not claimed.
- Flutter, device, emulator and UI tests, screenshots and visual sign-off: NOT RUN, per owner instruction. A requested hot-reload tool call found no DTD/debug process and made no runtime change; no app was started. Phone/wide/foldable, light/dark, English/Arabic, keyboard and large-text rendering remain unexercised.

## Documentation Updates

- PRODUCT_SCENARIOS.md: owner-approved four occasions and optional-group semantics.
- USER_SCENARIOS.md: dedicated event journey, discovery search/exploration, map selection and state behavior.
- BUSINESS_LOGIC.md: occasion-derived types and accepted group membership.
- SYSTEM_DESIGN.md: shared-map and event workflows.
- FLUTTER_ARCHITECTURE.md: focused compositions, shared component ownership, compatibility exports and unchanged data/DI patterns.
- PROJECT_STRUCTURE.md: new shared/feature/migration/verification files.
- API_CONTRACTS.md: occasion enum, optional group, derived type, validation, invitations and deployment order.
- DATABASE_ARCHITECTURE.md: additive enum/constraint migration and corrected optional group-to-outing relation in the ER diagram.
- AUTHENTICATION_AND_AUTHORIZATION.md: optional-group checks and independent/group event privacy.
- NOTIFICATIONS.md: shared event invitation/outbox paths for all four occasions.
- PROJECT_OVERVIEW.md: expanded event scope and discovery presentation.

Diagrams: corrected the database ER group's optional association. Lifecycle and component topology are unchanged; no replacement diagrams are necessary. No known Phase 4 contract inconsistency remains in the updated canonical sections. Historical audit records are retained as historical evidence.

## Deployment and remaining limits

The Phase 4 migration was rehearsed in a disposable PostgreSQL schema. **This task did not migrate the configured application schema or deploy the backend/client.** Apply the included migration before enabling the new contract in that environment. Existing application data was not rewritten. External geocoding depends on the existing configured provider and availability; live upstream results, map tiles, media upload and physical notifications were not exercised by this API-only verification. The implementation is complete in source; runtime/visual and deployed-environment acceptance remain outstanding.


### Subsequent deployment — 2026-11-14

The owner subsequently requested Neon deployment. The configured target's project/branch/database IDs were verified; a fresh private backup and full 27-table/661-row recovery rehearsal passed. Prisma applied `20261114000000_special_event_occasions`; all application-row checksums were unchanged, both new enum labels and the historical-row-preserving constraint were read back. All 15 migrations are now applied. See `NEON_GITHUB_SYNC_DEPLOYMENT.json`. Backend/client runtime deployment remains separate from this database deployment.
