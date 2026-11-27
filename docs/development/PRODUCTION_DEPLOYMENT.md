# Staging and public backend deployment

Use a long-lived Linux service or container with one Node process. The current Socket.IO adapter, replay window, rate limits and job orchestration are process-local. Select a host that supports WebSocket upgrades and HTTP long polling on the same listener. This runbook uses Node 24 and the pnpm version pinned in `backend/package.json`.

## Configure and build

1. This project deliberately uses the same existing cloud services in its two primary profiles. Follow the [environment reference](ENVIRONMENT_CONFIGURATION.md); do not create additional Firebase projects, databases or buckets for this configuration. Verify expected targets and native registration before deployment. Destructive rehearsals require a separately authorized disposable test target and must never use the shared live services.
2. Configure a dedicated Neon connection budget. The current Prisma client normalizes Neon pooler URLs to a direct connection and maintains a process-local pool. Set `connection_limit` and `pool_timeout` explicitly for your tier and instance count. Keep a separate migration role and credential. The place catalog listener also opens its own dedicated direct connection.
3. Configure `R2_BUCKET_NAME` as the private bucket with `r2.dev`, custom domains and anonymous gateways disabled. To serve public place imagery anonymously, configure `R2_PUBLIC_BUCKET_NAME` and `R2_PUBLIC_BASE_URL` on a separate catalog-only bucket. Restrict the R2 service credential to these buckets and give that credential object access only. Audit existing keys, stored image URLs, bucket policies and CDN caches before rollout. Copy verified catalog objects to the catalog bucket before switching any retained public image origin. Preserve referenced paths or update their catalog metadata. Purge any formerly cached private responses.
4. Configure the host's HTTPS ingress and redirect HTTP there. Restrict direct access to the Node listener. Configure `TRUST_PROXY` with the actual ingress IPs or CIDRs and have the ingress overwrite forwarded client identity headers. `CORS_ORIGINS` contains allowed HTTPS browser origins. Keep health and monitoring credentials separate from Firebase credentials.

```sh
cd backend
node --version
pnpm --version
pnpm install --frozen-lockfile
pnpm typecheck
pnpm build
pnpm exec prisma validate
pnpm audit --prod
```

Pin the same Node major and compatible Linux ABI for build and runtime. Install the release's dependencies for the target Linux distro and architecture so native bcrypt and Prisma binaries match it. Keep `backend/licenses` with the deployment. The API stores durable data in Neon and R2. Local files and optional Grafana/Prometheus volumes have separate retention needs.

## Migrate and start

Confirm the Neon project, branch, role, database and expected pending migration names and checksums. Capture a provider recovery point and a private, encrypted logical backup. Run the catalog audit with an output path outside the repository before backing up. Restore and checksum the backup on an isolated database, then rehearse the exact migration there. Measure locks and wait time on a staging clone. Inspect all pending SQL and schedule large or lock-sensitive migrations independently.

```sh
# From the repository root. Build before running the target checks.
pnpm --dir backend build
node scripts/database-status.mjs production
pnpm project production prisma migrate status
pnpm project production tsx scripts/database-catalog-audit.ts /private/neon-catalog.json
pnpm project production tsx scripts/database-backup.ts backup /private/release-backup /private/neon-catalog.json
# Set YALLA_TEST_DATABASE_URL for the disposable loopback yalla_test* database.
pnpm --dir backend exec tsx scripts/database-backup.ts verify /private/release-backup prisma/migrations/20261122000100_coordinated_account_deletion/migration.sql
# Only after approval, independent target checks, restore and rehearsal.
pnpm --dir backend db:deploy
node scripts/database-status.mjs production
pnpm project production prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --exit-code
pnpm start:production
```

Use a service manager to restart failed processes and allow at least 25 seconds after SIGTERM. Ingress sends traffic only after `/health/ready` returns 200. `/health/live` is a process probe. A separate bearer credential of at least 24 characters enables metrics and dependency reporting. Protect them at ingress. Production disables Swagger and the development media routes. Use Swagger in an isolated test process for manual contract verification.

Stop the previous notification worker before applying `20261127000200_meetup_realtime`. Start the backend release that recognizes the new outbox channel after the migration succeeds.

To build the hosting-neutral Linux image from the repository root, run `docker build -t yalla5roga-api:candidate .`. Deploy a single replica using the host's secret injection and restart policy. Bind Node to the container interface and place the listener on a private network behind ingress. The image uses Node.js 24, a frozen pnpm install, native Sharp and Prisma, and runs the direct Node process as a non-root user. The image excludes the local profiles and signing assets. Run migration tooling separately from the image startup.

```sh
curl --fail --silent "$API_ORIGIN/health/live"
curl --fail --silent "$API_ORIGIN/health/ready"
curl --fail --silent -H "Authorization: Bearer $MONITORING_TOKEN" "$INTERNAL_API_ORIGIN/health/dependencies"
curl --fail --silent -H "Authorization: Bearer $MONITORING_TOKEN" "$INTERNAL_API_ORIGIN/metrics"
```

Forward `/socket.io/` with HTTP/1.1 upgrade headers and a proxy read timeout above the sum of Socket.IO's ping interval and timeout. Verify polling and WebSocket through the actual ingress. Confirm room rejoin, REST reconciliation and replay reset after a process restart. [Socket.IO reverse-proxy documentation](https://socket.io/docs/v4/reverse-proxy/)

For a failed migration, halt the rollout and inspect the journal and schema before retrying. If the workaround requires rolling back the app artifact, keep the deletion schema and block both user DELETE routes on the old artifact, which has the previous deletion behavior. Record outstanding deletion jobs and resume them on the fixed artifact. Rehearse data restoration in a parallel branch. Before exposing restored data, reconcile deletions accepted after the recovery point, including their Firebase and R2 state.

## Staging verification and Android release

### Backend and ingress sign-off

1. Capture the build revision, migration checksums and staging resource IDs. Start the compiled artifact on the private listener. Check that liveness returns 200, readiness stays 503 until startup completes, jobs show ready, and the monitoring endpoints require the monitoring token. Send SIGTERM with a connected socket and an active request. Confirm readiness leaves rotation, the socket closes, the catalog listener and scheduled workers stop, Prisma disconnects, and the service exits within 25 seconds. Start it again and verify readiness and job timestamps.
2. Run the two requests below against the staging HTTPS ingress. Expect a successful Engine.IO open packet for the staging browser origin and 403 for the untrusted origin. Verify the HTTP endpoint redirects to HTTPS and that the TLS certificate validates without disabling verification.

```sh
curl -i -H "Origin: $STAGING_WEB_ORIGIN" "$API_ORIGIN/socket.io/?EIO=4&transport=polling"
curl -i -H "Origin: https://untrusted.example.invalid" "$API_ORIGIN/socket.io/?EIO=4&transport=polling"
```

3. Use `socket.io-client` from the backend workspace with the staging origin, path `/socket.io`, and `auth: { token }`. Connect with `transports: ["websocket"]`, then with `["polling"]`. With separate staging owner, member and outsider identities, check that a missing token fails, the member receives a successful `group:join` and `outing:join` acknowledgment, and the outsider receives `FORBIDDEN`. Leave each room and verify delivery stops. Restart the single process and confirm a stale `data:reconcile` cursor requests a REST reset.
4. Confirm the ingress overwrites forwarded identity headers and that the Node listener is unreachable directly. From a controlled staging IP, exhaust the 300-request API bucket within one minute and check 429 plus `Retry-After`. Repeat with altered `X-Forwarded-For` values and confirm the bucket stays exhausted. Confirm a separate egress IP can still call the route. Use `GET /api/places/licenses` to isolate the shared limiter from credential-specific limits.

### Firebase, deletion and media sign-off

1. In the isolated Firebase project create disposable users A, B and an outsider. Mint custom sessions using the staging backend and verify Firebase `verifyIdToken(token, true)` with the Admin SDK. Open REST and Socket.IO sessions for A. Use Admin `revokeRefreshTokens(uid)` after the token's `auth_time` second. Once Firebase reports revocation, expect REST and a new socket to reject the old token. Allow up to 40 seconds for an established connection to close, including an already-running verification and the next check. Reauthenticate and verify the new socket can join allowed rooms. Repeat with `updateUser(uid, { disabled: true })` and verify refresh and reconnect denial. Re-enable A and sign in again for the deletion check. [Firebase session management](https://firebase.google.com/docs/auth/admin/manage-sessions)
2. Give A a group with B, an outing, both sent and received invitations, a chat message and a private image. Create another group for A with historical outings but no remaining member. From B attempt to delete A through `DELETE /api/users/{id}` and expect 403. From A call `DELETE /api/users/cuser` and expect 202 with `data.status=accepted`, immediate REST denial and socket closure, and the profile disappearing from the database. Verify B becomes group owner, other users retain membership and their own messages, A's chat text and notification previews are redacted, pending invitations from A are withdrawn, and active owned outings are cancelled. Read the retained history and confirm its sender/creator placeholder.
3. Check protected job health during cleanup. Confirm Firebase disables A, then removes the UID after the 65-minute custom-token hold. Confirm private R2 objects are removed after their upload windows and the job completes with no Firebase UID or object keys retained in the queue. Repeat with a disposable object while denying its delete permission or with an isolated Firebase operation failure. Restore that fixture permission, wait for retry, and verify progress resumes across a process restart without replaying completed effects.
4. Use a fresh disposable owner for `POST /api/media/upload-url`. PUT the fixture image with the exact declared `Content-Type` and byte length, then POST `/api/media/{id}/confirm`. Verify a mismatched type/size or modified key fails. For an unlinked profile or group asset, verify anonymous and B's API requests cannot obtain a signed URL, while the owner can. Repeat with a linked group or outing asset and verify only authorized participants can resolve it. Request the direct S3 object URL without query credentials and request the same key beneath every public origin. All private reads must fail. Check the authorized signed GET, its cache-control response, and expiry, capped at five minutes. Check that the signed PUT expires within 15 minutes.
5. Upload a curator place image. Verify R2 stores it in the catalog bucket under `places/`, GET and HEAD succeed anonymously on the catalog origin, and the public bucket cannot serve any private fixture. Check a retained legacy place image through the new origin. Confirm listing, unrelated keys, and PUT without a signature fail. [R2 presigned URLs](https://developers.cloudflare.com/r2/api/s3/presigned-urls/)

### Local regression commands

```sh
cd backend
pnpm test
pnpm test:contract
pnpm audit:routes
pnpm benchmark:http
# See OBSERVABILITY.md for the disposable PostgreSQL and local k6 prerequisites.
LOAD_SCENARIO=baseline VUS=1 WRITE_FIXTURES=1 pnpm load:local
```

Android uses only device and production flavors with the existing Firebase app. Device Release uses the local HTTP LAN origin; production Release requires the final public HTTPS API origin. Both use ignored `flutter/android/key.properties` and an approved keystore. See the [environment reference](ENVIRONMENT_CONFIGURATION.md) for signing fields, missing configuration and safe build commands. Shared production services must never be used for the destructive staging tests above; those tests are separate from offline configuration verification.

```sh
cd flutter
flutter pub get
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub
cd ..
pnpm build:apk:device
pnpm build:apk:production
```


### Location requests and departure reminder rollout

Apply `20261127000300_location_requests_departure_reminders` through the standard target, backup and rehearsal procedure before deploying the API that writes the new event type. Confirm the status of the preceding Smart Meetup realtime migration before batching them. Deploy the Flutter app with the setup destination handler before verifying notification taps on devices. Personalized scheduling requires a separate routing integration and remains inactive in this release.
