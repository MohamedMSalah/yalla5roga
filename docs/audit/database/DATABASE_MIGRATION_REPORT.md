# Database migration report

Both migrations were applied on November 10, 2026 to the owner-confirmed Neon development target `neon-pink-ladder / main / neondb`. SQL returned project ID `rough-mountain-69896781`, branch ID `br-fragrant-heart-avfm4h2t`, endpoint `ep-misty-glitter-av3zwlzf.c-11.us-east-1.aws.neon.tech`, and PostgreSQL 18.6. Deployment used Prisma Migrate against the direct endpoint.

## Deployment and recovery

| Migration | State | SHA-256 |
| --- | --- | --- |
| [20261110130000_harden_database_integrity](../../../backend/prisma/migrations/20261110130000_harden_database_integrity/migration.sql) | Applied | `ebf626fd7b3d29fc64727f0c19552005928768b83b55a1a017680dc9ac39d98c` |
| [20261110140000_remove_obsolete_schema](../../../backend/prisma/migrations/20261110140000_remove_obsolete_schema/migration.sql) | Owner approved and applied | `07eddd83e1eb10521dba2ba727c355f03642fdd8b0579a3a88047bf296a4350b` |

Before each deployment, a private logical backup captured the live schema and all table rows. Both backups restored 24 tables with matching per-table SHA-256 digests and recreated keys and indexes. The first snapshot contained five Prisma history records, and the second contained six. The migration SQL ran on the reconstructed schema within rolled-back transactions. An initial rehearsal exposed an enum default dependency. The reviewed version drops the old default before recasting and restores the push default afterward.

The application tables had zero rows in both fresh pre-deploy snapshots and in the final public-schema readback. Older audit snapshots recorded application rows, so they are historical evidence rather than current counts. The restore window in Neon's control plane was not independently verified. Local logical backup and restore were verified.

## Change register

| Object | Deployed change |
| --- | --- |
| Tables | Retained all 23 application tables and Prisma history. |
| Removed columns | `users.email`, `users.password_updated_at`, `outings.suggested_by_user_id`. |
| Added columns | None. |
| User keys | Retained the Firebase UID primary key and existing relations. Phone is a unique, required E.164 lookup key. Bcrypt hash retained. |
| Outing relationships | Dropped the unused suggester FK. Creator, winner, candidate, participant, attendance and arrival relationships retained. New guest rows default to pending. |
| New checks | E.164 users and invitation phones, coordinate bounds for places, outings, drafts and voting options, place price bounds and nonnegative amounts, draft JSON arrays. Six existing outing and draft checks are now validated. |
| New indexes | Partial unique `uq_group_invitations_pending_phone`, `idx_saved_outings_user_saved`, `idx_saved_places_user_saved`, `idx_user_fcm_tokens_user`. |
| Removed indexes | `users_email_key`, `idx_outings_suggested_by`, `idx_group_invitations_phone`, `idx_outings_status`, `idx_chat_messages_outing_sent`, `user_fcm_tokens_user_id_token_key`. |
| Notification enum | Removed SMS and email values. Push and WhatsApp remain. Inbox history and the FCM delivery architecture remain separate. |
| Object Storage | Images are represented by external URL references. The audited backend has no upload adapter. Existing image and catalog references retain their purpose. |

## Backend and Flutter contract

Login uses normalized phone and the Neon password hash without OTP. Signup verifies a recent Firebase phone OTP token against the submitted phone, provisions under that Firebase UID, and claims invitations. Both routes mint Firebase application sessions. Public profile JSON exposes `has_password`. REST and Socket.IO share the app-session verifier.

Group creation and the first owner membership commit together. Owner removal locks the group and checks the last-owner rule. Invitation claiming locks rows, preserves history and avoids duplicate memberships. FCM registration is an atomic upsert and chat read timestamps advance monotonically. Outing validators and Swagger were aligned with the new constraints.

The existing Flutter client already sends `phoneVerificationToken` at signup, accepts the existing session envelope and refreshes Firebase ID tokens. Its outing parser already tolerates an absent legacy suggester field. The integration review exercised the matching API contract through Swagger and statically analyzed the related Flutter source.

## Verification

- Prisma schema validation, client generation and TypeScript compilation completed successfully.
- `prisma migrate status` reported all seven migrations applied. Every stored checksum matched its migration file. `prisma migrate diff` reported no difference in Prisma-supported objects.
- PostgreSQL catalog readback found 24 tables, 195 columns, 218 constraints, 39 foreign keys and 76 indexes. All constraints and indexes were valid. The catalog separately verifies SQL checks and the partial unique index.
- Flutter static analysis completed with six warnings and three informational findings in the selected auth, group, outing, chat, and notification directories. Flutter verification was static, as requested.

### Real PostgreSQL backend tests

All seven migrations replayed in a separate schema on the same Neon PostgreSQL database. The full backend suite passed with 126 tests, zero failures and zero skips. The real PostgreSQL tests exercised atomic group owner creation, immediate member addition, a pending invitation claimed on signup, signup replay, login, outing membership defaults, linked notification persistence, outing lifecycle, and concurrent voting. The group test rolled back its fixtures.

### Swagger browser tests

Playwright executed all application HTTP cases through Swagger UI's Try it out and Execute controls. Two configured fictional Firebase phone numbers produced genuine OTP proofs. The backend used its normal Firebase verifier, validators, services and generated Prisma Client against the isolated Neon schema. Scheduled jobs and delivery workers were stopped for this test.

| Case | Observed result |
| --- | --- |
| Database health | 200, connected |
| Missing signup OTP proof | 400 |
| OTP proof for a different number | 401 |
| OTP-only token used as an application Bearer token | 401 |
| OTP-verified signup for two fictional users | 201 each, same verified UIDs in the response and Neon, public password flag only |
| Group creation | 201, creator is owner and member count is 1 |
| Invite before application registration / repeat invite | 201 pending / 409 duplicate |
| Current-user groups and repeat sync after signup | 200 each, claimed group visible and stored name preserved |
| Incorrect password / password-only login | 401 / 200, canonical UID returned |
| Group outing creation and member visibility | 201 / 200, correct creator and group |
| Notification inbox | 200, persisted outing notification visible |
| FCM token registration | 201 |
| Chat read watermark | 200 |

All 18 Swagger requests produced the expected status. SQL readback found two UID-matched profiles, one claimed invite, one claimed membership, one linked outing, one persisted notification, and one FCM token for the recipient. The harness removed its isolated test schema and only the Firebase identities it created.

## Remaining risks and boundaries

- Historical accounts without a usable phone and password need verified account recovery if imported from an older backup. No such rows existed on the deployed development target.
- The review retained existing general group and outing read rules. The historical Swagger report documented broad cross-user read access on several legacy routes. New tests target the current-user and invitation paths.
- Public API deployment to a backend hosting service was outside the Neon deployment. Swagger exercised the checked-out backend's routes on a temporary local backend. Socket.IO delivery, physical FCM and WhatsApp delivery, device OTP behavior, and Object Storage upload were outside the executed tests.

- Deletion of a group with existing group outings still needs a product decision. The historical FK would clear the group reference, which the validated outing-type check rejects. The audit preserved the rule that a group outing needs a group.
