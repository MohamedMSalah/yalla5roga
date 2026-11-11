# Group phone membership investigation and fix

Verified 2026-11-10. Changes are in the local working tree; no deployment was performed.

## Root cause and live evidence

The former signup flow verified SMS OTP on Firebase identity X, signed it out,
then created a separate bare Firebase identity Y and saved `users.id=Y` in Neon.
The verified phone remained on X. `InviteToGroupUseCase` looked up X by verified
phone, could not find `users.id=X`, and correctly saved a pending invitation
instead of inserting a membership. Password login returned Y without claiming
invitations. Y's ID token had no verified phone, so ordinary sync could not
claim the invitation either. Settings phone updates used a profile PATCH,
which also did not claim invitations, and Firebase linking failed because X
already held the phone credential.

A read-only audit of the configured Neon/Firebase environment found:

| Check | Actual result |
|---|---:|
| Pending group invitations | 6 |
| Pending invitations whose phone matches a registered Neon account | 2 |
| Those recipients with a different Firebase UID holding the verified phone | 2 |
| Those recipients with a phone on their canonical Neon/Firebase UID | 0 |
| Noncanonical phone strings among pending recipients | 0 |
| Membership rows with a missing user/group reference | 0 |

The audit printed aggregates only. Existing live accounts, invitations and
memberships were not modified. No database reset, migration or deletion was
performed.

## Complete flow

1. Flutter Create Group/Add Member calls `GroupsProvider.inviteMember` and the
   group repository/datasource, which POST normalized phone input to
   `/api/groups/:id/invitations`.
2. The API validates Firebase authentication and group membership, normalizes
   the phone with the shared Egyptian-default E.164 helper, and resolves the
   verified Firebase phone owner. A matching Neon UID is added immediately as
   `group_members(group_id, user_id, role=member)`; otherwise the existing
   pending invitation contract is used, with normalized `invited_phone` and
   `user_id=null`.
3. Signup now sends `phoneVerificationToken`, verifies recent Firebase OTP
   proof server-side, matches its phone, and creates the Neon account under
   the same verified UID. Valid pending invitations are claimed before the
   signup response. Password login also claims invitations when the canonical
   Firebase identity owns the login phone. Claiming inserts the membership and
   marks the invitation accepted with the same User ID in a transaction.
4. `GET /api/groups/cuser` already correctly selects groups through
   `group_members.some(user_id=Bearer UID)`, regardless of who created them.
   This query and its response contract did not require a behavior change.
5. Flutter session restore now awaits the existing sync request before the
   shell fetches groups. Profile/phone refresh uses sync so verified-phone
   invitations are claimed. Successful Settings verification refreshes groups
   once. Existing requests were reused; no polling was added.
6. Group cache/dedupe keys now include caller UID and a logout generation.
   Logout clears visible groups. List/detail provider loads ignore responses
   from an older epoch, so a previous account cannot restore its old list.

## Existing affected accounts

After releasing the backend and client changes, affected users log in with
their existing phone/password and verify the number once in Settings.
For the legacy credential collision, Flutter obtains fresh OTP proof through
a secondary Firebase Auth instance while keeping the canonical session.
Authenticated sync verifies that proof, refuses to merge another registered
identity, and moves only an unused OTP identity's phone credential onto the
canonical UID. No PostgreSQL IDs or relationships change. If binding fails,
the source phone credential is restored. Sync then claims valid invitations,
and Flutter refreshes the group list.

The fix intentionally does not silently infer ownership from an unverified
profile phone. Expired/declined/revoked invitations remain ineligible under the
existing policy. Normal new registrations need no extra repair step.

## Compatibility

- Authentication architecture remains Neon passwords plus Firebase identity,
  custom-token sessions and backend-verified Bearer tokens.
- Signup additionally requires `phoneVerificationToken`. The client and API
  must be released together; old clients cannot provide server-verifiable OTP
  proof. Session and group API response envelopes remain unchanged.
- `/api/users/sync` accepts an optional proof for legacy repair. Plain profile
  phones still cannot claim memberships.
- There are no new dependencies, endpoints, schema changes or polling loops.

## Actual validation

| Check | Result |
|---|---|
| `node node_modules/tsx/dist/cli.mjs --test tests/group-account-linking.test.ts tests/group-invitations.test.ts tests/create-group.test.ts` | 50 passed, 0 failed |
| `RUN_GROUP_DATABASE_TESTS=1` with `tests/group-membership.database.test.ts` | 1 passed, 0 failed against configured Neon |
| `flutter test --no-pub test/group_account_linking_test.dart test/group_bio_test.dart` | 9 passed, 0 failed |
| `node node_modules/typescript/bin/tsc --noEmit` | Passed |
| Dart MCP analysis of all changed Flutter sources and new regression test | No errors |
| `git diff --check` | Passed |

The HTTP/database test uses real Express controllers, use cases, Prisma
membership queries and PostgreSQL relationships, with injected Firebase proof
and session providers. It checks immediate membership, another account's
isolation, invitation before registration, verified signup claim, login,
duplicate membership prevention, and exact User ID/Group ID associations.
All fixture writes were inside one rolled-back transaction; a subsequent query
verified no fixture accounts persisted. It does not send real SMS or mutate
live Firebase identities.

The existing `sync-user.test.ts` suite was also run: 15 passed and 4 failed.
The same four failures were present before this fix and assert obsolete email
provisioning behavior from before the phone/password transition. They were
left unchanged. An initial broader baseline run also hit an unrelated
`resource-authz.test.ts` outing-update failure because it reached Neon from
the restricted sandbox; this is not counted among the passing focused checks.

No emulator or physical device was launched. Hot reload was attempted through
the connected Dart Tooling Daemon, which reported no active application.
Real SMS/secondary-Firebase-app interaction and visual phone/wide,
English/Arabic and light/dark states were not exercised; layout/copy were not
redesigned.

## Modified files for this task

Existing unrelated working-tree changes were retained. Only this task's
contributions are described below.

| Area | Files | Change |
|---|---|---|
| Backend phone proof | `backend/src/services/phone/phone-identity.ts` | Verify current/recent phone proof and bind an unused OTP phone credential |
| Backend auth | `backend/src/usecases/auth/signup.usecase.ts`, `login.usecase.ts`; `backend/src/controllers/auth/auth.controller.ts`; `backend/src/types/auth/auth.types.ts`; `backend/src/validators/auth/auth.validator.ts` | Retain verified signup UID, require proof and claim invitations on signup/login |
| Backend user sync | `backend/src/usecases/users/sync-user.usecase.ts`; `backend/src/controllers/users/user.controller.ts`; `backend/src/types/users/user.types.ts`; `backend/src/validators/users/user.validator.ts` | Pass and verify optional legacy repair proof while preserving canonical UID |
| Backend datasource test support | `backend/src/datasources/groups/group.datasource.ts`, `group-invitation.datasource.ts` | Optional transaction client for group queries and export the existing Prisma claim store for rollback testing |
| OpenAPI | `backend/src/config/swagger.ts`; `backend/src/routes/auth/index.ts`; `backend/src/routes/users/user.sync.routes.ts` | Describe proof fields and corrected identity behavior |
| Flutter auth | `flutter/lib/features/auth/data/datasources/firebase_auth_service.dart`, `auth_remote_datasource.dart`; `flutter/lib/features/auth/data/repositories/auth_repository_impl.dart`; `flutter/lib/features/auth/presentation/providers/auth_provider.dart` | Forward proof, preserve canonical session for legacy verification, sync claims and await restore |
| Flutter groups | `flutter/lib/features/groups/data/repositories/groups_repository_impl.dart`; `flutter/lib/features/groups/presentation/providers/groups_provider.dart` | Account-scoped caches, clear visible state and ignore stale session responses |
| Settings | `flutter/lib/features/setting/presentation/widgets/profile_phone_sheet.dart` | Refresh groups after successful phone sync |
| Tests/audit | `backend/tests/group-account-linking.test.ts`, `group-membership.database.test.ts`; `flutter/test/group_account_linking_test.dart`; `backend/scripts/group-membership-audit.ts` | Focused regressions, transactional HTTP/PostgreSQL test and repeatable read-only aggregate audit |

## Documentation Updates

- `docs/API_CONTRACTS.md`: required signup proof, optional sync proof, group
  membership/claim response semantics and coordinated release requirement.
- `docs/AUTHENTICATION_AND_AUTHORIZATION.md`: backend verification, retained
  UID, claim points and legacy repair boundaries.
- `docs/ARCHITECTURE_DECISIONS.md`: clarified ADR-005 identity binding while
  retaining the existing Firebase/Neon architecture.
- `docs/PRODUCT_SCENARIOS.md`: removed the obsolete implementation limitation
  that signup OTP was checked only on the client; existing product behavior is
  unchanged.
- `docs/BUSINESS_LOGIC.md`, `docs/USER_SCENARIOS.md`, `docs/SYSTEM_DESIGN.md`:
  distinguish group verified-phone claims from outing acceptance; document
  registration/login/restore/Settings membership behavior.
- `docs/SYSTEM_ARCHITECTURE.md`: updated authentication sequence diagram for
  OTP UID retention and claims before group loading.
- `docs/FLUTTER_ARCHITECTURE.md`: sync ordering, legacy proof handling and
  account-scoped group cache/state lifecycle.
- `docs/BACKEND_ARCHITECTURE.md`: phone proof service and transaction testing.
- `docs/DATABASE_ARCHITECTURE.md`: verified User ID/Group ID association and
  unchanged schema.
- `docs/PROJECT_STRUCTURE.md`: phone identity service, audit and test locations.
- This report records evidence, modified files and actual validation limits.

The authentication sequence diagram was updated; the database relationship
diagram remains accurate because no relationships changed. Remaining known
inconsistencies are the four historical email assertions and historical
social/email descriptions outside this task's phone/group flow.
