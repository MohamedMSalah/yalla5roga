# Smart Meetup realtime verification

## REST through Swagger

The focused backend suite passed 22 checks against disposable loopback PostgreSQL. It served `/api-docs/openapi.json` from the Express app and validated authenticated responses against the documented operations. Fixtures covered current group rosters, private Quick Meetup access, default and temporary starts, consent and exclusions, preferences, results, cancellation, expiry and stale handoff. Result reads exposed the session status and calculation attempt. Callers lost REST access after removal from the group.

The migration applied to a fresh database. The release backup workflow restored 57 synthetic tables and 103 rows, verified their checksums, and applied the exact migration inside the disposable rehearsal transaction before rolling it back. A backup taken after applying the migration also passed restore and checksum verification.

## Socket.IO

`backend/tests/smart-meetup-realtime.test.ts` used real Socket.IO clients on the same loopback HTTP server as Swagger. It ran the production handshake and gateway with fixture Firebase verification. The test delivered committed outbox rows through `MeetupEventPublisher`, independently of the Swagger calls.

- The server rejected missing authentication, malformed session IDs, nonmembers and other users' Quick Meetup joins. The owner could leave the Meetup room without leaving the existing user room.
- Accepted members received the current version after joining or reconnecting. A default change updated readiness. Withdrawing location consent removed the input while the current member retained readiness access.
- The publisher removed an ex-member from the room. They received an access-loss event with the session ID and no subsequent readiness version. Expiry followed the authorized terminal event and closed the room.
- A rolled-back write produced no durable hint. Database constraints rejected extra payload fields. Shared messages contained only the session ID, input version, change type, and calculation attempt where applicable.
- Relevant evaluated candidate changes invalidated the calculation at its existing input version. A change to an unrelated candidate left the result current. The completion fixture seeded a terminal attempt in PostgreSQL.
- Existing group authorization, chat and outing invalidation, reconnect and notification dispatcher checks passed.

The persistent outbox retries server-side processing. Clients recover missed hints by rejoining and reading authenticated REST state. Socket delivery provides a refresh signal and may be repeated when the worker retries. [Socket.IO delivery guarantees](https://socket.io/docs/v4/delivery-guarantees/)

## Flutter

Targeted static analysis had no findings. Eight focused Flutter tests passed. The realtime regression covered repeated invalidations, delayed results for the same attempt, completion of a newer attempt, release on route deactivation, reconciliation on return, and expiry. Existing tests covered offline handoff and account-switch cleanup. Physical-device lifecycle, rendering and hosted ingress remain unverified. Routing remains deferred for Prompt 19.

## Release status

The configured Neon target reported 35 applied migrations and one pending migration, `20261127000200_meetup_realtime`, with no checksum mismatches, failures or unexpected entries. The production backup and restore rehearsal remain pending because Windows encryption was unavailable in the checked local destinations. Production data stayed in Neon. Existing sessions may advance their input version once on the first read because input fingerprints now track effective location dependencies and group-specific exclusions.
