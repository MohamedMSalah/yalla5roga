# Media Storage System — Implementation Report

| Metadata | Value |
|----------|-------|
| Date | 2026-11-12 |
| Scope | Cloudflare R2 media pipeline, presigned direct uploads, private signed delivery, public CDN place media, Flutter persistent image caching |
| Status | Implemented and unit-verified; real R2/CDN activation pending credentials/domain |
| Migration | `backend/prisma/migrations/20261112120000_media_assets` (applied to the configured Neon database) |
| Tests | Backend `tests/media.service.test.ts` — 11/11; Flutter media + `app_sync_provider` tests — 29/29; `tsc --noEmit` clean |

## 1. What was implemented

### Backend

- `media_assets` Prisma model and `media_visibility` / `media_status` / `media_purpose` enums with owner + entity links, unique object key, cleanup indexes, and back-relations to users/groups/outings/places.
- Storage adapter abstraction:
  - `r2-storage.adapter.ts` — Cloudflare R2 via the S3-compatible API (`@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`).
  - `mock-storage.adapter.ts` — in-memory adapter for development; enforces issued object keys and a byte budget.
  - Provider selection is env-only (`r2` only when all required credentials exist; otherwise `mock`).
- `media.service.ts` lifecycle: request upload intent (with expired-URL re-issue), HEAD verification on confirm, delete, single/batch delivery URL resolution, entity reference resolution/linking, and orphan cleanup.
- `media-access.ts` authorization:
  - Upload: profile = self; group/outing with entity id = owner/creator; entity-less covers allowed before creation; chat = outing participant; place = catalog mutation APIs.
  - View: profile = any authenticated user; place/public = any authenticated user; group/outing/chat = membership/participant eligibility; owner override.
- Media routes + controller + validators + Swagger (`Media` tag, request bodies, intent/asset/URL/deleted schemas):
  - `POST /api/media/upload-url`
  - `POST /api/media/:id/confirm`
  - `POST /api/media/signed-urls`
  - `GET /api/media/:id/url`
  - `DELETE /api/media/:id`
- Development-only mock storage routes (`PUT /api/media/mock-upload/:key`, `GET /api/media/mock-download/:key`) registered only while the provider is `mock`.
- `jobs/media-cleanup.job.ts`, started from `server.ts`, reaps expired pending intents and failed assets.
- Entity integration (backward compatible):
  - Users, groups, outings, places validators accept `media://<uuid>` in addition to http(s).
  - Create/update use cases resolve and link references before/after persistence; covers may be linked after row creation.
  - Place images accept media references.
  - Local file paths are rejected.
- `.env.example` documents all R2/media variables and placeholders.

### Flutter

- `core/media/media_reference.dart` — parse/build/classify `media://`, http(s), and local paths.
- `core/media/media_upload_service.dart` — request intent → direct storage PUT → confirm; MIME/size validation; best-effort delete on failure; mock loopback host rewrite for emulators.
- `core/media/media_url_store.dart` — persistent per-account delivery URL metadata (URL, visibility, expiry), capped at 400 entries/account, clear/evict helpers.
- `core/media/media_url_resolver.dart` — batch signed-URL resolution (max 50), stale-while-revalidate, offline fallback, stable account-scoped cache keys, invalidation, account clearing.
- `AppNetworkImage` renders `media://` through `CachedNetworkImage` with stable `cacheKey`, account-switch safety, error-triggered revalidation, and existing fallbacks.
- `remote_image_url.dart` accepts http(s) or `media://`.
- DI wiring: `AppDependencies` owns `MediaUrlResolver`/`MediaUploadService`; Provider exposure in `app.dart`; `AppSyncProvider`/logout clear account-scoped media state.
- Upload wiring: Edit Profile, Create Group, group cover change, Create Outing (create + suggest).
- Bilingual `imageUploadFailed` copy added.
- Tests: reference parsing, URL store persistence/isolation, resolver batching/offline/cache keys, upload flow/failure cleanup/host rewrite, remote URL helper.

## 2. Environment variables

| Variable | Purpose | Default |
|----------|---------|---------|
| `R2_ACCOUNT_ID` | R2 account id (required for `r2` provider) | empty (mock) |
| `R2_ACCESS_KEY_ID` | R2 access key (required) | empty |
| `R2_SECRET_ACCESS_KEY` | R2 secret key (required) | empty |
| `R2_BUCKET_NAME` | Bucket name (required) | empty |
| `R2_ENDPOINT` | Optional custom S3 endpoint | `https://<account>.r2.cloudflarestorage.com` |
| `R2_JURISDICTION` | Optional R2 jurisdiction hint | empty |
| `R2_PUBLIC_BASE_URL` | Public CDN base for `place` media | `https://media.example.com` placeholder |
| `MEDIA_UPLOAD_URL_TTL_SECONDS` | Presigned PUT lifetime | 900 |
| `MEDIA_SIGNED_URL_TTL_SECONDS` | Signed GET lifetime | 300 |
| `MEDIA_MAX_UPLOAD_BYTES` | Max upload size | 10 MiB |
| `MEDIA_ALLOWED_MIME_TYPES` | Accepted MIME list | jpeg,png,webp,gif |
| `MEDIA_PENDING_TTL_MINUTES` | Orphan pending age | 1440 |
| `MEDIA_CLEANUP_INTERVAL_MS` | Cleanup job interval | 3600000 |
| `MEDIA_MOCK_BASE_URL` | Base URL used in mock presigned URLs | `http://localhost:3000` |

Switching from mock to real R2 requires only env changes; no code edits.

## 3. Verification evidence

- `backend`: `pnpm exec tsc --noEmit` → clean.
- `backend`: `pnpm exec tsx --test tests/media.service.test.ts` → 11 pass / 0 fail. Coverage includes upload intent/re-issue, ownership, confirm/failed object, MIME/size policy, signed-vs-public delivery (including the R2-without-CDN fallback), reference linking/purpose mismatch, legacy http(s) passthrough, and cleanup.
- Running server (`PORT=3100`): `/health` → 200 with `database: connected`; unauthenticated `POST /api/media/upload-url` and `POST /api/media/signed-urls` → 401; unknown mock download → 404; mock upload without an issued key → 400 (guard working).
- Swagger spec at `/api-docs/swagger-ui-init.js` contains `/api/media/upload-url`, `/api/media/signed-urls`, `/api/media/{id}/confirm`, `/api/media/{id}/url`, `/api/media/{id}`.
- Neon: migration `20261112120000_media_assets` applied via `prisma migrate deploy` (12 migrations total).
- Flutter: targeted analyzer clean for all media/integration files; full analyzer has no errors (only pre-existing warnings/infos outside media). Media tests and `app_sync_provider_test.dart` pass (29 tests). Full `flutter test` is otherwise green except the pre-existing, unrelated `map_selection_test.dart` failure (untouched files).

## 4. Remaining work for real R2 activation

1. Create the R2 bucket and an API token with object read/write permission; set `R2_ACCOUNT_ID`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY`, `R2_BUCKET_NAME`.
2. Configure a bucket CORS policy allowing `PUT` from the app (and `GET/HEAD` as needed for the CDN).
3. Attach a Cloudflare custom domain to the bucket and set `R2_PUBLIC_BASE_URL` (replacing the placeholder).
4. Ensure `MEDIA_MOCK_BASE_URL` is not used in production (the mock routes disappear with the `r2` provider).
5. Run an authenticated device E2E upload/confirm/display/logout cycle against real R2.
6. Optional operational hardening: external metrics/alerting for cleanup failures and storage errors; bucket lifecycle rules are not a substitute for the cleanup job because DB rows must also be removed.

## 5. Known limitations / unexercised states

- Real R2 or CDN upload/download was not exercised (no credentials/domain yet).
- Authenticated end-to-end HTTP flow was not exercised with a real Firebase token; backend unit tests + unauthenticated route checks + mock adapter guards were used instead.
- Physical-device mock upload requires `MEDIA_MOCK_BASE_URL` to be a LAN-reachable API address; emulators rewrite loopback hosts automatically.
- UI states (offline first render after cold start, account switch while images are on screen) are covered by resolver/store tests and cache-key design but were not manually exercised on a device in this task.
- Disk eviction is intentionally best effort and time-bounded; key isolation guarantees cross-account safety even if a file cannot be deleted.
