# Phase B — Integration Test Results Matrix

**Date:** 2026-11-06  
**Overall:** NOT COMPLETE — API matrix mostly PASS; Flutter UI device re-run BLOCKED (Gradle crash); notifications mark-read BLOCKED (empty feed)  
**Legend:** PASS | FAIL | BLOCKED | NOT TESTED  
**Harness:** `docs/system-design/_phase_b_verify.mjs` → `_phase_b_results.json` (tokens redacted)  
**Config:** `USE_MOCK_DATA=false`, API `http://localhost:3000` (emulator `10.0.2.2:3000`)

---

## Environment

| # | Test | Status | Endpoint / check | HTTP | Notes |
|---|------|--------|------------------|------|-------|
| 1.1 | Flutter `.env` mock off | PASS | `USE_MOCK_DATA=false` | — | |
| 1.2 | Emulator API base | PASS | `API_BASE_URL=10.0.2.2:3000` | — | |
| 1.3 | Backend health | PASS | `GET /health` | 200 | `database=connected` |
| 1.4 | Emulator present | PASS | `emulator-5554` | — | |
| 1.5 | Fresh Flutter run this session | FAIL | `flutter run …assembleDebug` | — | Gradle daemon/JVM crash |

---

## A — Authentication

| # | Test | Status | Endpoint | HTTP | Sanitized summary | UI | DB |
|---|------|--------|----------|------|-------------------|----|----|
| A.1 | Email/password login | PASS | `POST /api/auth/login` | 200 | uid + customToken + idToken | NOT TESTED | n/a |
| A.2 | Custom token present | PASS | same | 200 | `customToken=true` | NOT TESTED | n/a |
| A.3 | ID token as Bearer | PASS | `GET /api/users/cuser` | 200 | uid match | NOT TESTED | PASS |
| A.4 | Missing Bearer | PASS | `GET /api/users/cuser` | 401 | unauthorized | n/a | n/a |
| A.5 | Login again | PASS | `POST /api/auth/login` | 200 | tokens re-issued | NOT TESTED | n/a |
| A.6 | API after re-login | PASS | `GET /api/outings/cuser` | 200 | Bearer accepted | NOT TESTED | PASS |
| A.7 | Logout | NOT TESTED | Flutter UI | — | device rebuild blocked | BLOCKED | — |
| A.8 | App restart persistence | NOT TESTED | Flutter UI | — | device rebuild blocked | BLOCKED | — |

---

## B — Profile

| # | Test | Status | Endpoint | HTTP | Summary | UI | DB |
|---|------|--------|----------|------|---------|----|----|
| B.1 | Get profile | PASS | `GET /api/users/cuser` | 200 | id match | NOT TESTED | PASS |
| B.2 | Update profile | PASS | `PATCH /api/users/cuser` | 200 | name set | NOT TESTED | PASS |
| B.3 | Persist | PASS | `GET /api/users/cuser` | 200 | name retained | NOT TESTED | PASS |

---

## C — Groups

| # | Test | Status | Endpoint | HTTP | Summary | UI | DB |
|---|------|--------|----------|------|---------|----|----|
| C.1 | Create | PASS | `POST /api/groups` | 201 | id present | NOT TESTED | PASS |
| C.2 | List | PASS | `GET /api/groups/cuser` | 200 | created found | NOT TESTED | PASS |
| C.3 | Update | PASS | `PATCH /api/groups/:id` | 200 | bio updated | NOT TESTED | PASS |
| C.4 | Add member | PASS | `POST /api/groups/:id/members` | 201 | User B by phone | NOT TESTED | PASS |
| C.5 | Remove member | PASS | `DELETE /api/groups/:id/members/:userId` | 200 | removed | NOT TESTED | PASS |

Disposable group deleted after suite.

---

## D — Outings

| # | Test | Status | Endpoint | HTTP | Summary | UI | DB |
|---|------|--------|----------|------|---------|----|----|
| D.1 | Create group outing | PASS | `POST /api/outings` | 201 | `type=group` | NOT TESTED | PASS |
| D.2 | Create special event | PASS | `POST /api/outings` | 201 | `type=special_event` | NOT TESTED | PASS |
| D.3 | Get details | PASS | `GET /api/outings/:id` | 200 | type=group | NOT TESTED | PASS |
| D.4 | Vote options | PASS | `GET/POST .../vote-options` | 200/201 | count≥1 | NOT TESTED | PASS |
| D.5 | Cast vote | PASS | `POST /api/outings/:id/votes` | 201 | voter=auth uid | NOT TESTED | PASS |
| D.6 | Attendance | PASS | `PUT /api/outings/:id/attendance` | 200 | `going` | NOT TESTED | PASS |

Disposable outings deleted after suite.

---

## E — Chat

| # | Test | Status | Endpoint | HTTP | Summary | UI | DB |
|---|------|--------|----------|------|---------|----|----|
| E.1 | Send | PASS | `POST /api/chat/outings/:id/messages` | 201 | sender from token | NOT TESTED | PASS |
| E.2 | List | PASS | `GET /api/chat/outings/:id/messages` | 200 | message persisted | NOT TESTED | PASS |

---

## F — Notifications

| # | Test | Status | Endpoint | HTTP | Summary | UI | DB |
|---|------|--------|----------|------|---------|----|----|
| F.1 | List | BLOCKED | `GET /api/notifications` | 200 | empty feed | NOT TESTED | n/a |
| F.2 | Mark one read | NOT TESTED | `PATCH /api/notifications/:id/read` | — | empty feed | NOT TESTED | — |
| F.3 | Recipient ownership | NOT TESTED | same | — | needs notification row | NOT TESTED | — |

---

## G — Authorization (User B)

| # | Test | Status | Endpoint | HTTP | Summary |
|---|------|--------|----------|------|---------|
| G.1 | Signup User B | PASS | `POST /api/auth/signup` | 201 | distinct uid |
| G.2 | Unauthorized group update | PASS | `PATCH /api/groups/:id` | 403 | non-owner |
| G.3 | Unauthorized group delete | PASS | `DELETE /api/groups/:id` | 403 | non-owner |
| G.4 | Unauthorized outing update | PASS | `PATCH /api/outings/:id` | 403 | non-creator |
| G.5 | Unauthorized outing delete | PASS | `DELETE /api/outings/:id` | 403 | non-creator |
| G.6 | Notifications isolation | PASS | `GET /api/notifications` | 200 | no foreign leak |
| G.7 | Foreign notification mark-read | NOT TESTED | `PATCH /api/notifications/:id/read` | — | no User A notif id |
| G.8 | Unauthorized chat access | PASS | `GET /api/chat/outings/:id/messages` | 403 | non-participant |

---

## Totals (executed harness)

| PASS | FAIL | BLOCKED | NOT TESTED |
|------|------|---------|------------|
| 29 | 0 | 1 | 2 (+ device UI rows above) |

---

## Closing checklist

| Item | Status |
|------|--------|
| Remaining blockers | DEVICE-01 Gradle crash; NOTIF-01 empty feed; backend stopped after run |
| Contract mismatches | None found on exercised routes |
| Authentication issues | API path PASS; device logout/restart NOT TESTED |
| Security issues | Group/outing/chat 403 PASS; foreign notif mark-read NOT TESTED |
| Integration complete? | **No** |
