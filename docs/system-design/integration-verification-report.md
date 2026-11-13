> **Historical reference — corrected 2026-11-13:** Endpoint paths and PASS claims below describe an older implementation/run and are not current verification. Current registered routes use `/api/outings/:outingId/messages` and `/api/outings/:outingId/read`, `/api/invitations/:invitationId/decline`, and `/api/users/cuser/fcm-token`. There is no registered `POST /api/outings/hydrate`; Flutter hydrates via the existing current-user/detail/voting/attendance GET operations. Prefer `../API_CONTRACTS.md` and the current confirmed-fixes report.

# Phase B — Full End-to-End Integration Verification Report

**Date:** 2026-11-06  
**Mode:** Live verification (`USE_MOCK_DATA=false`); no app/schema changes  
**Overall:** **NOT COMPLETE** — protected API matrix largely PASS; Flutter device UI re-run **BLOCKED** (Gradle daemon crash); notifications mark-read **BLOCKED** (empty feed)

---

## Executive summary

- Neon email/password login → Firebase custom token → ID token → Bearer-protected APIs was verified live against `:3000` with disposable data (cleaned up).
- Harness result: **PASS=29 / FAIL=0 / BLOCKED=1 / NOT TESTED=2** (see `integration-test-results.md` and `_phase_b_results.json`).
- A disposable User B was created via `POST /api/auth/signup` for authorization and group member add/remove.
- Flutter `flutter run` on Pixel 6a (`emulator-5554`) **failed**: Gradle daemon disappeared / JVM crash during `assembleDebug` (~1553s). Package `com.example.yalla_5roga` was already installed from earlier runs, but this session did **not** complete a fresh UI login / logout / restart pass under the new custom-token client path.
- Backend `pnpm run dev` was later **terminated**; re-check health before further device work.
- Integration is **not** marked complete until device auth persistence + notifications mark-read are executed.

Auth model under test (code + API):

1. `POST /api/auth/login` (Neon password) returns `customToken` + `idToken`
2. Flutter `signInWithCustomToken` then refreshes Firebase ID token
3. Dio `Authorization: Bearer <Firebase ID token>`
4. Backend verifies Firebase ID tokens on protected routes

---

## Environment

| Check | Result | Evidence |
|-------|--------|----------|
| `USE_MOCK_DATA=false` in Flutter `.env` | PASS | `.env` read |
| `API_BASE_URL=http://10.0.2.2:3000` | PASS | `.env` read |
| Backend `/health` DB connected | PASS (during harness) | HTTP 200 `database=connected` |
| Emulator `emulator-5554` present | PASS | `flutter devices` |
| Fresh Flutter debug install this session | **FAIL / BLOCKED** | Gradle daemon crash; `hs_err_pid10968.log` |
| Secrets / tokens logged | PASS (avoided) | Harness redacts tokens |

---

## A. Authentication

| Test | Status | Endpoint | HTTP | Sanitized summary | UI | DB |
|------|--------|----------|------|-------------------|----|----|
| Email/password login (Neon) | PASS | `POST /api/auth/login` | 200 | `uid` + `customToken` + `idToken` present | NOT TESTED this session | n/a |
| Custom token exchange fields | PASS | same | 200 | `customToken=true` | NOT TESTED | n/a |
| Firebase ID token usable as Bearer | PASS | `GET /api/users/cuser` | 200 | profile `id` matches login uid | NOT TESTED | PASS |
| Missing Bearer | PASS | `GET /api/users/cuser` | 401 | unauthorized without Authorization | n/a | n/a |
| Login again | PASS | `POST /api/auth/login` | 200 | tokens re-issued | NOT TESTED | n/a |
| Authenticated API after re-login | PASS | `GET /api/outings/cuser` | 200 | Bearer accepted | NOT TESTED | PASS |
| Logout + UI re-login | **NOT TESTED** | Flutter UI | — | Device flow not re-run | BLOCKED | — |
| App restart session persistence | **NOT TESTED** | Flutter UI | — | Requires stable app process | BLOCKED | — |

**Auth issues:** None observed on the Neon → custom token → ID token → API path in this harness. Device logout/restart still unproven in Phase B.

---

## B. Profile

| Test | Status | Endpoint | HTTP | Summary | DB |
|------|--------|----------|------|---------|-----|
| Get current profile | PASS | `GET /api/users/cuser` | 200 | uid match | PASS |
| Update profile | PASS | `PATCH /api/users/cuser` | 200 | name updated | PASS |
| Persist | PASS | `GET /api/users/cuser` | 200 | name retained | PASS |

UI profile screens: **NOT TESTED** this session (device rebuild blocked).

---

## C. Groups

| Test | Status | Endpoint | HTTP | Summary | DB |
|------|--------|----------|------|---------|-----|
| Create | PASS | `POST /api/groups` | 201 | disposable group id | PASS |
| List mine | PASS | `GET /api/groups/cuser` | 200 | created found | PASS |
| Update | PASS | `PATCH /api/groups/:id` | 200 | bio updated | PASS |
| Add member (User B phone) | PASS | `POST /api/groups/:id/members` | 201 | membership created | PASS |
| Remove member | PASS | `DELETE /api/groups/:id/members/:userId` | 200 | membership removed | PASS |
| Cleanup delete | PASS | `DELETE /api/groups/:id` | 200 | disposable removed | PASS |

---

## D. Outings

| Test | Status | Endpoint | HTTP | Summary | DB |
|------|--------|----------|------|---------|-----|
| Create group outing | PASS | `POST /api/outings` | 201 | `type=group` | PASS |
| Create special event | PASS | `POST /api/outings` | 201 | `type=special_event`, occasion=birthday | PASS |
| Get details | PASS | `GET /api/outings/:id` | 200 | type=group | PASS |
| Vote options (+ create option) | PASS | `POST/GET .../vote-options` | 201/200 | count≥1 | PASS |
| Cast vote | PASS | `POST /api/outings/:id/votes` | 201 | voter = auth uid | PASS |
| Attendance | PASS | `PUT /api/outings/:id/attendance` | 200 | `status=going` | PASS |
| Cleanup | PASS | `DELETE /api/outings/:id` | 200 | disposable removed | PASS |

---

## E. Chat

| Test | Status | Endpoint | HTTP | Summary | DB |
|------|--------|----------|------|---------|-----|
| Send message | PASS | `POST /api/chat/outings/:id/messages` | 201 | `sender_id` from token | PASS |
| List messages | PASS | `GET /api/chat/outings/:id/messages` | 200 | message found | PASS |

---

## F. Notifications

| Test | Status | Endpoint | HTTP | Summary | DB |
|------|--------|----------|------|---------|-----|
| List | **BLOCKED** | `GET /api/notifications` | 200 | empty feed | n/a |
| Mark one read | **NOT TESTED** | `PATCH /api/notifications/:id/read` | — | no row to mark | — |
| Recipient ownership | **NOT TESTED** | same | — | depends on non-empty feed | — |

Per requirements: empty feed ⇒ **BLOCKED / NOT TESTED**, not PASS.

---

## G. Authorization (User B)

| Test | Status | Endpoint | HTTP | Summary |
|------|--------|----------|------|---------|
| User B provision | PASS | `POST /api/auth/signup` | 201 | distinct uid |
| Unauthorized group update | PASS | `PATCH /api/groups/:id` | 403 | non-owner |
| Unauthorized group delete | PASS | `DELETE /api/groups/:id` | 403 | non-owner |
| Unauthorized outing update | PASS | `PATCH /api/outings/:id` | 403 | non-creator |
| Unauthorized outing delete | PASS | `DELETE /api/outings/:id` | 403 | non-creator |
| Notifications isolation | PASS | `GET /api/notifications` | 200 | no foreign leak (empty own feed) |
| Mark foreign notification | **NOT TESTED** | `PATCH /api/notifications/:id/read` | — | no User A notification id |
| Unauthorized chat access | PASS | `GET /api/chat/outings/:id/messages` | 403 | non-participant |

---

## Device evidence

1. Emulator connected: `sdk gphone64 x86 64` / `emulator-5554`.
2. Installed package observed earlier: `com.example.yalla5roga` / `MainActivity` resumed (stale install; not accepted as Phase B UI PASS).
3. `flutter run -d emulator-5554 --dart-define-from-file=.env` → **FAIL**: Gradle daemon disappeared; JVM crash log under `flutter/android/hs_err_pid10968.log`.
4. Prior user report that Pixel 6a login + Home APIs succeeded is noted but **not** re-executed as PASS in this Phase B session.

---

## Remaining integration blockers

1. **P0 DEVICE-01:** Fresh Flutter debug build/run failed (Gradle daemon/JVM crash). Blocks UI logout, re-login, and restart persistence verification.
2. **P1 NOTIF-01:** Empty notification feed blocks mark-read and cross-user mark-read ownership tests.
3. **P2 OPS-01:** Backend process was terminated after harness; restart required before more live runs.

---

## Contract mismatches

None newly observed between Flutter `ApiConstants` and live routes for the exercised surfaces (`/api/auth/login`, `/api/users/cuser`, groups, outings `type`, `/vote-options`, votes, attendance, chat messages, notifications list).

---

## Authentication issues

- API custom-token login path: **PASS**.
- Device custom-token login / session restore this session: **NOT TESTED** (build failure).
- Phase A AUTH-01 (Firebase `signInWithEmailAndPassword`) is superseded by Neon login + `signInWithCustomToken` in current client code; not re-failed here because UI was not driven.

---

## Security issues

- Cross-user group/outing/chat denials returned **403** as expected (PASS).
- Foreign notification mark-read still **NOT TESTED** (no notification rows).
- Tokens were not written to reports.

---

## Recommended next steps

1. Restart backend (`pnpm run dev` in `backend/`).
2. Fix/retry Flutter Android build (stop extra Gradle daemons, free RAM, clear crashed daemon, re-run `flutter run -d emulator-5554 --dart-define-from-file=.env`).
3. On device: login → Home APIs → logout → login again → kill/relaunch app → confirm session.
4. Seed or trigger at least one notification for User A; re-test mark-read + User B forbidden mark-read.
5. Only then mark Phase B integration complete.

---

## Evidence artifacts

- Sanitized harness output: `docs/system-design/_phase_b_results.json`
- Harness script: `docs/system-design/_phase_b_verify.mjs`
- Matrix: `docs/system-design/integration-test-results.md`
