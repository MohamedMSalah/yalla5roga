# Deployment preparation verification

22 November 2026 · Local release candidate

`main` and live GitHub `origin/main` were both at `a90c360aa08469a172a24ae2c3010af83a5904f3`. The checkout was already dirty. The candidate is that commit plus the working-tree remediation and deployment preparation. The account-deletion migration and related remediation remain local changes. No live migration or public deployment was performed.

## Environment and configuration security

- The checkout contains only the ignored repository-root `.env.device` and `.env.production` application dotenv files. The former files were parsed and round-trip checked before removal. Existing values were retained in their intended configuration. The legacy backend targeted the previously deployed Neon database and shared its Firebase project with both mobile profiles. Its credential groups and matching mobile values were kept in production, and the device Firebase and database fields are empty pending isolated targets.
- Production retained `DATABASE_URL`, `FIREBASE_PROJECT_ID`, `FIREBASE_CLIENT_EMAIL`, `FIREBASE_PRIVATE_KEY`, `FIREBASE_API_KEY`, `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID`, `FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID`, `FIREBASE_IOS_BUNDLE_ID`, `FIREBASE_IOS_CLIENT_ID`, `FIREBASE_MESSAGING_SENDER_ID`, `FIREBASE_STORAGE_BUCKET` and `FIREBASE_WEB_CLIENT_ID`. The device LAN URL and public app defaults were preserved. Expected production identifiers, missing credentials and service requirements are in the [provider inventory](../SERVICE_SETUP_GUIDE.md).
- The test loader discards application service credentials and accepts only a disposable loopback `yalla_test*` database. The Flutter wrapper supplies individual allowlisted values, and a fixture test excludes the database URL, Admin key, R2 and WhatsApp credentials, monitoring token and signing password. The APK binaries still require post-build inspection on the release workstation.
- Redacted Git history scanning covered 3,652 eligible text blobs across 51 reachable commits and compared the configured database password and private-key material in memory. The scan found no candidate private key or matching production credential in those blobs. The old environment example contained a key-marker pattern, with no full PEM found. Git history was left intact. Native Firebase app registrations are public client configuration and should retain appropriate restrictions.

## Results

| Check | Result |
| --- | --- |
| Backend | Frozen install, build and type check passed. **333 backend tests** and **145 API contract tests** passed. The HTTP fixtures exercised malformed media rejection, owner/outsider authorization, decoded WebP delivery and deletion against served OpenAPI. |
| Flutter | **207 host tests passed**, including compression, orientation, metadata stripping, alpha, static and animated WebP, expected sizes and failure cleanup. Static analysis reported zero errors, zero warnings and 37 existing information-level findings. |
| Dependency registry | Full and production audits both reported zero critical and high advisories, three moderate and one low. |
| Neon | TLS read-only status found **25 applied, one pending**, zero failed/unexpected rows and zero checksum mismatches. Live Prisma schema diff showed the two account-deletion tables and their index/foreign key from the pending migration. No live write was used. |
| Disposable PostgreSQL | All **26 migrations** applied, Prisma validation and schema diff passed, and a separate backup/recovery fixture restored **42 tables and 128 rows** with matching checksums, foreign keys and indexes. The restore transaction rolled back. |
| Firebase live | Admin OAuth and Auth project-config reads succeeded. Existing Android and iOS project/app IDs matched the backend Admin project. Live OTP, FCM, Google sign-in, session revocation behavior and deletion remain fixture or device checks. |
| Maps and catalog sources | Public OpenFreeMap TileJSON, Geofabrik Egypt checksum metadata and the Overture STAC root returned HTTP 200. No live import was run. |
| k6 smoke | One VU for eight seconds on a disposable loopback API completed 19 HTTP requests with zero failures. P50/P95/P99 were 9.28/20.42/22.20 ms. This is a smoke result. The 10-, 25- and 50-user profiles are documented for controlled runs. |
| Compiled startup | A disposable loopback startup reported route count and database latency. Liveness and readiness returned 200. Metrics returned 401 without the bearer and 200 with it. The catalog listener became ready and invoking the shutdown handler exited cleanly. Linux signal delivery and hosted ingress remain unverified. |
| Actual profiles | Backend production preflight rejected missing `CORS_ORIGINS` and device preflight rejected missing `DATABASE_URL`. Android preflight rejected missing production `API_BASE_URL` and missing isolated device Firebase settings. The release signer is absent. |

Migration `20261122000100_coordinated_account_deletion` introduces the deletion journal and media purge ledger, updates the phone constraint for the deletion sentinel, and adds a hashed identity fence trigger. Roll back the server artifact independently of the database schema. If returning to an artifact before coordinated deletion, block its user deletion routes and reconcile accepted deletions before using any restore. See the [migration, backup and rollback procedures](../development/PRODUCTION_DEPLOYMENT.md).

## Image measurements

The Flutter optimizer ran on the host on two representative inputs and one previously optimized project asset. The values are encoded byte counts before any network transfer.

| Sample | Input | Output | Result |
| --- | ---: | ---: | --- |
| Synthetic textured camera JPEG | 2,614,889 B, 2100 × 1400 | 233,868 B, 1200 × 800 WebP | 91.1% smaller |
| Transparent project logo PNG | 1,077,044 B, 1129 × 1129 | 63,338 B, 1129 × 1129 WebP | 94.1% smaller |
| Existing project WebP | 26,116 B, 320 × 309 | 26,116 B, 320 × 309 WebP | Original retained after decode and metadata checks |

Signup/profile, group covers and outing/draft photos use the same local optimizer. Server confirmation checks the real bytes and writes a different, server-owned final key. Existing references and delivery cache identities are retained. The curator importer processes an allowlisted source before storage. The existing ready media and catalog were left in place. Private bucket owners still need a lifecycle rule for the `uploads/` prefix so R2 removes any replayed staging bytes or interrupted staging uploads.

## Release verdicts

| Target | Verdict | Remaining gate |
| --- | --- | --- |
| Local device testing | Configuration required | Set an isolated database and Firebase project, install the debug native app registration, confirm the configured LAN address against startup output, then build and test on the device. |
| Hosted backend | Prepared for an isolated rollout | Select the host/ingress, configure CORS and private R2, verify provider policies and migrate the intended isolated target. Linux container/ingress and live R2 were not exercised. |
| Production APK | Blocked | Confirm public HTTPS API and WebSocket ingress, configure and register the release signer, then build and inspect release APKs per ABI. |
| Public production | Blocked | Approve the pending live migration after a current verified backup, complete staging/provider and physical-device sign-off, and review retention and remaining advisories. |

Run `pnpm dev:device` or `pnpm start:production` from the repository root. Use `pnpm build:apk:device` for an Android debug APK and `pnpm build:apk:production` for the signed split release. `pnpm monitoring:device` starts the optional private local monitoring stack when configured. The [environment reference](../development/ENVIRONMENT_CONFIGURATION.md), [deployment runbook and device checklist](../development/PRODUCTION_DEPLOYMENT.md) and [observability guide](../development/OBSERVABILITY.md) provide exact commands and live checks.

## Files and documentation

- Root `package.json`, `scripts/*environment*.mjs`, `scripts/flutter-*.mjs`, `scripts/project-command.mjs`, `scripts/database-status.mjs` and `scripts/monitoring-local.mjs` select and verify the configuration. The Android PowerShell helper delegates to the safe build path. Legacy dotenv files and full-file IDE launchers were removed.
- `Dockerfile` and `.dockerignore` prepare the Linux container. Backend configuration, startup, dependency health, media adapters and tests are under `backend/`. Legacy backend tools consume the selected profile through the wrapper. The lockfile records Sharp and the retired direct dotenv dependency.
- Flutter preprocessing, transfer progress, configuration and tests are under `flutter/lib/core/media/`, `flutter/lib/core/config/` and `flutter/test/core/media/`. Telemetry initialization remains optional.
- The environment reference, service setup guide, deployment/recovery and observability runbooks, Android setup, API contracts, and backend, Flutter and system architecture docs reflect the changed flow. No existing diagrams needed a topology change.
