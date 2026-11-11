# Forgot password implementation and verification

Date: 2026-11-11. Scope: Flutter presentation/data/domain, Express auth, Firebase proof validation, and additive Neon security state. Existing uncommitted repository changes were preserved.

## Audit outcome

`LoginUseCase` verifies Neon `users.password_hash` with bcrypt; signup and password change write that same hash. Firebase owns phone proof and UID/session issuance, rather than this application's password. Recovery therefore updates the established bcrypt authority, never sets an unrelated Firebase password, provisions an account, transfers a phone or changes a UID. The existing authenticated settings repair path remains separate. Shared `verifyProof` retains its original `{uid,phone}` contract; the recovery method additionally exposes the validated sign-in time. Existing controller constructor argument order is preserved.

## Delivered behavior

- Login has Forgot Password. A dedicated form asks for the registered phone, SMS OTP, then password and confirmation; success returns to Login.
- English/Arabic strings, existing shared theme/widgets/responsive limits, Arabic digit normalization, async loading and Snackbar failures are wired. Resend cooldown uses absolute time and a local timer. Operation guards prevent duplicate submits; disposing the route clears reset/request secrets.
- Start preflight requires a registered password-bearing account and matching enabled Firebase phone credential, before the app asks Firebase to send SMS. OTP is verified on a secondary Firebase Auth instance, without changing the primary session or syncing a profile.
- Backend validates fresh phone-provider ID-token proof including revocation and current phone, exact request UID/phone, sign-in time and replay digest. A five-minute authorization is single-use; concurrent consumption and conditional password replacement share a transaction. Current phone and password version must still match. Raw recovery secrets are random 256-bit values; only SHA-256 digests persist. Plaintext passwords/OTPs/Firebase proof tokens never persist in Neon.
- Reset passwords require 8+ characters, uppercase/lowercase, digit and symbol, exact confirmation and at most 72 UTF-8 bytes. Existing signup/login/change-password API policies are not changed.
- Shared limits: 30 recovery requests/IP/minute, five starts/phone/hour and one/minute, five proof attempts/request, five reset attempts/secret per ten minutes. Responses are no-store. A successful reset invalidates all other outstanding grants for the same UID. Existing Firebase sessions remain valid by design.

## Verification

Only API integration/OpenAPI and static checks were used. No Flutter app, emulator, device, unit/widget/integration tests, hot reload or runtime visual inspection was run.

| Check | Result |
|---|---|
| `RUN_RECOVERY_API_TESTS=1` + `tsx --test tests/password-recovery.api.test.ts` | 13 passed, 0 failed (12 API scenarios plus the enclosing test) |
| `tsx scripts/validate-api-docs.ts` | 89 Express/OpenAPI operations match; unique IDs and valid local references |
| `tsc --noEmit` | Passed |
| `prisma validate` | Passed |
| Targeted `dart analyze` for auth, API constants, localization and interceptors | No errors; 4 existing warnings and 3 existing info diagnostics; nonzero exit because of warnings |
| New recovery page/provider | No analyzer diagnostics |
| Flutter format | Modified auth Dart files formatted |

The integration suite starts the actual auth router/controller/use cases and Prisma repository against a unique disposable schema on the configured Neon database. It executes the exact new migration SQL there and removes the schema in `finally`. Existing application rows and Firebase identities are untouched. All behavioral assertions are through HTTP, using operation IDs from generated OpenAPI; direct database access is limited to fixture setup/cleanup and checking security invariants. Firebase's SDK boundary (ID-token decoding/account lookup and session issuance) is controlled. Production code still uses Admin `verifyIdToken(token,true)` and current user lookup. The suite is opt-in, matching the existing database-test convention, so ordinary test runs do not require a live Neon schema.

Covered scenarios: successful reset and login with the new password; old-password rejection; invalid/expired/custom-provider proof; wrong UID/phone and pre-request proof; forged client flags; unavailable/unregistered/legacy unbound numbers; weak/mismatched/oversized UTF-8 passwords; challenge/grant expiry; proof replay including refreshed tokens; consumed-token replay; resend/per-phone/per-IP/guessing limits; concurrent reset single-consumption; account/password/phone change rejection; existing OTP signup and subsequent password login retaining UID. Expected duplicate-proof constraint violations are caught and returned as 401; Prisma may log the corresponding expected unique-constraint rejection during the test.

Initial runs exposed a schema-qualification bug in the raw limiter upsert; it was corrected to use the configured, quoted PostgreSQL schema. Network sandbox DNS initially prevented Neon access; network-enabled integration runs passed. Prisma generation initially encountered a locked Windows query-engine DLL; generated model APIs nevertheless compiled and executed successfully in the integration suite. Normal deployment should regenerate the client with application processes stopped.

## Deployment and authentication limitations

1. Follow-up 2026-11-11: applied migration `20261111180000_password_recovery` to the configured application schema with `prisma migrate deploy`. It was the only pending migration; all eleven migrations are now applied. The real backend start succeeded for the reported account afterward, without sending SMS or changing its password.
2. Real SMS delivery, incorrect/expired SMS behavior in the live Flutter SDK, native app verification, screen rendering, RTL/light/dark/foldable interaction and real Firebase session exchange remain unverified. Those cases are covered at the controlled API boundary, not claimed as live provider/device tests.
3. Legacy unbound/split phone identities, passwordless Neon rows and Firebase-only password accounts are deliberately unavailable. Recovery cannot trust profile phones or merge registered identities. These need the existing authenticated repair path or support. The Firebase SDK normally resolves an already-bound number to its existing UID; a concurrent external identity deletion/rebinding is rejected by backend UID/phone checks and cannot overwrite another Neon account.
4. Firebase SMS sending is direct from the client. Firebase app verification, quotas, throttling and SMS region configuration must remain enabled; the recovery API cannot enforce its cooldown on a modified client that calls Firebase directly. Availability preflight distinguishes a recoverable number from an unavailable one; all unavailable reasons use the same message.
5. Established sessions remain valid, as requested. Reset does not revoke Firebase refresh tokens or active sockets. SDK timeout wrappers do not cancel underlying Firebase work; the secondary Auth instance isolates recovery from the main session. If a reset response is lost, it may already have succeeded; the UI advises trying Login before restarting recovery.
6. IP limits use Express's current `req.ip` configuration; proxy deployments must retain a correct, bounded trust-proxy setup. The current checkout does not enable trust proxy, so a reverse proxy may share an IP bucket.

## Files modified by this task

Backend:

- `backend/prisma/schema.prisma`
- `backend/prisma/migrations/20261111180000_password_recovery/migration.sql` (new)
- `backend/src/controllers/auth/auth.controller.ts`
- `backend/src/routes/auth/index.ts`
- `backend/src/services/phone/phone-identity.ts`
- `backend/src/validators/auth/auth.validator.ts`
- `backend/src/repositories/auth/password-recovery.repository.ts` (new)
- `backend/src/usecases/auth/password-recovery.usecase.ts` (new)
- `backend/tests/password-recovery.api.test.ts` (new)

Flutter:

- `flutter/lib/core/constants/api_constants.dart`
- `flutter/lib/core/localization/l10n.dart`
- `flutter/lib/core/network/dio_interceptors.dart`
- `flutter/lib/features/auth/domain/repositories/auth_repository.dart`
- `flutter/lib/features/auth/data/repositories/auth_repository_impl.dart`
- `flutter/lib/features/auth/data/datasources/auth_remote_datasource.dart`
- `flutter/lib/features/auth/data/datasources/firebase_auth_service.dart`
- `flutter/lib/features/auth/presentation/widgets/auth_form.dart`
- `flutter/lib/features/auth/presentation/pages/password_recovery_page.dart` (new)
- `flutter/lib/features/auth/presentation/providers/password_recovery_provider.dart` (new)

## Documentation Updates

- `PRODUCT_SCENARIOS.md`: owner-approved recovery scope and unsupported identities.
- `AUTHENTICATION_AND_AUTHORIZATION.md`: audited password authority, proof/grant binding, replay, limits and session policy.
- `API_CONTRACTS.md`: three recovery bodies, envelopes, error statuses and policies.
- `USER_SCENARIOS.md`: AUTH-08 journey, alternatives, errors and verification boundaries.
- `FLUTTER_ARCHITECTURE.md`: route-local Provider, repository/datasource flow, isolated OTP Auth and transient secrets.
- `BACKEND_ARCHITECTURE.md`: controller/use case/repository responsibilities and shared persistence.
- `DATABASE_ARCHITECTURE.md`: security-state tables, atomic consumption, migration status; ER diagram adds the user/recovery relationship.
- `BUSINESS_LOGIC.md`: recovery eligibility, password policy and canonical-account restrictions.
- `SYSTEM_DESIGN.md`: recovery sequence diagram and authority/concurrency details.
- `SYSTEM_ARCHITECTURE.md`: existing component communication for recovery.
- `ARCHITECTURE_DECISIONS.md`: ADR-005 clarification for the established password authority and recovery.
- `PROJECT_STRUCTURE.md`: new implementation, migration, API test and report paths.
- `audit/PASSWORD_RECOVERY_REPORT.md`: this report.

Diagrams updated: recovery sequence and database ER relationship. Remaining inconsistencies: no known recovery code/contract inconsistency; deployment and live provider/Flutter verification remain pending as stated above. Earlier unrelated audit findings and existing analysis warnings are outside this change.

References for Firebase proof behavior: [Verify ID tokens](https://firebase.google.com/docs/auth/admin/verify-id-tokens), [Decoded ID token/auth_time](https://firebase.google.com/docs/reference/admin/node/firebase-admin.auth.decodedidtoken), [Manage users](https://firebase.google.com/docs/auth/admin/manage-users).

## OTP failure diagnosis and fix — 2026-11-11 follow-up

Read-only Neon/Firebase inspection confirmed the reported phone has an existing password and a matching enabled Firebase identity. Both recovery tables were missing, causing backend preflight to fail before Firebase SMS sending. Applied the existing additive migration with Prisma; the actual `PasswordRecoveryUseCase.start` then returned a valid ten-minute challenge and 60-second resend interval. No SMS was sent by this diagnostic and no password or identity was changed.

Also corrected the shared SMS adapter’s premature 15-second callback cutoff to one 75-second deadline, observed invocation errors immediately and ignored late callbacks. Failed recovery resends retain the prior valid request/verification pair. Recovery uses the existing signup OTP widget with automatic six-digit submission. All snackbar call sites now share the branded logo bubble, including map settings actions; recovery, OTP success/error and server messages were shortened.

Verification: targeted Dart MCP analysis reports no errors. All 27 focused Flutter tests pass (`password_recovery_test`, `app_snackbar_test`, `error_handling_test`, `group_account_linking_test`). The existing error test was aligned with the current localized invalid-credential mapping. Snackbar cases exercise English/Arabic, 320px phone/light and 800px wide/dark, with enlarged text on wide. No live device or rendered screenshot inspection is claimed. Hot reload was attempted but DTD has no running app. The existing HTTP/Neon integration suite was retried twice but could not connect (ETIMEDOUT/ENETUNREACH) before fixture creation; its earlier 13-pass result above remains historical.

Documentation Updates: AUTHENTICATION_AND_AUTHORIZATION, DATABASE_ARCHITECTURE, FLUTTER_ARCHITECTURE, USER_SCENARIOS, SYSTEM_DESIGN and this report now reflect deployment, callback deadlines, resend behavior and shared branded feedback. Existing diagrams remain accurate and were not changed. No known contract inconsistency remains; live Firebase SMS/app verification and device UI checks remain for owner testing. The owner-requested `flutter build apk --release --split-per-abi --dart-define-from-file=.env.device` completed successfully (352.3s). Outputs: `app-armeabi-v7a-release.apk` (21.9 MB), `app-arm64-v8a-release.apk` (24.0 MB), `app-x86_64-release.apk` (25.4 MB), under `flutter/build/app/outputs/flutter-apk/`. Build emitted non-blocking Java native-access and Firebase plugin KGP compatibility warnings. Physical-device testing is left to the owner.
