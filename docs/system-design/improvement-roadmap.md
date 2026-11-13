> **Historical reference — corrected 2026-11-13:** Endpoint paths and PASS claims below describe an older implementation/run and are not current verification. Current registered routes use `/api/outings/:outingId/messages` and `/api/outings/:outingId/read`, `/api/invitations/:invitationId/decline`, and `/api/users/cuser/fcm-token`. There is no registered `POST /api/outings/hydrate`; Flutter hydrates via the existing current-user/detail/voting/attendance GET operations. Prefer `../API_CONTRACTS.md` and the current confirmed-fixes report.

# Improvement Roadmap

Ordered for risk reduction first, then contract unlock, then product completeness, then scale.  
Issue IDs refer to [architecture-audit.md](./architecture-audit.md) and [flutter-backend-consistency.md](./flutter-backend-consistency.md).

---

## Phase A — Stop the bleeding (P0) · estimate 1–2 weeks

| Order | Work | Solves | Complexity | Depends on |
|------:|------|--------|------------|------------|
| A1 | Add ownership/membership checks to outing update & delete | SEC-01 | S | — |
| A2 | Scope notification mark-read to `req.user.uid` | SEC-02 | S | — |
| A3 | Require group owner (or created_by) on group update/delete; review member add/remove authZ | SEC-03 | S–M | — |
| A4 | Product decision: **Auth model** (Firebase passwords vs Neon `password_hash` vs both) | AUTH-01 | L (decision + impl) | Stakeholders |
| A5 | Publish frozen OpenAPI as contract; document `/api` + snake_case | API-01 | M | A4 |
| A6 | Rewrite Flutter `ApiConstants` + auth/outings/attendance/votes/chat remotes to match OpenAPI | CTRCT-01/02, API-01 | L | A5 |

**Exit criteria:** Live Flutter (`USE_MOCK_DATA=false`) can sign in, sync user, list/create a group outing, cast a vote, set attendance, and send a chat message against a local/staging API.

---

## Phase B — Close feature gaps (P1) · estimate 2–4 weeks

| Order | Work | Solves | Need now? | Complexity |
|------:|------|--------|-----------|------------|
| B1 | Force list filters to caller (remove cross-user `userId` or authorize) | SEC-04, ARCH-04 | Yes | S |
| B2 | Production CORS allowlist + auth rate limiting | SEC-06, SEC-07 | Yes before public | S |
| B3 | Flutter invitations → `POST /api/groups/:id/invitations` + WhatsApp share | INV-01 | Yes for growth loops | M |
| B4 | Chat mark-read API using `chat_reads` + Flutter wiring | CHAT-01 | Yes for badges | S |
| B5 | FCM token `POST /api/users/fcm-token` (or similar) + store in `user_fcm_tokens` | FCM-01 | Yes before server push | M |
| B6 | Switch saved outings & drafts from prefs to backend APIs | SAVE-01 | Yes for multi-device | M |
| B7 | Notification list DTO adapter (unreadCount + camelCase **or** fix Flutter parsers to snake_case) | consistency | Yes | S |
| B8 | Leave-group endpoint or document using DELETE member self | leave mismatch | Yes | S |
| B9 | CI smoke: Flutter contract tests against OpenAPI / staging | FL-02 | Yes | M |

**Defer inside B:** Actual FCM **send** worker until notification rows are created by domain events (create outing, invite, vote finalize).

---

## Phase C — Harden & polish (P2) · estimate 3–6 weeks

| Order | Work | Problem solved | Need now? | Cost |
|------:|------|----------------|-----------|------|
| C1 | Structured logging (pino) + request IDs | OBS-01 ops | Staging onward | Low |
| C2 | Cursor pagination for chat messages & long outing lists | PERF-01 | When groups > ~50 msgs/outings | Medium |
| C3 | Image upload (Firebase Storage or R2) + URL validation | UPLOAD-01 | When profiles/covers must sync | Medium–High |
| C4 | Proxy Nominatim via backend if OSM rate limits hit | PERF-07 | Only if traffic warrants | Medium |
| C5 | Flutter: avoid full `load()` after every small mutation | PERF-02 | UX polish | Medium |
| C6 | Soft DI factory for backend tests | ARCH-01 | Quality | Medium |
| C7 | Strip `/health` internal error details in production | SEC-12 | Prod | Low |
| C8 | App Check on Firebase | Client API key abuse | Before public abuse likely | Medium |

---

## Phase D — Scale when measured (P3)

Only implement when metrics or multi-instance deployment demand it.

| Work | Solves | Need now? | Complexity / ops cost |
|------|--------|-----------|------------------------|
| Move outing completion job to Neon cron / Cloud Scheduler / queue | Multi-instance duplicate jobs | When >1 API replica | Medium |
| Redis cache for place catalog / unread aggregates | Read load | After slow query evidence | Medium + ops |
| Read replica | Heavy read analytics | Unlikely early | High ops |
| WebSockets / SSE for chat | Live UX | After REST polling pain | High |
| CDN for images | Latency/bandwidth | After object storage | Low–Medium |
| `/api/v1` versioning | Breaking changes | After public clients | Low |
| Microservices split | Team scaling | **Not recommended** at current size | Very high |

---

## Suggested auth target (recommendation — not current state)

**Recommended:** Firebase as sole password/social authenticator; backend only `verifyIdToken` + `POST /api/users/sync`; deprecate Neon `password_hash` **or** keep it only if you explicitly want server-side credential APIs for non-Flutter clients.

| Approach | Pros | Cons | When |
|----------|------|------|------|
| Firebase-only passwords | Matches Flutter today; simpler mental model | Lose `/api/auth/login` as written | Prefer for mobile-first |
| Neon passwords + custom tokens | Backend-controlled credentials | Diverges from Flutter Firebase login | Prefer if web/admin clients need password API without Firebase client |
| Dual-write both | Compatibility | Highest complexity & bug surface | Avoid unless transitional |

---

## Implementation order (one-page)

```text
1. SEC-01, SEC-02, SEC-03          → authorization
2. AUTH-01 decision               → freeze OpenAPI
3. Flutter adapter rewrite        → live vertical slice
4. SEC-04, CORS, rate limit       → public hardening
5. Invitations, chat read, FCM token, saved/drafts
6. Pagination, uploads, logging
7. Jobs/queues/realtime           → only with scale evidence
```

---

## Success metrics

| Metric | Target |
|--------|--------|
| Live smoke test (auth → group → outing → vote → chat) | Pass on staging |
| OpenAPI ↔ Flutter path drift | 0 critical MISMATCH rows in matrix |
| Unauthorized cross-user outing delete | 403 in automated test |
| P0 issues open | 0 |
| Mock mode in release | Forbidden (already enforced in `AppConfig`) |
