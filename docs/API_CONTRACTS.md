# Yalla 5roga — API Contracts

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
| POST | `/api/groups/:id/invitations` | Yes | Invite by phone. Optional `whatsappOptIn: true` attests recipient agreement. `notification_queued` is true after successful outbox persistence for a consented recipient with a configured provider. The compatibility field `whatsapp_url` is null. Pending membership persists independently. |
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
| GET/PUT | `/api/outings/:id/attendance` | Yes | List or set RSVP | Existing `data` shapes, plus `my_response` and `summary`; PUT also returns current `items`. Identical writes preserve the previous timestamp. |
| GET | `/api/outings/:id/arrivals` | Yes | Participant roster and GPS policy | Returns `arrivals`, `unconfirmed`, `total_confirmed`, `open`, `opens_at`, `closes_at`, `radius_meters`, `max_accuracy_meters` and the confirmed `venue` coordinates. Compatibility fields report `automatic_eligible: true` and `can_confirm_arrivals: false`. |
| PUT | `/api/outings/:id/arrivals/self` | Yes | Verify own GPS arrival | Sends `latitude`, `longitude`, `accuracy` in meters and ISO `captured_at`. Optional `method` accepts `gps` and the older `automatic_gps` spelling. A reported mock fix is rejected. Returns `{ arrived }`. |
| GET/POST | `/api/outings/:id/guests` | Yes | List / invite | Repeated invites preserve pending or accepted membership and its original timestamp. |
| POST | `/api/outings/:id/invitations/accept` | Yes | Accept invite | → Member |
| POST | `/api/outings/:id/invitations/decline` | Yes | Decline | |
| DELETE | `/api/outings/:id/guests/:userId` | Yes | Remove guest | Owner; self-leave forbidden |
| GET/POST | `/api/outings/:id/vote-options` | Yes | List / add option | Owner add; resets votes |
| PUT | `/api/outings/:id/vote-options` | Yes | Replace options | resets votes; keeps deadline |
| DELETE | `/api/outings/:id/vote-options/:optionId` | Yes | Delete option | resets votes |
| GET/POST | `/api/outings/:id/votes` | Yes | List / add one selection | Idempotent selection; existing early close |
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
| POST | `/api/media/:id/confirm` | Yes | Verify the object exists in storage (HEAD) and mark the asset `ready`. Missing object → `409`, asset marked `failed`. |
| POST | `/api/media/signed-urls` | Yes | Batch resolve up to 50 ids. Body `{ media_ids: [...] }`. Returns `data: [{ media_id, url, visibility, expires_at }]` for assets the caller may view. |
| GET | `/api/media/:id/url` | Yes | Resolve one asset to a delivery URL after the same access check. |
| DELETE | `/api/media/:id` | Yes | Delete an owned asset (also used to clean up a failed upload). |

Delivery policy:

- `place` → `visibility=public`. When the `r2` provider is active **and** a real (non-placeholder) `R2_PUBLIC_BASE_URL` is configured, the response URL is the CDN `https://<domain>/<object_key>` with `expires_at: null`; in mock mode or before the CDN domain exists, a short-lived signed URL is returned so the app never receives the placeholder host.
- `profile`, `group`, `outing`, `chat` → `visibility=private`. Delivery uses a short-lived signed GET URL (`expires_at` set); the client must never persist it as the entity value or as the image-cache identity.
- View authorization: profile avatars are visible to any authenticated user; group/outing/chat media require membership/participant checks; public assets require authentication. Ownership mismatch returns `404` for confirm/delete to avoid leaking asset existence.
- Upload authorization: `profile` = self; `group`/`outing` with `entity_id` = group owner/outing creator (entity-less covers are allowed before creation and authorized when attached); `chat` requires an outing id and participant eligibility; `place` mutations are gated by the catalog APIs.
- Failed uploads, expired presigned URLs, and abandoned pending rows are handled by confirm failure + `media-cleanup.job.ts` (deletes storage object and row). The cleanup job also removes failed assets.
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

Open for outing statuses draft/voting/confirmed (backend `chat-access`). Cancelled blocked. Same authZ as before the path move (creator or guest).

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
- `GET /api/outings/:id/guests` includes a `users` projection containing only `name` and `image_url` for participant management. Guest deletion remains creator-only. Group deletion remains owner-only and returns 409 for a group containing outings; it does not cascade-delete those outings. Existing self-member deletion supports Leave Group with the last-owner restriction.
- Arrival coordinates are client-reported evidence, not attested GPS. `is_mocked=true` is rejected; false/omitted grants no trust. Server checks identity, current participation, confirmed pinned venue, coordinate/accuracy bounds, sample age, server time window and distance before its existing upsert. Persisted arrival time is server-generated.

Runtime evidence and unverified authenticated scenarios: `audit/CONFIRMED_FIXES_OPENAPI_RESULTS.json` and `audit/CONFIRMED_FIXES_IMPLEMENTATION_REPORT.md`.

## Phase 2 roster response extension — 2026-11-13

`GET /api/groups/:id/members` retains `success`, active profiles in `data`, and `pending_members`. It adds `invitation_history`, newest first, containing `{ invitation_id, invited_phone, invitee_name: string|null, inviter_name, status, created_at }`; status is `pending|accepted|declined|expired|revoked`. It is scoped to the requested group and protected by the existing active group-member authorization. Pending rows include verified identity-linked invitations (`user_id` may be non-null); linking never makes a member or removes the Pending display. The active membership list and member count are unchanged.

No route, request body, invitation decision behavior or Socket.IO event changed. Flutter's owner name editor forwards the already-supported optional `name` field on the existing group PATCH. Old roster payloads without history decode as an empty history list. Deploy the backend response extension with the client to populate group invitation history. Verification: [OpenAPI results](audit/PHASE_2_OPENAPI_RESULTS.json), [scope and limits](audit/PHASE_2_UI_UX.md).


## Phase 3 multi-location ballot contract — 2026-11-14

`replaceOutingBallot` accepts a full `option_ids` array. Empty array clears the caller’s selections; duplicate, invalid or foreign options fail with 400, nonparticipants with 403, missing outing with 404, and closed/expired voting with 409. Success is `{ success: true, data: { votes: Vote[], resolution: VoteResolution | null } }`. State reads return all caller selections and a distinct voter count, separate from the sum of per-option tallies. Existing POST/DELETE routes remain, and all vote writers reject deadline expiry. Existing realtime outing invalidation is emitted after commit; no Socket.IO wire event changes. `breakTie` now explicitly documents its existing 403/404/409 paths.
