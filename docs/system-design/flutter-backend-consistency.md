# Phase 3 — Flutter ↔ Backend Consistency Audit

**Generated:** 2026-11-06  
**Sources:** Flutter `lib/core/constants/api_constants.dart`, feature `*_remote_datasource.dart` files; Backend `src/routes/**`, validators, controllers, Prisma schema.

Companion matrix: [api-contract-matrix.md](./api-contract-matrix.md).

---

## Summary verdict

The Flutter live API layer and the Node backend were clearly evolved **toward the same product**, but they do **not** currently share a single HTTP contract. With `USE_MOCK_DATA=true` (debug default), this is masked. With `USE_MOCK_DATA=false` and default `API_BASE_URL=http://10.0.2.2:3000`, nearly every Dio call will **404** (missing `/api` prefix) or **400/422** (body/schema mismatch) even if the prefix is fixed.

| Category | Count (approx.) |
|----------|-----------------|
| MATCH | 1–2 (Bearer auth mechanism; some enum *sets*) |
| PARTIALLY IMPLEMENTED | ~10 |
| MISMATCH | ~20+ |
| MISSING IN BACKEND | ~5 |
| MISSING IN FLUTTER | ~25+ backend routes unused by app |

---

## Comparison table (feature-oriented)

| Feature | Flutter API | Backend API | Status | Issue |
|---------|-------------|-------------|--------|-------|
| API base / prefix | Paths like `/groups`; base host only | Mounted under `/api/...` | MISMATCH | Default base URL lacks `/api` — `flutter/.env.example` L18; `backend/src/routes/auth/auth.routes.ts` L97 |
| Auth header | Bearer Firebase ID token via `AuthInterceptor` (`dio_interceptors.dart`) | `authMiddleware` + `verifyIdToken` (`auth.middleware.ts`) | MATCH | Mechanism aligns once routes hit |
| Register / provision | `POST /auth/register` profile body (`auth_remote_datasource.dart` L42–47) | `POST /api/auth/signup` password body **or** `POST /api/users/sync` | MISMATCH | Path, body, and credential model diverge; Flutter comments deny Neon passwords (`api_constants.dart` L6–7) while schema has `password_hash` |
| Login | Firebase-only; `/auth/login` unused | `POST /api/auth/login` Neon bcrypt | MISMATCH | Dual sources of truth for passwords |
| Google / Apple | Firebase → `_provisionBackendUser` → register | Documented sync path | MISMATCH | Wrong Flutter target endpoint |
| Profile update | `PATCH /user/profile` `imageUrl` | `PATCH /api/users/cuser` `image_url` | MISMATCH | Path + casing (`user.validator.ts` L70–84) |
| Groups list/create | `/groups` camelCase rich JSON | `/api/groups` snake_case minimal create | MISMATCH | See `groups_remote_datasource.dart`, `group.validator.ts` |
| Group update | `PUT` | `PATCH` | MISMATCH | HTTP method |
| Add member / invite | member object JSON | `phoneNumber` (+ invitations resource) | MISMATCH | `addGroupMemberBodySchema` / `inviteToGroupBodySchema` |
| Leave group | `POST /groups/:id/leave` | none | MISSING IN BACKEND | `ApiConstants.groupLeave` |
| Outings list | Aggregate snapshot with votes/attendance maps | Flat `Outing[]` | MISMATCH | `outings_remote_datasource.dart` L56–73 vs `outing.controller.ts` L64–70 |
| Create outing / suggest | camelCase + nested places | snake_case Zod + separate options | MISMATCH | `createOutingBodySchema` |
| Voting | `optionIndex` / `finalize` / `clear` | `option_id` + option CRUD | MISMATCH | `castVoteBodySchema` L113–115 |
| Attendance | `POST` + `userId` + camelCase enum `.name` | `PUT` + token user + snake_case enum | MISMATCH | `AttendanceStatus.notGoing` → `"notGoing"` ≠ `"not_going"` |
| Chat messages | `/outings/:id/chat/messages` | `/api/chat/outings/:outingId/messages` | MISMATCH | Path nesting (`chat.routes.ts`) |
| Chat mark read | `POST …/chat/read` | no route (`chat_reads` table only) | MISSING IN BACKEND | |
| Notifications list | `{unreadCount, items}` camelCase | `data: Notification[]` snake_case | MISMATCH | `notification_model.dart` vs `notification.controller.ts` |
| Notification read | `POST` → unreadCount | `PATCH` → entity; no owner check | MISMATCH | Also AUTHZ gap |
| Mark all read | `POST /notifications/read` | none | MISSING IN BACKEND | |
| Saved outings | prefs; unused `/user/saved-outings` | `/api/outings/saved` + `/:id/save` | MISMATCH | Flutter never calls backend |
| Drafts | prefs | `/api/outings/drafts` | MISSING IN FLUTTER | |
| Places list/detail | `/places` | `/api/places` | PARTIALLY IMPLEMENTED | Field naming; nearby unused |
| FCM token | prefs + unused constant | table, no API | MISSING IN BACKEND | |
| Unread counts | unused constant | none | MISSING IN BACKEND | |
| Image upload | local paths only | URL strings only | PARTIALLY IMPLEMENTED | Both sides lack binary upload |
| Date/time | ISO strings / `DateTime.tryParse` | `timestamptz` via Prisma JSON ISO | PARTIALLY IMPLEMENTED | OK if ISO UTC; display TZ not centralized |
| Pagination | not used on Flutter lists | list endpoints return full arrays | PARTIALLY IMPLEMENTED | No cursor/limit contract either side for chat/outings |
| Error envelope | status → `AppException`; message opaque | `{success:false,message}` | PARTIALLY IMPLEMENTED | No shared error codes except a few chat strings |
| Nullable fields | defensive `apiString` helpers | Prisma nullables + Zod optional | NEEDS MANUAL VERIFICATION | Per-field runtime tests needed after contract lock |
| Mock mode | `USE_MOCK_DATA` defaults true in debug | N/A | N/A | Hides all mismatches in local UI testing |

---

## Deep-dive: authentication & user synchronization

### Confirmed issues

1. **Credential dual-write risk (P0 product decision)**  
   - Backend signup stores bcrypt in Neon and creates Firebase users **without** a Firebase password (`signup.usecase.ts`).  
   - Flutter signup sets Firebase email/password after phone OTP and never posts password to the API.  
   - Result: accounts created via Flutter cannot log in via `POST /api/auth/login`, and accounts created via backend signup cannot use Flutter’s Firebase email/password login unless passwords are also set in Firebase.

2. **Wrong provisioning endpoint**  
   Flutter `AuthRemoteDataSourceImpl.createUser` → `POST /auth/register`.  
   Backend equivalent for Firebase-first flows is `POST /api/users/sync` (`sync-user.usecase.ts`), which intentionally does **not** overwrite profile fields on later calls.

3. **Profile PATCH path & fields**  
   Flutter `imageUrl` vs backend `image_url`. Sync/update validators accept `phone` / `phoneNumber` aliases but not `imageUrl`.

### References

- `flutter/lib/core/constants/api_constants.dart` L6–14  
- `flutter/lib/features/auth/data/datasources/auth_remote_datasource.dart`  
- `backend/src/routes/auth/auth.routes.ts` L82–97  
- `backend/src/routes/users/user.routes.ts` (sync + cuser)  
- `backend/prisma/schema.prisma` `users.password_hash` L174–176  

---

## Deep-dive: outings, voting, attendance

| Check | Result |
|-------|--------|
| Endpoint exists? | Backend yes; Flutter hits related paths without `/api` |
| Method match? | Attendance POST vs PUT — **no** |
| Body match? | Create/vote/attendance — **no** |
| Enum match? | Attendance casing — **no**; outing status missing `cancelled` on Flutter |
| Response match? | Flutter expects composite snapshot; backend returns arrays/entities — **no** |
| Auth header? | Would be attached — OK |
| Ownership? | Backend update/delete outing — **no caller ownership check** (`update-outing.usecase.ts`, `delete-outing.usecase.ts`) |

---

## Deep-dive: chat

| Check | Result |
|-------|--------|
| URL | Flutter nests under outing; backend under `/api/chat/outings/...` |
| Send body | Flutter sends `senderId`/`sender`; backend ignores and uses token uid; optional `clientMessageId` for idempotency unused by Flutter |
| Response fields | Backend Prisma: `sender_id`, `sent_at`; Flutter reads `senderId`/`sentAt`/`createdAt` with some fallbacks |
| Mark read | Flutter only — backend table unused by routes |

---

## Deep-dive: notifications

| Check | Result |
|-------|--------|
| List shape | Flutter `NotificationsFeedModel` needs `items` + `unreadCount`; backend returns raw array in `data` |
| Field names | `is_read` vs `unread`; `image_url` vs `image`; `outing_id` vs `outingId` |
| Mark read | POST vs PATCH; response unreadCount vs entity |
| AuthZ | `MarkNotificationReadUseCase` loads by id only — any authed user can mark any notification read if they know the UUID |

---

## What needs further investigation (runtime)

1. Whether production/staging `API_BASE_URL` already appends `/api` (not in `.env.example`).  
2. Whether any gateway rewrites Flutter paths to backend paths (no evidence in repo).  
3. Exact JSON samples from Swagger vs Flutter parsers after adapters are fixed — especially group embedded UI fields (`lastMessage`, `unread`).  
4. Timezone display assumptions in outing `meta`/`date`/`time` computed getters vs `scheduled_at` UTC.  
5. Whether `GET /api/users/` is intentionally public-to-authenticated (enumeration risk).

---

## Recommended contract ownership

Until mismatches are closed:

1. Treat **Backend OpenAPI (`/api-docs`)** as source of truth.  
2. Rewrite Flutter `ApiConstants` + remote datasources to match.  
3. Avoid adding backend “compatibility shims” for every Flutter placeholder unless a short-lived migration adapter is explicitly desired.  
4. Add a contract test suite (Flutter golden request fixtures vs Zod schemas, or OpenAPI spectral + Pact-style checks).
