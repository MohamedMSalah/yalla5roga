# Database refactoring plan

## Target and recovery

The owner identified the development target as project `neon-pink-ladder`, branch `main`, database `neondb`. The live SQL connection confirmed project ID `rough-mountain-69896781`, branch ID `br-fragrant-heart-avfm4h2t`, PostgreSQL 18.6, and endpoint `ep-misty-glitter-av3zwlzf.c-11.us-east-1.aws.neon.tech`. The project and branch display names are owner-supplied. The Neon control-plane restore window is unverified.

The fresh read-only catalog found 24 tables, 198 columns, 209 constraints (including PostgreSQL 18 NOT NULL entries), and 78 indexes before the integrity migration. There were five migration records and zero rows in the 23 application tables. The previous snapshot recorded application data. The historical backup and the fresh private logical backup are separate snapshots under `backend/.database-backups/`.

The fresh backup restored all 24 tables, reconstructed FKs and indexes, and matched each table SHA-256 in an isolated schema. Both migration scripts ran against that restore within the transaction, preserved row counts, and were rolled back with the temporary schema. Refresh the catalog, backup and rehearsal immediately before the cleanup. The SQL preflight stops the cleanup if a legacy email, missing phone, populated suggester, or obsolete delivery-channel row exists.

## Identity and dependency decisions

Keep the current stable Firebase UID `users.id` as the primary key, and use canonical `users.phone` as the unique E.164 lookup and invitation address. Phone changes and reassignment then leave membership, chat, vote, attendance, saved items, and notification references intact. Historical phone-less identities need a separately verified recovery path before any database containing them can enforce NOT NULL. Preserve all existing UIDs and phone/password hashes.

Signup requires a recent Firebase phone OTP ID token matching the normalized submitted number. Login verifies a Neon bcrypt hash without OTP, and both routes return Firebase application sessions. OTP tokens prove phone ownership for signup or an authenticated phone change. The same verified UID and password can retry signup without changing the profile, claim, or hash.

Keep all application tables. Votes, attendance, arrivals, invitations, durable inbox, delivery outbox, and delivery logs represent distinct facts. Draft JSON holds incomplete form selections. Catalog images, prices and hours have active APIs. The repository contains URL references and no object-storage upload adapter. The cover reference selects a card image and candidate images preserve historical presentation. No image blob or unused object-key table is added.

See [DATABASE_SCHEMA_AUDIT.md](DATABASE_SCHEMA_AUDIT.md) for Flutter → API → backend → Prisma → PostgreSQL dependencies and [DATABASE_SCHEMA_REFERENCE.md](DATABASE_SCHEMA_REFERENCE.md) for every column and key.

## Applied integrity migration

`20261110130000_harden_database_integrity` was applied by `prisma migrate deploy`. It adds E.164 checks, a partial pending-invitation unique index, coordinate and price checks, and draft JSON array checks. It validates six existing checks, changes the default for new outing guests to pending, and adds the FCM and saved-list lookup indexes. It preserves existing records, IDs, columns, and enum labels.

Group creation writes its owner membership atomically. Owner removals lock the group and recheck ownership before deleting a member. Invitation claiming locks matching rows and inserts memberships conflict-safely. An expired invitation can be reissued with history preserved. FCM uses one token upsert and chat updates the read watermark monotonically.

## Approved and applied cleanup

Review [migration.sql](backend/prisma/migrations/20261110140000_remove_obsolete_schema/migration.sql), SHA-256 `07eddd83e1eb10521dba2ba727c355f03642fdd8b0579a3a88047bf296a4350b`. The owner explicitly approved this SQL after the initial restore rehearsal. The file was moved into the active migrations directory after a second verified backup.

| Object | Cleanup effect |
|---|---|
| `users.email` | Drop the unused field and its unique index. Prisma already ignores the field. |
| `users.password_updated_at` | Drop the unused legacy timestamp. Preserve the password hash used for login. |
| `users.phone` | Set NOT NULL if all rows have a phone. Retain E.164 and uniqueness. |
| `outings.suggested_by_user_id` | Drop the unused field, FK, and backing lookup index. Preserve `created_by`. |
| `idx_group_invitations_phone`, `idx_outings_status`, `idx_chat_messages_outing_sent` | Drop indexes covered by remaining index prefixes. |
| `user_fcm_tokens_user_id_token_key` | Drop pair uniqueness. Global token uniqueness and the user index cover both needs. |
| `notification_channel` | Rebuild with push and WhatsApp. Preserve the outbox push default and the delivery logs. |

The approved cleanup ran through `prisma migrate deploy` after the refreshed backup passed the restore and SQL rehearsal. Prisma Client was regenerated and the live schema was compared to the updated Prisma model. Backend deployments must use a client generated from the new schema so outing reads select only existing fields.

There are no proposed table drops, merges, row deletions, or primary-key changes. The historical backups contain sensitive records and are ignored by Git.
