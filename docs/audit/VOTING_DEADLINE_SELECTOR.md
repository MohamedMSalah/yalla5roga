# Voting deadline selector

Implemented 2026-11-14 (Africa/Cairo) within the existing Create Outing flow.

## Behavior

Information now includes “Voting Deadline” / “موعد انتهاء التصويت”, a native Material 3 Hours/Days segmented control, and single-selection wrapping ChoiceChips. Hour presets: 1, 2, 3, 6, 12, 24. Day presets: 1, 2, 3, 5, 7. Existing L10n/number formatting, theme roles, Responsive spacing and native focus/disabled/selection behavior are reused. No dependency/core control is added for one feature.

CreateOutingProvider owns the hours/unit, schedule validation and cancellable preview clock; a domain policy handles elapsed duration/instant comparisons. Invalid options are disabled, invalid selected values have inline errors, and Continue/Create are disabled until corrected. Schedule changes revalidate immediately; time passage revalidates every 30 seconds and again synchronously at navigation/submission. Selection survives previous-step navigation and saved drafts. Review shows a local deadline estimate.

The full selected duration starts immediately before the actual create POST, after any cover upload. The existing vote_ends_at field carries the absolute UTC ISO-8601 deadline; vote_deadline_hours remains duration metadata. Outing parses the canonical server timestamp, preserves it through copyWith and provider refresh, and the existing post-create detail route displays it. The preview explicitly says duration starts on submission.

Backend validation and the create use case share a resolver that requires a future deadline, strictly before scheduled_at when supplied. Equality is invalid. Legacy relative-only requests use server time. Existing voting resolution, closure jobs, permissions and notifications are unchanged.

## Database

The original outing/draft duration check capped existing fields at 72 hours. Five/seven-day selections require 120/168 to survive draft persistence. Migration 20261114010000_voting_deadline_durations expands those two checks to 168; no columns, endpoints, tables or IDs change. It was deployed to the verified Neon project/branch/database with Prisma Migrate after an impacted-table backup and rollback-only recovery/migration rehearsal. Existing source checksums matched after deployment. The scoped migration manifest excluded unrelated pending feature migrations. See VOTING_DEADLINE_DATABASE_DEPLOYMENT.json; private backup data remains ignored under backend/.database-backups/.

## Verification

- Eight focused headless Dart tests passed: every duration preset/offset arithmetic; strict schedule equality/ordering; wizard and saved-draft retention; schedule/time-passage revalidation; unit switching and invalid chips; English/Arabic local formatting; request-time calculation/canonical response parsing; and rejection before HTTP when submission becomes invalid.
- Targeted Flutter analysis reported no issues in the affected files. Dart format was run on the named task files.
- Backend TypeScript compilation passed.
- 35 Swagger/OpenAPI HTTP checks passed using real PostgreSQL in a disposable schema and a controlled Firebase verifier. Covers every requested hour/day preset, persisted deadline readback, offset normalization, mandatory/future/before-start validation, relative-only compatibility, upper bound rejection, and seven-day draft create/read. The temporary schema was removed.
- The API verification script initially mounted drafts after the dynamic CRUD route; it was corrected to the application’s static-first order. No production route change was required.

No Flutter app, emulator, device, UI automation or widget tests were launched. Phone/wide, light/dark, RTL/LTR, keyboard and large-text rendering were checked in source but not visually exercised. Actual Firebase issuance, physical device clocks and backend hosting deployment were outside these checks.

## Documentation Updates

Updated PRODUCT_SCENARIOS, USER_SCENARIOS and BUSINESS_LOGIC with approved presets, before-start validation and submission timing. API_CONTRACTS documents existing fields/ranges/400 outcomes. DATABASE_ARCHITECTURE records the check expansion/deployment. FLUTTER_ARCHITECTURE and BACKEND_ARCHITECTURE document policy/provider/datasource/helper boundaries. SYSTEM_DESIGN records the unchanged create flow with deadline calculation, and PROJECT_STRUCTURE maps the new files. No diagram topology changed; no known deadline contract inconsistency remains. Other in-progress repository work was preserved.
