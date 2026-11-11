# Automatic GPS attendance

## Findings and implementation

The previous arrival flow coupled automatic verification to Going RSVP and a stored opt-in switch. It also accepted explicit GPS submissions and organizer confirmations, and refreshed other viewers through polling. Actual Attendance now opens the same automatic GPS flow for every current group participant. The roster and GPS verification are independent of RSVP and creator role.

Flutter loads the confirmed venue coordinates and check-in window from the authenticated API. The visible outing route requests foreground OS location permission when needed. It checks on open and resume, takes bounded position samples up to once per minute while the route remains active, and stops scheduling after departure from the route, backgrounding, verification, or the end of the window. A sample already requested from the OS can finish, but the route discards it if the route or window is inactive. The affected user sees Location unavailable when permission, GPS, or fix accuracy prevents verification. Other unverified members are shown as Not yet verified so the application does not disclose their device state.

The server derives the participant UID from Firebase, validates current group membership, locks the outing and the caller’s membership row, and resolves the confirmed coordinates in Neon. It checks timestamps, coordinate bounds and reported accuracy, and calculates Haversine distance. Defaults are a 100 m radius, a 50 m maximum reported horizontal accuracy and a 360-minute window capped by the scheduled end. The sample must be at most 30 seconds old and at most five seconds ahead of server time. The app filters platform-reported mock fixes, and the API rejects fixes explicitly reported as mocked. Device GPS remains client-reported evidence.

The first successful GPS verification writes one row for the outing and participant. The row records a server timestamp, method `gps`, distance and accuracy. Exact device coordinates are discarded. An authorized retry returns the existing result even after the participant has left the venue. Removal from the group denies new submissions.

After committing a new arrival, the server emits `outing:arrival_changed` with the outing ID to current participants over authenticated Socket.IO user rooms. The event contains no participant location or device status. A visible Flutter roster reloads on that event and on reconnect. The same Socket.IO connection serves chat.

## Database and API

- Applied Prisma migration `20261110150200_gps_arrivals` to the configured Neon development database. Prisma reported ten applied migrations and an up-to-date schema.
- Reused `outing_arrivals` and its composite key. The constraint accepts the new `gps` method. Earlier GPS records are preserved. Previous organizer records remain in the database for compatibility but are excluded from verified attendance and can be superseded by valid GPS verification.
- `GET /api/outings/{id}/arrivals` returns the authorized roster, confirmed venue coordinates and the verification policy. `PUT /api/outings/{id}/arrivals/self` verifies the caller’s GPS sample. It accepts `automatic_gps` as a compatibility spelling and stores `gps` for new rows. The organizer endpoint and Flutter manual controls were removed.
- Updated OpenAPI, the product and journey documents, backend and Flutter architecture, API and database contracts, authorization and business rules, the system design diagram, and the Cursor backend and Flutter rules. This report supersedes the earlier manual and organizer attendance design.

## Main files

- Backend `usecases/outings/arrivals.usecase.ts`, `services/outings/arrival-policy.ts`, `validators/outings/outing.validator.ts`, `routes/outings/outing.participants.routes.ts`, `controllers/outings/outing.controller.ts`, `config/swagger.ts`, and `realtime/{chat-emitter,rooms,socket-server}.ts`.
- Flutter `outing_arrivals_section.dart`, `outing_arrival_service.dart`, `outing_arrivals_remote_datasource.dart`, `outing_arrival.dart`, `outing_chat_socket_client.dart`, the app dependency wiring, shell lifecycle, localization, and the iOS foreground permission description.
- Verification `backend/scripts/backend-full-integration.ts --custom-session-features`, `backend/tests/arrival-policy.test.ts`, and `flutter/test/automatic_arrival_test.dart`.

## Verified results

- **PASS** Real Express, Firebase, Neon and Socket.IO integration. An owner and a regular member both verified independently, including a member whose RSVP was Not Going. A Going RSVP alone, a fix outside 100 m, an inaccurate fix, a reported mock fix and a stale fix did not verify. Repeated submissions kept one row and the first timestamp. Leaving the radius did not remove an arrival. A removed member was denied. Both connected clients received both new-arrival invalidations. Fixtures were cleaned up.
- **PASS** Backend TypeScript build and Express/OpenAPI agreement across 86 operations.
- **PASS** Flutter focused tests for denied permissions, disabled GPS, poor accuracy, mock fixes, range, foreground resume and realtime roster refresh.

- **PASS** Full Flutter suite, 97 tests. Flutter analyzer reported zero errors. Existing warnings remain outside the GPS feature.
- **PASS** The two GPS policy tests and the real Neon outing lifecycle test passed in a focused backend run. The preceding full backend regression run reported 128 passes and one Neon connection failure. That lifecycle test passed on the focused retry.

## Device-level verification

A supported Android or iOS device is needed to exercise the OS permission prompt, physically cross the configured radius, and confirm the timer behavior during native app switching. The implemented path uses foreground GPS only. A closed app leaves previously verified arrivals in Neon and has no running Flutter GPS scheduler.
