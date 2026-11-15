# Backend development scripts

Run from `backend/` using the installed Node/tsx toolchain. Read
[root AGENTS.md](../../AGENTS.md) first. Existing script paths are preserved so
historical reports and development commands stay usable.

| Purpose | Scripts / evidence |
|---|---|
| Current no-data HTTP audit | `phase7-openapi-verification.ts`; serves Swagger locally, probes missing/malformed authentication, forces an unreachable DB target, starts no jobs/socket server |
| Route/contract consistency | `validate-api-docs.ts`; checks operation IDs, refs and Express/OpenAPI parity; explicitly classifies the two local media binary transports |
| Feature HTTP verification | `*-openapi-verification.ts`, `phase*-openapi-*.ts`; read each before use—older scripts may create authenticated fixtures or disposable database schemas |
| Places import/source inspection | `places-*`, `places_sources.py`, `places-requirements.txt`; source/worker/deployment behavior documented in `docs/audit/PLACES_*.md` |
| Database audit/deployment | `database-*`, `deploy-*`, `*-database*`, `neon-sync-deploy.ts`, `review-neon-release.ts`; task authorization, target checks and backup/rehearsal requirements apply |
| Earlier probes/integration evidence | `auth-roundtrip.ts`, `backend-full-integration.ts`, `*-probe.ts`, `*-audit.ts`; retain historical evidence, never assume read-only |

Phase 7/8 runs only the current Swagger/OpenAPI audit. It does not run historical
fixtures, migration/deployment/import scripts or production database commands.
Credentials/private row backups must never enter public reports.
