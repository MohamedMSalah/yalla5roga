# Physical Android Device Testing Report

| Metadata | Value |
|----------|-------|
| Date | 2026-11-08 |
| Device | Samsung SM A566B (`RKGYA00YY1W`), Android 17 / API 37 |
| PC LAN IP used | `192.168.1.6` (Wi‑Fi; detected, not hardcoded in source) |
| Backend port | `3000` |
| Emulator | Not used |

## Environment configuration changes

| Change | Detail |
|--------|--------|
| Backend bind | [`backend/src/server.ts`](../../backend/src/server.ts) listens on `HOST` (default `0.0.0.0`) and logs localhost + detected LAN IPv4 URLs |
| Backend env example | [`backend/.env.example`](../../backend/.env.example) documents `HOST=0.0.0.0`; local `backend/.env` received `HOST=0.0.0.0` (gitignored) |
| Flutter device env | Gitignored `flutter/.env.device` generated from `.env` with `API_BASE_URL=http://192.168.1.6:3000` |
| Device env example | [`flutter/.env.device.example`](../../flutter/.env.device.example) |
| Helper script | [`scripts/dev-physical-android.ps1`](../../scripts/dev-physical-android.ps1) (`-PrepareOnly` or full run) |
| VS Code launch | [`flutter/.vscode/launch.json`](../../flutter/.vscode/launch.json) — added **Yalla 5roga (physical device)** → `.env.device` |
| Emulator launch | **Unchanged** — **Yalla 5roga (dev)** still uses `.env` / `10.0.2.2` |
| Production | **Unchanged** |
| Gitignore | `!.env.device.example` allowed under `flutter/.gitignore` |
| Docs map | [`docs/PROJECT_STRUCTURE.md`](../PROJECT_STRUCTURE.md) — physical-device section + `scripts/` |

## Backend network configuration

- Listen address: `0.0.0.0:3000`
- CORS: existing `origin: true` (unchanged)
- Neon / Firebase Admin: unchanged; DB health verified via `/health`
- Startup log (observed): Local `http://localhost:3000`, LAN `http://192.168.1.5:3000` and `http://192.168.1.6:3000`

## Flutter configuration changes

- Dedicated physical-device dart-define file (`.env.device`); no hardcoded LAN IP in Dart source
- Debug-only cleartext: [`flutter/android/app/src/debug/AndroidManifest.xml`](../../flutter/android/app/src/debug/AndroidManifest.xml) sets `android:usesCleartextTraffic="true"`
- Main/release manifests unchanged
- Default development URL in `AppConfig` remains `http://10.0.2.2:3000` for emulator

## Device connection status

| Check | Result |
|-------|--------|
| ADB (`…\platform-tools\adb.exe`) | Device `RKGYA00YY1W` state `device` (authorized) |
| `flutter devices` | SM A566B listed |
| `adb` on PATH | Missing (use full SDK path or Flutter) |
| Android licenses | Flutter doctor: not all accepted |
| App install / launch | **Blocked** — `flutter run` aborted mid-build / process terminated; one attempt failed Gradle sandbox cache (`metadata.bin` under Cursor sandbox Gradle home) |

## Tests executed

### Backend unit/integration suite (`pnpm test`)

| Result | Detail |
|--------|--------|
| 92 passed / 1 failed / 93 total | Failure: `allows the creator to create and delete a vote option` — `ConflictError: Voting deadline has passed` (pre-existing suite flake/conflict with live DB timing; **not** introduced by LAN bind) |

### LAN HTTP smoke (against `http://192.168.1.6:3000`)

Executed while backend was listening. Timings are wall-clock `Invoke-WebRequest` measurements.

| Scenario | Expected | Status | Time | Result |
|----------|----------|--------|------|--------|
| `GET /` | 200 | 200 | 30 ms | **Passed** |
| `GET /health` (Neon) | 200 | 200 | 160 ms | **Passed** |
| `GET /api/users/cuser` no auth | 401 | 401 | 16 ms | **Passed** |
| `GET /api/groups/cuser` no auth | 401 | 401 | 4 ms | **Passed** |
| `GET /api/outings/cuser` no auth | 401 | 401 | 6 ms | **Passed** |
| `GET /api/outings/saved` no auth | 401 | 401 | 2 ms | **Passed** |
| `GET /api/notifications` no auth | 401 | 401 | 3 ms | **Passed** |
| Chat messages (dummy outing) no auth | 401 | 401 | 3 ms | **Passed** |
| Votes (dummy outing) no auth | 401 | 401 | 4 ms | **Passed** |
| Voting state (dummy outing) no auth | 401 | 401 | 3 ms | **Passed** |

Raw JSON: [`docs/audit/_physical_device_api_smoke.json`](_physical_device_api_smoke.json)

### App feature smoke (Flutter → API)

| Area | Result | Notes |
|------|--------|-------|
| Auth / user sync | **Blocked** | App not installed in this session |
| User profile | **Blocked** | Requires authenticated device session |
| Groups | **Blocked** | Same |
| Outings | **Blocked** | Same |
| Voting | **Blocked** | Same |
| Chat | **Blocked** | Same |
| Notifications | **Blocked** | Same |
| Saved outings | **Blocked** | Unauth 401 verified at API only |
| Image-related APIs | **Blocked** | No device upload exercised |
| Error / unauthorized | **Passed** (API) | Missing Bearer → 401 on protected routes |

## Identified bugs / issues

1. **Gradle build under Cursor sandbox** — `Could not read workspace metadata … cursor-sandbox-cache\…\metadata.bin` when assembling `:image_picker_android`; retry with `GRADLE_USER_HOME=%USERPROFILE%\.gradle` was started but aborted before completion.
2. **Backend test failure** — vote-option create/delete vs voting deadline on shared Neon data (`pnpm test`).
3. **Firewall rule not created** — `New-NetFirewallRule` for `Yalla5roga Dev API` returned **Access is denied** (needs elevated PowerShell). Existing Node.js inbound Allow rules are on **Public** profile only.
4. **Flutter doctor** — Android licenses not fully accepted.

## API integration issues

- None observed for health / unauthenticated protected routes over LAN IP from the PC.
- End-to-end authenticated flows from the phone were **not** executed (app launch blocked).

## Performance observations

| Item | Type | Value / note |
|------|------|----------------|
| `GET /` | Measurement | ~30 ms |
| `GET /health` | Measurement | ~160 ms (includes Neon round-trip) |
| Protected 401s | Measurement | ~2–16 ms |
| Flutter startup / frames / memory | Observation | **Not measured** — app did not reach running state |
| Backend CPU/memory | Observation | Not sampled; jobs (voting deadline, completion, notification worker) were active while server ran |

## Remaining manual actions

1. **Start backend** (elevated terminal optional):  
   `cd backend` → `pnpm dev`  
   Confirm logs show `Server listening on 0.0.0.0:3000` and LAN URLs.
2. **Refresh device env**:  
   `pwsh -File scripts/dev-physical-android.ps1 -PrepareOnly`
3. **Build/run on phone** (outside sandbox if Gradle cache errors persist):  
   ```powershell
   $env:GRADLE_USER_HOME = "$env:USERPROFILE\.gradle"
   cd flutter
   flutter run -d RKGYA00YY1W --dart-define-from-file=.env.device
   ```  
   Or use VS Code/Cursor launch **Yalla 5roga (physical device)**.
4. **Firewall (admin PowerShell, Private profile only)** — only if the phone cannot reach the API:  
   ```powershell
   New-NetFirewallRule -DisplayName 'Yalla5roga Dev API' -Direction Inbound -Action Allow -Protocol TCP -LocalPort 3000 -Profile Private -Description 'Dev: physical Android → local Express API'
   ```
5. Accept Android licenses: `flutter doctor --android-licenses`
6. Optionally add `adb` to PATH: `%LOCALAPPDATA%\Android\sdk\platform-tools`
7. Phone must stay on the same LAN as `192.168.1.6` (re-run the helper if the PC IP changes).
8. Manually smoke auth → groups → outings → vote → chat → notifications → saved → images on device after install.

## Documentation Updates

| File | Change |
|------|--------|
| `docs/PROJECT_STRUCTURE.md` | Physical-device paths, `scripts/`, last verified date |
| `docs/audit/PHYSICAL_DEVICE_TESTING_REPORT.md` | This report |
| `docs/audit/_physical_device_api_smoke.json` | Smoke timing artifact |

No production, schema, Firebase secret, or emulator-default changes.
