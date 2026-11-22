# Yalla 5roga — API Contracts

## Account deletion

`DELETE /api/users/cuser` and self-scoped `DELETE /api/users/:id` return HTTP 202 with `{"success":true,"data":{"status":"accepted"}}` after the database transaction commits. The path UID must match the Bearer UID. After acceptance, old credentials receive 401 and overlapping valid requests cannot create a second job. An unknown profile returns 404. The app signs out on acceptance while the server finishes Firebase and R2 cleanup independently. [Retention and retry details](SYSTEM_DESIGN.md#coordinated-account-deletion)

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-09 |
| Documentation version | 1.0.0 |
| OpenAPI UI | `GET /api-docs` (generated from route JSDoc + `config/swagger.ts`) |
| Flutter paths | `flutter/lib/core/constants/api_constants.dart` |
| Verification | See the [Swagger integration report](audit/SWAGGER_INTEGRATION_TEST_REPORT.md) for current HTTP and Neon evidence, and the [previous integration audit](audit/BACKEND_FLUTTER_INTEGRATION_REPORT.md) for isolated fixture coverage. |

Convention: JSON, snake_case bodies for most write APIs. Auth: `Authorization: Bearer <Firebase ID token>` unless noted. Success envelope typically `{ success, data }`.

**Do not invent endpoints.** Below lists routes verified in `backend/src/routes/**`.

## System

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/` | No | Process alive |
| GET | `/health` | No | DB `SELECT 1` |

## Auth — `/api/auth`

Current login body: `{phone, password}`. Signup body: `{name, phone, password, phoneVerificationToken}`. Login requires the password and no OTP. The signup proof is a Firebase ID token from a phone OTP sign-in within ten minutes; the backend verifies it (including revocation), matches its normalized phone, and retains its UID. Missing/invalid proof is rejected. Session response envelopes are unchanged. Protected REST and Socket.IO calls accept Firebase phone OTP ID tokens and Firebase custom-session ID tokens from login or signup. An OTP-authenticated caller can provision a profile with sync and subsequently enroll a password without replacing the profile. Clients and API must be released together for the required signup field.

| Method | Path | Auth | Body | Purpose | Flutter |
|--------|------|------|------|---------|---------|
| POST | `/api/auth/login` | No | phone, password | Neon hash verify → Firebase session tokens | `ApiConstants.login` |
| POST | `/api/auth/signup` | No | name, phone, password, phoneVerificationToken | Neon user keyed by verified OTP UID; link pending invitation identity without acceptance | `ApiConstants.signup` |
| POST | `/api/auth/change-password` | Yes | currentPassword, newPassword | Update Neon `password_hash` | `ApiConstants.changePassword` |
| POST | `/api/auth/verify-password` | Yes | password | Confirm Neon password (no change) | `ApiConstants.verifyPassword` |

Errors: 400 validation, 401 bad credentials, 409 conflict, 429 rate limit (when configured).

Public user payloads for self/known-UID reads include `has_password` (boolean) and a required unique E.164 phone. `password_hash` stays in Neon. The obsolete `suggested_by_user_id` outing field was removed. Creator attribution is `created_by`. Directory results from `GET /api/users/` are phone-free; member phones remain available only through authorized group member endpoints.

## Users — `/api/users`

| Method | Path | Auth | Purpose | Flutter |
|--------|------|------|---------|---------|
| GET | `/api/users/cuser` | Yes | Current Neon user (`created_at`, `has_password`, …) | settings / `AuthProvider.refreshProfile` |
| PATCH | `/api/users/cuser` | Yes | Update profile | settings |
| DELETE | `/api/users/cuser` | Yes | Delete self | optional |
| POST | `/api/users/sync` | Yes | Upsert Neon user from Firebase claims | `ApiConstants.syncUser` |
| GET | `/api/users/` | Yes | Find by `ids` (comma-separated Firebase UIDs, max 100) or exact `phone`; returns `id`, `name`, `image_url`, timestamps only. A bare request returns 400. | — |
| GET | `/api/users/:id` | Yes | Get by id | — |
| DELETE | `/api/users/:id` | Yes | Delete by id (self rules in use case) | — |

Entities: `users`.

`image_url` accepts an absolute http(s) URL or a stable `media://<uuid>` reference (see [Media](#media--apimedia)); local paths are rejected.

`POST /api/users/sync` links pending invitation identities when the verified token phone matches the current Firebase phone credential. It accepts optional `phoneVerificationToken` for an authenticated user repairing a legacy signup OTP identity. The backend verifies recent phone sign-in, checks phone uniqueness, refuses to merge another registered UID, and moves only the unused identity's Firebase phone credential onto the Bearer UID. PostgreSQL IDs and memberships remain unchanged. A profile phone alone is never proof. Signup and verified-phone password login also link pending invitation identities before returning; the app defers one session-restore sync until cached shell hydration, before online group revalidation.

## FCM — `/api/users/cuser/fcm-token`

| Method | Path | Auth | Body | Purpose | Flutter |
|--------|------|------|------|---------|---------|
| POST | `/api/users/cuser/fcm-token` | Yes | token, platform? | Register (UID from Bearer token only) | `ApiConstants.fcmToken` |
| DELETE | `/api/users/cuser/fcm-token` | Yes | token | Unregister | same |
| DELETE | `/api/users/cuser/fcm-token/:token` | Yes | — | Unregister via path | — |

Entities: `user_fcm_tokens`.

## Groups — `/api/groups`

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/api/groups/cuser` | Yes | My groups (`member_count`, `my_role`) |
| GET | `/api/groups` | Yes | List the caller’s groups. A supplied `userId` must equal the caller UID. |
| POST | `/api/groups` | Yes | Create (`image_url` optional; omit or `""` for default cover). Creator is inserted as `group_members` owner; response includes `member_count: 1`, `my_role: owner` |
| GET | `/api/groups/:id` | Yes | Active member only. Includes `member_count` and `my_role`. |
| PATCH | `/api/groups/:id` | Yes | Update as owner. Partial payload accepts `bio` up to 160 characters, including an empty value to clear it, and optional `name` and `image_url`. |
| DELETE | `/api/groups/:id` | Yes | Delete (owner). Returns 409 while the group has outings. |
| GET | `/api/groups/:id/members` | Yes | Active member only. `data` contains active profiles, including the creator. `pending_members` contains `{ invitation_id, phone, status: "pending" }` pending invitations awaiting an explicit decision. |
| POST | `/api/groups/:id/members` | Yes | Owner-only direct add for a verified, registered phone. A duplicate returns 409. |
| DELETE | `/api/groups/:id/members/:userId` | Yes | Remove member |
| POST | `/api/groups/:id/invitations` | Yes | Invite by phone. Optional `whatsappOptIn: true` attests recipient agreement; Flutter Create Group/Add people require this explicit checkbox. `notification_queued` is true after successful outbox persistence for a consented non-user with a configured provider. Existing verified app users retain pending in-app invitations without a WhatsApp send. The compatibility field `whatsapp_url` is null. Pending membership persists independently. |
| DELETE | `/api/groups/:id/pending-memberships/:invitationId` | Yes | Owner-only revocation of the pending association returned by the phone-add API. Returns 404 once revoked or linked. |

Flutter: `ApiConstants.groups*`. Entities: `groups`, `group_members`, `group_invitations`. Create/details reload members so the owner card and count ≥ 1 appear immediately. `image_url` accepts http(s) or `media://<uuid>`; a cover may be uploaded before the group exists and is linked when the create/update succeeds.

Invitation creation returns a pending invitation for registered and unregistered phones. Verified signup/login/sync may associate the pending row with the account but cannot accept it or create membership. Existing memberships remain unchanged. Duplicate pending invitations reuse the existing record internally and retain the API conflict response. The separate owner-only `POST /api/groups/:id/members` operation adds an existing verified user as `member`; it cannot assign `owner`.

## Invitations — `/api/invitations`

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/api/invitations` | Yes | List invitation history matching the authenticated PostgreSQL user ID, plus pending unlinked rows matching the current Firebase-verified phone. Each entry includes `invitation_id`, `group_id`, `group_name`, `group_image`, `invited_phone`, `status`, `created_at`, and `inviter_name`. Listing never accepts an invitation. |
| POST | `/api/invitations/:invitationId/accept` | Yes | Accept a pending invitation. Creates a `group_members` entry and updates the invitation status to `accepted`. Idempotent — a repeated or conflicting call returns the persisted `status` without rewriting the row. Emits `data:changed` for `membership` and invalidates the inbox. |
| POST | `/api/invitations/:invitationId/decline` | Yes | Decline a pending invitation, including a phone-only row with `user_id=null`. Updates the invitation status to `declined` and links the caller for history. The record is preserved; no membership is created. Idempotent — a repeated or conflicting call returns the persisted `status`. Emits `data:changed` for `group` and invalidates the inbox. |

Flutter: `ApiConstants.invitations`, `ApiConstants.invitationAccept`, `ApiConstants.invitationDecline`. Entities: `group_invitations`. Pending invitations appear in the Group Members screen as "Pending" status. Accepting transitions the user from Pending to Member and makes the group visible in the Groups Tab. Declining removes the user from visible group members.

**Identity mapping**: `users.id` is the authenticated Firebase UID. The inbox and decision controller obtain the current verified phone from Firebase Admin, never request body/query/profile values. Account-linked rows remain visible for history. Only pending rows with `user_id IS NULL` may use phone matching. Signup/login/sync links identity without deciding invitations. Accept/decline decisions serialize on the invitation row; acceptance inserts membership with duplicate protection in the same transaction. Repeated or conflicting decisions return persisted status.


## Outings — `/api/outings`

| Method | Path | Auth | Purpose | Notes |
|--------|------|------|---------|-------|
| GET | `/api/outings/cuser` | Yes | My outings | created / invited / group |
| GET | `/api/outings` | Yes | List caller outings | `groupId` requires active group membership. `userId` must match the caller if supplied. |
| POST | `/api/outings` | Yes | Create | requires deadline; `image_url` optional http(s) or `media://<uuid>`; owner Going |
| GET | `/api/outings/:id` | Yes | Get | Creator, active group member, or pending or accepted outing guest. Same read scope applies to attendance, guests and voting data. |
| PATCH | `/api/outings/:id` | Yes | Update | Creator only. Venue confirmation uses the dedicated voting endpoint. The confirmed location is locked. |
| DELETE | `/api/outings/:id` | Yes | Permanently delete outing | Creator only. Flutter removes the outing and cached bookmark after success. |
| POST | `/api/outings/:id/cancel` | Yes | Cancel | Owner |
| GET/POST | `/api/outings/drafts` | Yes | List/create drafts | |
| PATCH/DELETE | `/api/outings/drafts/:id` | Yes | Update/delete draft | owner |
| GET/PUT | `/api/outings/:id/attendance` | Yes | List or set RSVP | GET returns the complete accepted roster, including read-only `no_response` defaults and phone-free `users` profiles. PUT keeps its persisted response in `data` and returns the roster in `items`. Summary includes `no_response`; identical writes preserve the previous timestamp. |
| GET | `/api/outings/:id/arrivals` | Yes | Participant roster and GPS policy | Returns `arrivals`, `unconfirmed`, `total_confirmed`, `open`, `opens_at`, `closes_at`, `radius_meters`, `max_accuracy_meters` and the confirmed `venue` coordinates. Compatibility fields report `automatic_eligible: true` and `can_confirm_arrivals: false`. |
| PUT | `/api/outings/:id/arrivals/self` | Yes | Verify own GPS arrival | Sends `latitude`, `longitude`, `accuracy` in meters and ISO `captured_at`. Optional `method` accepts `gps` and the older `automatic_gps` spelling. A reported mock fix is rejected. Returns `{ arrived }`. |
| GET/POST | `/api/outings/:id/guests` | Yes | List / invite | Repeated invites preserve pending or accepted membership and its original timestamp. |
| POST | `/api/outings/:id/invitations/accept` | Yes | Accept invite | → Member |
| POST | `/api/outings/:id/invitations/decline` | Yes | Decline | |
| DELETE | `/api/outings/:id/guests/:userId` | Yes | Remove guest | Owner; self-leave forbidden |
| GET/POST | `/api/outings/:id/vote-options` | Yes | List / add option | Owner add; resets votes |
| PUT | `/api/outings/:id/vote-options` | Yes | Replace options | resets votes; keeps deadline |
| DELETE | `/api/outings/:id/vote-options/:optionId` | Yes | Delete option | resets votes |
| GET/POST | `/api/outings/:id/votes` | Yes | List / add one selection | Idempotent current-round selection; deadline closure |
| PUT | `/api/outings/:id/votes` | Yes | Replace complete ballot | `{ option_ids: UUID[] }`, 0–5 distinct options; atomic replacement then closure evaluation |
| DELETE | `/api/outings/:id/votes` | Yes | Remove my vote | if open |
| DELETE | `/api/outings/:id/votes/:optionId` | Yes | Remove my vote for option | |
| GET | `/api/outings/:id/voting-state` | Yes | Tallies / closure state | Ordered `options` with `vote_count`, `my_option_ids`, distinct `voted_count`, legacy first `my_option_id`, and `eligible_voter_count`. |
| PUT | `/api/outings/:id/confirmed-venue` | Yes | Creator confirms a proposed option | Body `{ option_id }`. Atomically closes voting. Repeating the confirmed choice is idempotent. |
| POST | `/api/outings/:id/tie-break` | Yes | Owner RNG among tied leaders | |

Flutter consumes these via `OutingsRemoteDataSource` / `ApiConstants.outing*`.

Special-event create accepts up to 50 `guest_phones`, requires `guest_phones_whatsapp_opt_in: true`, a `create_request_key`, a future schedule and a fixed named venue. Phone numbers are normalized and deduplicated. With a configured WhatsApp sender, messages are queued atomically with the event. Otherwise the owner receives `manual_whatsapp_urls` in the create response. Reuse the same request key for retries.

Entities: `outings`, `outing_guests`, `outing_attendance`, `outing_arrivals`, `outing_vote_options`, `outing_votes`, `outing_drafts`.

Possible errors: 400 validation, 401, 403 forbidden, 404, 409 conflict (closed voting, attendance closed, etc.).

## Saved outings / places

| Method | Path | Auth | Purpose | Flutter |
|--------|------|------|---------|---------|
| GET | `/api/outings/saved` | Yes | List saved outings, including nested `outing.occasion` for cover selection | `savedOutings` |
| POST | `/api/outings/:id/save` | Yes | Save outing | `savedOuting(id)` |
| DELETE | `/api/outings/:id/save` | Yes | Unsave | |
| GET | `/api/places/saved` | Yes | List saved places | `savedPlaces` |
| POST | `/api/places/:id/save` | Yes | Save place | `savedPlace(id)` |
| DELETE | `/api/places/:id/save` | Yes | Unsave | |

Entities: `saved_outings`, `saved_places`.

## Places — `/api/places`

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/api/places` | No* | List / filter |
| GET | `/api/places/nearby` | No* | Haversine nearby |
| GET | `/api/places/:id` | No* | Detail |
| POST/PATCH/DELETE | `/api/places`… | Yes | CRUD (curator only) |
| GET/PUT/DELETE | `/api/places/:id/hours`… | mix | Hours (writes curator only) |
| GET/POST/DELETE | `/api/places/:id/images`… | mix | Images (writes curator only; url accepts http(s) or `media://<uuid>`) |
| GET/POST/DELETE | `/api/places/:id/prices`… | mix | Prices (writes curator only) |

\*List/get/nearby are public in route file (no `authMiddleware` on those GETs). Catalog writes require a Firebase bearer token **and** a curator UID listed in the server-only `PLACES_CURATOR_UIDS` environment variable (comma-separated). The allowlist fails closed when unset, so an ordinary authenticated user receives 403. This is configuration, not a product role: the authorization model still has no global admin role.

Flutter Discover uses list/detail (+ saved places) and calls Nearby with `lat`, `lng`, `limit` and `offset` after obtaining foreground location. It reads all pages within the default 5 km radius and applies the vibe filter to the loaded pins and list. Latitude and longitude must be valid numeric coordinates. Results come from active geocoded rows in `places`, ordered by `distance_km` with a stable ID tie-break. The outing location picker uses a separate geocoding flow.

An outing participant can request `GET /api/outings/:outingId/messages?messageId=<uuid>` for an exact notification target. It returns one message in the existing list envelope and a null cursor. Omit `before` and `limit`. A missing message or a message from another outing returns 404.

## Media — `/api/media`

All routes require `Authorization: Bearer <Firebase ID token>`. Binaries never pass through these endpoints; the API returns presigned object-storage URLs only.

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| POST | `/api/media/upload-url` | Yes | Create or re-issue an upload intent. Body: `purpose` (`profile`\|`group`\|`outing`\|`place`\|`chat`), `mime_type`, `file_size`, optional `entity_id`, optional `media_id` (pending retry). Returns `media_id`, `object_key`, `visibility`, `status`, `upload_url`, `upload_expires_at`. |
| POST | `/api/media/:id/confirm` | Yes | Validate the private staging object's contents, then publish a server-owned delivery key and mark the asset `ready`. Missing or expired upload → `409`. Invalid image → `400`. |
| POST | `/api/media/signed-urls` | Yes | Batch resolve up to 50 ids. Body `{ media_ids: [...] }`. Returns `data: [{ media_id, url, visibility, expires_at }]` for assets the caller may view. |
| GET | `/api/media/:id/url` | Yes | Resolve one asset to a delivery URL after the same access check. |
| DELETE | `/api/media/:id` | Yes | Delete an owned asset (also used to clean up a failed upload). |

Delivery policy:

- `place` → `visibility=public`. When the `r2` provider is active **and** a real (non-placeholder) `R2_PUBLIC_BASE_URL` is configured, the response URL is the CDN `https://<domain>/<object_key>` with `expires_at: null`; in mock mode or before the CDN domain exists, a short-lived signed URL is returned so the app never receives the placeholder host.
- `profile`, `group`, `outing`, `chat` → `visibility=private`. Delivery uses a short-lived signed GET URL (`expires_at` set); the client must never persist it as the entity value or as the image-cache identity.
- View authorization: profile avatars are visible to any authenticated user; group/outing/chat media require membership/participant checks; public assets require authentication. Ownership mismatch returns `404` for confirm/delete to avoid leaking asset existence.
- Upload authorization: `profile` = self; `group`/`outing` with `entity_id` = group owner/outing creator (entity-less covers are allowed before creation and authorized when attached); `chat` requires an outing id and participant eligibility; `place` mutations are gated by the catalog APIs.
- Failed uploads are removed after rejection and the cleanup job reaps expired or abandoned rows and objects. An R2 lifecycle rule on the private `uploads/` prefix catches any staged object replayed within a valid PUT window. The ready key is outside the staging prefix.
- Entity integration: create/update payloads accept `image_url` as an absolute http(s) URL or `media://<uuid>`; local file paths are rejected. The Flutter client uploads first, then sends the reference. Response fields remain plain strings for backward compatibility.

Flutter: `ApiConstants.mediaUploadUrl`, `mediaSignedUrls`, `mediaConfirm`, `mediaAssetUrl`, `mediaDelete`; `core/media/` owns reference parsing, upload, URL resolution/caching and account-scoped eviction.

When `R2_*` credentials are absent the backend uses the in-memory mock adapter and registers `PUT /api/media/mock-upload/:key` + `GET /api/media/mock-download/:key` for local development only. Those routes disappear automatically once the provider resolves to `r2`.

## Notifications — `/api/notifications`

| Method | Path | Auth | Purpose | Flutter |
|--------|------|------|---------|---------|
| GET | `/api/notifications` | Yes | Inbox includes `eventType` and optional `messageId` for navigation. `limit` defaults to 20 (maximum 100); opaque `cursor` returns a stable newest-first page with `pagination.nextCursor` and compatibility alias `next_cursor`. | `notifications` |
| PATCH | `/api/notifications/read` | Yes | Mark all read | `notificationsReadAll` |
| PATCH | `/api/notifications/:id/read` | Yes | Mark one | `notificationRead` |

## Chat — outing sub-resource `/api/outings/:outingId/...`

| Method | Path | Auth | Purpose | Flutter |
|--------|------|------|---------|---------|
| GET | `/api/outings/:outingId/messages` | Yes | List messages | `outingChatMessages` |
| POST | `/api/outings/:outingId/messages` | Yes | Send `{ text, clientMessageId? }` | same |
| PATCH | `/api/outings/:outingId/read` | Yes | Mark read | `outingChatRead` |

History/read access requires the creator, a current group member, or a pending/accepted outing guest. Sending and own-message editing/deletion require draft/voting/confirmed status and close at scheduled start + two hours. Past/cancelled mutations are blocked (409 CHAT_CLOSED).

### Socket.IO realtime (same origin/port, path `/socket.io`)

| Direction | Event | AuthZ | Payload |
|-----------|-------|-------|---------|
| Handshake | — | Firebase ID token in `auth.token` | uid from Admin `verifyIdToken` only |
| C→S | `outing:join` | Participant (`assertChatParticipant`) | `{ outingId }` → ack `{ ok, room? }` / `{ ok:false, error }` |
| C→S | `outing:leave` | Authenticated | `{ outingId }` |
| S→C | `outing:message` | Room members only | Same shape as REST Prisma message (`id`, `outing_id`, `sender_id`, `text`, `sent_at`, …) |
| S→C | `outing:read` | Room members only | `{ outing_id, user_id, last_read_at }` |
| S→C | `data:changed` | Server-selected `user:{uid}` rooms from verified identity | `{ kind, id?, cursor: {epoch, sequence} }`; kinds `group`, `membership`, `outing`, `outings`, `profile`, `inbox` |
| C→S | `data:reconcile` | Authenticated; journal filtered by verified UID | `{epoch?, sequence?}` → ack `{ok, reset, cursor, changes}` |

Room name: `outing:{outingId}`. Persistence is REST-only; sockets never create chat rows.

`data:changed` is an invalidation hint: clients reload authorized REST resources. `outing` targets detail/votes/attendance/lifecycle; `outings` also invalidates the list. Membership invalidates groups/outings and active chats. Removed users receive revocation hints for revalidation. Message delivery filters joined sockets against the current participant audience. A single-process invalidation journal retains up to 512 changes for 10 minutes. Reconciliation returns only changes whose recorded audience includes the verified UID. Invalid/old/future cursors, process restart or retention expiry return `reset:true` for REST revalidation. This journal is not durable and does not replay chat content.

Chat POST accepts `clientMessageId` (UUID). PostgreSQL deduplicates `(outing_id, sender_id, client_message_id)`, returning the original canonical row on retry. A committed send can still be acknowledged after chat closure, following the participant check. An unsent closed-chat message remains a permanent conflict. Only chat sends support offline replay; other writes require online success.

## Related

- OpenAPI freeze notes: `docs/system-design/openapi-contract-freeze.md` (may lag — prefer route sources)
- Older mismatch matrix: `docs/system-design/api-contract-matrix.md` is **historical** and partly superseded by `/api` prefix + compliance fixes

### Map search and atomic creation

- `POST /api/places/geocoding` requires a Firebase bearer token. Supply `{kind:"search", query, language}` or `{kind:"reverse", latitude, longitude, language}`. Language is `en` or `ar`. The response envelope contains `data.available`, `data.results` (rows with `id`, `name`, `area`, `latitude`, `longitude`), and, when configured, `data.attribution` and `data.cache_seconds`. A disabled provider returns `available:false`. Invalid requests return 400, the process quota returns 429 with `Retry-After`, and upstream failure returns 502.
- `POST /api/outings` accepts optional `initial_vote_options` with 2–5 options in array order for a group outing without a fixed venue. Each uses the existing option fields. Coordinates may be absent or a valid pair. The backend assigns zero-based `sort_order`, rejects duplicate identities, and commits the options, outing and owner attendance together. A valid retry with the same `create_request_key` for the same creator returns the original outing. The first successful request wins for that key. The older individual and replacement option routes remain available. Deploy the backend change before clients that send `initial_vote_options`.
- Fixed custom venues can include `location_category_id` and `location_address`. Custom vote options can include `category_id` and `address`. Confirming a winning option copies its snapshot to the outing under the existing attendance, voting and outing-access rules. Device-local place identifiers are excluded from these requests.

For chat history, Flutter sends `limit=40` and passes `next_cursor` as `before` when loading older messages. The API accepts page sizes from 1 to 100 and retains the legacy unpaged response when query parameters are omitted. REST history, send responses, and Socket.IO messages carry the sender’s `sender` display name and `avatar` fields. Existing message IDs and `client_message_id` remain the deduplication keys.

`outing:arrival_changed` carries only `{ outing_id }` and is emitted after a new verified write. Flutter reloads the roster over authenticated REST. The socket server chooses recipients from current outing participants and joins sockets to user rooms from their verified Firebase identity.


## Chat mention text and invalidation replay — 2026-11-11

POST message `text` accepts inline `<@URI-encoded-user-id|URI-encoded-display-name>` tokens. The ID is authoritative; the backend replaces supplied names with Neon names. IDs outside current chat participants, malformed ID percent encoding, more than 50 distinct mentions, or canonical text longer than 2000 characters return 400. The REST response, history (including cursor pagination/messageId lookup), socket message, and offline resend retain the same tokens. Legacy `@name` text remains readable and receives no identity semantics. No new database field is required. Supply `clientMessageId` for retry idempotency; repeated requests preserve the committed text and notification key.

S→C `data:changed` carries `{kind,id?,cursor:{epoch,sequence}}`. Invalidation kinds remain group, membership, outing, outings, profile and inbox; complete attendance events are documented below. C→S `data:reconcile` sends the last cursor (or `{}` initially); acknowledgement is `{ok:true,reset,cursor,changes}`. Only invalidations addressed to the authenticated socket UID are returned. Reset requests bounded cache reconciliation after restart/expiry; it never bypasses REST authorization. This is Socket.IO, not an HTTP operation in OpenAPI.


## Centralized synchronization contract — 2026-11-11

All events share the existing Firebase-authenticated `/socket.io` transport. REST URLs, bodies, authorization and response envelopes are preserved.

| Direction / event | Payload | Handling |
| --- | --- | --- |
| C→S `group:join`, `group:leave` | `{groupId: UUID}` | Join checks current Neon membership; ack `{ok,room? ,error?}`. Errors: `INVALID_GROUP_ID`, `UNAUTHORIZED`, `FORBIDDEN`. Leave removes only this socket. |
| S→C `data:changed` | `{kind,id?,cursor:{epoch,sequence},payload?}` | User-scoped committed changes; group/membership/outing/outings/profile/inbox hints remain supported. |
| S→C `data:changed`, `kind=attendance` | `{kind:"attendance",id: outingId,payload:{user_id,status,updated_at},cursor}` | Complete committed attendance row; statuses `going`, `not_going`, `maybe`. Only owner, accepted guests and group members receive it; pending-only guests do not. Apply directly when the outing is loaded; otherwise target that outing. |
| C→S `data:reconcile` | Last acknowledged `{epoch,sequence}`, or `{}` | Ack `{ok:true,reset,cursor,changes}`. Each replay entry now includes its original cursor for deduplication. Attendance replays as an `outing` identifier without historical domain data; REST checks current access. |
| Existing chat events | `outing:join/leave`, `outing:message`, `outing:read`, `outing:arrival_changed` | Preserved. Message/read recipients are filtered using current membership even for stale room occupants. |

`user:{uid}` is server-assigned; `group:{groupId}` is joined only after authorization; `outing:{outingId}` retains existing participant authorization. Group subscriptions are synchronized from the loaded group list, without another connection. Domain delivery uses deduplicated user rooms so list screens receive changes without needing a detail route subscription. The replay checkpoint advances on reconciliation acknowledgement only, never on live delivery. See [implementation and verification report](audit/CENTRALIZED_REALTIME_SYNC.md).

## Password recovery APIs — 2026-11-11

All three endpoints are public, use the standard `{success,data}` envelope, return `Cache-Control: no-store`, and reject additional body properties. Never put secrets in URLs or persist response secrets.

| POST path | Body | Success `data` | OpenAPI operation |
|---|---|---|---|
| `/api/auth/recovery/start` | `{phone}` | `{requestToken, expiresIn:600, resendAfter:60}` | `startPasswordRecovery` |
| `/api/auth/recovery/verify` | `{requestToken, phoneVerificationToken}` | `{resetToken, expiresIn:300}` | `verifyPasswordRecovery` |
| `/api/auth/recovery/reset` | `{resetToken, newPassword, confirmPassword}` | `{updated:true}` | `resetRecoveredPassword` |

Secrets are 32 random bytes encoded as 43 base64url characters. Verification requires a fresh, current, non-revoked Firebase phone-provider ID token for the request's exact existing UID and phone; body phone/UID/verified flags are never accepted. Reset policy: 8+ characters with uppercase, lowercase, digit and symbol; maximum 72 UTF-8 bytes; exact confirmation. Existing login/signup/change-password contracts remain unchanged.

Errors: 400 validation/unavailable account or changed binding/password; 401 invalid/old/wrong/replayed proof or expired/consumed authorization; 429 shared rate limit or cooldown; 500 infrastructure failure. The same unavailable message covers missing passwords, unregistered and unbound phones. Limits: 30 API attempts/IP/minute; five starts/phone/hour and 60-second cooldown; five verify attempts/request and reset attempts/secret per ten minutes. Swagger definitions live beside the auth routes. Test evidence is in [PASSWORD_RECOVERY_REPORT](audit/PASSWORD_RECOVERY_REPORT.md).

## Confirmed API corrections — 2026-11-13

- The existing `/api-docs/swagger-ui-init.js` serves the generated OpenAPI document used by `/api-docs/`. Existing operation IDs and endpoint paths are preserved.
- Signup accepts either `phone` or `phoneNumber`, with at least one required, plus `name`, `password`, and `phoneVerificationToken`. After trimming, phone strings accept 8–20 characters matching `^\+?[0-9\s().-]+$`; verified identity checks remain unchanged.
- All `/api` HTTP routes share a single-process limit of 300 requests/IP/minute. Existing login/signup limits remain 20 attempts/IP/minute, and recovery limits remain stricter. 429 uses `{success:false,message}` and `Retry-After`. Socket.IO and Swagger assets are outside this limiter. Proxy trust is not broadened.
- `GET /api/notifications` always defaults to 20 rows; `limit` is 1–100. `cursor` is opaque. Order is `created_at DESC, id DESC`, with database-native keyset traversal and ownership-checked anchors. Response preserves `{success,data}` and `next_cursor`, and adds `pagination:{limit,nextCursor}`. Null cursors end pagination. Flutter follows pages to preserve the existing complete inbox/unread count behavior.
- `POST /api/outings` ignores client initial status; server selects voting/options, confirmed/fixed venue, or draft/no venue. It never creates cancelled/past outings. Flutter no longer sends status or server-owned suggestion attribution.
- Outing reads use a dedicated access check (creator, group member, pending/accepted outing invitee), independent of chat lifecycle. Chat operations retain their existing authorization.
- Owner cancellation notifies eligible participants via `outing_cancelled`, including outing/group IDs, title and navigation fields. A stable owner-cancellation event key deduplicates inbox and outbox rows. The controller publishes the existing Socket.IO change event.
- Draft operations remain GET/POST `/api/outings/drafts`, PATCH/DELETE `/api/outings/drafts/:id`. Optional POST `Idempotency-Key` is a stable UUID used as the existing draft ID; retry returns the owned existing row without replacing content. Optional PATCH/DELETE `If-Match` is the exact loaded `updated_at` timestamp; conflicts return 409. Updates/deletes lock the draft row and version checks use the API's millisecond precision. New Flutter writes always send the version when updating/deleting a loaded draft. Older callers omitting it retain compatibility. Responses retain their existing envelopes.
- `GET /api/outings/:id/guests` includes a `users` projection containing only `name` and `image_url` for participant management. Guest deletion remains creator-only. Group deletion remains owner-only and now requires that owner to be the sole active member; other active members or any outings return 409. It does not cascade-delete outings. The client uses DELETE group when the sole owner leaves, while other members use the existing self-member DELETE with the last-owner restriction.
- Arrival coordinates are client-reported evidence, not attested GPS. `is_mocked=true` is rejected; false/omitted grants no trust. Server checks identity, current participation, confirmed pinned venue, coordinate/accuracy bounds, sample age, server time window and distance before its existing upsert. Persisted arrival time is server-generated.

Runtime evidence and unverified authenticated scenarios: `audit/CONFIRMED_FIXES_OPENAPI_RESULTS.json` and `audit/CONFIRMED_FIXES_IMPLEMENTATION_REPORT.md`.

## Phase 2 roster response extension — 2026-11-13

`GET /api/groups/:id/members` retains `success`, active profiles in `data`, and `pending_members`. It adds `invitation_history`, newest first, containing `{ invitation_id, invited_phone, invitee_name: string|null, inviter_name, status, created_at }`; status is `pending|accepted|declined|expired|revoked`. It is scoped to the requested group and protected by the existing active group-member authorization. Pending rows include verified identity-linked invitations (`user_id` may be non-null); linking never makes a member or removes the Pending display. The active membership list and member count are unchanged.

No route, request body, invitation decision behavior or Socket.IO event changed. Flutter's owner name editor forwards the already-supported optional `name` field on the existing group PATCH. Old roster payloads without history decode as an empty history list. Deploy the backend response extension with the client to populate group invitation history. Verification: [OpenAPI results](audit/PHASE_2_OPENAPI_RESULTS.json), [scope and limits](audit/PHASE_2_UI_UX.md).


## Phase 3 multi-location ballot contract — 2026-11-14

`replaceOutingBallot` accepts a full `option_ids` array. Empty array clears the caller’s selections; duplicate, invalid or foreign options fail with 400, nonparticipants with 403, missing outing with 404, and closed/expired voting with 409. Success is `{ success: true, data: { votes: Vote[], resolution: VoteResolution | null } }`. State reads return all caller selections and a distinct voter count, separate from the sum of per-option tallies. Existing POST/DELETE routes remain, and all vote writers reject deadline expiry. Existing realtime outing invalidation is emitted after commit; no Socket.IO wire event changes. `breakTie` now explicitly documents its existing 403/404/409 paths.

## Phase 4 special-event contract extension — 2026-11-14

Existing POST/PATCH `/api/outings` and draft schemas now accept `occasion: none|birthday|wedding|celebration|other`. Type remains server-derived: `none` requires a group and means `group`; every other occasion means `special_event` regardless of group_id. For a special event, group_id may be omitted/null or an accepted-member group. A supplied group receives the existing group authorization checks (403 for nonmembers or pending invitations; 404 for a missing group). Creator-only update rules still apply. Group association gives current accepted group members the existing outing access; removing the association removes that route to access.

Creation of any special event requires a future scheduled_at and a fixed location_name; initial_vote_options remain the regular group-outing flow. Image references, idempotency, RSVP, app guest invitations and opted-in phone guests retain their contracts, including for group-associated events. No new outing_type, endpoint, event field or Socket.IO wire event was introduced. Draft and entity enum decoders round-trip the new occasions. Existing map/geocoding HTTP contracts are unchanged. Deploy the additive database migration before the new backend/client; verification does not deploy it to the application schema.


## Create voting deadline selection — 2026-11-14

The existing POST /api/outings accepts vote_ends_at as an absolute ISO-8601 instant with an offset/Z and vote_deadline_hours as optional duration metadata, now 1–168 inclusive. At least one is required. Explicit vote_ends_at takes precedence; it must be future-dated and strictly before scheduled_at when that field is supplied. Relative-only clients use server-time resolution and the same checks. Invalid/missing/elapsed/equal-or-after-start deadlines return 400 before persistence. Flutter calculates the absolute timestamp immediately before POST and displays the returned outing.vote_ends_at on success; local summaries use toLocal(). The draft API retains its existing vote_deadline_hours field with range 1–168. No route, field name or response envelope changes.


## Unanswered RSVP projection — 2026-11-14

GET /api/outings/:id/attendance data and PUT items use AttendanceRosterEntry: outing_id, user_id, status (going/not_going/maybe/no_response), nullable updated_at, and users { name, image_url }. Missing persisted rows serialize as no_response with no invented update time; the creator stays Going. my_response is explicit and summary includes all four counts. PUT request status still accepts only going/not_going/maybe; no_response is a default/read projection, not a selectable mutation. Existing membership checks gate the roster and exclude pending invitees. No database column/enum migration or endpoint is added.


## Phase 5 outing-message mutations — 2026-11-14

| Method | Path | Operation | Contract |
|--------|------|-----------|----------|
| PATCH | `/api/outings/{outingId}/messages/{messageId}` | `editOutingMessage` | `{text: string}` trimmed, 1–2000 characters; canonical `ChatMessageResponse` |
| DELETE | same | `deleteOutingMessage` | 200 `ChatMessageResponse` with empty text tombstone; repeated delete remains 200 while open |

Both use the existing Firebase middleware, participant and own-sender authorization. 400 invalid path/text, 401 unauthenticated, 403 nonparticipant/other sender, 404 wrong outing/message, 409 CHAT_CLOSED, MESSAGE_DELETED or MESSAGE_EDIT_WINDOW_EXPIRED. PATCH requires now < sent_at + 60 seconds; the cutoff is also enforced in the database update predicate. DELETE does not have the edit-age limit. Send/edit/delete close at scheduled start + two hours or status past/cancelled. History and mark-read contracts remain readable. Existing rooms and `outing:message` payloads carry canonical updated rows and tombstones; no transport or required response field changes. No migration is needed. The push sender retains APNs category `outing_chat`; the later Android system-push extension uses data-only Android messages and preserves visible iOS APNs alerts.


## Android system push contracts — 2026-11-14

New authenticated operations: GET `/api/notifications/preferences` (`getNotificationPreferences`), PATCH the same path (`updateNotificationPreferences`, strict partial boolean preferences), and GET `/api/notifications/{id}/system-payload` (`getNotificationSystemPayload`, UUID; 403 for a different recipient, 404 missing). The last operation returns `{success,data:{available,payload}}`, uses Cache-Control:no-store and never marks read. Unavailable resources, deleted/read messages, expired/decided invitations, obsolete reminders and preference-disabled displays return available=false/payload=null. Routing IDs never confer access.

GET `/api/notifications` retains its category `type`, pagination and response envelope, and adds `unreadCount` for all owned rows plus `preferences` and structured per-row data: notificationId, eventId, notificationType, actionType, createdAt and relevant groupId/outingId/invitationId/messageId. Legacy event keys remain readable. `eventId` is a notification event UUID, never an outing ID. Swagger defines the new responses and preference schema.

Android actions reuse existing message POST/clientMessageId, chat read PATCH, invitation decision POST, and token registration/deletion APIs; no reply/accept/read duplicate endpoint was added. Chat read now atomically marks this user's chat inbox rows in the selected outing as read and publishes inbox invalidation plus a silent cross-device dismissal. Other outings remain unread. Edit/delete APIs and the 60-second authorization window remain; related inbox previews update/tombstone and queued pushes resolve current text. Candidate resets, winners and outing transitions enqueue notifications in their existing business transactions. Existing Socket.IO contracts are unchanged.

See [notification delivery](NOTIFICATIONS.md) and [HTTP/OpenAPI evidence](audit/ANDROID_PUSH_OPENAPI_RESULTS.json). Native action execution is not verified by Swagger.

The existing POST `/api/users/cuser/fcm-token` additionally accepts optional notificationVersion (integer 1 or 2; default 1). Updated Flutter registers 2. Android v2 receives data-only action-capable delivery; preupgrade Android registrations retain ordinary OS-visible notifications with redacted title/body when lock-screen previews are disabled. This avoids breaking older installed clients when the backend is deployed first. The token's existing platform field stays android/ios/other and reassignment/logout ownership rules remain unchanged.


## Dynamic places catalog — 2026-11-14

Existing `GET /api/places` retains `{success,data:[...]}` and adds `pagination:{limit,offset,has_more,next_offset}` and OSM attribution. Default limit=50, maximum=100. Query parameters: `search`, comma-separated `categories`, comma-separated `vibes`, legacy `vibe`, `featured=true|false`, `status` (active default), `lat`+`lng`, `radiusKm` (maximum 100), `bbox=west,south,east,north`, `sort=updated|name|distance`, `limit`, `offset`. Dimensions combine with AND; IDs inside a category/vibe dimension combine with OR. Distance sorting requires valid coordinates; coordinates must appear together. Unsupported/invalid values return 400. Existing `/nearby` remains compatible and active-only.

Public `/api/places/categories` and `/vibes` return active definitions with stable IDs, Arabic/English labels, icon tokens and category group IDs. `/version` returns `{data:{version}}` for reconnect/resume revision checks. Place payloads add category, vibe IDs, status, bilingual/source/contact metadata without replacing old fields. Details keep `place_vibes` relations; Flutter accepts either representation. Curator create/PATCH accepts the new metadata and mappings. DELETE is archival; historical GET remains available.

Firebase-authenticated curators (`PLACES_CURATOR_UIDS`) use `POST /api/places/sync` with optional `{dryRun,limit,dueOnly}`, `GET /sync/status`, and paged `GET /sync/history?limit=20&offset=0`. Status includes last full successful synchronization, next due, live lease and last run. POST returns the completed run or a not-due result; a held lease returns 409. The external `POST /sync/worker` requires the separate server-only bearer secret (at least 32 characters), always enforces due-only and ignores client import options. It runs synchronously; use the standalone CLI scheduler when the hosting proxy cannot allow the import duration. Swagger is augmented in `config/places-openapi.ts`; [HTTP verification](audit/PLACES_OPENAPI_RESULTS.json).


## Saved place cards and filter — 2026-11-14

GET /api/places/saved retains saved-place IDs/timestamps and adds nested places (including category and place_vibes). POST/DELETE /api/places/:id/save remain the canonical bookmark mutations. No new endpoint or migration.


## MapLibre client viewport integration — 2026-11-14

No endpoint or schema changed. Both map adapters use existing GET /api/places with status=active, bbox=west,south,east,north, categories, vibes, search, limit=50 and offset. The outing picker retains intersecting nearby coordinates/radius filters. Discover searches the active catalog across bounds while search text is nonempty; clearing search restores the current visible bounds. Discover All/Clear Filters remove category/vibe IDs while retaining search and bounds. Discover orders loaded viewport places locally by user distance without restricting manual exploration to a GPS radius. The client debounces viewport reads, cancels superseded Dio requests, retains next raw-page offset separately from displayed/deduplicated places, and fetches up to ten pages per burst before explicit Load more. Existing details, taxonomy, revision, geocoder and outing creation contracts remain unchanged.

[Read-only served Swagger/OpenAPI results](audit/MAPLIBRE_OPENAPI_RESULTS.json): parameter/response contracts, bilingual taxonomy, empty catalog/bounds responses and invalid-request statuses were verified through HTTP. The configured database has zero active places at verification time, so non-empty pagination, category/vibe result intersection and real-place details/search checks are explicitly NOT_RUN. No records were inserted or migrated to satisfy these checks.


Discover map-first verification: [23 passed read-only Swagger/OpenAPI checks](audit/DISCOVER_MAP_OPENAPI_RESULTS.json), including Arabic/English query acceptance, multiple taxonomy IDs and bounded distance sorting. The configured target returned zero active places; non-empty pagination/search/detail intersections remain NOT_RUN. Existing Create Outing request/authorization contracts are unchanged; the selected-place handoff is client navigation only.


Group DELETE clarification (2026-11-14): `deleteGroup` now returns 409 for other active members as well as existing outings. Ownership is rechecked under the group lock; the response envelope and URL are unchanged. `updateGroup` retains its ordinary owner-only editing rule and has no sole-member restriction. Notification settings retain GET/PATCH `/api/notifications/preferences`; strict partial boolean `pushEnabled` writes remain per caller, independent of OS permission. [Scoped HTTP/OpenAPI verification](audit/HOME_GROUP_SETTINGS_OPENAPI_RESULTS.json).


Arrival startup / mark-all presentation (2026-11-14): no API contract changes. Flutter delays arrival roster GET and GPS verification PUT until the outing’s scheduled start. The response’s existing open/opens_at/closes_at gate remains authoritative; backend arrival verification continues to reject before-start and after-window proofs. Notifications’ app-bar action uses the existing markAllNotificationsRead operation. [Scoped Swagger/OpenAPI HTTP evidence](audit/NOTIFICATIONS_ARRIVAL_OPENAPI_RESULTS.json).


## Current free-source catalog contracts — 2026-11-15

These changes supersede the earlier OSM-only scheduler contract. Existing GET `/api/places` retains its array/envelope and offset pagination, adding all-four `minLat,minLng,maxLat,maxLng` bounds aliases, `category` as an alias for categories, and a filter/sort-bound opaque `cursor`. `pagination.next_cursor` uses stable keyset ordering, retaining PostgreSQL timestamp microseconds. Limits remain 1–100. Mixed incomplete/conflicting bounds and invalid/mismatched cursors return 400. Existing bbox/category/vibe/search/distance filters and public-read/curator-write rules remain.
- Clients reconciling viewport caches use `bbox`, `compact=true`, and `sort=id` with each `next_cursor` until `has_more` is false. The UUID order stays stable across updates to a place's name and details.

GET `/api/places/geojson` (`getPlacesGeoJson`) requires geographic bounds and returns `application/geo+json`: a FeatureCollection with Point [longitude,latitude], place_id/name/bilingual names/category/vibe IDs/icon, pagination and attribution. Marker responses exclude details/images and internal sync evidence. GET `/api/places/:id` additionally includes category, place_vibes, place_hours, licensed place_images and available place_prices. Missing price_level is nullable; missing photos use existing fallback behavior. Public catalog/details/saved-place projections exclude source_tags, curator flags, absence counters and administrative logs.

GET `/api/places/licenses` (`getPlacesLicenses`) makes source license text/notices and attribution available; list/GeoJSON responses link it with rel=license. Overture source attribution is additive to OSM. Manual curator POST `/api/places/sync` accepts optional source=overture|osm, city=cairo|giza, dryRun and explicit limit. `/sync/status` reports automatic_sync_enabled=false, manual run history and lease status. The scheduled `/sync/worker` operation, worker secret and dueOnly option are removed. Sync history remains authenticated/curator-only. No automatic places schedule remains in this checkout.

See [real served-Swagger checks and import evidence](audit/PLACES_INGESTION.md). Older zero-place verification statements are historical; use the current results for populated-data checks.

## Home recommendations and Discover viewport

Home uses public GET `/api/places/recommendations?limit=8`. The valid range is 1–24 and the default is 8. It returns a cached random sample of active records with names, area, vibe and one cover URL. Optional paired `lat` and `lng` sample nearby places within 5 km of a center rounded to two decimals. The server refresh window is configured with `PLACE_RECOMMENDATIONS_TTL_SECONDS` and defaults to 900 seconds.

Discover uses `GET /api/places?bbox=…&compact=true` for card and pin fields and loads detail by place ID only when requested. Pagination and attribution stay available. A bbox with west greater than east crosses the antimeridian. Clients that omit `compact` continue to receive the original catalog fields.

## Offline place catalog

Public GET `/api/places/changes` returns `{success, data: {changes, cursor, has_more}}`. Omit the cursor to bootstrap, then replay the opaque cursor with each request. The default page size is 250 and the maximum is 500. Each change carries `kind`, `id`, and the current public record. A null record removes the entity from the browsing catalog. Kinds are place, brand, category, and vibe. Store each page and its cursor in one transaction. A finished page still returns a checkpoint for the next refresh. PostgreSQL transaction snapshots hold the watermark below uncommitted writers.

GET `/api/places?bbox=…&details=true` adds image references, hours and prices for explicit offline-region downloads. The Flutter app uses this bounded route when downloading a region and uses demand-driven reads for ordinary browsing.

## Socket lifecycle compatibility — 2026-11-15

No REST or Socket.IO wire contract changes. Clients now acquire the shared authenticated transport only for current feature demand and leave/dispose it on final release or suspend it in inactive/background/offline states. Group/chat join authorization remains server-side; leave/disconnect invalidate pending joins. Existing history/send/read/edit/delete and reconciliation contracts remain authoritative. [188 served Swagger/OpenAPI checks](audit/SOCKET_LIFECYCLE_OPENAPI_RESULTS.json) passed across 111 documented operations (93 protected operations, missing/malformed authentication). Authenticated payloads, live messaging and socket lifecycle were NOT RUN; see [scope and evidence](audit/SOCKET_LIFECYCLE.md).


## Multi-branch places — 2026-11-15

Places remain physical branches with stable UUIDs and existing outing/vote, taxonomy, hours, image and price relations. Nullable place_brands association and bilingual aliases identify shared brands. Explicit brand evidence and conservative address/distance matching prevent name-only physical merges; ambiguous matches are logged. Independent places remain supported. Existing source/type/source_id fields provide namespaced external identity, with an additional SQL uniqueness index.

GET /api/places accepts brand_id; GET /api/place-brands/:id and /:id/branches expose metadata and paginated physical branches. Nearby and detail DTOs carry brand/branch metadata. Flutter reuses catalog Provider/repository/cache queries for explicit branch selection; map pins and outing payloads retain physical IDs and coordinates. No category/vibe defaults are inherited. Existing manual import operation is retained; no weekly scheduler is restored.

Verification: ten requested scenarios passed through served Swagger/HTTP against local PostgreSQL/WASM, migration applied twice, 15 catalog logic tests passed, TypeScript and Prisma validation passed. Targeted Dart analysis has no errors/warnings and three existing style infos. Flutter runtime, themes/locales/sizes/input states and device/realtime behavior were not exercised. See audit/PLACE_BRANCHES_OPENAPI_RESULTS.json and audit/PLACE_BRANCHES_MIGRATION_DEPLOYMENT.json for deployment status.


## Location tie/revote contract — 2026-11-15

Equivalent existing routes are extended rather than duplicated:

| Method | Route | Behavior |
|---|---|---|
| GET | `/api/outings/:id/voting-state` | Existing results plus `voting_state`, `current_round` (ID/number/deadline/status), eligible `options`/counts, `tiedOptionIds`, confirmed venue, `resolution_method`, creator-only `can_resolve_tie` |
| POST | `/api/outings/:id/tie-break` | `{ method: "random", round_number }`; persisted `outing`, `winningOptionId`, `confirmed_location`, and `confirmed_location_id` for catalog places |
| POST | `/api/outings/:id/voting/revote` | `{ deadline: ISO8601, round_number: positive integer }`; new empty round in the same voting-state envelope |

PUT/POST votes, random resolution, and revote accept `round_number`. DELETE votes accepts it as a query parameter. Omission targets round 1. Resolution routes return 403 for participants other than the outing creator. Results and resolution routes return 404 for missing or inaccessible outings. Invalid input returns 400, missing authentication returns 401, and closed, expired, stale, or conflicting operations return 409. Closed-round tallies use persisted snapshots. The backend selects and saves the random winner before responding.

Outing PATCH locks deadline fields once a round closes or a revote starts. Manual venue confirmation remains available for a single candidate. For multiple candidates, the manual action ends at the voting deadline.

See [served Swagger HTTP verification](audit/LOCATION_TIE_OPENAPI_RESULTS.json). The verifier controls Firebase token verification and uses real route/controller/service/Prisma behavior against local disposable PostgreSQL/WASM. Production business mutations and live Firebase/FCM were not exercised.

## Operational HTTP surfaces

`GET /health/live` reports process liveness. `GET /health/ready` returns 200 or 503 based on initialized dependencies and the shared PostgreSQL probe. `GET /health` retains its legacy 200/500 envelope. `GET /metrics` and `GET /health/dependencies` require the private monitoring bearer. `POST /monitoring/mobile` is opt-in, authenticated with Firebase and limited by account, IP and batch size. OpenAPI JSON is served at `/api-docs/openapi.json` in development and test.

JSON parsing returns the standard error envelope with 400 for malformed bodies, 413 for oversized bodies and 415 for unsupported encodings or charsets. Production authentication can return 503 when Firebase is unavailable. Production has no mock media routes and reports 503 when a media operation needs unavailable storage.

The server accepts `X-Request-ID`, `X-Correlation-ID`, `X-Client-Source` and `X-Request-Trigger`. It exposes validated request and correlation IDs, the normalized route template and `Server-Timing` when observability is enabled. Existing application envelopes and route paths remain available. Swagger now documents the vote-option write 403 and the replacement options array. See the [route and Flutter consumer inventory](audit/API_CONSUMERS.md).
