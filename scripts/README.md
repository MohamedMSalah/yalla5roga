# Repository scripts

Run these from the repository root; project policy is [AGENTS.md](../AGENTS.md).

- `audit-project-structure.py`: read-only local source imports, screen inventory,
  consolidated rule sections and moved-document references. Writes only the
  public JSON report under `docs/audit/`; no network, Flutter execution or DB work.
- `dev-physical-android.ps1`: existing physical Android development helper;
  **do not run during the Phase 7/8 static-only audit**.

Feature/API/database scripts remain under `backend/scripts/`; Flutter developer
tools remain under `flutter/tool/`. Their existing paths and imports are stable.
