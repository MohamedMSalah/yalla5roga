# Release APK build and Neon deployment — 2026-11-14

## Outcome

The reported Dart compilation error is fixed. All three split release APKs built with the existing `.env.device` configuration. The reviewed notification migration is deployed to Neon, with no pending migrations and all pre-existing application values preserved.

## Build fix and verification

- `flutter/lib/core/di/app_dependencies.dart` used `unawaited` for account-notification cleanup and token refresh without importing `dart:async`. Added that standard-library import; existing initialization and session behavior are unchanged.
- Focused Flutter analysis of `app_dependencies.dart`: **No issues found**.
- Build command: `flutter build apk --release --split-per-abi --dart-define-from-file=.env.device`.
- Actual release build: **PASS**, Gradle assembleRelease completed in 376.9 seconds.
- Android SDK `apksigner verify --print-certs`: **PASS** for all three APKs. The repository's existing release configuration uses the Android Debug certificate; this task did not change signing credentials.
- Java native-access and Firebase plugin KGP messages remain non-fatal toolchain warnings. No dependency/toolchain migration was needed to complete this build.
- No active Dart Tooling Daemon/debug app was available for hot reload. APK installation, physical-device UI, push delivery and live backend startup were not exercised in this task.

Artifacts are under `flutter/build/app/outputs/flutter-apk/`:

| APK | Bytes | SHA-256 |
|---|---:|---|
| `app-arm64-v8a-release.apk` | 25603769 | `DEB648FF325E0C62DF8FD623D44D167B188E9BB882E7D590BE236171168025FE` |
| `app-armeabi-v7a-release.apk` | 23536773 | `92A94E30E04CE97A00CAB670012A230ED8A74F22716D015AC3A16FE5F5E4D6A0` |
| `app-x86_64-release.apk` | 27153077 | `1AE8111738CAFE1F578B8D9EC3A66F7F3E85235B65A8AF217767F4AB59163C73` |

## Neon deployment

Target checked before mutation: project `rough-mountain-69896781`, branch `br-fragrant-heart-avfm4h2t`, database `neondb`, role `neondb_owner`. The direct connection uses verified TLS; credentials are not included in this report.

All 15 previously applied migration checksums matched their local SQL files. The only pending migration was `20261114030000_android_system_notifications` (SHA-256 `9a5af7f9a8a8a03c2b76f0cccc06ef56ceabd3eb1b33d50429778bc6d259fcfb`). Its SQL adds three defaulted NOT NULL columns, a token-version constraint and notification-event enum values. It deletes no table, column or application row.

`backend/scripts/deploy-notification-migration.ts --apply`:

1. Created and verified an ignored private logical backup of all **27 public tables / 662 rows**, including migration history, column metadata, constraints, indexes and notification enum labels.
2. Restored those rows with keys/indexes and foreign keys in a temporary schema. Applied the exact reviewed SQL using an isolated notification enum. Compared the original column values and rolled the rehearsal back.
3. Applied the pending migration with **Prisma Migrate deploy**, retaining normal migration history/checksums.
4. Confirmed **all original application-column row checksums matched** after deployment, excluding the expected migration-history update.
5. Read back all three columns/defaults/nullability, the validated `notification_version_supported` constraint and every enum value added by the migration.
6. A final read-only audit confirmed **16 applied migrations, zero pending**, and no remaining rehearsal schema.

Private backup: `backend/.database-backups/notifications-2026-11-14T14-19-03.158Z/snapshot.json` (gitignored). Public evidence: `NOTIFICATION_MIGRATION_DEPLOYMENT.json` and `NOTIFICATION_MIGRATION_READBACK.json` beside this report. No reset, `db push` or application-data deletion was used. Backend TypeScript compilation (`tsc --noEmit`) also passed.

## Documentation Updates

- `docs/DATABASE_ARCHITECTURE.md`: notification schema deployment status, verified target, backup/rehearsal and preservation evidence.
- `docs/PROJECT_STRUCTURE.md`: deployment utility and audit artifact paths; corrected the earlier notification migration deployment status.
- This report and the two metadata-only JSON audits record the build fix and deployment results. No architecture or product-flow changes required updates elsewhere. No diagram relationships changed. Historical reports retain their original task-time verification limits; current deployment status is recorded here and in the canonical database document. No new inconsistencies identified.


## Places / saved-places release — 2026-11-14

Owner explicitly approved committing the complete 202-file staged application set, including existing notification/auth/UI work, to main. Commit `ce82e4401dbe2934a94624e1c3e2b6ddded3e61d` was verified on GitHub origin/main.

Neon readback passed: no pending migrations; the deployed places migration checksum matches local SQL. No reset or additional schema mutation was required. See PLACES_MIGRATION_READBACK.json.

Release command: `flutter build apk --release --split-per-abi --dart-define-from-file=.env.device`. Build passed in 326.4 seconds. ARM64 signature verification passed using the existing Android Debug certificate. No device installation or device tests ran.

| APK | Bytes | SHA-256 |
|---|---:|---|
| app-arm64-v8a-release.apk | 25740485 | 369894739FDF36C8DB57E786FC9202D590599AC4B0620EC6F7A41A3D0BED1613 |
| app-armeabi-v7a-release.apk | 23689873 | 65A9C866956F0A78495CDC0FD4CCB1A9380169DBA870A3832C498A66D41556A5 |
| app-x86_64-release.apk | 27289793 | F0E83285CAED758AF28931C2A7099410AE2C0AF7FA593588F267BA41FD33BA4C |

Documentation Updates: this release report and migration readback record current verification; no diagram changes. The earlier documented OSM live-import/source and external scheduler activation requirements remain outstanding. Backend hosting deployment was not verified.
