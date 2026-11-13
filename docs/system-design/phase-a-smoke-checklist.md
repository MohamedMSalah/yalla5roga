> **Historical reference — corrected 2026-11-13:** Endpoint paths and PASS claims below describe an older implementation/run and are not current verification. Current registered routes use `/api/outings/:outingId/messages` and `/api/outings/:outingId/read`, `/api/invitations/:invitationId/decline`, and `/api/users/cuser/fcm-token`. There is no registered `POST /api/outings/hydrate`; Flutter hydrates via the existing current-user/detail/voting/attendance GET operations. Prefer `../API_CONTRACTS.md` and the current confirmed-fixes report.

# Phase A — Vertical Slice Smoke Checklist (QA-A7)

Run with Flutter `USE_MOCK_DATA=false` and `API_BASE_URL` pointing at a local/staging API host (no `/api` suffix; paths include `/api`).

## Backend

- [ ] `pnpm test` passes (includes `tests/resource-authz.test.ts`)
- [ ] Non-creator `PATCH/DELETE /api/outings/:id` → 403
- [ ] Non-owner `PATCH/DELETE /api/groups/:id` → 403
- [ ] Other user `PATCH /api/notifications/:id/read` → 403
- [ ] `/api-docs` shows `/api/auth/login|signup` as deprecated; sync described as canonical

## Flutter live path

- [ ] Firebase email/phone/Google/Apple sign-in succeeds
- [ ] App calls `POST /api/users/sync` after sign-in (network log)
- [ ] Profile save hits `PATCH /api/users/cuser`
- [ ] List/create group against `/api/groups`
- [ ] Create outing, cast vote (`option_id`), set attendance (`PUT`, snake_case status)
- [ ] Send outing chat message via `/api/chat/outings/:id/messages`
- [ ] Mark outing chat read via `PATCH /api/chat/outings/:id/read`
- [ ] Notifications list + mark one read via `PATCH`
- [ ] Mark all notifications read via `PATCH /api/notifications/read`

## Known Phase A workarounds

- Leave group uses `DELETE /api/groups/:id/members/:selfUid` (owners who are sole owner will get 403)
- Saved outings / drafts still prefs-only
