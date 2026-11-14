# No response RSVP and live voting countdown

Implemented 2026-11-14 (Africa/Cairo), preserving unrelated in-progress work.

## Changes

Unanswered RSVP defaults now appear as **No response** / **لم يرد بعد**, including Who’s going. The backend merges actual saved responses with current accepted membership, returning explicit no_response rows, nullable timestamps, phone-free names/avatars, and a four-way summary. A missing response remains the durable default; GET does not create fake responses. Going/Maybe/Not Going remain the three user-selected persisted writes, and the creator stays Going. Pending invitees remain excluded until acceptance. Location votes remain independent.

The outing datasource previously returned an empty membersForOuting list. It now stores roster profiles from the authorized attendance response and preserves profiles/defaults in the existing account/origin snapshot cache, including after complete realtime RSVP events. The UI shows default status and count and refuses to post the read-only default as a mutation.

Voting countdowns now update every second with days/hours/minutes/seconds, use current wall time rather than accumulated ticks, clamp expiry to Voting ended, and respect early closure/terminal states. The countdown is inside the shared active-vote card footer and remains in detail voting cards. Its timer stops for disabled TickerMode/background and on disposal, and recomputes on resume or deadline changes. No API polling, client closure or winner logic is added.

## Verification

Seven focused headless tests passed and 18 OpenAPI HTTP checks passed. The headless tests cover time arithmetic, final-second rounding, expiry/early closure, UTC offsets, English/Arabic labels, readonly defaults, roster hydration/response changes, cache clearing, and profile/default persistence through realtime cache writes and offline reopening. OpenAPI HTTP checks exercise actual routers/use cases/repositories in a disposable PostgreSQL schema with a controlled Firebase verifier. They cover initial/repeated defaults, complete phone-free rosters, counts, RSVP persistence, place-vote independence, pending exclusion, explicit acceptance/new-member default and owner Going. See RSVP_COUNTDOWN_OPENAPI_RESULTS.json. No public data/schema change or migration was needed; the test schema was removed.

Dart format, focused Flutter analysis (no issues) and TypeScript compilation passed for this change. No Flutter app, emulator, device, widget tests or UI automation is launched. Visual/physical-device timer and theme/RTL rendering remain unexercised; timer behavior is verified in source and remaining-time logic is unit-tested.

## Documentation Updates

PRODUCT_SCENARIOS, BUSINESS_LOGIC and USER_SCENARIOS record the explicit unanswered default and UI behavior. API_CONTRACTS documents roster/profile/default/summary fields. FLUTTER_ARCHITECTURE, BACKEND_ARCHITECTURE and SYSTEM_DESIGN describe the read projection/cache/timer boundaries. DATABASE_ARCHITECTURE explains the unchanged absence-of-response storage model. PROJECT_STRUCTURE maps extracted files and checks. No diagram topology changed; no known RSVP/countdown contract mismatch remains.
