# Environment configuration

The root `.env.example` is a public, credential-free template with the same variable names as both private profiles. Copy it to the required profile only when creating a new setup; never overwrite an existing populated profile. Supply existing service credentials securely and set the mode-specific values described below. Only `.env.example` is exempt from Git ignore; the real profiles and private backups remain ignored.

Updated 2026-11-23. Exactly two primary profiles live at the repository root: ignored `.env.device` and `.env.production`. They have identical variable names and deliberately share existing Neon, Firebase, R2, WhatsApp and monitoring settings. No additional cloud services are required. R2 and WhatsApp sender credentials remain empty because none were available in the local profiles.

`SHARED_PRODUCTION_SERVICES=true` explicitly permits credential reuse. The local launcher warns about live resources. Local API actions can change real accounts, application data and media or enqueue real messages. Firebase client telemetry also targets the shared project. Use development only with that risk understood. Local startup disables automatic voting closure, outing completion, notification dispatch, media cleanup and account deletion jobs; the read-only catalog listener remains enabled. User-requested API mutations retain their existing behavior. A deployed production process runs its normal workers. Startup and APK scripts never run migrations, imports or cleanup commands. Device Prisma writes are blocked while sharing services; migration deployment is a separately authorized operation.

Device uses `NODE_ENV=development`, `APP_ENV=development`, `HOST=0.0.0.0`, `PORT=3000` and the current LAN origin `http://192.168.1.6:3000`. Update the origin when the workstation's LAN address changes. Production uses `NODE_ENV=production`, `APP_ENV=production`, `DEPLOYMENT_ENV=production`; its `API_BASE_URL`, ingress `TRUST_PROXY` and `CORS_ORIGINS` remain empty until deployment. Public API and CORS origins must use HTTPS. Production honors host-injected settings before its file; device uses its own file instead of inherited application settings.

Original profiles, including the previous distinct local monitoring secrets, are preserved privately in ignored `.configuration-backups/`. These backups are not launch profiles. Do not share or commit them. No production credentials were rotated or changed.

```sh
pnpm dev:device
pnpm build:device
pnpm build:production
pnpm check:environments
```

`build:apk:device` and `build:apk:production` remain aliases. Both build commands validate client configuration, the native Firebase Android registration and release signing properties, then invoke `flutter build apk --release --split-per-abi --flavor <device|production> --dart-define-from-file=<temporary-client.json>`. The temporary JSON contains only the allowlisted client variables below, is outside Flutter assets, and is deleted when the command ends. Neither full profile is passed to Flutter; known profile variables are also removed from the child environment. No APK is installed or launched.

The Android flavors retain the existing application ID `com.example.yalla_5roga` and base Firebase registration. There is no application ID suffix or extra Firebase app. Optional flavor Firebase files belong at `src/device/google-services.json` and `src/production/google-services.json`; both are ignored and validated. Android forbids cleartext in the main manifest; only the device flavor enables it, including device Release. Production rejects an empty, HTTP or non-public API origin before invoking Flutter, and its Android manifest retains the cleartext prohibition.

Both release flavors use the existing Gradle release signing configuration: ignored `flutter/android/key.properties` with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. Relative store paths resolve from `flutter/android/`; use Java Properties escaping for Windows paths or forward slashes. Keep the actual keystore outside Git. There is no debug-signing fallback and no key generation. File checks do not verify keystore passwords or Firebase certificate fingerprints; register the approved signer's SHA fingerprints in the existing Firebase app before distributing.

Successful builds report each output under `flutter/build/app/outputs/flutter-apk/`: `app-<flavor>-armeabi-v7a-release.apk`, `app-<flavor>-arm64-v8a-release.apk`, `app-<flavor>-x86_64-release.apk`. Device and production filenames are independent. Existing APKs from earlier builds are not evidence of these new builds.

`pnpm check:environments` performs offline profile parity, shared settings, current LAN, Firebase native registration, client filtering and production URL rejection checks, and reports missing service/signing configuration. It does not contact cloud services, start a server or build an APK. Tests continue to require their isolated loopback test database. For authorized operational commands use `pnpm project device|production tsx|prisma <arguments>`; never run data-changing audit scripts against live resources merely to validate configuration.

## Client-safe variables

| Variable | Requirement, default or example |
| --- | --- |
| `APP_ENV` | Required by the build command. `development` in device and `production` in production. |
| `API_BASE_URL` | Required for APKs. Use a bare origin such as `http://192.168.1.50:3000` or `https://api.example.org`. The API paths already include `/api`. The backend may use this to report its configured origin. |
| `API_CONNECT_TIMEOUT_MS`, `API_RECEIVE_TIMEOUT_MS` | Optional. Both default to 15000 ms, capped at 120000 ms. |
| `APP_DOWNLOAD_URL` | Optional. Defaults to the existing Yalla 5roga site. Also used for invitations. Confirm the actual landing page and download availability. |
| `FIREBASE_PROJECT_ID` | Required for mobile and backend Auth. Match the project's native app registration and the Admin service account. |
| `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID` | Required. Android project's native API key and Firebase Android app ID. |
| `FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID`, `FIREBASE_IOS_BUNDLE_ID`, `FIREBASE_IOS_CLIENT_ID` | Required by the current shared Flutter config. Get values from the same project's iOS registration and its plist. |
| `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_STORAGE_BUCKET`, `FIREBASE_WEB_CLIENT_ID` | Required by the shared Flutter config. Project number, Firebase options storage-bucket identifier and Google Web OAuth client ID. Setting the bucket identifier does not enable Firebase Storage. |
| `MAP_VECTOR_TILEJSON_URL`, `MAP_GLYPHS_URL`, `MAP_ATTRIBUTION`, `MAP_ATTRIBUTION_URL` | Optional. Defaults to OpenFreeMap and the data licenses in `YallaMapStyle`. Any client key in these URLs must be publishable and restricted. |
| `MAP_LIGHT_STYLE_URL`, `MAP_DARK_STYLE_URL` | Optional HTTPS styles. Bundled style generation is the default. Hosted styles can substitute `{language}`. |
| `MAP_OFFLINE_ALLOWED` | Built-in OpenFreeMap defaults allow bounded offline downloads. For other endpoints, enable only when the provider explicitly permits it. |
| `OSM_TILE_URL`, `OSM_DARK_TILE_URL`, `OSM_DARK_TILE_ATTRIBUTION` | Legacy public compatibility settings. MapLibre uses the vector settings above. |
| `IMAGE_UPLOAD_MAX_EDGE`, `IMAGE_UPLOAD_TARGET_BYTES`, `IMAGE_UPLOAD_QUALITY` | Shared with the API. Defaults 1600 px, 358400 bytes and 80. Supported ranges 256–2400 px, 32768–2097152 bytes and 65–90. The client preserves aspect ratio and uses a bounded quality and size ladder. |
| `PLACE_RECOMMENDATIONS_TTL_SECONDS` | Shared with the API. Optional client/provider recommendation cache policy. |
| `API_DIAGNOSTICS`, `API_DIAGNOSTICS_LOG`, `API_DUPLICATE_WINDOW_MS`, `API_TELEMETRY_SAMPLE` | Optional request diagnostics, debug summaries, duplicate time window, and sample rate. Leave defaults unless collecting controlled diagnostic evidence. |
| `FIREBASE_TELEMETRY_ENABLED` | Defaults to `true`. Set `false` to disable the app's Analytics, Crashlytics and Performance collection. |

## Backend settings and secrets

Blank entries use a source default or disable an optional service. Configure secret values on the host or in its selected ignored file. Set actual resource IDs independently of credential strings. Variable names and defaults are safe to share. Connection strings, private keys, secret tokens and signing values are private.

| Service | Variables and defaults |
| --- | --- |
| Application | `HOST` defaults to `0.0.0.0`. `PORT` defaults to `3000` and accepts a platform-injected port. `NODE_ENV`, `YALLA_ENVIRONMENT` are set by launchers. `DEPLOYMENT_ENV` is `production` or `staging` for hosted startup. |
| Database | `DATABASE_URL` required. `DIRECT_URL` optional direct migration URL, recommended for Neon. Production requires `EXPECTED_DATABASE_HOST` (direct hostname without `-pooler`) and `EXPECTED_DATABASE_NAME`. Prisma uses a direct session with default `connection_limit=5`, `connect_timeout=10` and `pool_timeout=10`. The catalog listener uses one separate direct connection. Keep `sslmode=verify-full` for hosted drivers where supported. `YALLA_TEST_DATABASE_URL` is device/test-only. |
| Firebase Admin and exchange | `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, and backend `FIREBASE_API_KEY` are required for hosted startup and authenticated device testing. Hosted startup requires `EXPECTED_FIREBASE_PROJECT_ID`. Development has no ambient service-account discovery. Use a quoted multiline PEM or escaped `\n`; the Admin loader normalizes escaped newlines. Production refuses `FIREBASE_AUTH_EMULATOR_HOST` and a conflicting `GOOGLE_CLOUD_PROJECT`. |
| Notifications | `NOTIFICATION_WORKER_INTERVAL_MS` defaults to 5000, `NOTIFICATION_WORKER_BATCH_SIZE` to 20, `NOTIFICATION_MAX_ATTEMPTS` to 5. FCM uses Firebase Admin. |
| Private storage | `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME` are required in hosted production. Also set `EXPECTED_R2_ACCOUNT_ID` and `EXPECTED_R2_PRIVATE_BUCKET`. Set `R2_ENDPOINT` only to override the account's S3 endpoint. `R2_JURISDICTION` allows a jurisdiction such as `eu` or `fedramp`. Without R2 credentials, device storage falls back to the existing in-memory mock; persistent cloud media is unavailable until real R2 credentials are supplied to both profiles. `MEDIA_MOCK_BASE_URL` defaults to `http://localhost:3000`. |
| Image limits and cleanup | `MEDIA_MAX_UPLOAD_BYTES` defaults to and is capped at 10485760. `MEDIA_ALLOWED_MIME_TYPES` defaults to JPEG, PNG, WebP and GIF. Images are capped at 24 million decoded pixels across at most 60 frames for supported GIF and WebP animations. `MEDIA_UPLOAD_URL_TTL_SECONDS` and `MEDIA_SIGNED_URL_TTL_SECONDS` cap at 900 and 300 respectively. `MEDIA_CLEANUP_INTERVAL_MS` defaults to 3600000. Cleanup uses each intent's upload expiry. |
| Catalog and CDN | `R2_PUBLIC_BUCKET_NAME`, `EXPECTED_R2_PUBLIC_BUCKET` and `R2_PUBLIC_BASE_URL` are optional. Use a separate bucket and bare HTTPS origin. `PLACES_CURATOR_UIDS` is a comma-separated Firebase UID allowlist. `PLACE_IMAGE_SOURCE_HOSTS` is an exact hostname allowlist for the manual image importer. Leave it empty to disable remote imports. |
| WhatsApp | `WHATSAPP_PROVIDER=meta` enables the optional outbound sender once `WHATSAPP_ACCESS_TOKEN` and `WHATSAPP_PHONE_NUMBER_ID` are present. Leave provider blank to use share links. `WHATSAPP_API_VERSION` defaults to the historical `v21.0`; pin a version supported by your Meta app. `WHATSAPP_INVITE_TEMPLATE`, `WHATSAPP_INVITE_TEMPLATE_LANG`, `WHATSAPP_SPECIAL_EVENT_TEMPLATE` default to `group_invite`, `en`, `special_event_invite`. `INVITE_DEEP_LINK_BASE` defaults to `APP_DOWNLOAD_URL`. `FLUTTER_APP_SCHEME` defaults to `yalla5roga`. |
| Geocoding | Optional `GEOCODING_PROVIDER=pelias` requires an HTTPS `GEOCODING_BASE_URL` and `GEOCODING_ATTRIBUTION`. Set `GEOCODING_API_KEY` if the host requires it. `GEOCODING_CACHE_SECONDS` defaults to 0, clamped at 300. `GEOCODING_REQUESTS_PER_MINUTE` controls the route limiter. |
| Ingress and attendance | `CORS_ORIGINS` is required in production as a comma-separated HTTPS origin allowlist. `TRUST_PROXY` takes the exact ingress IPs/CIDRs and defaults to no trusted forwarder. `OUTING_ARRIVAL_MAX_ACCURACY_METERS`, `OUTING_ARRIVAL_RADIUS_METERS`, `OUTING_ARRIVAL_WINDOW_MINUTES` override the existing arrival policy. No separate Socket.IO URL, port or credential is needed. |
| Catalog ingestion | `PLACES_BATCH_SIZE`, `PLACES_ABSENCE_THRESHOLD`, `PLACES_DUPLICATE_DISTANCE_METERS`, `PLACES_MIN_CONFIDENCE`, `PLACES_PYTHON`, `PLACES_EXPECTED_TARGET`, `PLACES_SYNC_QUIET` control the operator CLI. `OSM_OVERPASS_URLS` or `OSM_OVERPASS_URL` selects operator Overpass sources. `OSM_REQUEST_INTERVAL_MS`, `OSM_USER_AGENT`, `OSM_HEALTH_ENDPOINTS` control operator Overpass requests and health probes. |
| Rating ranking | `PLACE_RATING_PRIOR_WEIGHT` is a positive safe integer with a default of 20. The API validates it at startup. Changing it invalidates previously issued Top Rated cursors. |
| Observability | `OBSERVABILITY_ENABLED` defaults on. `OBS_MOBILE_TELEMETRY=1` enables the bounded authenticated mobile sink. A `MONITORING_TOKEN` of at least 24 characters enables private dependency and metrics routes. `OBS_LOG_FORMAT=json` selects JSON in device, and `LOG_LEVEL` overrides the production/device log threshold. |
| Observability tuning | `OBS_HTTP_LOG_SAMPLE` defaults to 0 in production and 1 otherwise. `OBS_DUPLICATE_WINDOW_MS` defaults to 2000, `OBS_HEALTH_TTL_MS` to 15000, `OBS_DB_WARN_MS` to 100 and `OBS_DB_CRITICAL_MS` to 500. `OBS_ENDPOINT_THRESHOLDS` accepts a JSON object of per-route thresholds. `OBS_ISOLATED_LOAD_TEST` is fixture-only. `GRAFANA_ADMIN_PASSWORD` is a separate Compose setting. |

Use literal assignments such as `R2_SECRET_ACCESS_KEY=`, `CORS_ORIGINS=https://app.example.org` or `GEOCODING_PROVIDER=pelias`. Keep signing in ignored `flutter/android/key.properties` and the keystore outside the checkout where practical. Retain native Firebase configuration files. The flavor overrides are `flutter/android/app/src/device/google-services.json` and `flutter/android/app/src/production/google-services.json`. Match iOS using the appropriate scheme and plist.

If local startup reports `DATABASE_URL`, restore the existing shared connection setting; do not create a new database or run migrations automatically. An invalid or missing Admin key leaves local auth unavailable. For hosted startup, populate the reported key or group and restart. A configured bucket that fails the private S3 health probe keeps hosted readiness at 503. A bucket probe verifies access to the bucket, and live reads, writes and public-access policies require their own checks.

The [service setup guide](../SERVICE_SETUP_GUIDE.md) maps existing and missing credentials to provider dashboards. The [deployment runbook](PRODUCTION_DEPLOYMENT.md) covers backup, rehearsal, ingress and rollback.


Set `PLACE_REVIEW_MODERATOR_UIDS` on the backend to authorize specific Firebase UIDs for report triage and review visibility changes. Leaving it empty disables moderator operations.


### Smart Meetup location request limits

`LOCATION_REQUEST_COOLDOWN_MINUTES` controls the global recipient cooldown. The default is 360 minutes and valid values are 1–1440. `LOCATION_REQUEST_DAILY_LIMIT` sets the rolling 24-hour sender cap. The default is 5 and valid values are 1–100. An unset or invalid value uses the default.
