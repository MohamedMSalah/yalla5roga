# Production service configuration

Recorded 2026-11-22. No deployment, migration, production record writes, billing activation, credential rotation, IAM change or public exposure was performed.

## Verified

- Existing ignored `.env.production` Neon target matches the signed-in dashboard main branch and database. Expected host/name and TLS settings agree. A connection and `BEGIN READ ONLY; SELECT current_database(); ROLLBACK` succeeded.
- Existing Firebase project, Android app/key, sender, Web OAuth client and iOS project/app/key/bundle/OAuth settings match native configuration. The existing RSA Admin key parses and successfully exchanges for an access token. A read-only Identity Toolkit configuration request succeeds and reports Phone enabled. The dashboard reports FCM v1 enabled. Actual message delivery and SMS were not exercised.
- Firebase Google and Apple sign-in providers are disabled. No Google/Apple sign-in implementation was found in the client source search; no provider or IAM settings changed. Existing OAuth settings were retained.
- `.env.production` and `.env.device` are Git ignored. No profile was committed. Flutter's existing client define allowlist remains in place.
- Generated missing monitoring bearer and Grafana password locally using cryptographic randomness. Saved existing implementation defaults for JSON logging, production HTTP sampling, media compression, upload limits and media cleanup. These settings are local; monitoring infrastructure was not deployed.

## Pending

| Service | Local configuration / next step |
| --- | --- |
| Hosting | API_BASE_URL and CORS_ORIGINS intentionally remain empty at the user's request. TRUST_PROXY must follow actual ingress topology. |
| Cloudflare R2 | Signed in; account routes to R2 subscription signup. User deferred billing activation. Credentials, buckets and public CDN remain missing. No subscription or token created. |
| Meta WhatsApp | Created the separately approved Yalla 5roga business portfolio (968113122794099), outside Levai, and app (1459451919653457), after terms approval and user password re-entry. Verified the new app dashboard and portfolio pairing. WhatsApp setup currently offers a test phone number and additional platform terms; onboarding was not submitted because production-only configuration was requested. No production sender, access token or approved templates are available yet. App remains unpublished; no messages sent. |
| Maps | Existing MapLibre/OpenFreeMap source defaults need no credential. Retained without replacing provider. Network rendering and offline downloads unverified. |
| Geocoding | Optional Pelias configuration absent; no authorized instance discovered in local config. No provider invented or purchased. |
| Background jobs | Existing notification worker values retained. Media cleanup interval populated from source default. Server/jobs not started against production. |
| Release | Android release signer and hosting/storage completion still required; no APK produced by this configuration task. |

## Tools and documentation

`node scripts/production-config-audit.mjs` performs local consistency checks without printing values. `--inventory` writes the variable inventory; `--remote-readonly` checks the database and Firebase without starting the application or its jobs. `--configure-defaults` fills only empty application-managed secrets and supported local defaults; it never rotates existing values.

See [variable inventory](PRODUCTION_ENVIRONMENT_VARIABLES.md). Dynamic lookups are additionally documented in the environment reference and owning modules. No application architecture or diagrams changed.
