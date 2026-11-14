# Yalla 5roga Flutter client

Provider / Clean Architecture client over the existing Node.js API and Neon catalog.

Map rendering uses free, open-source `maplibre_gl` and OpenFreeMap vector tiles. No map account, key or paid subscription is required. Discover and Create Outing share `YallaMapView`; styles live in `lib/core/maps/yalla_map_style.dart`.

Use `.env.example` for public compile-time configuration. Production can replace `MAP_VECTOR_TILEJSON_URL`, `MAP_GLYPHS_URL`, attribution and optional hosted light/dark style URLs without UI changes. The tile schema must remain OpenMapTiles compatible; the hosted style owns its fonts/translation fallback and may use `{language}` in its URL. Never put private service credentials in Flutter config. Legacy OSM raster defines no longer control rendering.

[Map setup, free-provider limits, offline behavior and verification](../docs/audit/MAPLIBRE_MAP.md). Do not assume viewed vector tiles are downloaded for offline use. Android/iOS expose bounded explicit region downloads; web does not.
