# Yalla 5roga Flutter client

Provider / Clean Architecture client over the existing Node.js API and Neon catalog.

[Android setup, SDK upgrades and download troubleshooting](../docs/development/FLUTTER_ANDROID_SETUP.md).

## Maps

Map rendering uses free, open-source `maplibre_gl` and OpenFreeMap vector tiles. No map account, key or paid subscription is required. Discover and Create Outing share `YallaMapView`; styles live in `lib/core/maps/yalla_map_style.dart`.

Use the repository [environment reference](../docs/development/ENVIRONMENT_CONFIGURATION.md) and run `pnpm build:apk:device` or `pnpm build:apk:production` from the repository root. Both commands build signed Release splits using Android flavors and a temporary allowlisted `--dart-define-from-file` JSON. The shorter aliases are `pnpm build:device` and `pnpm build:production`. Production map settings can override the TileJSON, glyphs, attribution and hosted light/dark styles. Keep the OpenMapTiles schema. Hosted styles can use `{language}`.

[Map setup, free-provider limits, offline behavior and verification](../docs/audit/MAPLIBRE_MAP.md). Do not assume viewed vector tiles are downloaded for offline use. Android/iOS expose bounded explicit region downloads; web does not.
