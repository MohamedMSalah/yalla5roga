# Production variable inventory

Recorded 2026-11-22. Values are deliberately omitted. Set does not establish validity. Dynamic lookups require the environment reference and owning configuration module.

| Variable | Local status | Source references |
| --- | --- | --- |
| API_BASE_URL | Empty / source default | backend/src/config/deployment.ts, backend/src/server.ts, flutter/lib/core/config/app_config.dart, scripts/flutter-config.mjs |
| API_CONNECT_TIMEOUT_MS | Set | flutter/lib/core/config/app_config.dart |
| API_DIAGNOSTICS | Empty / source default | flutter/lib/core/network/diagnostics/request_diagnostics.dart |
| API_DIAGNOSTICS_LOG | Empty / source default | flutter/lib/core/network/diagnostics/request_diagnostics.dart |
| API_DUPLICATE_WINDOW_MS | Empty / source default | flutter/lib/core/network/diagnostics/request_diagnostics_interceptor.dart |
| API_RECEIVE_TIMEOUT_MS | Set | flutter/lib/core/config/app_config.dart |
| API_TELEMETRY_SAMPLE | Empty / source default | flutter/lib/core/network/diagnostics/mobile_telemetry.dart |
| APP_DOWNLOAD_URL | Set | backend/src/config/notifications.ts, backend/src/services/whatsapp/special-event-invitation.ts, flutter/lib/core/config/app_config.dart |
| APP_ENV | Set | flutter/lib/core/config/app_config.dart, scripts/flutter-config.mjs |
| CORS_ORIGINS | Empty / source default | backend/src/config/cors.ts, backend/src/config/deployment.ts |
| DATABASE_URL | Set | backend/src/config/database.ts, backend/src/monitoring/config.ts, backend/src/repositories/auth/password-recovery.repository.ts, backend/src/server.ts, backend/src/services/places/catalog-notifications.ts, scripts/database-status.mjs, scripts/production-config-audit.mjs, scripts/project-command.mjs |
| DEPLOYMENT_ENV | Set | backend/src/config/deployment.ts |
| DIRECT_URL | Empty / source default | scripts/database-status.mjs, scripts/project-command.mjs |
| EXPECTED_DATABASE_HOST | Set | backend/src/config/deployment.ts, scripts/production-config-audit.mjs |
| EXPECTED_DATABASE_NAME | Set | backend/src/config/deployment.ts, scripts/production-config-audit.mjs |
| EXPECTED_FIREBASE_PROJECT_ID | Set | backend/src/config/deployment.ts, scripts/production-config-audit.mjs |
| EXPECTED_R2_ACCOUNT_ID | Empty / source default | backend/src/config/deployment.ts |
| EXPECTED_R2_PRIVATE_BUCKET | Empty / source default | backend/src/config/deployment.ts |
| EXPECTED_R2_PUBLIC_BUCKET | Empty / source default | backend/src/config/deployment.ts |
| FIREBASE_ANDROID_API_KEY | Set | flutter/lib/core/config/app_config.dart, scripts/flutter-config.mjs, scripts/production-config-audit.mjs |
| FIREBASE_ANDROID_APP_ID | Set | flutter/lib/core/config/app_config.dart, scripts/flutter-config.mjs, scripts/production-config-audit.mjs |
| FIREBASE_API_KEY | Set | backend/src/config/deployment.ts, backend/src/config/firebase-client.ts, backend/src/server.ts |
| FIREBASE_AUTH_EMULATOR_HOST | Empty / source default | backend/src/config/deployment.ts |
| FIREBASE_CLIENT_EMAIL | Set | backend/src/config/deployment.ts, backend/src/config/firebase.ts, scripts/production-config-audit.mjs |
| FIREBASE_IOS_API_KEY | Set | flutter/lib/core/config/app_config.dart, scripts/production-config-audit.mjs |
| FIREBASE_IOS_APP_ID | Set | flutter/lib/core/config/app_config.dart, scripts/production-config-audit.mjs |
| FIREBASE_IOS_BUNDLE_ID | Set | flutter/lib/core/config/app_config.dart, scripts/production-config-audit.mjs |
| FIREBASE_IOS_CLIENT_ID | Set | flutter/lib/core/config/app_config.dart, scripts/production-config-audit.mjs |
| FIREBASE_MESSAGING_SENDER_ID | Set | flutter/lib/core/config/app_config.dart, scripts/production-config-audit.mjs |
| FIREBASE_PRIVATE_KEY | Set | backend/src/config/deployment.ts, backend/src/config/firebase.ts, scripts/production-config-audit.mjs |
| FIREBASE_PROJECT_ID | Set | backend/src/config/deployment.ts, backend/src/config/firebase-client.ts, backend/src/config/firebase.ts, flutter/lib/core/config/app_config.dart, scripts/flutter-config.mjs, scripts/production-config-audit.mjs |
| FIREBASE_STORAGE_BUCKET | Set | flutter/lib/core/config/app_config.dart |
| FIREBASE_TELEMETRY_ENABLED | Empty / source default | flutter/lib/core/monitoring/analytics_service.dart, flutter/lib/core/monitoring/crashlytics_service.dart, flutter/lib/core/monitoring/performance_service.dart |
| FIREBASE_WEB_CLIENT_ID | Set | flutter/lib/core/config/app_config.dart, scripts/production-config-audit.mjs |
| FLUTTER_APP_SCHEME | Set | backend/src/config/notifications.ts |
| FLUTTER_ROOT | Empty / source default | scripts/flutter-android.mjs |
| GEOCODING_API_KEY | Empty / source default | backend/src/services/places/geocoding.ts |
| GEOCODING_ATTRIBUTION | Empty / source default | backend/src/services/places/geocoding.ts |
| GEOCODING_BASE_URL | Empty / source default | backend/src/services/places/geocoding.ts |
| GEOCODING_CACHE_SECONDS | Empty / source default | backend/src/services/places/geocoding.ts |
| GEOCODING_PROVIDER | Empty / source default | backend/src/services/places/geocoding.ts |
| GEOCODING_REQUESTS_PER_MINUTE | Empty / source default | backend/src/routes/places/place.geocoding.routes.ts |
| GOOGLE_CLOUD_PROJECT | Empty / source default | backend/src/config/deployment.ts |
| GRAFANA_ADMIN_PASSWORD | Set | Profile/launcher, dynamic lookup, or optional operator setting |
| HOST | Set | backend/src/server.ts |
| IMAGE_UPLOAD_MAX_EDGE | Set | backend/src/services/media/image-optimization.ts, flutter/lib/core/media/image_optimizer.dart |
| IMAGE_UPLOAD_QUALITY | Set | backend/src/services/media/image-optimization.ts, flutter/lib/core/media/image_optimizer.dart |
| IMAGE_UPLOAD_TARGET_BYTES | Set | backend/src/services/media/image-optimization.ts, flutter/lib/core/media/image_optimizer.dart |
| INVITE_DEEP_LINK_BASE | Set | backend/src/config/notifications.ts |
| LOG_LEVEL | Set | backend/src/monitoring/logger.ts |
| MAP_ATTRIBUTION | Empty / source default | flutter/lib/core/maps/yalla_map_style.dart |
| MAP_ATTRIBUTION_URL | Empty / source default | flutter/lib/core/maps/yalla_map_style.dart |
| MAP_DARK_STYLE_URL | Empty / source default | flutter/lib/core/maps/yalla_map_style.dart |
| MAP_GLYPHS_URL | Empty / source default | flutter/lib/core/maps/yalla_map_style.dart |
| MAP_LIGHT_STYLE_URL | Empty / source default | flutter/lib/core/maps/yalla_map_style.dart |
| MAP_OFFLINE_ALLOWED | Empty / source default | flutter/lib/core/maps/yalla_map_style.dart |
| MAP_VECTOR_TILEJSON_URL | Empty / source default | flutter/lib/core/maps/yalla_map_style.dart |
| MEDIA_ALLOWED_MIME_TYPES | Set | backend/src/config/media.ts |
| MEDIA_CLEANUP_INTERVAL_MS | Set | backend/src/config/media.ts |
| MEDIA_MAX_UPLOAD_BYTES | Set | backend/src/config/media.ts |
| MEDIA_MOCK_BASE_URL | Empty / source default | backend/src/config/media.ts |
| MEDIA_SIGNED_URL_TTL_SECONDS | Set | backend/src/config/media.ts |
| MEDIA_UPLOAD_URL_TTL_SECONDS | Set | backend/src/config/media.ts |
| MONITORING_TOKEN | Set | backend/src/monitoring/health.ts |
| NODE_ENV | Set | backend/src/app.ts, backend/src/config/cors.ts, backend/src/config/database.ts, backend/src/middleware/auth.middleware.ts, backend/src/monitoring/config.ts, backend/src/routes/media/index.ts, backend/src/services/media/media.service.ts |
| NOTIFICATION_MAX_ATTEMPTS | Set | backend/src/config/notifications.ts |
| NOTIFICATION_WORKER_BATCH_SIZE | Set | backend/src/config/notifications.ts |
| NOTIFICATION_WORKER_INTERVAL_MS | Set | backend/src/config/notifications.ts |
| OBSERVABILITY_ENABLED | Set | backend/src/monitoring/config.ts |
| OBS_DB_CRITICAL_MS | Empty / source default | Profile/launcher, dynamic lookup, or optional operator setting |
| OBS_DB_WARN_MS | Empty / source default | Profile/launcher, dynamic lookup, or optional operator setting |
| OBS_DUPLICATE_WINDOW_MS | Empty / source default | Profile/launcher, dynamic lookup, or optional operator setting |
| OBS_ENDPOINT_THRESHOLDS | Empty / source default | backend/src/monitoring/config.ts |
| OBS_HEALTH_TTL_MS | Empty / source default | Profile/launcher, dynamic lookup, or optional operator setting |
| OBS_HTTP_LOG_SAMPLE | Set | Profile/launcher, dynamic lookup, or optional operator setting |
| OBS_ISOLATED_LOAD_TEST | Empty / source default | backend/src/monitoring/config.ts |
| OBS_LOG_FORMAT | Set | backend/src/monitoring/logger.ts |
| OBS_MOBILE_TELEMETRY | Empty / source default | backend/src/monitoring/mobile.ts |
| OSM_DARK_TILE_ATTRIBUTION | Empty / source default | flutter/lib/core/config/app_config.dart |
| OSM_DARK_TILE_URL | Empty / source default | flutter/lib/core/config/app_config.dart |
| OSM_HEALTH_ENDPOINTS | Empty / source default | Profile/launcher, dynamic lookup, or optional operator setting |
| OSM_OVERPASS_URL | Empty / source default | backend/src/services/places/osm.ts |
| OSM_OVERPASS_URLS | Empty / source default | backend/src/services/places/osm.ts |
| OSM_REQUEST_INTERVAL_MS | Empty / source default | backend/src/services/places/osm.ts |
| OSM_TILE_URL | Set | flutter/lib/core/config/app_config.dart |
| OSM_USER_AGENT | Empty / source default | backend/src/services/places/osm.ts |
| OUTING_ARRIVAL_MAX_ACCURACY_METERS | Empty / source default | Profile/launcher, dynamic lookup, or optional operator setting |
| OUTING_ARRIVAL_RADIUS_METERS | Empty / source default | Profile/launcher, dynamic lookup, or optional operator setting |
| OUTING_ARRIVAL_WINDOW_MINUTES | Empty / source default | Profile/launcher, dynamic lookup, or optional operator setting |
| P | Empty / source default | scripts/flutter-android.mjs |
| PATH | Empty / source default | scripts/flutter-android.mjs |
| PLACES_ABSENCE_THRESHOLD | Empty / source default | backend/src/services/places/bulk-sync.ts |
| PLACES_BATCH_SIZE | Empty / source default | backend/src/services/places/bulk-sync.ts |
| PLACES_CURATOR_UIDS | Empty / source default | backend/src/services/auth/place-curator.ts |
| PLACES_DUPLICATE_DISTANCE_METERS | Empty / source default | backend/src/services/places/branch-write.ts, backend/src/services/places/bulk-sync.ts |
| PLACES_EXPECTED_TARGET | Empty / source default | backend/src/services/places/bulk-sync.ts |
| PLACES_MIN_CONFIDENCE | Empty / source default | backend/src/services/places/bulk-sync.ts |
| PLACES_PYTHON | Empty / source default | backend/src/services/places/bulk-sync.ts |
| PLACES_SYNC_QUIET | Empty / source default | backend/src/services/places/osm.ts |
| PLACE_IMAGE_SOURCE_HOSTS | Empty / source default | backend/src/services/media/catalog-image-source.ts |
| PLACE_RECOMMENDATIONS_TTL_SECONDS | Empty / source default | backend/src/usecases/places/catalog.usecase.ts, flutter/lib/core/cache/cache_policy.dart |
| PORT | Set | backend/src/server.ts |
| R2_ACCESS_KEY_ID | Empty / source default | backend/src/config/media.ts |
| R2_ACCOUNT_ID | Empty / source default | backend/src/config/media.ts |
| R2_BUCKET_NAME | Empty / source default | backend/src/config/media.ts |
| R2_ENDPOINT | Empty / source default | backend/src/config/media.ts |
| R2_JURISDICTION | Empty / source default | backend/src/config/media.ts |
| R2_PUBLIC_BASE_URL | Empty / source default | backend/src/config/media.ts |
| R2_PUBLIC_BUCKET_NAME | Empty / source default | backend/src/config/media.ts |
| R2_SECRET_ACCESS_KEY | Empty / source default | backend/src/config/media.ts |
| TRUST_PROXY | Empty / source default | backend/src/config/deployment.ts |
| WHATSAPP_ACCESS_TOKEN | Empty / source default | backend/src/config/notifications.ts |
| WHATSAPP_API_VERSION | Set | backend/src/config/notifications.ts |
| WHATSAPP_INVITE_TEMPLATE | Set | backend/src/config/notifications.ts |
| WHATSAPP_INVITE_TEMPLATE_LANG | Set | backend/src/config/notifications.ts |
| WHATSAPP_PHONE_NUMBER_ID | Empty / source default | backend/src/config/notifications.ts |
| WHATSAPP_PROVIDER | Empty / source default | backend/src/config/deployment.ts, backend/src/config/notifications.ts |
| WHATSAPP_SPECIAL_EVENT_TEMPLATE | Empty / source default | backend/src/config/notifications.ts |
| YALLA_ENVIRONMENT | Empty / source default | backend/src/server.ts |
| YALLA_TEST_DATABASE_URL | Empty / source default | Profile/launcher, dynamic lookup, or optional operator setting |
