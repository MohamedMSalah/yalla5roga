# Yalla 5roga

Monorepo for the Yalla 5roga backend and Flutter app. The two projects stay in separate directories, and each keeps the commit history from its original repository.

## Layout

- `backend/` — Node.js, TypeScript, Express, and Prisma API
- `flutter/` — Flutter app
- `docs/` — canonical product/architecture docs; `audit/` evidence and `development/` setup
- `scripts/` — repository helpers; backend scripts stay under `backend/scripts/`

Read [AGENTS.md](AGENTS.md) before coding and use the
[structure map](docs/PROJECT_STRUCTURE.md) to locate files. Open the monorepo root
in agent tools. Project policy lives only in AGENTS.md; installed skills and tool
configuration remain in their existing directories.

Read-only organization verification: `python scripts/audit-project-structure.py`.
From `backend/`, run `node --import tsx scripts/phase7-openapi-verification.ts`
for served OpenAPI/auth-boundary checks with an unreachable verification DB target.
See [Phase 7/8 evidence and limits](docs/audit/PHASE_7_8_FINAL_REPORT.md).

## Commits

Stage one project at a time so a backend change and a Flutter change can be committed separately.

Backend only:

```bash
git add backend/
git commit -m "Describe the backend change."
```

Flutter only:

```bash
git add flutter/
git commit -m "Describe the Flutter change."
```

Root files only:

```bash
git add README.md .gitignore
git commit -m "Describe the root change."
```

## Local files that stay untracked

Do not commit `.env` files, Firebase client options, signing keys, keystores, or service-account credentials. Copy those files into the matching directory on each machine. `.env.example` is the committed template for the backend.
