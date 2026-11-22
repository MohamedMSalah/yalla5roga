# Repository scripts

Run these from the repository root; project policy is [AGENTS.md](../AGENTS.md).

- `production-config-audit.mjs`: checks the ignored production profile without printing values. `--inventory` records variable names and source references; `--remote-readonly` checks Neon and Firebase without starting jobs; `--configure-defaults` fills only empty application-managed secrets and supported defaults. See `docs/audit/PRODUCTION_SERVICE_CONFIGURATION.md`.

- `audit-project-structure.py`: read-only local source imports, screen inventory,
  consolidated rule sections and moved-document references. Writes only the
  public JSON report under `docs/audit/`; no network, Flutter execution or DB work.
- `dev-physical-android.ps1` delegates to `pnpm build:apk:device` or, with a device ID, `pnpm run:android:device`. Both read the shared-service device profile through the client allowlist; APK builds are signed device Release ABI splits.
- `database-status.mjs` reports target-checked, read-only migration metadata. `pnpm project <device|production> <prisma|tsx>` selects the root profile for backend operator scripts.

Feature/API/database scripts remain under `backend/scripts/`; Flutter developer
tools remain under `flutter/tool/`. Their existing paths and imports are stable.
