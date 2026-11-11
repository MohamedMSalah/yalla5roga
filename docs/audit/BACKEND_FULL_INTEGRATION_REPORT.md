# Backend full integration audit

Run on 10 November 2026 (Africa/Cairo)

## Scope and execution

The audit served the checked-out Express application on an ephemeral loopback port and used its production routers, validators, controllers, Firebase Admin verifier, Prisma client and Socket.IO gateway. It connected to the configured Neon PostgreSQL development database and the actual Firebase Authentication project. The listener omitted background jobs and the notification worker so the run could not process unrelated development data. Swagger UI’s initializer loaded over HTTP. The Express 5 route inventory was derived independently from registered handlers and source mount paths and compared with generated OpenAPI. Swagger assets, automatic HTTP HEAD/OPTIONS, the removed group response routes and Socket.IO events are outside the REST operation count.

The runner read Firebase’s configured fictional-number definitions without printing credentials. It checked that the selected numbers had no Firebase user, Neon profile or pre-existing group association. It completed Firebase Phone OTP for three isolated identities, verified the resulting Firebase-issued ID tokens, and verified that signup, sync, and password login retained the expected UID. The tests created isolated groups and business records and checked cleanup by fixture identifiers and test phone numbers. The report contains no tokens, verification codes, phone numbers, UIDs, or database connection strings. [Firebase test phone numbers](https://firebase.google.com/docs/auth/web/phone-auth#test-with-fictional-phone-numbers), [Firebase Admin ID token verification](https://firebase.google.com/docs/auth/admin/verify-id-tokens).

Reproduce from `backend/` with `pnpm exec tsx scripts/validate-api-docs.ts` and `pnpm exec tsx scripts/backend-full-integration.ts`. The latter requires development Firebase and Neon settings, access to read Firebase test-number configuration, and three unused configured test numbers. Run only one audit instance against those numbers at a time. Unit and repository regression tests ran separately with `RUN_GROUP_DATABASE_TESTS=1`.

## Results

**PASS for REST and critical membership flows.** The three provider checks and live token-expiry check listed below remain blocked.

| Measure | Final result |
| --- | ---: |
| Express REST operations discovered | 85 |
| OpenAPI REST operations matched | 85 |
| Distinct operations executed over HTTP | 85 |
| Operations with a verified successful response | 85 |
| Operations with failing executed cases | 0 |
| Protected operations rejecting both missing and invalid Bearers | 75 |
| Authentication rejection requests | 150 |
| Requests across the counted REST operations | 325 |
| Observed OpenAPI status or response-shape mismatches after fixes | 0 |
| Backend regression tests | 126 passed, 0 failed, 0 skipped |
| Prisma migrations applied during this audit | 0 |

The live suite checked the JSON success and error envelopes, documented status codes, and the documented response types, enums, required fields, and schema branches. It also asserted business results with API reads and independent Neon queries.

## Critical scenarios

| Critical scenario | Status | Live evidence |
| --- | --- | --- |
| Firebase Phone OTP, signup, login and sync retain one UID per account | PASS | Verified Firebase phone ID tokens and application ID tokens. Neon had one profile for the verified UID and phone, including concurrent OTP sync and signup. |
| Registered user joins immediately | PASS | Two concurrent adds returned 201 and 409. Exactly one active membership existed and the group appeared immediately for the member. |
| Unregistered phone association | PASS | Alternate formatting resolved to one normalized E.164 row per group. Each row had a null user reference. Firebase and Neon had no account for the test number before OTP. |
| First registration links all groups | PASS | Two groups added before registration and a third added concurrently with registration all appeared with the member role. A fresh password login returned the same groups. |
| OTP-only profile sync links pending membership | PASS | A verified phone token provisioned a profile and linked a pending association under the same UID. |
| Group and outing permissions | PASS | Members could read their group and outing. An outsider received 403 on group details, member lists, outing reads and subresources, group-filtered reads, and unauthorized creation or reassignment. A member could not edit the group. |
| Pending owner revocation and active member removal | PASS | Unauthorized revocation returned 403. Owner revocation returned 200 and a repeat returned 404. A subsequent signup did not restore the revoked association. Active removal survived sync. |
| Group acceptance or rejection | PASS | Candidate group accept and decline routes returned 404. No recipient action was used to activate group access. |
| Invalid phone, body, proof and cross-identity claims | PASS | Invalid group phones and malformed or missing request fields returned 400. Proof for another phone returned 401. A spoofed phone on sync failed to link any groups to the caller. |
| Neon relationship integrity and rollback | PASS | Confirmed active and pending rows, FK joins and uniqueness. An outing with an invalid place FK returned 409 and left no outing under the request key. Deleting a group with outings or an account referenced by an outing returned 409. |
| Outing lifecycle, special events, attendance and voting | PASS | Verified creation, draft isolation, cancellation, owner Going, attendance, arrival persistence, vote retries, tie-break winner, and exactly one successful response to concurrent outing guest accept/decline. Reissuing an invite preserved an accepted guest. |
| Chat and realtime | PASS | Retried message writes persisted one row. Valid Socket.IO bearer joined and received a persisted message. An outsider could not join, and an invalid handshake was rejected. |
| Notifications and FCM token APIs | PASS | Verified inbox, read mutations, push outbox persistence and FCM token registration and removal scoped to the signed-in user. |
| Saved outings, places and image metadata | PASS | Verified bookmark persistence and retries, discovery coordinates, place metadata relationships and rejection of cross-place delete IDs. |
| Fixture cleanup | PASS | Deleted only audit-created Neon data and Firebase users. Confirmed the selected phone numbers had no remaining test profiles or associations, and the Firebase user lookups returned user-not-found. |

## Bugs found and fixed

| Finding | Fix |
| --- | --- |
| A group recipient could call the decline route, and a pending phone row stopped qualifying after its legacy expiry date. | Replaced recipient decline with owner-scoped revocation. Pending E.164 associations remain eligible until linked or revoked. Existing historical statuses remain historical. |
| A pending add could miss signup or sync when Firebase lookup and the Neon insert straddled the claim transaction. Registered removal could also leave a pending row behind. | Recheck the verified account after persisting a pending row. Claim locks the matching Neon profile and pending rows and writes active memberships and link state in one transaction. Active removal revokes any matching pending row before deleting the member. |
| Firebase OTP tokens were rejected as REST/Socket.IO session tokens. A passwordless profile created through sync could block later signup. | Accept Firebase phone or custom ID tokens. Sync compares the phone claim with the current Firebase identity. Signup conditionally enrolls the first password for the same verified UID and phone. |
| Authenticated callers could read unrelated groups, member profiles, group outings and outing subresources or create an outing against a group they did not belong to. | Scope group lists to the caller. Require membership for group detail, member lists and group-filtered outing requests. Scope outing detail and subresources to the creator, relevant group members and pending or accepted outing guests. Require group membership to create or move an outing there. |
| Duplicate direct adds returned 500. Bookmark retries hit the composite unique key. Malformed JSON and missing or conflicting resources did not always return a consistent error envelope. | Map Prisma unique and FK conflicts to 409 and missing rows to 404. Make place and outing bookmark writes idempotent. Return JSON 400 for malformed bodies and JSON 404 for unknown routes. |
| Reissuing an outing guest invite could reset an accepted guest, and concurrent guest responses could overwrite each other. | Preserve pending and accepted rows on repeated invites. Atomically transition only pending guest rows so the competing response returns 409. |
| Nested place metadata deletes and some voting deletes ignored part of the resource path. | Match the supplied place/outing ID with the child ID, and scope option-specific vote removal to the actual selected option. |
| Group deletion with linked outings would conflict with the database’s required group/type relationship. | Lock the group during deletion and return 409 while it still has outings, preserving the related data. |
| Pending group activation performed repeated per-row reads/writes. Notification fan-out issued per-recipient inserts and could leave a committed inbox row without its outbox event. | Batch group membership insertion and association linking. Batch notification inbox and outbox inserts in one transaction with separate idempotency keys. Use a filtered membership lookup for single-user voting and attendance authorization. |
| The Swagger checker relied on the Express 4 layer shape, and affected operations omitted authorization or conflict responses. | Compare Express 5 runtime routes with Swagger paths/methods, validate operation IDs and schema references, and document updated status codes and access rules. |

## Neon and performance

- PostgreSQL 18.6 answered the live health query. An independent Neon client connected with certificate verification and confirmed TLS. The seven completed migration records matched local migrations and checksums. This audit reused the deployed schema and applied no migrations.
- The live catalog confirmed unique user phones, the composite group-membership primary key, both membership foreign keys, the phone-association foreign keys, E.164 checks and the partial unique pending-phone index. A read-only join found zero orphan group memberships.
- A representative pending-phone query used `uq_group_invitations_pending_phone` and executed in 0.056 ms. The sample membership lookup chose a sequential scan at development cardinality and executed in 0.036 ms. The catalog has `idx_group_members_user` for that filter. The catalog also showed indexes for group outings, chat ordering and idempotency, votes and nearby-place coordinates. These are single-run planning samples from the development database.
- The Express app uses one shared Prisma client per process. The runner closed Socket.IO, its HTTP listener and Prisma connections. The tests exercised concurrent signup/sync, phone adds, votes, chat retries and bookmark writes. Load testing at production cardinality was outside this run.
- Across 325 measured REST requests, loopback client-observed p50 was 398 ms and p95 was 1985 ms. The sample mixes authentication rejection, Firebase exchanges and Neon-backed business calls. The timing describes the test run rather than a production latency target.

## Remaining blockers and limits

| Area | Status | Evidence |
| --- | --- | --- |
| Physical FCM delivery | BLOCKED | Device-token storage, ownership, the in-app inbox and push outbox rows were verified. A controlled live device registration token was unavailable and the development worker was intentionally left off. |
| Automatic WhatsApp delivery | BLOCKED | Manual link generation and duplicate-phone collapse were verified. The configured environment has no active automatic WhatsApp sender. |
| External geocoding | BLOCKED | The live API returned its documented disabled-provider response. No upstream provider is enabled in development. |
| Expired Firebase-issued ID token | BLOCKED | Missing and malformed Bearers were verified live. The regression suite covers the expiry error path with an injected verifier. A genuinely expired Firebase-issued test token was unavailable in the live run. |
| Binary image upload, presign or object deletion | Outside implemented REST scope | Source and Swagger expose place image metadata and URL fields. The live suite verified metadata creation, reads, scoped deletion and its foreign key. |

## Documentation updates

- `API_CONTRACTS.md` and Swagger annotations document the membership, authorization, retry and conflict behavior and the owner revocation endpoint.
- `PRODUCT_SCENARIOS.md`, `BUSINESS_LOGIC.md`, `USER_SCENARIOS.md` and `SYSTEM_DESIGN.md` distinguish automatic group membership from the separate outing guest workflow.
- `AUTHENTICATION_AND_AUTHORIZATION.md`, `ARCHITECTURE_DECISIONS.md`, `BACKEND_ARCHITECTURE.md` and `SYSTEM_ARCHITECTURE.md` document OTP session support, stable UID binding and the updated authentication sequence diagram.
- `DATABASE_ARCHITECTURE.md` documents the existing membership tables and batched claim transaction. The database relationship diagram still reflects the schema. `NOTIFICATIONS.md` documents atomic fan-out and `PROJECT_STRUCTURE.md` locates the runner.
- Historical audit reports reflect earlier runs. The endpoint inventory and observed statuses below apply to this run.

## Endpoint matrix

The status column evaluates the cases actually exercised. Protected operations also received missing-token and invalid-token requests. A 401 result verifies the authentication boundary. Successful business requests and negative cases are listed separately. External-provider availability is tracked above.

| Operation | Status | Verified HTTP statuses |
| --- | --- | --- |
| `GET /` | PASS | 200 |
| `POST /api/auth/change-password` | PASS | 200; 401 for missing and invalid Bearer |
| `POST /api/auth/login` | PASS | 200, 400, 401 |
| `POST /api/auth/signup` | PASS | 201, 400, 401 |
| `POST /api/auth/verify-password` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /api/groups` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `POST /api/groups` | PASS | 201, 400; 401 for missing and invalid Bearer |
| `GET /api/groups/cuser` | PASS | 200; 401 for missing and invalid Bearer |
| `DELETE /api/groups/{id}` | PASS | 200, 409; 401 for missing and invalid Bearer |
| `GET /api/groups/{id}` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `PATCH /api/groups/{id}` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `POST /api/groups/{id}/invitations` | PASS | 201, 400, 403, 409; 401 for missing and invalid Bearer |
| `GET /api/groups/{id}/members` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `POST /api/groups/{id}/members` | PASS | 201, 409; 401 for missing and invalid Bearer |
| `DELETE /api/groups/{id}/members/{userId}` | PASS | 200; 401 for missing and invalid Bearer |
| `DELETE /api/groups/{id}/pending-memberships/{invitationId}` | PASS | 200, 403, 404; 401 for missing and invalid Bearer |
| `GET /api/notifications` | PASS | 200; 401 for missing and invalid Bearer |
| `PATCH /api/notifications/read` | PASS | 200; 401 for missing and invalid Bearer |
| `PATCH /api/notifications/{id}/read` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `GET /api/outings` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `POST /api/outings` | PASS | 201, 403, 409; 401 for missing and invalid Bearer |
| `GET /api/outings/cuser` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /api/outings/drafts` | PASS | 200; 401 for missing and invalid Bearer |
| `POST /api/outings/drafts` | PASS | 201; 401 for missing and invalid Bearer |
| `DELETE /api/outings/drafts/{id}` | PASS | 200; 401 for missing and invalid Bearer |
| `PATCH /api/outings/drafts/{id}` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `GET /api/outings/saved` | PASS | 200; 401 for missing and invalid Bearer |
| `DELETE /api/outings/{id}` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /api/outings/{id}` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `PATCH /api/outings/{id}` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `GET /api/outings/{id}/arrivals` | PASS | 200; 401 for missing and invalid Bearer |
| `PUT /api/outings/{id}/arrivals/self` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `GET /api/outings/{id}/attendance` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `PUT /api/outings/{id}/attendance` | PASS | 200, 400; 401 for missing and invalid Bearer |
| `POST /api/outings/{id}/cancel` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /api/outings/{id}/guests` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `POST /api/outings/{id}/guests` | PASS | 201; 401 for missing and invalid Bearer |
| `DELETE /api/outings/{id}/guests/{userId}` | PASS | 200; 401 for missing and invalid Bearer |
| `POST /api/outings/{id}/invitations/accept` | PASS | 200; 401 for missing and invalid Bearer |
| `POST /api/outings/{id}/invitations/decline` | PASS | 200, 409; 401 for missing and invalid Bearer |
| `DELETE /api/outings/{id}/save` | PASS | 200; 401 for missing and invalid Bearer |
| `POST /api/outings/{id}/save` | PASS | 201, 403; 401 for missing and invalid Bearer |
| `POST /api/outings/{id}/tie-break` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /api/outings/{id}/vote-options` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `POST /api/outings/{id}/vote-options` | PASS | 201; 401 for missing and invalid Bearer |
| `PUT /api/outings/{id}/vote-options` | PASS | 200; 401 for missing and invalid Bearer |
| `DELETE /api/outings/{id}/vote-options/{optionId}` | PASS | 200, 404; 401 for missing and invalid Bearer |
| `DELETE /api/outings/{id}/votes` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /api/outings/{id}/votes` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `POST /api/outings/{id}/votes` | PASS | 201, 403; 401 for missing and invalid Bearer |
| `DELETE /api/outings/{id}/votes/{optionId}` | PASS | 200, 404; 401 for missing and invalid Bearer |
| `GET /api/outings/{id}/voting-state` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `GET /api/outings/{outingId}/messages` | PASS | 200; 401 for missing and invalid Bearer |
| `POST /api/outings/{outingId}/messages` | PASS | 201; 401 for missing and invalid Bearer |
| `PATCH /api/outings/{outingId}/read` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /api/places` | PASS | 200 |
| `POST /api/places` | PASS | 201; 401 for missing and invalid Bearer |
| `POST /api/places/geocoding` | PASS | 200, 400; 401 for missing and invalid Bearer |
| `GET /api/places/nearby` | PASS | 200, 400 |
| `GET /api/places/saved` | PASS | 200; 401 for missing and invalid Bearer |
| `DELETE /api/places/{id}` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /api/places/{id}` | PASS | 200 |
| `PATCH /api/places/{id}` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /api/places/{id}/hours` | PASS | 200 |
| `PUT /api/places/{id}/hours` | PASS | 200; 401 for missing and invalid Bearer |
| `DELETE /api/places/{id}/hours/{hourId}` | PASS | 200, 404; 401 for missing and invalid Bearer |
| `GET /api/places/{id}/images` | PASS | 200 |
| `POST /api/places/{id}/images` | PASS | 201, 400; 401 for missing and invalid Bearer |
| `DELETE /api/places/{id}/images/{imageId}` | PASS | 200, 404; 401 for missing and invalid Bearer |
| `GET /api/places/{id}/prices` | PASS | 200 |
| `POST /api/places/{id}/prices` | PASS | 201; 401 for missing and invalid Bearer |
| `DELETE /api/places/{id}/prices/{priceId}` | PASS | 200, 404; 401 for missing and invalid Bearer |
| `DELETE /api/places/{id}/save` | PASS | 200; 401 for missing and invalid Bearer |
| `POST /api/places/{id}/save` | PASS | 201; 401 for missing and invalid Bearer |
| `GET /api/users` | PASS | 200; 401 for missing and invalid Bearer |
| `DELETE /api/users/cuser` | PASS | 200, 409; 401 for missing and invalid Bearer |
| `GET /api/users/cuser` | PASS | 200, 404; 401 for missing and invalid Bearer |
| `PATCH /api/users/cuser` | PASS | 200; 401 for missing and invalid Bearer |
| `DELETE /api/users/cuser/fcm-token` | PASS | 200; 401 for missing and invalid Bearer |
| `POST /api/users/cuser/fcm-token` | PASS | 201; 401 for missing and invalid Bearer |
| `DELETE /api/users/cuser/fcm-token/{token}` | PASS | 200; 401 for missing and invalid Bearer |
| `POST /api/users/sync` | PASS | 200; 401 for missing and invalid Bearer |
| `DELETE /api/users/{id}` | PASS | 200, 403; 401 for missing and invalid Bearer |
| `GET /api/users/{id}` | PASS | 200; 401 for missing and invalid Bearer |
| `GET /health` | PASS | 200 |
