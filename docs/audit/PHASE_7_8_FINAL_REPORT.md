# Phase 7 & 8 — Final polish, integration audit and organization

Date: 2026-11-15. Scope: existing Flutter app, backend verification tooling, canonical project instructions and file organization. All evidence is from the working-tree snapshot at execution time. The checkout already contained substantial uncommitted places/map/arrival/notification changes; those were preserved. No commit, deployment or application database operation was performed.

## Phase 7 completed

- Shared SegmentedTabs: keyboard-operable Material targets, selected semantics, at least 48dp height, equal-height wrapping labels/counts, existing semantic colors, offset shadow and reduced-motion duration. Auth/Saved tab APIs and selection state remain.
- Shared CustomTextField: localized semantic label while preserving visible heading, hint, input/OTP behavior and validation. MarqueeText measures ambient system text scaling and remeasures direction/locale/dependency/gap changes.
- Existing group creation, auth, planning, settings Account/Preferences/Support/About, phone status and chat mention controls reuse AppPalette semantic roles; the auth header can wrap and saved-item removal has a localized tooltip. Chat loading bubbles use directional alignment.
- Feature-local OutingScheduleField removes duplicated date/time card rendering. It accepts existing values/callbacks; date/time policy remains in the wizard/provider.
- Existing chat route already leaves its reference-counted outing room on dispose. Transient room-join retries are now capped at five delays (1/2/4/8/16 seconds); success clears attempts, explicit recovery/reconnect retains room intent, exhaustion reports offline, leave/logout cancel retries. Provider disposal advances generation/cancels subscriptions and blocks late notifications; repeated zero-count unsubscribe is harmless. The shared session socket remains available to other app-wide consumers.
- Removed two analyzer-confirmed unused auth helpers and awaited registration/password-cache completion within existing error boundaries. No auth endpoint, identity policy or application password authority changed.
- Removed unused SplashPreview and ActiveVoteTile after checking imports/symbols and their current replacements. Current onboarding and GroupOutingsList remain. Referenced compatibility exports/aliases remain.

## Integration and business-rule source audit

The inventory covers **30 page files** across auth/recovery, shell/Home/onboarding, groups/contacts, invitations, outings/create/edit/special-event/details/history/saved/location/guest selection, Discover, notifications and settings/profile/information. Per-page paths and component-import counts are recorded in PHASE_8_STRUCTURE_RESULTS.json. This inventory and targeted dependency tracing are source evidence, not a rendered audit or an authenticated journey pass.

| Concern | Source evidence / disposition |
|---|---|
| Real application data | Existing RepositoryFactory → repositories/datasources → ApiClient remains; page inventory has no direct Dio/http/Firebase/socket SDK imports. No production demo repository/data was introduced. The removed splash preview was unused. Existing mock media storage is an environment-selected development adapter, retained with its contracts. |
| Authorization / invitations | Existing Firebase REST/socket identity verification, resource guards and pending/accept/decline workflows retained. The HTTP audit covers rejection of missing/malformed credentials, not authenticated ownership success. |
| Voting / lifecycle | Existing outing-scoped multiple-place ballots, server closure/winner/tie/deadline/confirmed-venue guards retained; no voting logic or migration changed. |
| RSVP / GPS | Existing attendance and arrival paths remain separate; creator Going and scheduled/foreground/venue/permission gates retained. |
| Chat | Outing-only route, participant-authorized history, completed/cancelled/two-hour read-only gates retained. Room retries/disposal hardened as above; no group chat or additional socket added. |
| Notifications / deep links | Existing push navigator resource refresh, account-current checks, specific invitation/chat/message/detail destinations retained. No routes renamed. |
| Offline / images | Existing account/origin snapshots, UUID chat queue, bounded recovery/deduper and media:// image resolver/cache remain. No replacement cache or generic mutation replay added. |
| Network lifecycle | Existing AppSyncProvider owns global subscriptions/debounce/resume/reconnect; route-specific arrival/countdown resources are cancelled. This pass removes one identified unbounded room retry loop; live traffic/request volume was not measured. |

Larger creation/chat/map routes remain coordinators for existing feature widgets and providers. No broad architecture replacement or untested module rename was attempted. Existing design tokens and Material 3/Provider/GetX/manual L10n remain authoritative.

## Phase 8 completed

Root AGENTS.md now contains all 13 requested policy sections, the selective documentation workflow, same-task documentation mapping and safety requirements. Its source hashes are in PHASE_8_RULE_SOURCES.json. Source rules were compared with current schema, auth flow, map dependency and existing architecture before consolidation.

| Original policy source | Result / preserved content |
|---|---|
| Root AGENTS.md | Expanded/consolidated; existing workflow, safety, documentation, stack and UI/accessibility requirements retained. |
| .cursor/rules/global.mdc | Reduced to an always-applied `@AGENTS.md` reference, with no project policy copy. |
| .cursor/rules/flutter.mdc | Merged then removed: Provider/layer/DI/API/widget and RSVP/arrival guidance. |
| .cursor/rules/backend.mdc | Merged then removed: thin controllers, use cases, transactions, resource guards, consent and GPS rules. |
| .cursor/rules/database.mdc | Merged then removed: integrity, migration safety, enums and source-of-truth rules. Stale single-vote uniqueness corrected to the implemented outing/user/option ballot key. |
| .cursor/rules/documentation.mdc | Merged then removed: maintenance mapping, diagrams and explicit implementation/verification status. |
| .cursor/rules/ui-ux.mdc | Merged then removed: existing design/RTL/themes/tokens/responsive/accessibility/motion/skill guidance. |
| flutter/.cursor/rules/project-context.mdc | Merged then removed: package/entry/manual DI/live repositories, saved data/auth/push guidance. Old flutter_map/social-email descriptions corrected to current MapLibre and phone/password+OTP/custom sessions. |
| backend/.specify/memory/constitution.md | Unfilled upstream placeholder replaced with a reference to root AGENTS.md; workflow lookup path retained. No unique project principles existed there. |

[Cursor documents AGENTS.md and file references in .mdc rules](https://cursor.com/docs/rules). Its references ask the agent to read a file; they do not guarantee automatic full inlining. Open the monorepo root. This Codex task receives root rules through the host project context. Installed-version Cursor loading was not UI-tested. No Claude/Gemini instruction setup is present, so no compatibility for those uninstalled tools is claimed. Codex/Cursor MCP, hook/settings files, installed skills/Impeccable agents, lockfiles and Spec Kit templates/manifests remain; they are tool packages/configuration, not redundant project policies.

## Files moved / removed and safety

- `docs/AI_UI_UX_SETUP.md` → `docs/development/AI_UI_UX_SETUP.md`.
- `docs/UI_UX_AUDIT_AND_HOME_REDESIGN.md` → `docs/audit/UI_UX_AUDIT_AND_HOME_REDESIGN.md`.
- Both moves verified identical bytes at move time; later compatibility/historical-status notes were appended. Original content is retained; canonical journey/Flutter links were updated. Hash/move evidence is in PHASE_8_FILE_MOVES.json.
- Deleted the six duplicate Cursor rules listed above, unused `flutter/lib/features/splash/presentation/widgets/splash_preview.dart`, and unused `flutter/lib/features/groups/presentation/widgets/cards/active_vote_tile.dart`.
- Removed only verified empty `flutter/.cursor/rules`, `flutter/.cursor`, `.github/workflows`, `backend/deploy` and `flutter/lib/features/outings/data/models` directories, nonrecursively. The pre-existing places schedule file deletions were not performed by this task.
- Removed this task's failed SDK-lock analyzer output; kept successful initial/final analysis evidence. Kept historical reports, older referenced probes, generated/tool directories and `.cleanup-checkpoint` rather than treating age/names as deletion proof. No byte-identical Markdown document groups were found.
- No schema, migration, seed, production asset, environment/secret or required build configuration was removed or moved by this task. No application API/source module was renamed. Backend changes in this task are verification scripts and their index only.

## Final folder structure

```text
yalla5roga/
  AGENTS.md                 canonical project policy
  README.md, DESIGN.md       project entry and incumbent visual authority
  .agents/skills/            installed skills
  .codex/                   MCP and hooks (retained)
  .cursor/                  one policy reference; installed skills/agents/hooks/MCP
  .vscode/                  development configuration
  docs/
    *.md                    canonical product / architecture / contracts
    audit/                  dated evidence, reports and results
      database/             existing database audits
    development/            tool setup guide
    system-design/          historical technical deep dives
  scripts/                  repository audit and existing device helper
  flutter/
    lib/core/               shared tokens/widgets/network/cache/media/maps
    lib/features/           existing feature-first data/domain/presentation
    assets/, test/, tool/   existing application resources and developer tools
    android/, ios/, .../    existing platform/build configuration
  backend/
    src/                    existing routes/controllers/usecases/repositories/data
    prisma/                 schema, all migrations and existing seed structure
    scripts/, tests/        verification/development scripts and existing tests
    licenses/               existing places data attribution
    .cursor/, .specify/     retained development tooling
```

Ignored local build/data/cache/environment/checkpoint directories are retained; this tree describes organization, not a deletion list. Script README indexes group existing commands by purpose without breaking established paths.

## Verification results

| Check | Result |
|---|---|
| Flutter static analysis, initial | 0 errors, 4 warnings, 46 infos; 50 findings. |
| Flutter static analysis, final | **0 errors, 0 warnings, 45 infos**; analyzer exit 1 because informational lints remain. No errors/warnings introduced. |
| Formatting | All 20 added/modified Dart files formatted; final small-edit pass reported no changes. Earlier sandbox telemetry access failure was resolved by the permitted formatter run. |
| Served Swagger/OpenAPI | **188 PASS checks**, 111 documented operations, 93 protected operations checked with missing and malformed auth; no failed final checks. |
| Route/OpenAPI parity | All 111 JSON application operations match with unique IDs/valid local refs. The exact two existing mock-media binary transports are explicitly classified outside JSON application parity; no wildcard exemption. R2 runtime branch untested. |
| Structure/reference audit | **2952 local source imports checked, 0 unresolved**, 0 stale moved-document references; one canonical AGENTS.md and one reference-only Cursor rule; all required policy sections present. |
| Static text contrast | 16 selected opaque semantic foreground/background pairs, light/dark, each ≥4.5:1. This is color arithmetic from source; it does not certify rendered screens, overlays, map labels or all combinations. |
| Diff whitespace | `git diff --check` passed. |
| Flutter runtime / visual / widgets / integration / emulator / device / UI automation | **NOT RUN**, explicitly prohibited. |
| Authenticated user scenarios / live sockets / actual FCM / offline replay / GPS / SMS | **NOT RUN**; source wiring retained, no end-to-end claim. |
| Production data / migrations | **No operations performed**. HTTP audit forces an unreachable DB target; no workers or socket server started. |

Flutter Windows wrapper stalled on its SDK cache lock; static analysis used the installed Dart executable + flutter_tools.snapshot with `analyze --no-pub`, with cache access approved. It is the Flutter analyzer, not an app launch. The new HTTP audit initially exposed the validator's two dev-transport mismatch; that was corrected and the final audit passed. Sandbox localhost access was approved for the temporary listener. No Flutter tests, database fixtures or production mutations were used to obtain these results.

Reproduce from repo root: `python scripts/audit-project-structure.py`. From `backend/`: `node --import tsx scripts/phase7-openapi-verification.ts`. Flutter static check: `flutter analyze --no-pub` (or the installed tool snapshot if the host wrapper stalls). Do not substitute `pnpm start`, which runs migrations.

## Documentation Updates

Updated root AGENTS.md, README.md and DESIGN.md; canonical PROJECT_STRUCTURE, FLUTTER_ARCHITECTURE, SYSTEM_DESIGN, USER_SCENARIOS, AUTHENTICATION_AND_AUTHORIZATION and BACKEND_ARCHITECTURE; moved setup/historical audit documents; added root/backend script README indexes and this report plus JSON/text verification evidence. The structure map and obsolete Discover renderer statement were synchronized with source. No product/API/schema policy changed. **Diagrams: unchanged**, because component/data/authorization/ER flows did not change; bounded retry/disposal details are documented in text.

Remaining limits: 45 informational analyzer lints across existing network/auth/chat/notification/discovery code remain; broad mechanical rewrites were avoided in the shared working tree. Source/static checks cannot establish visual consistency, actual assistive-technology announcements, layout at every text scale, live request rates, auth/membership success, push/deep-link lifecycle, reconnection, offline image/cache behavior or real GPS. Existing audit reports retain their dated findings and may describe superseded implementations; canonical docs/current source take precedence. Other in-progress changes remain uncommitted and outside this task's ownership.
