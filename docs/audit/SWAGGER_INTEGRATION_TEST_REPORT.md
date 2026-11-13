# Swagger integration test report

The original run below is historical. See [Database migration report](database/DATABASE_MIGRATION_REPORT.md#swagger-browser-tests) for the completed post-refactor Swagger run.

**Run date** November 10, 2026, Africa/Cairo  
**Overall result** BLOCKED for the requested fresh-registration and invitation sequence.  
**HTTP coverage** 85 of 85 final OpenAPI operations received requests. 15 passed the cases identified below, 5 failed the requested cross-user read isolation check, and 65 had a required scenario blocked. Authentication rejection coverage is separate from business-case coverage.

## Environment and method

- Served the checked-out Express app at `http://127.0.0.1:3000` after finding no listener there. The loopback test listener used the actual routes, validators, Firebase Admin token verifier, Prisma client and configured remote Neon connection. The standalone HTTP listener omitted scheduled jobs and the notification worker because the configured database already contained data. Each test listener was closed when its run finished.
- `GET /api-docs/` and `GET /api-docs/swagger-ui-init.js` both returned HTTP 200. The live initializer supplied the OpenAPI 3.0.0 document and its `http/bearer` JWT scheme. Requests used one `Bearer` prefix. Browser Authorize and Execute interactions were **NOT TESTED** under the no-UI-automation constraint.
- The backend configuration identifies the environment as `development`, the Firebase project as `yalla-5roga`, and the database as Neon PostgreSQL 18.6, database `neondb`, schema `public`. The configured database failed the empty-reset precondition. This run does not establish the identity of any other Neon branch.
- All tests in the endpoint matrix used live HTTP. Neon checks ran through Prisma against the configured database. Response checks covered observed status codes, JSON success/error envelopes, and documented required fields and types where schemas were present. Positive read checks used existing development rows or the pre-existing Firebase test identity.
- No Flutter launch or tests, mobile emulator, physical device, UI automation, Socket.IO delivery test, physical FCM delivery, or WhatsApp sending was performed. No token, verification code, database connection string, account UID, or credential appears in this report.

## Baseline and migration evidence

| Check | Status | Evidence |
| --- | --- | --- |
| Neon connection | PASS | Read-only metadata and exact table-count queries succeeded. The connection used the configured Neon endpoint over TLS. |
| Previous test data removed and application tables empty | FAIL | The configured schema was populated before any authentication attempt. There were 9 users, 12 groups, 12 outings and 6 group invitations. Existing rows were treated as pre-existing application data. |
| Prisma migration history | PASS | Five completed rows, zero rolled back, zero repository migrations missing and zero migration checksum mismatches. |
| HTTP database health | PASS | `GET /health` returned 200 with `{"success":true,"message":"OK","database":"connected"}`. |
| Live Swagger/OpenAPI | PASS | HTTP 200 for the HTML and generated initializer. Initial contract had 84 operations. Corrected contract has 85. |

Applied migrations checked against the repository:

- `20261107000000_init_product_scenario`
- `20261107010000_outing_member_invite_status`
- `20261109000000_harden_constraints_and_indexes`
- `20261109010000_phone_password_auth`
- `20261109090000_outing_arrivals`

| Neon table | Before HTTP run | After final HTTP run |
| --- | ---: | ---: |
| `_prisma_migrations` | 5 | 5 |
| `chat_messages` | 18 | 18 |
| `chat_reads` | 7 | 7 |
| `group_invitations` | 6 | 6 |
| `group_members` | 15 | 15 |
| `groups` | 12 | 12 |
| `notification_delivery_logs` | 382 | 382 |
| `notification_events` | 382 | 382 |
| `notifications` | 21 | 21 |
| `outing_arrivals` | 0 | 0 |
| `outing_attendance` | 12 | 12 |
| `outing_drafts` | 0 | 0 |
| `outing_guests` | 0 | 0 |
| `outing_vote_options` | 5 | 5 |
| `outing_votes` | 4 | 4 |
| `outings` | 12 | 12 |
| `place_hours` | 1 | 1 |
| `place_images` | 1 | 1 |
| `place_prices` | 1 | 1 |
| `places` | 1 | 1 |
| `saved_outings` | 7 | 7 |
| `saved_places` | 0 | 0 |
| `user_fcm_tokens` | 1 | 1 |
| `users` | 9 | 9 |

## Firebase identities and business scenarios

| Scenario | Status | Evidence |
| --- | --- | --- |
| Firebase development configuration read | PASS | Identity Platform config returned 200. Phone Authentication is enabled. |
| User A phone test authentication | BLOCKED | The project has no configured test-number definition for A. Admin lookup returned `auth/user-not-found`. No verification request was sent to A. |
| A profile creation, Firebase UID mapping and current-user 200 | BLOCKED | No valid A ID token. Neon had zero matching phone profiles and zero matching group invitations. |
| A Swagger authorization | BLOCKED | The live Bearer scheme was verified. No valid A ID token was available for an authorized request. |
| A creates and owns group | BLOCKED | Requires A's synchronized profile. Group creation, owner membership and owner list retrieval were not exercised. |
| A creates and manages group outing | BLOCKED | Requires A's profile and a temporary group. Group association and outing persistence were not exercised. |
| A invites unregistered B, normalization and duplicate prevention | BLOCKED | B already had a Firebase phone identity. Neon contained one profile with B's normalized phone under a different UID. No B-targeted group invitation existed at baseline. |
| B phone OTP and verified Firebase ID token | PASS | Test-number definition and supplied code matched. Firebase verification-session creation and sign-in both returned 200. Firebase reported an existing identity. Firebase Admin verified the token, matched its audience, UID and phone, and reported the `phone` sign-in provider. |
| B profile registration and current-user 200 | BLOCKED | The valid B token passed backend authentication. `GET /api/users/cuser` returned 404 with `{"success":false,"message":"User not found"}`. Neon had zero profiles for the verified B UID and one for the same phone under another UID. Sync was withheld at the failed reset precondition. |
| B claims pre-registration invitation and gains access | BLOCKED | No temporary invitation or test membership was created. Source uses the verified phone claim to locate pending invites, and claims those invites and inserts memberships together in a Prisma transaction. The fresh-profile and invitation sequence requires live execution. |
| A invites registered B and B accesses the second group | BLOCKED | Requires both synchronized profiles and a temporary group. |
| Duplicate invite or membership, repeated sync, Egyptian normalization and invalid phone | BLOCKED | Live write scenarios require the clean test identities and database. Focused backend tests exercised phone normalization and invitation idempotency separately from live coverage. |
| Manual group acceptance | NOT TESTED | The running API has no manual group acceptance operation. An authenticated probe to the candidate path returned 404. Verified-phone group claims use `POST /api/users/sync`. Outing guest acceptance is a separate documented operation. |
| Group invitation decline | BLOCKED | Missing and invalid tokens returned 401. A pending invitation addressed to B would be required to exercise decline. |
| My group invitations | NOT TESTED | No dedicated operation in the live contract. An authenticated probe to the candidate path returned 404. |
| Group outings endpoint | FAIL | The dedicated group subpath returned 404. The documented equivalent `GET /api/outings?groupId=...` returned three existing outings to B without a membership in that group. Authorized member success remains blocked. |
| Nonexistent group and outing | PASS | A valid B bearer returned 404 for each unknown UUID and 400 for each malformed ID. |
| Missing and invalid ID token | PASS | All 75 protected operations returned 401 in both cases after the Swagger fixes. |
| Expired ID token | NOT TESTED | No genuinely expired Firebase-issued test ID token was available. The malformed-token checks do not cover expiry. |
| Owner-only group modification | PASS | B submitted the existing name to an existing group with zero B memberships. HTTP 403 returned `Only the group owner can perform this action`. Neon name and update timestamp were unchanged. |
| Owner-only outing modifications | BLOCKED | Unauthenticated rejection was verified. Temporary owner/member fixtures were unavailable. |
| Cross-user isolation | FAIL | B received 200 for group details, member list, another user's group list, a nonmember group's outings, and an unrelated outing detail. Chat and arrival reads for that unrelated outing returned 403. |
| Database rollback | BLOCKED | No live transaction fault was induced. The focused invitation tests covered rollback with their test store. |
| Notification records, FCM registration, safe dispatch | BLOCKED | B's inbox returned 200 with zero rows. Neon contained 21 pre-existing notifications and 382 existing outbox events. No test notifications were queued and the worker was stopped. |
| Image upload authorization | NOT TESTED | No upload or presign operation appears in live OpenAPI. Place image metadata operations are in the matrix. |

The Firebase OTP calls used the documented [verification-session endpoint](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v1/accounts/sendVerificationCode) and [phone sign-in endpoint](https://docs.cloud.google.com/identity-platform/docs/reference/rest/v1/accounts/signInWithPhoneNumber). User B's bearer was held in memory and used for independent permission probes. Those probes did not substitute for the A-to-B registration sequence.

## Endpoint results

**PASS** covers only the executed cases shown in the row. For self-scoped reads using B, a 200 with zero rows verifies the baseline response for the unsynced UID. Positive coverage with owned rows or active memberships remains blocked. **FAIL** indicates an observed response that did not meet the requested isolation criterion. **BLOCKED** means that a required case could not run safely even if the row records successful negative checks. **NOT TESTED** identifies an unexecuted scenario outside the retained-operation matrix.

For protected operations, the missing-token response was HTTP 401 with `success: false` and `Missing Bearer token`. The invalid-token response was HTTP 401 with `success: false` and `Invalid or expired Firebase token`. Requests with those headers can reach router-level authentication before dispatch, so these two responses alone do not prove the protected handler or its persistence behavior.

| Area | Operation | Status | Observed HTTP and Neon evidence |
| --- | --- | --- | --- |
| System | `GET /` | **PASS** | Valid 200 |
| System | `GET /health` | **PASS** | Valid 200. Prisma query connected |
| Users | `POST /api/users/sync` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Users | `GET /api/users/cuser` | **BLOCKED** | Missing/invalid token 401/401. Valid B bearer 404, UID profile absent. Required registered-user 200 blocked |
| Users | `PATCH /api/users/cuser` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Users | `DELETE /api/users/cuser` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Users | `GET /api/users` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Users | `GET /api/users/{id}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Users | `DELETE /api/users/{id}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Users | `POST /api/users/cuser/fcm-token` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Users | `DELETE /api/users/cuser/fcm-token` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Users | `DELETE /api/users/cuser/fcm-token/{token}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `GET /api/places/saved` | **PASS** | Missing/invalid token 401/401. Valid B bearer 200, 0 rows |
| Places | `POST /api/places/{id}/save` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `DELETE /api/places/{id}/save` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `POST /api/places/geocoding` | **PASS** | Missing/invalid token 401/401. Configured-disabled geocoder 200. Invalid geocoding payload 400. Provider disabled, `available=false`, 0 results |
| Places | `GET /api/places/nearby` | **PASS** | Valid 200. Invalid 400. Returned 1 known Neon place |
| Places | `GET /api/places` | **PASS** | Valid 200. Invalid 400. Returned 1 known Neon place |
| Places | `POST /api/places` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `GET /api/places/{id}` | **PASS** | Valid 200. Invalid 400. Place ID matched Neon |
| Places | `PATCH /api/places/{id}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `DELETE /api/places/{id}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `GET /api/places/{id}/hours` | **PASS** | Valid 200. Invalid 400. 1 rows, Neon count 1 |
| Places | `PUT /api/places/{id}/hours` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `DELETE /api/places/{id}/hours/{hourId}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `GET /api/places/{id}/images` | **PASS** | Valid 200. Invalid 400. 1 rows, Neon count 1 |
| Places | `POST /api/places/{id}/images` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `DELETE /api/places/{id}/images/{imageId}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `GET /api/places/{id}/prices` | **PASS** | Valid 200. Invalid 400. 1 rows, Neon count 1 |
| Places | `POST /api/places/{id}/prices` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Places | `DELETE /api/places/{id}/prices/{priceId}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `GET /api/outings/{id}/vote-options` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `POST /api/outings/{id}/vote-options` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `PUT /api/outings/{id}/vote-options` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `DELETE /api/outings/{id}/vote-options/{optionId}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `GET /api/outings/{id}/votes` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `POST /api/outings/{id}/votes` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `DELETE /api/outings/{id}/votes` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `DELETE /api/outings/{id}/votes/{optionId}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `GET /api/outings/{id}/voting-state` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Voting | `POST /api/outings/{id}/tie-break` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Saved Outings | `GET /api/outings/saved` | **PASS** | Missing/invalid token 401/401. Valid B bearer 200, 0 rows |
| Saved Outings | `POST /api/outings/{id}/save` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Saved Outings | `DELETE /api/outings/{id}/save` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Participants | `GET /api/outings/{id}/attendance` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Participants | `PUT /api/outings/{id}/attendance` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Participants | `GET /api/outings/{id}/guests` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Participants | `POST /api/outings/{id}/guests` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Participants | `DELETE /api/outings/{id}/guests/{userId}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Participants | `POST /api/outings/{id}/invitations/accept` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Participants | `POST /api/outings/{id}/invitations/decline` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Participants | `GET /api/outings/{id}/arrivals` | **BLOCKED** | Missing/invalid token 401/401. Arrival list nonexistent outing 404. Outing arrival list as unrelated Firebase UID 403 |
| Outing Participants | `PUT /api/outings/{id}/arrivals/self` | **BLOCKED** | Missing/invalid token 401/401. Arrival write with invalid payload 400. Arrival write with nonexistent outing 404 |
| Outing Drafts | `GET /api/outings/drafts` | **PASS** | Missing/invalid token 401/401. Valid B bearer 200, 0 rows |
| Outing Drafts | `POST /api/outings/drafts` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Drafts | `PATCH /api/outings/drafts/{id}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Drafts | `DELETE /api/outings/drafts/{id}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outings | `GET /api/outings/cuser` | **PASS** | Missing/invalid token 401/401. Valid B bearer 200, 0 rows |
| Outings | `GET /api/outings` | **FAIL** | Missing/invalid token 401/401. Group outing list from outside its membership 200, 3 rows |
| Outings | `POST /api/outings` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outings | `POST /api/outings/{id}/cancel` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outings | `GET /api/outings/{id}` | **FAIL** | Missing/invalid token 401/401. Outing detail as unrelated Firebase UID 200 |
| Outings | `PATCH /api/outings/{id}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outings | `DELETE /api/outings/{id}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Chat | `GET /api/outings/{outingId}/messages` | **BLOCKED** | Missing/invalid token 401/401. Outing chat as unrelated Firebase UID 403 |
| Outing Chat | `POST /api/outings/{outingId}/messages` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Outing Chat | `PATCH /api/outings/{outingId}/read` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Notifications | `GET /api/notifications` | **PASS** | Missing/invalid token 401/401. Valid B bearer 200, 0 rows |
| Notifications | `PATCH /api/notifications/read` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Notifications | `PATCH /api/notifications/{id}/read` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Group Members | `GET /api/groups/{id}/members` | **FAIL** | Missing/invalid token 401/401. Group member list from outside its membership 200, 1 rows |
| Group Members | `POST /api/groups/{id}/members` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Group Members | `DELETE /api/groups/{id}/members/{userId}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Group Invitations | `POST /api/groups/{id}/invitations` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Group Invitations | `POST /api/groups/invitations/{invitationId}/decline` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Groups | `GET /api/groups/cuser` | **PASS** | Missing/invalid token 401/401. Valid B bearer 200, 0 rows |
| Groups | `GET /api/groups` | **FAIL** | Missing/invalid token 401/401. Select another user in group list 200, 4 rows |
| Groups | `POST /api/groups` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Groups | `GET /api/groups/{id}` | **FAIL** | Missing/invalid token 401/401. Group detail from outside its membership 200 |
| Groups | `PATCH /api/groups/{id}` | **BLOCKED** | Missing/invalid token 401/401. Non-owner group update 403. Name and update timestamp unchanged in Neon |
| Groups | `DELETE /api/groups/{id}` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Authentication | `POST /api/auth/login` | **BLOCKED** | Invalid 400. Password-flow success excluded from OTP scenario |
| Authentication | `POST /api/auth/signup` | **BLOCKED** | Invalid 400. Password-flow success excluded from OTP scenario |
| Authentication | `POST /api/auth/change-password` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |
| Authentication | `POST /api/auth/verify-password` | **BLOCKED** | Missing/invalid token 401/401. Authenticated business case blocked |

## Failures, fixes and remaining blockers

1. **Missing geocoding operation in Swagger.** The first live contract omitted `POST /api/places/geocoding` although the Express route rejected unauthenticated traffic with 401. The route had no OpenAPI annotation. Added its request alternatives, response schema and documented errors. The final live contract included it. Retest with a genuine B bearer returned 200 with `available: false` and an empty results list, malformed input returned 400, and both unauthenticated cases returned 401. No external geocoder was configured.
2. **Arrival response documentation drift.** Both arrival operations returned 401 through the existing auth middleware without declaring that status. Aligned the OpenAPI error responses and accuracy bounds with the controller, request validator and Prisma-backed use case. The final sweep confirmed documented 401 on both endpoints, 404 for a nonexistent outing, 400 for invalid check-in input, and 403 for the unrelated caller on arrival reads. Participant success and persistence remain blocked.
3. **B's phone/UID conflict.** The current-user controller retrieves the profile by the verified Firebase UID. The two independent Neon lookups explain the 404. The sync use case checks phone ownership before profile creation and Prisma makes `users.phone` unique. This is a data mismatch in the configured environment. No sync conflict response was asserted because sync was not called.
4. **Cross-user read isolation.** Group detail and member controllers pass the requested group ID to repository reads without checking caller membership. The group list accepts a caller-supplied `userId`. Outing detail fetches by ID, and the group-filtered list queries by `groupId` without a caller-membership check. The chat and arrival paths do enforce participant checks. These reads remain open failures against the requested isolation check. The current API explicitly documents cross-user filtering, and the approved outing invite flow opens outing details before acceptance. Changing those read rules requires a defined visibility policy for group data and pending invitees, plus a clean fixture to retest the permitted paths.
5. **Reset environment required.** To run the requested mutation and cleanup sequence, identify the reset development Neon target and Firebase project containing both configured phone test numbers. User B must begin without an application phone profile and, for the no-Firebase-account invitation assertion, without a pre-existing Firebase identity.

Validation after the documentation fixes included the live HTTP sweep, TypeScript compilation without emit, and 36 focused backend tests covering arrivals, geocoding, phone normalization and group invitations. The focused tests are separate from the live endpoint results.

## Cleanup verification

- **PASS for run-created data.** The before and after row counts matched for every table. No temporary PostgreSQL data was created, and Firebase reported `isNewUser: false` for B. A had no Firebase account at lookup and was not signed in. No account or test-number definitions were removed. B's successful authentication used the existing test identity.
- **BLOCKED for an all-empty schema.** Pre-existing rows remained, including 9 users, 12 groups and 12 outings. The requested all-empty final state requires the reset development database. The runs made no schema, migration, or project-configuration changes.

## Documentation updates

- Added this report and linked it from `docs/API_CONTRACTS.md`. The contract now records the arrival response codes and input accuracy bounds.
- Updated route annotations for geocoding and arrival error handling. No architecture or workflow diagrams changed.
- The group and outing read visibility issue and the configured-environment identity conflict remain open as described above.
