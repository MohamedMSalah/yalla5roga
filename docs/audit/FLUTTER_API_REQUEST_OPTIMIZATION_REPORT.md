# Flutter API Request Optimization Report

| Metadata | Value |
|----------|-------|
| Date | 2026-11-08 |
| Scope | Entire Flutter app (`flutter/lib`) |
| Backend contracts changed | **No** |
| Status | Implemented + unit-tested |

## 1. Global API request inventory

| Feature | Primary endpoints | Trigger |
|---------|-------------------|---------|
| Auth | `POST /api/auth/*`, `POST /api/users/sync`, `GET /api/users/cuser` | Login / restoreSession / refreshProfile |
| Outings | `GET /api/outings/cuser`, `…/vote-options`, `…/votes`, `…/voting-state`, `…/attendance`, mutations | Shell boot, tab/detail refresh, vote/attendance |
| Groups | `GET /api/groups/cuser`, `GET /api/groups/:id` | Shell boot, resume, group details |
| Discover | `GET /api/places`, featured places | Shell boot after home |
| Notifications | `GET /api/notifications`, mark-read | Shell boot, resume, inbox |
| Saved | `GET /api/outings/saved`, local drafts | Shell boot |
| Chat | `GET/POST …/messages`, `POST …/read`, Socket.IO | Chat page subscribe / reconnect |
| FCM | `POST/DELETE /api/users/cuser/fcm-token` | After permission |

Path: UI → Provider → Repository → DataSource → `ApiClient`/Dio.

## 2. Duplicate / excessive request findings

### Critical (fixed): Outings N+1 fan-out

**Before:** `OutingsRemoteDataSource.load()` fetched `GET /outings/cuser`, then for **every** outing sequentially called vote-options + votes + voting-state + attendance (~**1 + 4N** requests).

`refreshLifecycle()` was `=> load()` and **bypassed** the 2-minute TTL cache.

Amplified by:

| Trigger | File | Issue |
|---------|------|-------|
| Outings tab | `outings_page.dart` | Forced full fan-out |
| Event details | `event_page.dart` | Full feed for one screen |
| Chat open | `outing_chat_page.dart` | Full feed + chat REST |
| Vote / attendance / tie-break | `outings_remote_datasource.dart` | Ended with full `load()` |

### Secondary

| Finding | Verdict | Action |
|---------|---------|--------|
| No in-flight GET dedupe | Inefficiency | Added `RequestDeduper` + `cachedRemote` integration |
| Discover featured → places sequential | Safe parallelize | Parallel start |
| Saved + drafts sequential | Safe parallelize | Parallel start |
| App resume groups+notifications | Legitimate unread; TTL OK | 2s debounce |
| Auth `refreshProfile` on restore | Legitimate once/boot | Unchanged |
| Chat socket reconnect → REST | Legitimate gap-fill | Keep debounce + dedupe |
| API calls in `build()` | None found | — |
| Duplicate app-wide providers | None (single `AppDependencies` instances) | — |

## 3. Root causes (source references)

1. **N+1 hydration** — `flutter/lib/features/outings/data/datasources/outings_remote_datasource.dart` (former sequential loop over all outings).
2. **Lifecycle = full reload** — same file `refreshLifecycle → load`; repository always hit network.
3. **Mutation over-refresh** — `selectVote` / `setAttendance` / `breakTie` returned `await load()`.
4. **Missing request coalescing** — `core/cache/cached_remote.dart` had TTL but no in-flight sharing.

## 4. Before / after request statistics

Scenario: **5 voting + 3 past/draft** outings.

| Scenario | Before (approx HTTP) | After (approx HTTP) |
|----------|----------------------|---------------------|
| Cold shell outings load | 1 + 4×8 = **33** | 1 + ~3×5 (options+votes+attendance, parallel) ≈ **16**; no past/draft hydrate; skip voting-state when `vote_ends_at` present |
| Open Outings tab (TTL fresh) | **33** (forced network) | **0** network (cache hit) |
| Open Event page | **33** | **1–3** for that outing only |
| Cast vote | 1 POST + **33** | 1 POST + votes/attendance for **one** id |
| App resume (within TTL) | 2 (groups+notifications) often network | Debounced; TTL may serve cache |

Exact counts appear in debug logs via `RequestDiagnostics.instance.formatSummary()` after shell bootstrap.

## 5. Optimizations implemented

### Diagnostics (debug only)

- `core/network/diagnostics/request_diagnostics.dart`
- `core/network/diagnostics/request_diagnostics_interceptor.dart`
- Wired in `AppDependencies` when `kDebugMode`
- No tokens/bodies logged; path IDs normalized to `:id`

### In-flight dedupe

- `core/network/request_deduper.dart`
- Integrated into `cachedRemote`, outings hydrate helpers, chat `getMessages`

### Outings hydrate redesign

- List load hydrates **voting** outings only (votes + attendance), concurrency 4
- Skip `voting-state` when list/detail JSON already has closure/`vote_ends_at`
- `reloadOutingDetails(outingId)` for detail/mutation paths
- Mutations merge into last snapshot without full cuser fan-out
- Create outing still does one full `load()` (membership changed)

### Lifecycle / cache

- `refreshLifecycle({outingId, forceRefresh})` — TTL for full refresh; targeted for detail
- Event/Chat pass `outingId`
- MainShell resume debounced 2s
- `clearCache()` on outings/groups/discover/notifications/chat repos; providers call on logout `clear()`

### Parallel boot helpers

- Discover featured + places start together
- Saved bookmarks + drafts start together

## 6. Cache invalidation strategy

| Event | Behavior |
|-------|----------|
| TTL expiry | Next read hits network (`CachePolicy`: outings/groups 2m, discover 10m, notifications 45s, chat 30s) |
| Mutation success | Snapshot/key updated or invalidated for that resource |
| Pull-to-refresh / `forceRefresh: true` | Bypass TTL |
| Logout / account switch | Provider `clear()` + repository `clearCache()` |
| Failed in-flight request | Deduper drops key → retry allowed |

User-specific data is session-scoped in memory TTL caches; logout clears them. Do not lengthen TTLs arbitrarily.

## 7. Remaining unnecessary / expected requests

| Item | Notes |
|------|-------|
| Per-voting-outing options+votes+attendance | Still O(V) until backend batch hydrate |
| Create outing → full `load()` | Required to refresh feed membership |
| Chat reconnect REST | Needed for missed socket messages |
| Profile refresh on boot | One `GET /users/cuser` |
| Group details `ensureGroupLoaded` | When list row lacks members |

## 8. Backend optimization recommendations (not implemented)

1. **`GET /api/outings/cuser?include=votes,attendance`** or **`POST /api/outings/hydrate`** with ids → one payload with options, tallies, my votes, attendance.
2. Embed on list items: `vote_ends_at`, `vote_closed_at` / `is_voting_closed`, `my_vote_option_ids`, `going_count`.
3. Optional **unread badge** endpoint for resume (avoid full groups list when only badges needed).

Expected benefit: cold home outings path → **O(1)–O(2)** requests instead of O(V).

## 9. Automated test results

```
flutter test test/request_deduper_test.dart \
  test/async_pool_test.dart \
  test/request_diagnostics_test.dart \
  test/cached_remote_dedupe_test.dart \
  test/outings_hydrate_optimization_test.dart
```

**Result: All 11 tests passed** (2026-11-08).

Coverage:

- In-flight dedupe + retry after failure
- `cachedRemote` TTL hit + concurrent miss coalesce
- Selective voting-only hydrate; skip past/draft
- `selectVote` / `setAttendance` do not re-hit `/outings/cuser`

## 10. Manual QA scenarios

- [ ] Cold launch authenticated → home feed; check debug `[API Diagnostics]` summary
- [ ] Switch Home ↔ Groups ↔ Outings ↔ Settings (no storm of duplicate GETs)
- [ ] Open / close Event page (only that outing’s detail calls)
- [ ] Vote + attendance; related lists update without full fan-out
- [ ] Chat open, background app, resume (socket recover + single REST fill)
- [ ] Notifications pull-to-refresh still forces network
- [ ] Logout → login other account (no stale groups/outings/chat)
- [ ] Airplane mode → cached/stale paths still degrade gracefully

## Documentation Updates

| File | Change |
|------|--------|
| This report | Created |
| `docs/FLUTTER_ARCHITECTURE.md` | Networking: diagnostics, dedupe, selective outings hydrate |
| `docs/PROJECT_STRUCTURE.md` | New core paths |
