# Run locally and in production

Updated 2026-11-23. Commands run from the repository root with Node.js 24+, pnpm and the project's Flutter SDK. See [environment configuration](ENVIRONMENT_CONFIGURATION.md) for the complete variable reference, security controls and shared-service risk.

The two ignored root profiles share the existing service credentials. Device points to `http://192.168.1.6:3000`, bound on `0.0.0.0:3000`. Production API URL and ingress settings remain empty pending deployment. Neon, Firebase and monitoring settings are populated; R2 and WhatsApp sender credentials are unavailable. No credentials were fabricated or rotated. Original profiles are preserved in ignored `.configuration-backups/`.

```powershell
pnpm check:environments
# Start later, when ready to use live cloud services:
pnpm dev:device
# Independently build signed Release APKs; these do not install or launch:
pnpm build:device
pnpm build:production
```

Both APK commands use `--release --split-per-abi`, select their Android flavor, and send only allowlisted public values in a temporary `--dart-define-from-file` JSON. Both require the approved release signer in ignored `flutter/android/key.properties`. No release signer is currently configured. Production additionally requires a public HTTPS `API_BASE_URL`; its missing URL blocks the build before Flutter starts. Device alone permits HTTP in its Android flavor. Both retain the existing Firebase app and Android application ID.

Outputs are `flutter/build/app/outputs/flutter-apk/app-<device|production>-<armeabi-v7a|arm64-v8a|x86_64>-release.apk`. Successful commands print the absolute paths. No APKs were built by this configuration task. The older `build:apk:device` and `build:apk:production` commands remain aliases.

Starting local development warns about shared production services and disables automatic mutation/cleanup workers. Explicit API actions still affect live data and authentication; locally queued notifications may later be dispatched by a production worker. Never automatically migrate, bulk import or clean up this database. Production startup retains its normal jobs and uses the same configured services after deployment.

For deployment, supply the final HTTPS `API_BASE_URL`, `CORS_ORIGINS`, ingress-specific `TRUST_PROXY`, existing R2 credentials and expected account/bucket settings. Then build the backend with `pnpm --dir backend build` and start using `pnpm start:production`. Use one long-lived process with TLS ingress and Socket.IO forwarding at `/socket.io`. Database deployment remains a separate authorized release operation. WhatsApp delivery requires valid Business sender configuration; existing share-link flows remain available.

Verification for this task is offline static/configuration inspection only. No service connectivity, device rendering, APK contents, certificate fingerprints or signing passwords were verified. No deployment, app run, install, migration or production data modification was performed.
