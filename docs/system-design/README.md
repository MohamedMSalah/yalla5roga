# Yalla 5roga — System Design & Architecture Audit

**Audit date:** 2026-11-06  
**Scope:** `backend/` (Node.js + Express + Prisma + PostgreSQL/Neon) and `flutter/` (Dart Clean Architecture)  
**Method:** Source-code verification only. No application code, schemas, or packages were modified.

## Document index

| File | Contents |
|------|----------|
| [01-high-level-architecture.md](./01-high-level-architecture.md) | System context diagram |
| [02-backend-internal-architecture.md](./02-backend-internal-architecture.md) | Request lifecycle & layers |
| [03-flutter-architecture.md](./03-flutter-architecture.md) | Client Clean Architecture |
| [04-authentication-flow.md](./04-authentication-flow.md) | Firebase + Neon auth flows |
| [05-database-erd.md](./05-database-erd.md) | Full Prisma ERD |
| [06-api-request-lifecycle.md](./06-api-request-lifecycle.md) | Sequence for a real endpoint |
| [07-critical-business-workflows.md](./07-critical-business-workflows.md) | Core domain workflows |
| [api-contract-matrix.md](./api-contract-matrix.md) | Endpoint-by-endpoint contract matrix |
| [openapi-contract-freeze.md](./openapi-contract-freeze.md) | Phase A frozen OpenAPI conventions |
| [flutter-backend-consistency.md](./flutter-backend-consistency.md) | Flutter ↔ Backend consistency audit |
| [architecture-audit.md](./architecture-audit.md) | Backend architecture, DB, security, performance |
| [improvement-roadmap.md](./improvement-roadmap.md) | Prioritized remediation roadmap |

---

## Executive summary

### 1. Current architecture overview

Yalla 5roga is a mobile outing-planning product for Egypt. The Flutter client uses feature-first Clean Architecture (Provider + Dio + Firebase Auth/FCM). The Node backend uses feature-oriented Clean Architecture (routes → controllers → use cases → repositories → Prisma datasources → Neon PostgreSQL). Firebase verifies identity; PostgreSQL stores application users and business data. Backend Swagger UI is available at `/api-docs`.

### 2. Overall architecture assessment

**Backend is substantially further along than the Flutter live API adapters.** The server exposes ~60 authenticated REST endpoints spanning users, groups, invitations, outings, voting, attendance, drafts, saved outings, places, chat, and notifications. The Flutter app still targets an earlier / placeholder contract (camelCase paths without `/api` prefix, different auth endpoints, different vote/attendance/chat shapes). With `USE_MOCK_DATA` defaulting to `true` in debug, the app can run without exercising the live API at all.

**Verdict:** Solid backend foundation; **client–server contract is not production-ready**. Integration work is the critical path before feature work.

### 3. Most critical problems

| ID | Problem | Priority |
|----|---------|----------|
| AUTH-01 | Divergent auth models (Flutter Firebase-password vs Backend Neon `password_hash` + custom tokens) | P0 |
| API-01 | Path prefix / route naming mismatch (`/auth/register` vs `/api/auth/signup`, `/user/profile` vs `/api/users/cuser`, chat nesting) | P0 |
| AUTHZ-01 | Outing/group update/delete and notification mark-read lack ownership checks | P0 |
| CTRCT-01 | Vote / attendance / create-outing request bodies are incompatible | P0 |
| CASE-01 | Systematic camelCase (Flutter) vs snake_case (Backend) field naming | P1 |

### 4. Flutter / Backend mismatches (headline)

- **Auth provisioning:** Flutter `POST /auth/register` (Bearer + profile) ≠ Backend `POST /api/auth/signup` (email/password into Neon) or `POST /api/users/sync`.
- **Profile update:** Flutter `PATCH /user/profile` ≠ Backend `PATCH /api/users/cuser`.
- **Chat:** Flutter `/outings/:id/chat/messages` ≠ Backend `/api/chat/outings/:outingId/messages`.
- **Votes:** Flutter `{optionIndex, toggle}` / `{finalize}` / `{clear}` ≠ Backend `{option_id}` (+ separate option CRUD).
- **Attendance:** Flutter `POST` + `userId` + `notGoing`/`notVoted` ≠ Backend `PUT` + `{status}` with `not_going`/`not_voted`.
- **Saved/drafts:** Backend has REST; Flutter uses SharedPreferences only.
- **Mark-all-read / leave-group / FCM token / unread-counts:** referenced or used on Flutter; missing or different on Backend.

Full tables: [flutter-backend-consistency.md](./flutter-backend-consistency.md), [api-contract-matrix.md](./api-contract-matrix.md).

### 5. Database design concerns

- Schema is well-normalized with strong FK cascades and useful indexes (including SQL-only partial indexes for invitations and outing due queries).
- `user_fcm_tokens` exists but has **no registration or send API**.
- `chat_reads` exists but Flutter’s mark-read path has **no matching backend route**.
- Outing/group ownership is modeled (`created_by`, `group_role`) but **not consistently enforced** in use cases.
- Dual auth credential store (Firebase + Neon `password_hash`) needs an explicit product decision.

### 6. Security risks

- Authenticated users can update/delete **any** outing (no creator/member check) — confirmed in `update-outing.usecase.ts` / `delete-outing.usecase.ts`.
- Mark-notification-read does not verify `user_id` matches the caller.
- CORS `origin: true` reflects any origin; no rate limiting despite Swagger `429` docs.
- No file upload validation today (URLs only) — low risk now; needs rules when uploads are added.
- Prisma parameterization mitigates SQL injection; Zod validates request shapes.

### 7. Scalability limitations

Current scale (single Express process + Neon + in-process `setInterval` completion job) is fine for early users. Not needed yet: Redis, microservices, WebSockets, CDN for API. Later candidates: FCM worker, read replicas, object storage for images, horizontal API replicas behind a load balancer once sticky in-process jobs are removed.

### 8. Recommended target architecture

Keep the **monolith API + Flutter Clean Architecture**. Align on one contract:

1. Firebase as identity for all sign-in providers (phone / Google / Apple / email).
2. `POST /api/users/sync` as the canonical provisioning path after Firebase sign-in.
3. Neon as source of truth for profiles and domain data.
4. Decide whether email/password verification lives in Firebase, Neon, or both — then delete the unused path.
5. Standardize on `/api` prefix, snake_case (or a documented camelCase adapter), and shared OpenAPI as the contract source of truth.
6. Enforce resource authorization in use cases before any new Flutter wiring.

### 9. Suggested implementation order

1. **P0 security:** ownership checks on outings, groups, notifications.
2. **P0 contract decision:** auth model + OpenAPI as single source of truth.
3. **P0 Flutter adapter rewrite** against real backend routes (or temporary BFF aliases — prefer fixing Flutter to match Backend).
4. **P1** invitations, saved/drafts, chat mark-read, FCM token registration.
5. **P2** logging, rate limits, pagination, image upload strategy.
6. **P3** real-time chat, caching, queues — only when metrics justify them.

Details: [improvement-roadmap.md](./improvement-roadmap.md).
