# Yalla 5roga — Product Scenario Implementation & Verification Report

**Date:** 2026-11-07  
**Scope:** Flutter + Node/Express/Prisma + Neon PostgreSQL alignment to approved outing scenario  
**Neon target (verified before reset):** host `ep-misty-glitter-av3zwlzf-pooler.c-11.us-east-1.aws.neon.tech`, database `neondb`, `NODE_ENV=development`

---

## A. Executive Summary

**Overall status:** Partially aligned — core outing lifecycle, voting integrity, attendance separation, tie-break, chat openness, and saved places are implemented and verified against Neon. Full UI end-to-end on device and every notification/FCM delivery path were not fully executed in this session.

**Matches approved scenario for:**
- Outing types (group / special_event) with shared voting/attendance/chat
- Owner = creator; owner auto Going
- One active vote per user (upsert); early close; deadline close; unique winner; tie + server RNG tie-break; zero-vote cancel
- Attendance independent of place votes (`going` / `not_going` / `maybe`)
- Chat open in draft / voting / confirmed
- Saved places separate from saved outings
- Clean schema rebuild on confirmed development Neon

**Major conflicts discovered (pre-fix):**
- Multi-vote PK; client-driven `vote_finalized`; status `upcoming` vs Confirmed; attendance `not_voted` + UI coupling; no tie-break; no early/deadline resolution; no saved_places; thin outing notifications

**Major fixes implemented:** Schema rebuild + migration reset; voting resolution service; Flutter decoupling + tie-break animation; APIs for voting-state / tie-break / cancel / saved places.

---

## B. Flutter Changes

| Feature | Previous | New | Files | Tests |
|---------|----------|-----|-------|-------|
| Status enums | upcoming/voting/past/cancelled | draft/voting/confirmed/cancelled/past | `outing_enums.dart`, filters, parsers | Analyzer (warnings cleaned) |
| Attendance | going/notGoing/notVoted; gated voting | going/notGoing/maybe/unset; independent | vote/attendance widgets, api_payload | Analyzer |
| Finalize vote | PATCH vote_finalized from client | Refresh-only; server closes | remote datasource, provider | Not Run (device) |
| Tie-break | Missing | Owner CTA + animation reveals server winner | `outing_vote_widget.dart`, API constants | Not Run (device) |
| Saved places | Missing API constants | `/api/places/saved` + save/unsave paths | `api_constants.dart` | Not Run |
| Chat | Location-gated | Open for draft/voting/confirmed | `outing.dart` | Not Run |

---

## C. Backend Changes

| Area | Change |
|------|--------|
| Votes | Upsert on `(outing_id, user_id)`; participant checks; reject when closed |
| Closure | `tryCloseIfAllVoted`, deadline job, unique/tie/zero resolution in transactions |
| Tie-break | `POST /api/outings/:id/tie-break` — owner only, crypto RNG, idempotent |
| Create | Owner Going in same transaction; draft/confirmed status defaults |
| Attendance | `maybe`; owner forced Going; notifications to owner |
| Chat | Open statuses draft/voting/confirmed; group members can participate |
| Notifications | Idempotent `event_key` fan-out for invite/update/attendance/chat/vote/confirm/cancel |
| Saved places | `GET/POST/DELETE /api/places/.../save` |
| Cancel | `POST /api/outings/:id/cancel` owner-only |
| Leave | Member self-remove rejected (403) |

Key files: `vote-resolution.ts`, `outing-participants.ts`, `outing-notifier.ts`, `voting.usecase.ts`, `outing.datasource.ts`, `close-voting-deadline.job.ts`, routes/controllers/validators.

---

## D. Database Changes

| Item | Detail |
|------|--------|
| Migration | `20261107000000_init_product_scenario` (full rebuild) |
| Neon deploy | **Verified** — `prisma migrate reset` succeeded on development `neondb` |
| Status enum | draft, voting, confirmed, cancelled, past |
| Attendance | going, not_going, maybe |
| Votes PK | `(outing_id, user_id)` |
| Winner | `winning_option_id` composite FK to same-outing option |
| Closure meta | `vote_closed_at`, `vote_close_reason` |
| saved_places | `(user_id, place_id)` |
| notifications.event_key | unique idempotency |
| Integrity check | Enums + vote PK + saved_places confirmed via SQL |

**Data note:** Existing rows were wiped by authorized development reset. No production data preserved (by request).

---

## E. Conflict Report

| Conflict | Existing Behavior | Required Behavior | Resolution |
|----------|-------------------|-------------------|------------|
| Vote uniqueness | PK included option_id | One active vote/user | New PK + upsert |
| Vote change | create second row | Update existing | Upsert |
| Closure authority | Flutter PATCH finalized | Server early/deadline/winner | Removed client authority; server jobs/use cases |
| Status model | upcoming | Confirmed (+ draft) | Enum rebuild; map legacy upcoming→confirmed in Flutter |
| Attendance | not_voted; blocked voting | maybe; independent | Enum + UI/API |
| Owner Going | Missing | Auto on create | Transactional create |
| Tie-break | None | Backend RNG + Flutter animation | Endpoint + dialog |
| Zero votes | None | Cancel on close | Resolution path |
| Saved places | None | Separate persistence | Table + API |
| Chat in draft | upcoming/voting only | draft/voting/confirmed | chat-access update |
| Member leave | Possible via guest delete self | Rejected | Forbidden in RemoveGuestUseCase |

---

## F. Testing Report

| Test | Status | Evidence / Notes |
|------|--------|------------------|
| Flutter analyzer (outing surface) | Passed* | 0 errors after fixes; earlier 4 warnings cleaned (*re-run not required for blockers) |
| Backend unit/existing suite | **Passed** | `resource-authz` + lifecycle re-run exit 0 after FakeOuting status fix |
| Outing lifecycle integration | **Passed** | `tests/outing-lifecycle.test.ts` — 3/3 pass (create/upsert/attendance; unique+tie-break+zero cancel; special event draft chat) |
| Database schema verification | **Passed** | Live Neon enums/PK/tables JSON check |
| Prisma validate/generate | **Passed** | After reset |
| Integration E2E Flutter device | **Not Run** | No emulator session in this pass |
| Notification push delivery (FCM send) | **Not Run** | In-app rows + outbox events written; FCM worker send not fully exercised |
| Concurrent race harness | **Not Run** | Transactions + FOR UPDATE present; dedicated race suite not executed |
| Scenarios 1–33 matrix | **Partial** | Covered via lifecycle tests + authz patterns; not every row as isolated HTTP case |

Never marked Passed without execution above.

---

## G. Remaining Issues

1. Full HTTP scenario matrix (all 33) as discrete API tests still incomplete — core paths covered in lifecycle suite.
2. Flutter device E2E (Gradle/emulator) not re-run this session.
3. FCM push delivery worker for outing outbox events still mostly stub/log path depending on channel config.
4. Product ambiguity resolved as documented: **no-deadline voting stays open until all eligible voters vote** (no owner manual close added).
5. Discover/maps polish unchanged except contract preservation.
6. Generated Mockito file patched manually for `breakTie`; regenerate when mock codegen next runs.
7. `tmp-verify-schema.mjs` / similar temp scripts can be deleted when convenient.

---

## H. Final Assessment

**Partially aligned** with the approved product scenario.

**Evidence:** Development Neon schema matches the rebuilt Prisma model; backend voting/attendance/tie-break/cancel/notifications write paths behave per rules in executed integration tests; Flutter contracts and UX were updated to stop inventing winners and to separate attendance from voting. Remaining gaps are primarily full device E2E coverage, exhaustive HTTP scenario enumeration, and production-grade FCM delivery verification — not the absence of core business-rule implementation.
