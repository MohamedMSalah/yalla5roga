# OpenAPI Contract Freeze (Phase A)

**Frozen:** 2026-11-06  
**Source of truth:** Backend OpenAPI at `/api-docs` (`swagger-jsdoc` from `backend/src/config/swagger.ts` + `@openapi` on route files).  
**Client rule:** Flutter adapts to this contract. No camelCase compatibility layer on the API.

## Conventions

| Rule | Value |
|------|-------|
| Base prefix | `/api` |
| Field naming | snake_case (`image_url`, `group_id`, `option_id`, `is_read`, `created_by`) |
| Success envelope | `{ "success": true, "data": T }` |
| Sync special case | Also returns top-level `invitations` |
| Error envelope | `{ "success": false, "message": string }` + HTTP status |
| Auth header | `Authorization: Bearer <Firebase ID Token>` |
| OpenAPI security | `bearerAuth` on protected routes |

## Authentication (canonical)

1. Client signs in with **Firebase Authentication** (phone OTP, Google, Apple, or Firebase email/password).
2. Client obtains a Firebase **ID token**.
3. Client calls **`POST /api/users/sync`** with the Bearer token (canonical provisioning).
4. Profile edits use **`PATCH /api/users/cuser`** (`name`, `email`, `phone`/`phoneNumber`, `image_url`).
5. All subsequent APIs use the same Bearer token; backend verifies via Firebase Admin `verifyIdToken`.

### Deprecated (still implemented, not for Flutter)

| Method | Path | Notes |
|--------|------|-------|
| POST | `/api/auth/login` | Neon `password_hash` → custom token |
| POST | `/api/auth/signup` | Neon `password_hash` + Firebase identity without Firebase password |

## Authorization (enforced)

| Resource action | Rule |
|-----------------|------|
| Outing PATCH/DELETE | Caller must be `created_by` |
| Outing guests add/remove | Caller must be `created_by` |
| Vote option create/delete | Caller must be `created_by` |
| Group PATCH/DELETE | Caller must be `group_members.role = owner` |
| Group member add/remove | Caller must be owner; cannot remove last owner |
| Group invite | Any group member |
| Notification mark read | Caller must own `notification.user_id` |
| Chat send/list | Creator or guest (existing) |
| Drafts | Draft owner (existing) |

## Key Flutter-facing endpoints

| Method | Path | Body / notes |
|--------|------|--------------|
| POST | `/api/users/sync` | Optional bootstrap fields; uid from token |
| GET/PATCH/DELETE | `/api/users/cuser` | Profile |
| GET/POST | `/api/groups` | Create: `{ name, bio?, image_url? }` |
| GET/PATCH/DELETE | `/api/groups/:id` | Owner for mutate |
| GET/POST | `/api/groups/:id/members` | POST body `{ phoneNumber, role? }` — owner |
| DELETE | `/api/groups/:id/members/:userId` | Owner |
| POST | `/api/groups/:id/invitations` | `{ phoneNumber }` — any member |
| GET/POST | `/api/outings` | Create snake_case Zod schema |
| GET/PATCH/DELETE | `/api/outings/:id` | Creator for mutate |
| PUT | `/api/outings/:id/attendance` | `{ status: going\|not_going\|not_voted }` |
| POST | `/api/outings/:id/votes` | `{ option_id }` |
| GET/POST | `/api/outings/:id/vote-options` | Creator for POST |
| GET/POST | `/api/chat/outings/:outingId/messages` | Send `{ text, clientMessageId? }` |
| PATCH | `/api/chat/outings/:outingId/read` | Participant; upserts `chat_reads` |
| GET | `/api/notifications` | `data: Notification[]` |
| PATCH | `/api/notifications/read` | Mark all owned notifications read; `{ count }` |
| PATCH | `/api/notifications/:id/read` | Owner only |
| GET | `/api/places` | Optional filters |

## Enums (API wire values)

- `attendance_status`: `going`, `not_going`, `not_voted`
- `outing_status`: `upcoming`, `voting`, `past`, `cancelled`
- `outing_occasion`: `none`, `birthday`, `wedding`
- `outing_vibe`: `food`, `activity`, `outdoor`, `movie`
- `group_role`: `owner`, `member`

## Explicitly not in Phase A contract

- Dedicated leave-group route  
- FCM token registration  
- `/user/unread-counts`  
- Pagination cursors  

## Validation

Run backend tests including `tests/resource-authz.test.ts`. Inspect `/api-docs` after server start for deprecated auth ops and 403 responses on mutating routes.
