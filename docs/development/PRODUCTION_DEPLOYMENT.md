# Public backend deployment

Use a long-lived Linux service or container with one Node process. The current Socket.IO adapter, replay window, rate limits and job orchestration are process-local. Select a host that supports WebSocket upgrades and HTTP long polling on the same listener. This runbook uses Node 24 and the pnpm version pinned in `backend/package.json`.

## Configure and build

1. Create isolated staging Firebase, Neon and R2 resources for functional verification. Inject settings from [the production environment template](../../backend/.env.production.example). Use the intended Firebase project across Admin credentials, API key and mobile platform identifiers.
2. Configure a dedicated Neon connection budget. The current Prisma client normalizes Neon pooler URLs to a direct connection and maintains a process-local pool. Set `connection_limit` and `pool_timeout` explicitly for your tier and instance count. Keep a separate migration role and credential. The place catalog listener also opens its own dedicated direct connection.
3. Keep the media bucket private. Disable unrestricted `r2.dev` and direct public bucket domains. Leave `R2_PUBLIC_BASE_URL` empty for signed delivery, or put a gateway in front of the private bucket that accepts GET/HEAD for verified `places/` objects and denies other prefixes and listing. Test anonymous reads of a private fixture and validate signed PUT/GET and expiry before accepting traffic.
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
# DATABASE_URL and DIRECT_URL are injected for the intended release target.
DATABASE_URL="$DIRECT_URL" pnpm exec prisma migrate status
pnpm exec tsx scripts/database-catalog-audit.ts /private/neon-catalog.json
pnpm exec tsx scripts/database-backup.ts backup /private/release-backup /private/neon-catalog.json
# Run verify with DATABASE_URL pointing to the private disposable restore instance.
pnpm exec tsx scripts/database-backup.ts verify /private/release-backup prisma/migrations/20261121000000_outing_location_snapshot/migration.sql
# Restore the verified target settings before applying.
DATABASE_URL="$DIRECT_URL" pnpm db:deploy
DATABASE_URL="$DIRECT_URL" pnpm exec prisma migrate status
DATABASE_URL="$DIRECT_URL" pnpm exec prisma migrate diff --from-schema-datasource prisma/schema.prisma --to-schema-datamodel prisma/schema.prisma --exit-code
pnpm start
```

Use a service manager to restart failed processes and allow at least 25 seconds after SIGTERM. Ingress sends traffic only after `/health/ready` returns 200. `/health/live` is a process probe. A separate bearer credential of at least 24 characters enables metrics and dependency reporting. Protect them at ingress. Production disables Swagger and the development media routes. Use Swagger in an isolated test process for manual contract verification.

```sh
curl --fail --silent "$API_ORIGIN/health/live"
curl --fail --silent "$API_ORIGIN/health/ready"
curl --fail --silent -H "Authorization: Bearer $MONITORING_TOKEN" "$INTERNAL_API_ORIGIN/health/dependencies"
curl --fail --silent -H "Authorization: Bearer $MONITORING_TOKEN" "$INTERNAL_API_ORIGIN/metrics"
```

Forward `/socket.io/` with HTTP/1.1 upgrade headers and a proxy read timeout above the sum of Socket.IO's ping interval and timeout. Verify polling and WebSocket through the actual ingress. Confirm room rejoin, REST reconciliation and replay reset after a process restart. [Socket.IO reverse-proxy documentation](https://socket.io/docs/v4/reverse-proxy/)

Restore the last verified app artifact if a rollout fails. The four nullable outing snapshot fields support rollback to the earlier application while retaining the added columns. For a failed migration, halt the rollout and inspect the migration journal and schema before retrying. For a data recovery event, restore into a parallel Neon branch, compare recoverable writes, and cut over only after explicit review. Avoid resets and drops on the existing branch.

## Staging verification and Android release

```sh
cd backend
pnpm test
pnpm test:contract
pnpm audit:routes
pnpm benchmark:http
# See OBSERVABILITY.md for the disposable PostgreSQL and local k6 prerequisites.
LOAD_SCENARIO=baseline VUS=1 WRITE_FIXTURES=1 pnpm load:local
```

Use an approved HTTPS API origin in the gitignored Flutter release configuration. Supply the appropriate Firebase client project, Android signing hashes and verified app links. iOS needs the matching bundle identifier, APNs setup, capabilities and associated domains before release. The Android build uses `flutter/android/key.properties` for `storeFile`, `storePassword`, `keyAlias` and `keyPassword`. Store the signing material in the release secret store. Signing verification and actual packaging require those values. [Flutter Android signing and release build](https://docs.flutter.dev/deployment/android)

```sh
cd flutter
flutter pub get
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release --split-per-abi --dart-define-from-file=.env.production
```
