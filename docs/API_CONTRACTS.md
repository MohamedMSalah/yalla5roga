# Yalla 5roga — API Contracts

| Metadata | Value |
|----------|-------|
| Last verified | 2026-11-08 |
| Documentation version | 1.0.0 |
| OpenAPI UI | `GET /api-docs` (generated from route JSDoc + `config/swagger.ts`) |
| Flutter paths | `flutter/lib/core/constants/api_constants.dart` |
| Needs verification | Exact response field aliases per endpoint under live traffic; place CRUD admin clients |

Convention: JSON, snake_case bodies for most write APIs. Auth: `Authorization: Bearer <Firebase ID token>` unless noted. Success envelope typically `{ success, data }`.

**Do not invent endpoints.** Below lists routes verified in `backend/src/routes/**`.

## System

| Method | Path | Auth | Purpose |
|--------|------|------|---------|
| GET | `/` | No | Process alive |
| GET | `/health` | No | DB `SELECT 1` |

## Auth — `/api/auth`

| Method | Path | Auth | Body | Purpose | Flutter |
|--------|------|------|------|---------|---------|
| POST | `/api/auth/login` | No | email, password | Neon hash verify → Firebase session tokens | `ApiConstants.login` |
| POST | `/api/auth/signup` | No | name, email, password, phone | Neon user + Firebase identity | `ApiConstants.signup` |
| POST | `/api/auth/change-password` | Yes | currentPassword, newPassword | Update Neon `password_hash` | `ApiConstants.changePassword` |
| POST | `/api/auth/verify-password` | Yes | password | Confirm Neon password (no change) | `ApiConstants.verifyPassword` |

Errors: 400 validation, 401 bad credentials, 409 conflict, 429 rate limit (when configured).

Public user payloads include `has_password` (boolean; credential hash never returned) plus profile fields such as `created_at`.

## Users — `/api/users`

| Method | Path | Auth | Purpose | Flutter |
|--------|------|------|---------|---------|
| GET | `/api/users/cuser` | Yes | Current Neon user (`created_at`, `has_password`, …) | settings / `AuthProvider.refreshProfile` |
| PATCH | `/api/users/cuser` | Yes | Update profile | settings |
| DELETE | `/api/users/cuser` | Yes | Delete self | optional |
| POST | `/api/users/sync` | Yes | Upsert Neon user from Firebase claims | `ApiConstants.syncUser` |
| GET | `/api/users/` | Yes | List users | — |
| GET | `/api/users/:id` | Yes | Get by id | — |
| DELETE | `/api/users/:id` | Yes | Delete by id (self rules in use case) | — |

Entities: `users`.

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
| GET | `/api/groups` | Yes | List (query filters; includes `member_count`) |
| POST | `/api/groups` | Yes | Create (`image_url` optional; omit or `""` for default cover). Creator is inserted as `group_members` owner; response includes `member_count: 1`, `my_role: owner` |
| GET | `/api/groups/:id` | Yes | Get (includes `member_count`) |
| PATCH | `/api/groups/:id` | Yes | Update (owner; `image_url` optional) |
| DELETE | `/api/groups/:id` | Yes | Delete (owner) |
| GET | `/api/groups/:id/members` | Yes | Members (enriched with `name`, `phone`, `image_url`; creator included from create) |
| POST | `/api/groups/:id/members` | Yes | Add member |
| DELETE | `/api/groups/:id/members/:userId` | Yes | Remove member |
| POST | `/api/groups/:id/invitations` | Yes | Invite by phone (+ WhatsApp outbox) |
| POST | `/api/groups/invitations/:invitationId/decline` | Yes | Decline invite |

Flutter: `ApiConstants.groups*`. Entities: `groups`, `group_members`, `group_invitations`. Create/details reload members so the owner card and count ≥ 1 appear immediately.

## Outings — `/api/outings`

| Method | Path | Auth | Purpose | Notes |
|--------|------|------|---------|-------|
| GET | `/api/outings/cuser` | Yes | My outings | created / invited / group |
| GET | `/api/outings` | Yes | List | query groupId/userId |
| POST | `/api/outings` | Yes | Create | requires deadline; `image_url` optional http(s); owner Going |
| GET | `/api/outings/:id` | Yes | Get | |
| PATCH | `/api/outings/:id` | Yes | Update | Owner; confirmed location locked |
| DELETE | `/api/outings/:id` | Yes | Delete | Owner |
| POST | `/api/outings/:id/cancel` | Yes | Cancel | Owner |
| GET/POST | `/api/outings/drafts` | Yes | List/create drafts | |
| PATCH/DELETE | `/api/outings/drafts/:id` | Yes | Update/delete draft | owner |
| GET/PUT | `/api/outings/:id/attendance` | Yes | List / set own | statuses going/not_going/maybe |
| GET/POST | `/api/outings/:id/guests` | Yes | List / invite | membership |
| POST | `/api/outings/:id/invitations/accept` | Yes | Accept invite | → Member |
| POST | `/api/outings/:id/invitations/decline` | Yes | Decline | |
| DELETE | `/api/outings/:id/guests/:userId` | Yes | Remove guest | Owner; self-leave forbidden |
| GET/POST | `/api/outings/:id/vote-options` | Yes | List / add option | Owner add; resets votes |
| PUT | `/api/outings/:id/vote-options` | Yes | Replace options | resets votes; keeps deadline |
| DELETE | `/api/outings/:id/vote-options/:optionId` | Yes | Delete option | resets votes |
| GET/POST | `/api/outings/:id/votes` | Yes | List / cast | upsert; early close |
| DELETE | `/api/outings/:id/votes` | Yes | Remove my vote | if open |
| DELETE | `/api/outings/:id/votes/:optionId` | Yes | Remove my vote for option | |
| GET | `/api/outings/:id/voting-state` | Yes | Tallies / closure meta | |
| POST | `/api/outings/:id/tie-break` | Yes | Owner RNG among tied leaders | |

Flutter consumes these via `OutingsRemoteDataSource` / `ApiConstants.outing*`.

Entities: `outings`, `outing_guests`, `outing_attendance`, `outing_vote_options`, `outing_votes`, `outing_drafts`.

Possible errors: 400 validation, 401, 403 forbidden, 404, 409 conflict (closed voting, attendance closed, etc.).

## Saved outings / places

| Method | Path | Auth | Purpose | Flutter |
|--------|------|------|---------|---------|
| GET | `/api/outings/saved` | Yes | List saved outings | `savedOutings` |
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
| POST/PATCH/DELETE | `/api/places`… | Yes | CRUD |
| GET/PUT/DELETE | `/api/places/:id/hours`… | mix | Hours |
| GET/POST/DELETE | `/api/places/:id/images`… | mix | Images |
| GET/POST/DELETE | `/api/places/:id/prices`… | mix | Prices |

\*List/get/nearby are public in route file (no `authMiddleware` on those GETs). Mutations require auth.

Flutter Discover uses list/detail (+ saved places). Nearby may be unused by Flutter (client Nominatim for picker).

## Notifications — `/api/notifications`

| Method | Path | Auth | Purpose | Flutter |
|--------|------|------|---------|---------|
| GET | `/api/notifications` | Yes | Inbox | `notifications` |
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

Room name: `outing:{outingId}`. Persistence is REST-only; sockets never create chat rows.

## Related

- OpenAPI freeze notes: `docs/system-design/openapi-contract-freeze.md` (may lag — prefer route sources)
- Older mismatch matrix: `docs/system-design/api-contract-matrix.md` is **historical** and partly superseded by `/api` prefix + compliance fixes
