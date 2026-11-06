# API Contract Matrix

Legend for **Status**:
- **MATCH** — method, path family, and primary contract align (minor field aliasing only)
- **MISMATCH** — both sides exist but contract differs materially
- **MISSING IN BACKEND** — Flutter references / calls it; backend has no equivalent
- **MISSING IN FLUTTER** — backend implements it; Flutter has no live Dio call
- **PARTIALLY IMPLEMENTED** — overlapping intent but incomplete on one or both sides
- **NEEDS MANUAL VERIFICATION** — requires runtime check beyond static analysis

**Prefix note:** Backend mounts under `/api`. Flutter `ApiConstants` omit `/api`. Unless `API_BASE_URL` ends with `/api`, every Flutter call misses the mount. Default `.env.example` is `http://10.0.2.2:3000` (**no** `/api`). This alone makes live integration fail.

---

## Auth & users

| Feature | Flutter API | Backend API | Status | Issue |
|---------|-------------|-------------|--------|-------|
| Email/password signup | Firebase Auth only; then `POST /auth/register` profile | `POST /api/auth/signup` `{name,email,password,phone}` → Neon hash + Firebase identity | MISMATCH | Different credential store and path; Flutter never sends password to API |
| Email/password login | Firebase `signInWithEmailAndPassword`; `ApiConstants.login` unused | `POST /api/auth/login` | MISMATCH | Dual login models; Flutter constant unused |
| Provision after Firebase | `POST /auth/register` Bearer + `{name,email?,phone?,imageUrl?}` | `POST /api/users/sync` Bearer + optional body | MISMATCH | Path `/auth/register` vs `/api/users/sync`; semantics differ (Flutter expects upsert profile; sync is identity-minimal) |
| Current user get | — | `GET /api/users/cuser` | MISSING IN FLUTTER | |
| Profile update | `PATCH /user/profile` camelCase `imageUrl` | `PATCH /api/users/cuser` snake_case `image_url` | MISMATCH | Path + field names |
| Delete self | — | `DELETE /api/users/cuser` or `DELETE /api/users/:id` (self only) | MISSING IN FLUTTER | |
| List users | — | `GET /api/users/` | MISSING IN FLUTTER | Admin/debug style; verify if intentional |
| Get user by id | — | `GET /api/users/:id` | MISSING IN FLUTTER | |

---

## Groups & invitations

| Feature | Flutter API | Backend API | Status | Issue |
|---------|-------------|-------------|--------|-------|
| List groups | `GET /groups` | `GET /api/groups` or `/api/groups/cuser` | PARTIALLY IMPLEMENTED | Prefix; response shape camel vs snake; Flutter expects `items`/`groups` wrappers |
| Get group | `GET /groups/:id` | `GET /api/groups/:id` | PARTIALLY IMPLEMENTED | Field naming; Flutter UI fields (`outings`, `unread`, `lastMessage`) not in Prisma group |
| Create group | `POST /groups` + `Group.toJson()` (id, outings, people, …) | `POST /api/groups` `{name, bio?, image_url?}` | MISMATCH | Extra client fields; `image` vs `image_url` |
| Update group | `PUT /groups/:id` | `PATCH /api/groups/:id` | MISMATCH | HTTP method + body shape |
| Delete group | — | `DELETE /api/groups/:id` | MISSING IN FLUTTER | |
| List members | — (embedded in group JSON) | `GET /api/groups/:id/members` | PARTIALLY IMPLEMENTED | |
| Add member | `POST /groups/:id/members` + member JSON | `POST /api/groups/:id/members` `{phoneNumber, role?}` | MISMATCH | Body contract |
| Remove member | `DELETE /groups/:id/members/:memberId` | `DELETE /api/groups/:id/members/:userId` | PARTIALLY IMPLEMENTED | Path param name; prefix |
| Leave group | `POST /groups/:id/leave` | — (could DELETE self as member) | MISSING IN BACKEND | |
| Invite by phone | UI sheet exists; uses add-member path | `POST /api/groups/:id/invitations` + WhatsApp URL outcomes | MISMATCH | Flutter does not call invitations API |
| Decline invitation | — | `POST /api/groups/invitations/:invitationId/decline` | MISSING IN FLUTTER | |

---

## Outings

| Feature | Flutter API | Backend API | Status | Issue |
|---------|-------------|-------------|--------|-------|
| List outings | `GET /outings` expects `outings` + `votesByOuting` + `attendanceByOuting` | `GET /api/outings` returns `data: Outing[]` only | MISMATCH | Aggregate snapshot vs flat list |
| Create outing | `POST /outings` camelCase rich JSON | `POST /api/outings` snake_case Zod schema | MISMATCH | Field names, nested places, status rules |
| Suggest places / voting create | `POST /outings` with `places[]`, `deadlineHours`, `status: voting` | Create outing + separate vote-option posts | MISMATCH | |
| Get / update / delete outing | `outing(id)` constant unused | `GET|PATCH|DELETE /api/outings/:id` | MISSING IN FLUTTER | Update/delete lack ownership checks on backend (security) |
| Guests | via create payload `guestIds` | `GET|POST|DELETE /api/outings/:id/guests` | MISMATCH / PARTIAL | |
| Attendance get | embedded in list snapshot | `GET /api/outings/:id/attendance` | PARTIALLY IMPLEMENTED | |
| Attendance set | `POST …/attendance` `{userId, status}` with `notGoing`/`notVoted` | `PUT …/attendance` `{status}` `going\|not_going\|not_voted` for token user | MISMATCH | Method, actor, enum casing |
| List vote options | embedded | `GET …/vote-options` | PARTIALLY IMPLEMENTED | |
| Add / remove vote option | via create suggest payload | `POST|DELETE …/vote-options` | MISMATCH | |
| Cast / toggle vote | `POST …/votes` `{optionIndex, toggle}` | `POST …/votes` `{option_id}` | MISMATCH | |
| Finalize / clear votes | `POST …/votes` `{finalize\|clear}` | Update outing / DELETE vote — no finalize/clear flags | MISMATCH | |
| Drafts | prefs only | `/api/outings/drafts` CRUD | MISSING IN FLUTTER | |
| Saved outings | prefs; constants `/user/saved-outings` unused | `GET /api/outings/saved`, `POST|DELETE /api/outings/:id/save` | MISMATCH | Different path family; Flutter not calling API |

---

## Chat

| Feature | Flutter API | Backend API | Status | Issue |
|---------|-------------|-------------|--------|-------|
| List messages | `GET /outings/:id/chat/messages` | `GET /api/chat/outings/:outingId/messages` | MISMATCH | Path nesting + prefix |
| Send message | `POST` same + `{text, senderId, sender}` | `POST` + `{text, clientMessageId?}`; sender = token uid | MISMATCH | Path; client must not trust senderId; snake_case response (`sent_at`, `sender_id`) |
| Mark chat read | `POST /outings/:id/chat/read` | — (`chat_reads` table only) | MISSING IN BACKEND | |

---

## Places / discover

| Feature | Flutter API | Backend API | Status | Issue |
|---------|-------------|-------------|--------|-------|
| List places | `GET /places?vibe=` | `GET /api/places` (+ query schema) | PARTIALLY IMPLEMENTED | Prefix; Flutter `coverImageUrl` vs `cover_image_url` |
| Get place | `GET /places/:id` | `GET /api/places/:id` | PARTIALLY IMPLEMENTED | |
| Nearby | Nominatim / client geo UI | `GET /api/places/nearby` | MISSING IN FLUTTER | Backend haversine unused by app |
| Place CRUD + hours/images/prices | — | Full nested routes under `/api/places` | MISSING IN FLUTTER | Likely admin/content tooling |

---

## Notifications & push

| Feature | Flutter API | Backend API | Status | Issue |
|---------|-------------|-------------|--------|-------|
| List notifications | `GET /notifications` expects `{unreadCount, items[]}` with camelCase | `GET /api/notifications` `{success, data: Notification[]}` snake_case `is_read`, `image_url`, `outing_id` | MISMATCH | Envelope + field names; no unreadCount aggregate |
| Mark one read | `POST /notifications/:id/read` → `unreadCount` | `PATCH /api/notifications/:id/read` → notification object | MISMATCH | Method + response; **no ownership check** on backend |
| Mark all read | `POST /notifications/read` | — | MISSING IN BACKEND | |
| Unread counts | `ApiConstants.unreadCounts` unused | — | MISSING IN BACKEND | Also unused in Flutter |
| FCM token register | constant `/user/fcm-token` unused; token in prefs | Table `user_fcm_tokens` — no routes | MISSING IN BACKEND / FLUTTER | |
| FCM send | receive only | not implemented | PARTIALLY IMPLEMENTED | |

---

## System

| Feature | Flutter API | Backend API | Status | Issue |
|---------|-------------|-------------|--------|-------|
| Health | — | `GET /`, `GET /health` | MISSING IN FLUTTER | OK for ops |
| OpenAPI | — | `/api-docs` | N/A | Contract source of truth candidate |
| Geocoding | Nominatim direct | — | N/A | Client-side only |
| Image upload | local picker paths | URL strings only | PARTIALLY IMPLEMENTED | Neither side uploads binaries |

---

## Enum alignment

| Enum | Flutter | Backend | Status |
|------|---------|---------|--------|
| `OutingStatus` | `upcoming, voting, past` | `upcoming, voting, past, cancelled` | MISMATCH |
| `AttendanceStatus` | `going, notGoing, notVoted` (`.name`) | `going, not_going, not_voted` | MISMATCH |
| `OutingOccasion` | `none, birthday, wedding` | same | MATCH |
| `OutingVibe` | `food, activity, outdoor, movie` | same | MATCH |
| `group_role` | string roles in member JSON | `owner, member` | NEEDS MANUAL VERIFICATION |

---

## Auth header

| Concern | Flutter | Backend | Status |
|---------|---------|---------|--------|
| Bearer ID token | `AuthInterceptor` from Firebase `idToken()` | `authMiddleware` `verifyIdToken` | MATCH (mechanism) |
| Cached prefs token | stored but not used for Dio | — | N/A |
| Error 401/403 | `ErrorInterceptor` → `AuthException` | `UnauthorizedError` / `ForbiddenError` | PARTIALLY IMPLEMENTED | Message-only body; Flutter does not parse structured codes beyond status |
