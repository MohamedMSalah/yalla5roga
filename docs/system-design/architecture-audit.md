# Phase 4–6 — Architecture, Security, Performance & Scalability Audit

**Scope:** Backend primary; Flutter called out where it affects system risk.  
**No code was modified.** Findings cite paths; line numbers refer to the tree as of 2026-11-06.

---

## Executive findings (short)

The backend Clean Architecture is coherent and the Prisma schema is thoughtfully constrained. The largest risks are **authorization gaps on mutating endpoints**, **auth model divergence with Flutter**, and **an unconsumable API contract** from the mobile client’s point of view. Performance/scalability are adequate for early launch if P0 authZ and contract issues are fixed first.

---

## 1. Backend architecture evaluation

### Separation of concerns

| Layer | Assessment |
|-------|------------|
| Routes | Thin; OpenAPI JSDoc colocated — good |
| Controllers | Mostly HTTP mapping; some query defaulting (`userId ?? req.user.uid`) |
| Use cases | Business rules live here for many flows (sync, invite claim, chat access) |
| Repositories / datasources | Clear; Prisma isolated from controllers |
| Services | Cross-cutting helpers appropriately extracted |

**Issue ARCH-01 — Manual default DI**  
Controllers/`new UseCase()` / `new Repository()` defaults impede testing substitution and hide dependency graphs.  
**Consequence:** Harder unit testing; accidental singleton assumptions.  
**Priority:** P2  
**Complexity:** Medium (introduce factory or lightweight container gradually).

**Issue ARCH-02 — Inconsistent authorization placement**  
Chat and drafts check access in services/use cases; outing update/delete and notification mark-read do not.  
**Files:** `services/chat/chat-access.ts` (good); `usecases/outings/update-outing.usecase.ts`, `delete-outing.usecase.ts`, `usecases/notifications/mark-notification-read.usecase.ts` (gap).  
**Priority:** P0  
**Complexity:** Low–medium.

**Issue ARCH-03 — Unused dependencies**  
`package.json` includes `pino`, `joi`, `express-validator`, `jsonwebtoken` but they are unused in `src/`. Zod + Firebase tokens are used instead.  
**Priority:** P3 (cleanup).

**Issue ARCH-04 — Feature boundary leakage**  
Outing list defaults `userId` to caller in controller (`outing.controller.ts` L67–69) while also exposing query `userId` — any authenticated client may list another user’s outings by query.  
**Priority:** P1  
**Complexity:** Low.

### Error handling & logging

- Central `errorMiddleware` — good shape consistency.  
- Logging via `console.*`; auth debug logs outside production — OK for now.  
- No request IDs, no structured logs, no metrics.  
**Issue OBS-01** — P2; adopt pino (already depended) with request id middleware when operating in staging/prod.

### Validation

Zod via `validate` middleware — strong. Domain refinements (group/occasion) duplicated between Zod and update use case — acceptable redundancy for defense in depth.

### API design

| Topic | Finding | Priority |
|-------|---------|----------|
| REST naming | Generally resource-oriented under `/api` | — |
| Versioning | None (`/api/v1`) | P3 until breaking clients exist |
| Pagination | Absent on lists/chat | P2 before large groups |
| Filtering | Basic query params on groups/outings/places | OK |
| Status codes | 200/201/400/401/403/404/409/500 used thoughtfully | — |
| Swagger 429 | Documented on auth; **no rate limiter implemented** | P1 |
| Response consistency | `{success, data}` mostly; sync adds `invitations` | P3 |

---

## 2. Database audit

### Strengths

- Normalized relational model matching product language.  
- Composite vote FK prevents cross-outing vote tampering at DB level.  
- Cascades on membership/chat/votes appropriate.  
- Partial SQL indexes for invitation and outing due queries.  
- E.164 / lat-lng / time-window CHECKs in migrations.

### Concerns

| ID | Issue | Consequence | Priority |
|----|-------|-------------|----------|
| DB-01 | `password_hash` + Firebase dual auth | Split brain credentials vs Flutter Firebase-password flow | P0 (product) |
| DB-02 | `user_fcm_tokens` without API | Dead table; push cannot be targeted | P1 |
| DB-03 | `chat_reads` without routes | Unread chat counts cannot be server-backed | P1 |
| DB-04 | `groups.created_by` NoAction on user delete | Soft operational hazard if users deleted | P2 |
| DB-05 | Place/outing image URLs unbounded trust | XSS/open-redirect only if rendered unsafely; storage abuse N/A until upload | P2 |
| DB-06 | No soft delete | Hard deletes cascade; recovery harder | P3 (product choice) |
| DB-07 | List endpoints may over-fetch relations | Possible N+1 depending on datasource includes — **needs query review** | NEEDS MANUAL VERIFICATION / P2 |

**Transactions:** Signup rolls back Firebase user on DB failure (`signup.usecase.ts`) — good. Invitation claim should be reviewed for multi-row atomicity (claim use case) — **NEEDS MANUAL VERIFICATION**.

---

## 3. Security audit

| ID | Area | Finding | Priority |
|----|------|---------|----------|
| SEC-01 | AuthZ outings | Any authenticated user can `PATCH`/`DELETE` any outing | **P0** |
| SEC-02 | AuthZ notifications | Mark-read by id without `user_id` check | **P0** |
| SEC-03 | AuthZ groups | `UpdateGroupUseCase` / `DeleteGroupUseCase` find-by-id then mutate with **no** owner/role check (`update-group.usecase.ts`, `delete-group.usecase.ts`). Invite checks membership only. | **P0** |
| SEC-04 | IDOR list | `GET /api/outings?userId=` and `GET /api/groups?userId=` may enumerate others’ data | **P1** |
| SEC-05 | Places GET | Public read without auth — OK if catalog is public; mutations auth’d | Confirm product intent |
| SEC-06 | CORS | `origin: true` reflects request origin (`app.ts` L11–17) | P1 for production lockdown |
| SEC-07 | Rate limit | None; Swagger mentions 429 on auth | **P1** |
| SEC-08 | Secrets | `.env` gitignored; Admin private key in env — OK pattern. Flutter client keys in dart-define — acceptable with App Check | P2 enable App Check |
| SEC-09 | SQL injection | Prisma parameterized — low risk | — |
| SEC-10 | File upload | None — no multipart risks yet | — |
| SEC-11 | Token handling | Bearer extraction tolerant of malformed Swagger pastes — fine; does not weaken verifyIdToken | — |
| SEC-12 | Health error | `/health` may echo DB error message (`app.ts` L85–90) | P2 strip in production |
| SEC-13 | User enumeration | Auth conflict messages distinguish email/phone in use | P2 |

**Firebase verification:** Confirmed real Admin `verifyIdToken` path — not a mock. Project ID must match Flutter Firebase project (documented in `.env.example`).

---

## 4. Performance audit

| ID | Finding | Need now? | Priority |
|----|---------|-----------|----------|
| PERF-01 | Full-table style lists without pagination | OK for MVP; chat history will hurt first | P2 |
| PERF-02 | Flutter reload-all after every vote/attendance mutation | Extra payload & latency | P2 (client) |
| PERF-03 | In-process outing completion every 60s | Fine on single instance; duplicates work if scaled out | P3 until multi-instance |
| PERF-04 | Neon pooled URL sanitization in `database.ts` | Good operational awareness | — |
| PERF-05 | No response caching | Not needed yet for personalized data | Later |
| PERF-06 | Nearby haversine in DB | Index on lat/lng helps; still scan-ish at scale | P3 |
| PERF-07 | Nominatim from every client | Risk of rate limits / ToS; proxy later if traffic grows | P2 when usage grows |

Connection pooling: rely on Neon pooler + Prisma — appropriate. No Redis today — **not required** until hot read paths or sessions appear.

---

## 5. Scalability assessment

| Capability | Current | Recommendation |
|------------|---------|----------------|
| Horizontal API | Single Node process; job in-process | Stateless API OK; **move job out** before multi-instance |
| DB | Neon Postgres | Stay; add read replica only with read-heavy metrics |
| Cache Redis | Absent | **Later** — for place catalog / unread counts if expensive |
| CDN | Absent | Use when hosting static images/assets |
| Object storage | Absent | Add when replacing URL-only images |
| Queues | Absent | Add for FCM fan-out / WhatsApp / email when volume warrants |
| WebSockets | Absent | REST OK until live chat UX demands; then consider SSE/WS |
| Push | Receive-only | Implement token register + worker when notifications must leave the DB |

**Do not** split microservices now — the modular monolith is the right shape.

---

## 6. Flutter architecture notes (system impact)

| ID | Finding | Priority |
|----|---------|----------|
| FL-01 | Live contract outdated vs backend | P0 |
| FL-02 | Mock default hides integration failures | P1 (CI live contract smoke) |
| FL-03 | Saved/drafts/chat cache local-only | P1 once multi-device matters |
| FL-04 | `core/mock` still present | P3 align with “no demo seed” policy for release |
| FL-05 | Presentation Clean Architecture generally respected | — |

---

## 7. Issue register (consolidated)

| ID | Module | Current | Problem | Consequences | Solution | Priority | Complexity | Dependencies | Flutter impact |
|----|--------|---------|---------|--------------|----------|----------|------------|--------------|----------------|
| SEC-01 | outings | Update/delete by id only | No ownership/membership check | Data destruction / tampering | Require creator or group owner in use case | P0 | S | — | None until wired |
| SEC-02 | notifications | Mark read by id | IDOR | Privacy / state corruption | Match `user_id` to token | P0 | S | — | Adapter after fix |
| SEC-03 | groups | Update/delete by id only | No owner/role check | Any authed user can alter/delete any group | Require `group_members.role = owner` (or created_by) | P0 | S | — | None until wired |
| AUTH-01 | auth | Neon hash vs Firebase password | Dual credential models | Broken login across clients | Pick one model; document; implement sync | P0 | L | Product decision | Rewrite auth remote |
| API-01 | contract | `/api` + snake_case vs Flutter paths | Integration failure | App cannot use backend | Align OpenAPI + Flutter ApiConstants | P0 | L | AUTH-01 | All datasources |
| CTRCT-01 | outings/votes | Different vote DTOs | Votes impossible live | Core feature broken live | Adopt backend option_id API in Flutter | P0 | M | API-01 | outings datasource/provider |
| CTRCT-02 | attendance | Method/enum/actor mismatch | Attendance broken live | Same | PUT + snake_case + token user | P0 | S | API-01 | outings |
| SEC-04 | list filters | userId query | Enumeration | Privacy | Force caller uid or authorize | P1 | S | — | Use `/cuser` |
| SEC-06 | CORS | Reflect all | CSRF-ish browser risk | Lock origins in prod | P1 | S | Deploy config | — |
| SEC-07 | rate limit | None | Auth abuse | express-rate-limit on auth | P1 | S | — | — |
| FCM-01 | push | Table only | No push delivery | Token register API + send worker | P1 | M | Queue later | Call register |
| CHAT-01 | chat_reads | No route | Unread wrong | Add mark-read endpoint | P1 | S | — | Point markRead |
| SAVE-01 | saved/drafts | Flutter prefs | No sync | Switch Flutter to API | P1 | M | API-01 | saved repos |
| INV-01 | invitations | Backend rich; Flutter add-member | Invite flow wrong | Wire invitations + WhatsApp | P1 | M | API-01 | groups UI |
| ARCH-04 | lists | userId override | IDOR | Same as SEC-04 | P1 | S | — | — |
| PERF-01 | lists/chat | No pagination | Latency growth | Cursor pagination | P2 | M | Client support | chat/outings |
| OBS-01 | logging | console | Weak ops | pino + request id | P2 | S | — | — |
| ARCH-01 | DI | new in constructors | Testability | Factory module | P2 | M | — | — |
| UPLOAD-01 | media | URL only | Local paths useless remotely | Storage + signed upload | P2 | L | Provider choice | image pickers |
| PERF-03 | jobs | setInterval | Multi-instance dupes | External cron / queue | P3 | M | Hosting | — |
| API-VER | versioning | none | Hard breaks | `/api/v1` when stable | P3 | S | — | constants |
| REALTIME | chat | REST poll | No live UX | WS/SSE later | P3 | L | Infra | chat provider |

Complexity: S = small, M = medium, L = large.

---

## 8. Recommended target architecture (confirmed vs aspirational)

**Keep (confirmed good):**

- Modular Express monolith + Prisma + Neon  
- Flutter feature-first Clean Architecture + Provider  
- Firebase ID token verification on API  
- OpenAPI at `/api-docs` as contract hub  
- WhatsApp click-to-chat (not Business API) until volume justifies otherwise  

**Change soon:**

- Single auth provisioning story (`/api/users/sync` + decided password policy)  
- Resource-level authorization middleware/helpers  
- Flutter adapters rewritten to OpenAPI  
- FCM token registration when push content exists  

**Defer:**

- Redis, Kafka/Bull, microservices, WebSockets, read replicas, CDN for API  

---

## 9. Unverified / further investigation

1. Member add/remove authorization (who may add/remove whom) beyond invite membership check.  
2. Datasource `include` graphs for N+1 on group/outing detail.  
3. Whether Neon connection limit fits expected concurrent mobile users.  
4. Production deployment topology (none in repo — no Docker/K8s manifests found).  
5. Crashlytics/monitoring wiring on Flutter vs backend (Flutter has monitoring folder; backend has none).
