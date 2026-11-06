# Final Compliance Report — Yalla 5roga Product Scenarios

**Date:** 2026-11-07  
**Verdict:** **PARTIALLY COMPLIANT**

Critical business rules for voting, deadlines, candidate reset, confirmed place lock, membership invitation status, FCM infrastructure, and Flutter live wiring were implemented and tested where possible. Device E2E and real FCM delivery to a physical/emulator device remain **NOT RUN**.

---

## What was wrong (baseline)

- Runtime Flutter mock/demo stack (`USE_MOCK_DATA`, `lib/core/mock`).
- Optional voting deadline.
- Candidate changes did not reset all votes.
- Confirmed location still patchable.
- Guest wording / pending invites counted as eligible after invite create.
- No FCM token API; dispatcher had no Push sender.
- Flutter saved outings prefs-only; saved places constants-only.
- Missing canonical `docs/PRODUCT_SCENARIOS.md` / `AGENTS.md`.

## What was fixed

| Area | Change |
|------|--------|
| Docs | `AGENTS.md`, `docs/PRODUCT_SCENARIOS.md`, canonical architecture wrappers, audit docs |
| Mocks | Deleted `flutter/lib/core/mock`; removed `useMockData` everywhere |
| Deadline | Create requires `vote_ends_at` or `vote_deadline_hours` |
| Vote reset | Create/delete/replace vote options clear votes + notify; `PUT …/vote-options` |
| Confirmed lock | UpdateOuting rejects location edits when confirmed/winner set |
| Membership | `outing_guests.status` (pending/accepted/…); eligibility = accepted + owner + group members; accept/decline APIs |
| FCM | `POST/DELETE /api/user/fcm-token`; `PushChannel` registered; Flutter registers token |
| Saved outings | Flutter remote DS → Neon APIs (drafts remain local) |
| Attendance | Flutter no longer blocks attendance when votes finalized |

## Tests executed

| Suite | Result |
|-------|--------|
| Neon identity check (host/db) | PASS — authorized development Neon |
| `prisma migrate deploy` additive `outing_member_invite_status` | PASS |
| `prisma generate` / `tsc --noEmit` | PASS |
| `tests/outing-lifecycle.test.ts` + `resource-authz.test.ts` | PASS (23/23) |
| `tests/voting-concurrency.test.ts` | PASS (3/3) |
| Flutter `dart analyze` (targeted after fixes) | 0 errors on fixed surfaces (prior infos/warnings elsewhere) |
| Flutter unit `app_config_test` | Not re-run in this pass after mock removal (file updated) |
| Device E2E scenarios A–N | **NOT RUN** |
| Real FCM delivery to device | **NOT RUN** (PushChannel + token path implemented; delivery unverified) |

## Compliance matrix (post-fix)

| Scenario | Status |
|----------|--------|
| A/B Create group / special event + mandatory deadline | PASS (API/tests) |
| C Invitation + deep link | PARTIAL — outing accept/decline APIs exist; Flutter group deep-link restore remains; outing deep-link UI incomplete |
| D Voting | PASS (tests) |
| E Candidate modification reset | PASS (concurrency + use cases) |
| F/G Early / deadline close | PASS (existing + tests) |
| H Tie-break idempotent | PASS (concurrency) |
| I Attendance independent | PASS (backend + Flutter write-path fix) |
| J Chat statuses | PASS (prior) |
| K Owner permissions | PASS (authz tests) |
| L Saved outings/places | PARTIAL — outings remote wired; places remote DS added, UI wiring thin |
| M Notifications / FCM | PARTIAL — outbox + PushChannel + token API; device delivery NOT RUN |
| N Deep-link edge cases | NOT RUN (device) |

## Remaining blockers / gaps

1. Flutter outing invite deep-link accept/decline UI and restore beyond group invites.
2. Saved places UI/provider wiring (remote DS present).
3. Candidate-edit UI calling `PUT` replace on Flutter.
4. Owner cancel / cancelled badge polish on Flutter.
5. Real device E2E + FCM delivery verification.
6. Flutter create outing must always send deadline fields to match new API validation.

## Security / performance notes

- Confirmed place IDOR-style location overwrite closed on update use case.
- Vote PK + clearVotes reduce orphan vote risk.
- Push with zero tokens marked sent (skip) to avoid infinite outbox retry; invalid tokens deleted.
- No production DB writes; development Neon only.

## Files changed (high level)

- Docs: `AGENTS.md`, `docs/*`, `docs/audit/*`, Flutter project-context rule
- Backend: validators, create/update outing, voting use cases, guests, push channel, FCM routes, prisma migration, tests
- Flutter: mock deletion, config/DI, saved outings remote, FCM token register, attendance fix, API constants

## Final instruction reminder

[`docs/PRODUCT_SCENARIOS.md`](../PRODUCT_SCENARIOS.md) is the permanent product reference. Conflicting implementations are compliance issues until the product owner updates that document.
