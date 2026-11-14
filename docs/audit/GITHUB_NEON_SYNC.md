# GitHub and Neon synchronization — 2026-11-14

Scope: commit and push the complete current working tree to the existing origin/main, including Phase 4 discovery/special events, voting-deadline refinements, RSVP/countdown work, Phase 5 chat/notifications and the reference chat refinement, with their documentation and verification artifacts. Private environment files and database backups stay ignored.

## Neon deployment

Verified against server metadata: project rough-mountain-69896781, branch br-fragrant-heart-avfm4h2t, database neondb, role neondb_owner. Names/development designation are not inferred from these IDs. Before deployment, 14 migrations were applied and only 20261114000000_special_event_occasions was pending; the voting-deadline migration was already applied. Applied migration checksums matched the working migration files. Git attributes preserve the exact deployed bytes of the two newly committed migration files, preventing automatic line-ending conversion from changing their recorded checksums.

A fresh private logical backup captured all 27 public tables / 661 rows with row hashes, constraints and indexes. The backup was read back from disk. Recovery restored all tables with keys/indexes/FKs, isolated the occasion enum, applied the exact pending SQL, verified every row hash, and rolled the rehearsal transaction back. No public enum or application-row writes occurred during rehearsal. Prisma migrate deploy then applied the pending migration. Postdeployment application-row hashes matched, both occasion labels and constraints were read back, and all 15 migrations were confirmed applied with no pending migrations. The constraint remains NOT VALID by migration design to preserve the existing historical-row policy.

Evidence: NEON_GITHUB_SYNC_DEPLOYMENT.json. Backup rows remain private under backend/.database-backups/ and are not committed. No prisma db push, reset or data-deleting migration was used. No production backend/client process was deployed by this task.

## Verification and documentation

Backend TypeScript noEmit check passed. Existing Phase 4, voting-deadline, RSVP/countdown and Phase 5 OpenAPI results are included; Phase 5 has 55 passing HTTP checks. Flutter was not launched and no Flutter/device/emulator/UI tests were run in this synchronization task. Latest Flutter analysis from the implementation task had zero errors, five existing warnings and twelve existing infos.

Documentation Updates: DATABASE_ARCHITECTURE.md now records all 15 applied migrations; PROJECT_STRUCTURE.md maps the guarded audit/deploy script and evidence; PHASE_4_UI_UX.md adds the subsequent actual deployment result; this report and NEON_GITHUB_SYNC_{READBACK,DEPLOYMENT}.json record synchronization/deployment evidence. Existing diagrams remain valid and unchanged. No known database migration mismatch remains; native-device/visual/runtime limits from the implementation reports remain.
