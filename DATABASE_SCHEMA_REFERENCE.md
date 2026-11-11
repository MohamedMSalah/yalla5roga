# Database schema reference

This catalog records live definitions as of the snapshot used to generate it. The appendix records the removed fields. See DATABASE_MIGRATION_REPORT.md for deployment state.


## _prisma_migrations

- Business purpose: Prisma migration execution/checksum history.
- Feature: Deployment tooling.
- Backend usage: No application endpoint → Prisma migrate deploy/status.
- Flutter usage: No Flutter usage; deployment-owned..
- Existing rows: 7.
- Table decision: KEEP.
- Redundancy, missing fields, relationship and simplification assessment: KEEP all columns and records; never reset or rewrite migration history.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `character varying(36)` | No | — | KEEP: stable row identity and relationships. |
| `checksum` | `character varying(64)` | No | — | KEEP: Prisma migration execution/checksum history; its active backend contract stores/returns this value.. |
| `finished_at` | `timestamp with time zone` | Yes | — | KEEP: Prisma migration execution/checksum history; its active backend contract stores/returns this value.. |
| `migration_name` | `character varying(255)` | No | — | KEEP: Prisma migration execution/checksum history; its active backend contract stores/returns this value.. |
| `logs` | `text` | Yes | — | KEEP: Prisma migration execution/checksum history; its active backend contract stores/returns this value.. |
| `rolled_back_at` | `timestamp with time zone` | Yes | — | KEEP: Prisma migration execution/checksum history; its active backend contract stores/returns this value.. |
| `started_at` | `timestamp with time zone` | No | now() | KEEP: Prisma migration execution/checksum history; its active backend contract stores/returns this value.. |
| `applied_steps_count` | `integer` | No | 0 | KEEP: Prisma migration execution/checksum history; its active backend contract stores/returns this value.. |

### Primary keys, foreign keys, unique/check constraints

- `_prisma_migrations_pkey`: `PRIMARY KEY (id)`; validated=true.

### Every index

- `_prisma_migrations_pkey`: `CREATE UNIQUE INDEX _prisma_migrations_pkey ON public._prisma_migrations USING btree (id)`; valid=true; observed scans=14. Scan counts are workload evidence, not sufficient grounds for removal.

## chat_messages

- Business purpose: Durable REST chat history with client retry deduplication.
- Feature: Outing chat / Socket.IO.
- Backend usage: /api/outings/:id/messages → chat/send-message.usecase.ts; datasources/chat/chat.datasource.ts; realtime/chat.gateway.ts.
- Flutter usage: chat/domain/entities/chat_message.dart; chat/data/models/chat_message_model.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: REST persists once and Socket.IO delivers after commit. client_message_id provides idempotency. The (outing_id, sent_at DESC, id DESC) index covers history ordering and replaces the shorter index.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `outing_id` | `uuid` | No | — | KEEP: outing context relationship or delivery snapshot. |
| `sender_id` | `character varying(128)` | No | — | KEEP: Durable REST chat history with client retry deduplication; its active backend contract stores/returns this value.. |
| `text` | `character varying(2000)` | No | — | KEEP: Durable REST chat history with client retry deduplication; its active backend contract stores/returns this value.. |
| `sent_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: Durable REST chat history with client retry deduplication; its active backend contract stores/returns this value.. |
| `client_message_id` | `uuid` | Yes | — | KEEP: Durable REST chat history with client retry deduplication; its active backend contract stores/returns this value.. |

### Primary keys, foreign keys, unique/check constraints

- `chat_messages_outing_id_fkey`: `FOREIGN KEY (outing_id) REFERENCES outings(id) ON DELETE CASCADE`; validated=true.
- `chat_messages_pkey`: `PRIMARY KEY (id)`; validated=true.
- `chat_messages_sender_id_fkey`: `FOREIGN KEY (sender_id) REFERENCES users(id)`; validated=true.

### Every index

- `chat_messages_pkey`: `CREATE UNIQUE INDEX chat_messages_pkey ON public.chat_messages USING btree (id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_chat_messages_outing_sent_id`: `CREATE INDEX idx_chat_messages_outing_sent_id ON public.chat_messages USING btree (outing_id, sent_at DESC, id DESC)`; valid=true; observed scans=15. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_chat_messages_sender`: `CREATE INDEX idx_chat_messages_sender ON public.chat_messages USING btree (sender_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `uq_chat_messages_client_msg`: `CREATE UNIQUE INDEX uq_chat_messages_client_msg ON public.chat_messages USING btree (outing_id, sender_id, client_message_id)`; valid=true; observed scans=94. Scan counts are workload evidence, not sufficient grounds for removal.

## chat_reads

- Business purpose: One read watermark per user per outing.
- Feature: Chat unread state.
- Backend usage: /api/outings/:id/read → chat/mark-chat-read.usecase.ts; datasources/chat/chat.datasource.ts.
- Flutter usage: chat/domain/entities/outing_chat_read_result.dart; chat/presentation/providers/outing_chat_provider.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: A watermark replaces per-message read flag duplication. The atomic upsert preserves the highest timestamp during concurrent requests.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `outing_id` | `uuid` | No | — | KEEP: outing context relationship or delivery snapshot. |
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `last_read_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: One read watermark per user per outing; its active backend contract stores/returns this value.. |

### Primary keys, foreign keys, unique/check constraints

- `chat_reads_outing_id_fkey`: `FOREIGN KEY (outing_id) REFERENCES outings(id) ON DELETE CASCADE`; validated=true.
- `chat_reads_pkey`: `PRIMARY KEY (outing_id, user_id)`; validated=true.
- `chat_reads_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `chat_reads_pkey`: `CREATE UNIQUE INDEX chat_reads_pkey ON public.chat_reads USING btree (outing_id, user_id)`; valid=true; observed scans=129. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_chat_reads_user`: `CREATE INDEX idx_chat_reads_user ON public.chat_reads USING btree (user_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.

## group_invitations

- Business purpose: Pending phone invitations before an account exists, plus claim history.
- Feature: Group invitations / deep links.
- Backend usage: /api/groups/:id/invitations; /api/auth/signup; /api/auth/login; /api/users/sync → groups/invite-to-group.usecase.ts; groups/claim-group-invitations.usecase.ts.
- Flutter usage: groups/domain/entities/group_invite_result.dart; invites/data/invite_link_parser.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: invited_phone is an address snapshot for an invitation, not a duplicate user phone column. user_id is null until the verified account claims it. A partial unique index enforces one pending row per group and phone. Expired rows can be replaced without losing history.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `group_id` | `uuid` | No | — | KEEP: group context relationship or delivery snapshot. |
| `invited_by_user_id` | `character varying(128)` | No | — | KEEP: Pending phone invitations before an account exists, plus claim history; its active backend contract stores/returns this value.. |
| `invited_phone` | `character varying(16)` | No | — | KEEP: Pending phone invitations before an account exists, plus claim history; its active backend contract stores/returns this value.. |
| `user_id` | `character varying(128)` | Yes | — | KEEP: stable user relationship / account isolation. |
| `status` | `invitation_status` | No | 'pending'::invitation_status | KEEP: domain state consumed by its feature workflow. |
| `expires_at` | `timestamp(6) with time zone` | No | — | KEEP: Pending phone invitations before an account exists, plus claim history; its active backend contract stores/returns this value.. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |

### Primary keys, foreign keys, unique/check constraints

- `group_invitations_group_id_fkey`: `FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE`; validated=true.
- `group_invitations_invited_by_user_id_fkey`: `FOREIGN KEY (invited_by_user_id) REFERENCES users(id)`; validated=true.
- `group_invitations_phone_e164`: `CHECK (invited_phone::text ~ '^[+][1-9][0-9]{1,14}$'::text)`; validated=true.
- `group_invitations_pkey`: `PRIMARY KEY (id)`; validated=true.
- `group_invitations_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL`; validated=true.

### Every index

- `group_invitations_pkey`: `CREATE UNIQUE INDEX group_invitations_pkey ON public.group_invitations USING btree (id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_group_invitations_group`: `CREATE INDEX idx_group_invitations_group ON public.group_invitations USING btree (group_id)`; valid=true; observed scans=36. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_group_invitations_invited_by`: `CREATE INDEX idx_group_invitations_invited_by ON public.group_invitations USING btree (invited_by_user_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_group_invitations_phone_status`: `CREATE INDEX idx_group_invitations_phone_status ON public.group_invitations USING btree (invited_phone, status)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_group_invitations_status`: `CREATE INDEX idx_group_invitations_status ON public.group_invitations USING btree (status)`; valid=true; observed scans=1. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_group_invitations_user`: `CREATE INDEX idx_group_invitations_user ON public.group_invitations USING btree (user_id)`; valid=true; observed scans=105. Scan counts are workload evidence, not sufficient grounds for removal.
- `uq_group_invitations_pending_phone`: `CREATE UNIQUE INDEX uq_group_invitations_pending_phone ON public.group_invitations USING btree (group_id, invited_phone) WHERE (status = 'pending'::invitation_status)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.

## group_members

- Business purpose: Current group membership and owner/member authorization.
- Feature: Groups / outing eligibility.
- Backend usage: /api/groups/:id/members → groups/add-group-member.usecase.ts; groups/remove-group-member.usecase.ts; services/groups/group-access.ts.
- Flutter usage: groups/domain/entities/group_member.dart; groups/domain/entities/group_role.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: Composite primary key prevents duplicate membership. No extra active/deleted state is necessary: removing a member deletes the join row.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `group_id` | `uuid` | No | — | KEEP: group context relationship or delivery snapshot. |
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `role` | `group_role` | No | 'member'::group_role | KEEP: Current group membership and owner/member authorization; its active backend contract stores/returns this value.. |
| `joined_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: Current group membership and owner/member authorization; its active backend contract stores/returns this value.. |

### Primary keys, foreign keys, unique/check constraints

- `group_members_group_id_fkey`: `FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE`; validated=true.
- `group_members_pkey`: `PRIMARY KEY (group_id, user_id)`; validated=true.
- `group_members_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `group_members_pkey`: `CREATE UNIQUE INDEX group_members_pkey ON public.group_members USING btree (group_id, user_id)`; valid=true; observed scans=261. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_group_members_user`: `CREATE INDEX idx_group_members_user ON public.group_members USING btree (user_id)`; valid=true; observed scans=34. Scan counts are workload evidence, not sufficient grounds for removal.

## groups

- Business purpose: Group identity, presentation and immutable creator attribution.
- Feature: Groups.
- Backend usage: /api/groups; /api/groups/cuser → groups/create-group.usecase.ts; datasources/groups/group.datasource.ts.
- Flutter usage: groups/domain/entities/group.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: created_by is historical authorship; group_members.role is current authorization and can support more than one owner. They are not duplicate relationships.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `name` | `character varying(30)` | No | — | KEEP: user-facing display label. |
| `bio` | `character varying(160)` | No | ''::character varying | KEEP: Group identity, presentation and immutable creator attribution; its active backend contract stores/returns this value.. |
| `image_url` | `character varying(2048)` | No | ''::character varying | KEEP: external object URL reference; image bytes remain outside PostgreSQL. |
| `created_by` | `character varying(128)` | No | — | KEEP: Group identity, presentation and immutable creator attribution; its active backend contract stores/returns this value.. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |

### Primary keys, foreign keys, unique/check constraints

- `groups_created_by_fkey`: `FOREIGN KEY (created_by) REFERENCES users(id)`; validated=true.
- `groups_pkey`: `PRIMARY KEY (id)`; validated=true.

### Every index

- `groups_pkey`: `CREATE UNIQUE INDEX groups_pkey ON public.groups USING btree (id)`; valid=true; observed scans=1003. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_groups_created_by`: `CREATE INDEX idx_groups_created_by ON public.groups USING btree (created_by)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.

## notification_delivery_logs

- Business purpose: Per-attempt provider delivery evidence and diagnostic history.
- Feature: Notification worker operations.
- Backend usage: Internal worker only → datasources/notifications/notification-event.datasource.ts; services/notifications/dispatch-notification.ts.
- Flutter usage: No direct Flutter access; operational evidence for push/WhatsApp..
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: KEEP distinct from the outbox: one event can have several attempts/providers. provider_message_id and response are provider metadata, not application duplicates.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `event_id` | `uuid` | No | — | KEEP: Per-attempt provider delivery evidence and diagnostic history; its active backend contract stores/returns this value.. |
| `channel` | `notification_channel` | No | — | MODIFY: retain push/whatsapp values; removed unused email/sms enum variants with approval. |
| `provider` | `character varying(40)` | No | — | KEEP: Per-attempt provider delivery evidence and diagnostic history; its active backend contract stores/returns this value.. |
| `provider_message_id` | `character varying(128)` | Yes | — | KEEP: Per-attempt provider delivery evidence and diagnostic history; its active backend contract stores/returns this value.. |
| `status` | `character varying(20)` | No | — | KEEP: domain state consumed by its feature workflow. |
| `response` | `jsonb` | Yes | — | KEEP: Per-attempt provider delivery evidence and diagnostic history; its active backend contract stores/returns this value.. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |

### Primary keys, foreign keys, unique/check constraints

- `notification_delivery_logs_event_id_fkey`: `FOREIGN KEY (event_id) REFERENCES notification_events(id) ON DELETE CASCADE`; validated=true.
- `notification_delivery_logs_pkey`: `PRIMARY KEY (id)`; validated=true.

### Every index

- `idx_notification_delivery_logs_event`: `CREATE INDEX idx_notification_delivery_logs_event ON public.notification_delivery_logs USING btree (event_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `notification_delivery_logs_pkey`: `CREATE UNIQUE INDEX notification_delivery_logs_pkey ON public.notification_delivery_logs USING btree (id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.

## notification_events

- Business purpose: Durable idempotent delivery outbox with retries.
- Feature: Push / WhatsApp worker.
- Backend usage: Produced by invite/lifecycle/chat APIs; no direct Flutter read → datasources/notifications/notification-event.datasource.ts; services/notifications/dispatch-notification.ts.
- Flutter usage: Indirect via notification inbox and FCM; worker fields are not product UI..
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: Recipient/resource IDs and phone are immutable delivery snapshots, intentionally not cascading FKs that would erase delivery history. payload is rendered delivery data, not another user profile. Keep attempts/max_attempts/status scheduling distinct. Push and WhatsApp are the active channel values after approved cleanup.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `type` | `notification_event_type` | No | — | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `channel` | `notification_channel` | No | 'push'::notification_channel | MODIFY: shared delivery enum restricts this to push and WhatsApp. |
| `status` | `notification_event_status` | No | 'pending'::notification_event_status | KEEP: domain state consumed by its feature workflow. |
| `recipient_phone` | `character varying(16)` | Yes | — | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `recipient_user_id` | `character varying(128)` | Yes | — | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `group_id` | `uuid` | Yes | — | KEEP: group context relationship or delivery snapshot. |
| `invitation_id` | `uuid` | Yes | — | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `outing_id` | `uuid` | Yes | — | KEEP: outing context relationship or delivery snapshot. |
| `event_key` | `character varying(191)` | Yes | — | KEEP: retry/idempotency boundary. |
| `payload` | `jsonb` | No | — | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `attempts` | `smallint` | No | 0 | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `max_attempts` | `smallint` | No | 5 | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `next_attempt_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `last_error` | `character varying(1000)` | Yes | — | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `sent_at` | `timestamp(6) with time zone` | Yes | — | KEEP: Durable idempotent delivery outbox with retries; its active backend contract stores/returns this value.. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |

### Primary keys, foreign keys, unique/check constraints

- `notification_events_pkey`: `PRIMARY KEY (id)`; validated=true.

### Every index

- `idx_notification_events_claim`: `CREATE INDEX idx_notification_events_claim ON public.notification_events USING btree (status, next_attempt_at)`; valid=true; observed scans=22271. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_notification_events_group`: `CREATE INDEX idx_notification_events_group ON public.notification_events USING btree (group_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_notification_events_invitation`: `CREATE INDEX idx_notification_events_invitation ON public.notification_events USING btree (invitation_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_notification_events_outing`: `CREATE INDEX idx_notification_events_outing ON public.notification_events USING btree (outing_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_notification_events_phone`: `CREATE INDEX idx_notification_events_phone ON public.notification_events USING btree (recipient_phone)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `notification_events_event_key_key`: `CREATE UNIQUE INDEX notification_events_event_key_key ON public.notification_events USING btree (event_key)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `notification_events_pkey`: `CREATE UNIQUE INDEX notification_events_pkey ON public.notification_events USING btree (id)`; valid=true; observed scans=890. Scan counts are workload evidence, not sufficient grounds for removal.

## notifications

- Business purpose: Persistent per-user in-app notification history and read state.
- Feature: Notification inbox.
- Backend usage: /api/notifications; /api/notifications/read-all → notifications/list-notifications.usecase.ts; datasources/notifications/notification.datasource.ts; services/notifications/outing-notifier.ts.
- Flutter usage: notifications/data/models/notification_model.dart; notifications/data/datasources/notifications_remote_datasource.dart.
- Existing rows: 0.
- Table decision: KEEP.
- Redundancy, missing fields, relationship and simplification assessment: KEEP distinct from delivery outbox/logs. FCM is delivery only, never history. event_key prevents repeated producers from duplicating inbox entries.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `body` | `character varying(500)` | No | — | KEEP: Persistent per-user in-app notification history and read state; its active backend contract stores/returns this value.. |
| `image_url` | `character varying(2048)` | Yes | — | KEEP: external object URL reference; image bytes remain outside PostgreSQL. |
| `type` | `notification_type` | No | 'system'::notification_type | KEEP: Persistent per-user in-app notification history and read state; its active backend contract stores/returns this value.. |
| `outing_id` | `uuid` | Yes | — | KEEP: outing context relationship or delivery snapshot. |
| `group_id` | `uuid` | Yes | — | KEEP: group context relationship or delivery snapshot. |
| `action_required` | `boolean` | No | false | KEEP: Persistent per-user in-app notification history and read state; its active backend contract stores/returns this value.. |
| `is_read` | `boolean` | No | false | KEEP: Persistent per-user in-app notification history and read state; its active backend contract stores/returns this value.. |
| `event_key` | `character varying(191)` | Yes | — | KEEP: retry/idempotency boundary. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |

### Primary keys, foreign keys, unique/check constraints

- `notifications_group_id_fkey`: `FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE SET NULL`; validated=true.
- `notifications_outing_id_fkey`: `FOREIGN KEY (outing_id) REFERENCES outings(id) ON DELETE SET NULL`; validated=true.
- `notifications_pkey`: `PRIMARY KEY (id)`; validated=true.
- `notifications_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_notifications_group`: `CREATE INDEX idx_notifications_group ON public.notifications USING btree (group_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_notifications_outing`: `CREATE INDEX idx_notifications_outing ON public.notifications USING btree (outing_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_notifications_user_created`: `CREATE INDEX idx_notifications_user_created ON public.notifications USING btree (user_id, created_at DESC)`; valid=true; observed scans=8. Scan counts are workload evidence, not sufficient grounds for removal.
- `notifications_event_key_key`: `CREATE UNIQUE INDEX notifications_event_key_key ON public.notifications USING btree (event_key)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `notifications_pkey`: `CREATE UNIQUE INDEX notifications_pkey ON public.notifications USING btree (id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.

## outing_arrivals

- Business purpose: First physical arrival timestamp per participant and outing.
- Feature: Foreground venue arrival.
- Backend usage: /api/outings/:id/arrivals; /api/outings/:id/arrivals/self → outings/arrivals.usecase.ts; services/outings/arrival-policy.ts.
- Flutter usage: outings/domain/entities/outing_arrival.dart; outings/presentation/providers/outing_arrival_service.dart.
- Existing rows: 0.
- Table decision: KEEP.
- Redundancy, missing fields, relationship and simplification assessment: Not attendance and not voting. No persistent GPS trail: only the first accepted timestamp is stored.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `outing_id` | `uuid` | No | — | KEEP: outing context relationship or delivery snapshot. |
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `arrived_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: First physical arrival timestamp per participant and outing; its active backend contract stores/returns this value.. |

### Primary keys, foreign keys, unique/check constraints

- `outing_arrivals_outing_id_fkey`: `FOREIGN KEY (outing_id) REFERENCES outings(id) ON DELETE CASCADE`; validated=true.
- `outing_arrivals_pkey`: `PRIMARY KEY (outing_id, user_id)`; validated=true.
- `outing_arrivals_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_outing_arrivals_user`: `CREATE INDEX idx_outing_arrivals_user ON public.outing_arrivals USING btree (user_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `outing_arrivals_pkey`: `CREATE UNIQUE INDEX outing_arrivals_pkey ON public.outing_arrivals USING btree (outing_id, user_id)`; valid=true; observed scans=5. Scan counts are workload evidence, not sufficient grounds for removal.

## outing_attendance

- Business purpose: Participant going/not_going/maybe decision independent of place voting.
- Feature: Attendance.
- Backend usage: /api/outings/:id/attendance → outings/attendance.usecase.ts; datasources/outings/outing.datasource.ts.
- Flutter usage: outings/domain/entities/outing_enums.dart; outings/presentation/widgets/outing_attendance_widget.dart.
- Existing rows: 0.
- Table decision: KEEP.
- Redundancy, missing fields, relationship and simplification assessment: Do not merge with outing_guests, arrivals or votes. Correct the misplaced Prisma user index annotation to this table.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `outing_id` | `uuid` | No | — | KEEP: outing context relationship or delivery snapshot. |
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `status` | `attendance_status` | No | — | KEEP: domain state consumed by its feature workflow. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |

### Primary keys, foreign keys, unique/check constraints

- `outing_attendance_outing_id_fkey`: `FOREIGN KEY (outing_id) REFERENCES outings(id) ON DELETE CASCADE`; validated=true.
- `outing_attendance_pkey`: `PRIMARY KEY (outing_id, user_id)`; validated=true.
- `outing_attendance_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_outing_attendance_user`: `CREATE INDEX idx_outing_attendance_user ON public.outing_attendance USING btree (user_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `outing_attendance_pkey`: `CREATE UNIQUE INDEX outing_attendance_pkey ON public.outing_attendance USING btree (outing_id, user_id)`; valid=true; observed scans=43. Scan counts are workload evidence, not sufficient grounds for removal.

## outing_drafts

- Business purpose: Incomplete user-owned create-form state, not published membership.
- Feature: Saved drafts / resume creation.
- Backend usage: /api/outings/drafts → outings/drafts.usecase.ts; datasources/outings/outing.datasource.ts.
- Flutter usage: outings/domain/entities/saved_outing.dart; outings/presentation/providers/create_outing_provider.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: KEEP despite zero live rows: active Flutter draft/resume feature. Draft date/hour/minute preserve incomplete form input; JSON selected_places and guest_ids are drafts, not authoritative relational memberships. guestPhones exists in Flutter but is lost by the current wire mapper: do not add a phone JSON column without defining consent persistence; record the gap.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `title` | `character varying(20)` | No | ''::character varying | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `image_url` | `character varying(2048)` | No | ''::character varying | KEEP: external object URL reference; image bytes remain outside PostgreSQL. |
| `group_id` | `uuid` | Yes | — | KEEP: group context relationship or delivery snapshot. |
| `occasion` | `outing_occasion` | No | 'none'::outing_occasion | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `special_event` | `boolean` | No | false | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `vibe` | `outing_vibe` | No | 'food'::outing_vibe | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `scheduled_date` | `date` | Yes | — | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `scheduled_hour` | `smallint` | Yes | — | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `scheduled_minute` | `smallint` | Yes | — | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `location_name` | `character varying(100)` | Yes | — | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `location_area` | `character varying(100)` | Yes | — | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `location_latitude` | `double precision` | Yes | — | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `location_longitude` | `double precision` | Yes | — | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `let_vote` | `boolean` | No | false | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `vote_deadline_hours` | `smallint` | Yes | — | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `guest_ids` | `jsonb` | No | '[]'::jsonb | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `selected_places` | `jsonb` | No | '[]'::jsonb | KEEP: Incomplete user-owned create-form state, not published membership; its active backend contract stores/returns this value.. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |

### Primary keys, foreign keys, unique/check constraints

- `outing_drafts_array_fields`: `CHECK (jsonb_typeof(guest_ids) = 'array'::text AND jsonb_typeof(selected_places) = 'array'::text)`; validated=true.
- `outing_drafts_coordinate_bounds`: `CHECK (location_latitude >= '-90'::integer::double precision AND location_latitude <= 90::double precision AND location_longitude >= '-180'::integer::double precision AND location_longitude <= 180::double precision)`; validated=true.
- `outing_drafts_group_id_fkey`: `FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE SET NULL`; validated=true.
- `outing_drafts_pkey`: `PRIMARY KEY (id)`; validated=true.
- `outing_drafts_scheduled_hour_range`: `CHECK (scheduled_hour IS NULL OR scheduled_hour >= 0 AND scheduled_hour <= 23)`; validated=true.
- `outing_drafts_scheduled_minute_range`: `CHECK (scheduled_minute IS NULL OR scheduled_minute >= 0 AND scheduled_minute <= 59)`; validated=true.
- `outing_drafts_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.
- `outing_drafts_vote_deadline_range`: `CHECK (vote_deadline_hours IS NULL OR vote_deadline_hours >= 1 AND vote_deadline_hours <= 72)`; validated=true.

### Every index

- `idx_outing_drafts_user`: `CREATE INDEX idx_outing_drafts_user ON public.outing_drafts USING btree (user_id)`; valid=true; observed scans=108. Scan counts are workload evidence, not sufficient grounds for removal.
- `outing_drafts_pkey`: `CREATE UNIQUE INDEX outing_drafts_pkey ON public.outing_drafts USING btree (id)`; valid=true; observed scans=4. Scan counts are workload evidence, not sufficient grounds for removal.

## outing_guests

- Business purpose: Registered outing invitation state and accepted direct participation.
- Feature: Outing invitations / special-event app members.
- Backend usage: /api/outings/:id/guests; /api/outings/:id/invitations/accept|decline → outings/guests.usecase.ts; services/outings/outing-participants.ts.
- Flutter usage: outings/data/datasources/outings_remote_datasource.dart; outings/domain/entities/outing.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: KEEP even with zero live rows: approved invitation/acceptance scenario and active APIs. Historical table name is not a Guest role. Default should be pending, not accepted.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `outing_id` | `uuid` | No | — | KEEP: outing context relationship or delivery snapshot. |
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `invited_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: Registered outing invitation state and accepted direct participation; its active backend contract stores/returns this value.. |
| `status` | `invitation_status` | No | 'pending'::invitation_status | MODIFY: default pending; acceptance remains explicit. Existing rows unchanged. |

### Primary keys, foreign keys, unique/check constraints

- `outing_guests_outing_id_fkey`: `FOREIGN KEY (outing_id) REFERENCES outings(id) ON DELETE CASCADE`; validated=true.
- `outing_guests_pkey`: `PRIMARY KEY (outing_id, user_id)`; validated=true.
- `outing_guests_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_outing_guests_status`: `CREATE INDEX idx_outing_guests_status ON public.outing_guests USING btree (outing_id, status)`; valid=true; observed scans=121. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_outing_guests_user`: `CREATE INDEX idx_outing_guests_user ON public.outing_guests USING btree (user_id)`; valid=true; observed scans=182. Scan counts are workload evidence, not sufficient grounds for removal.
- `outing_guests_pkey`: `CREATE UNIQUE INDEX outing_guests_pkey ON public.outing_guests USING btree (outing_id, user_id)`; valid=true; observed scans=555. Scan counts are workload evidence, not sufficient grounds for removal.

## outing_vote_options

- Business purpose: Ordered candidate place snapshots, including manual map pins.
- Feature: Place voting / roulette.
- Backend usage: /api/outings/:id/vote-options → outings/voting.usecase.ts; services/outings/vote-resolution.ts.
- Flutter usage: outings/domain/entities/place.dart; outings/domain/entities/place_vote.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: Composite unique (id,outing_id) is required by winner/vote composite foreign keys even though id alone is unique. Snapshot label/image/vibe/coordinates preserve manual and historical candidates.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `outing_id` | `uuid` | No | — | KEEP: outing context relationship or delivery snapshot. |
| `place_id` | `uuid` | Yes | — | KEEP: Ordered candidate place snapshots, including manual map pins; its active backend contract stores/returns this value.. |
| `label` | `character varying(100)` | No | — | KEEP: Ordered candidate place snapshots, including manual map pins; its active backend contract stores/returns this value.. |
| `area` | `character varying(100)` | No | ''::character varying | KEEP: Ordered candidate place snapshots, including manual map pins; its active backend contract stores/returns this value.. |
| `image_url` | `character varying(2048)` | No | ''::character varying | KEEP: external object URL reference; image bytes remain outside PostgreSQL. |
| `vibe` | `outing_vibe` | No | 'food'::outing_vibe | KEEP: Ordered candidate place snapshots, including manual map pins; its active backend contract stores/returns this value.. |
| `latitude` | `double precision` | Yes | — | KEEP: geographic latitude for map/distance semantics. |
| `longitude` | `double precision` | Yes | — | KEEP: geographic longitude for map/distance semantics. |
| `sort_order` | `integer` | No | 0 | KEEP: explicit presentation ordering. |

### Primary keys, foreign keys, unique/check constraints

- `outing_vote_options_coordinate_bounds`: `CHECK (latitude >= '-90'::integer::double precision AND latitude <= 90::double precision AND longitude >= '-180'::integer::double precision AND longitude <= 180::double precision)`; validated=true.
- `outing_vote_options_outing_id_fkey`: `FOREIGN KEY (outing_id) REFERENCES outings(id) ON DELETE CASCADE`; validated=true.
- `outing_vote_options_pkey`: `PRIMARY KEY (id)`; validated=true.
- `outing_vote_options_place_id_fkey`: `FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE SET NULL`; validated=true.

### Every index

- `idx_outing_vote_options_place`: `CREATE INDEX idx_outing_vote_options_place ON public.outing_vote_options USING btree (place_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `outing_vote_options_outing_id_place_id_key`: `CREATE UNIQUE INDEX outing_vote_options_outing_id_place_id_key ON public.outing_vote_options USING btree (outing_id, place_id)`; valid=true; observed scans=20. Scan counts are workload evidence, not sufficient grounds for removal.
- `outing_vote_options_pkey`: `CREATE UNIQUE INDEX outing_vote_options_pkey ON public.outing_vote_options USING btree (id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `uq_vote_options_id_outing`: `CREATE UNIQUE INDEX uq_vote_options_id_outing ON public.outing_vote_options USING btree (id, outing_id)`; valid=true; observed scans=108. Scan counts are workload evidence, not sufficient grounds for removal.

## outing_votes

- Business purpose: One active place vote per user per outing.
- Feature: Voting.
- Backend usage: /api/outings/:id/votes → outings/voting.usecase.ts; services/outings/vote-resolution.ts.
- Flutter usage: outings/domain/entities/place_vote.dart; outings/data/datasources/outings_remote_datasource.dart.
- Existing rows: 0.
- Table decision: KEEP.
- Redundancy, missing fields, relationship and simplification assessment: Composite FK prevents voting for another outing candidate. Keep direct outing FK for lifecycle ownership/cascade and lookup; no duplicated attendance status.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `outing_id` | `uuid` | No | — | KEEP: outing context relationship or delivery snapshot. |
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `option_id` | `uuid` | No | — | KEEP: One active place vote per user per outing; its active backend contract stores/returns this value.. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |

### Primary keys, foreign keys, unique/check constraints

- `outing_votes_option_id_outing_id_fkey`: `FOREIGN KEY (option_id, outing_id) REFERENCES outing_vote_options(id, outing_id) ON DELETE CASCADE`; validated=true.
- `outing_votes_outing_id_fkey`: `FOREIGN KEY (outing_id) REFERENCES outings(id) ON DELETE CASCADE`; validated=true.
- `outing_votes_pkey`: `PRIMARY KEY (outing_id, user_id)`; validated=true.
- `outing_votes_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_outing_votes_option`: `CREATE INDEX idx_outing_votes_option ON public.outing_votes USING btree (option_id)`; valid=true; observed scans=28. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_outing_votes_user`: `CREATE INDEX idx_outing_votes_user ON public.outing_votes USING btree (user_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `outing_votes_pkey`: `CREATE UNIQUE INDEX outing_votes_pkey ON public.outing_votes USING btree (outing_id, user_id)`; valid=true; observed scans=211. Scan counts are workload evidence, not sufficient grounds for removal.

## outings

- Business purpose: Group plans and special events with schedule, venue and server-owned lifecycle.
- Feature: Outings / events / history.
- Backend usage: /api/outings; /api/outings/cuser → outings/create-outing.usecase.ts; outings/update-outing.usecase.ts; services/outings/vote-resolution.ts.
- Flutter usage: outings/domain/entities/outing.dart; outings/data/datasources/outings_remote_datasource.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: Location strings/coordinates are an intentional manual-venue or winner snapshot, not a duplicate catalog entity. type, occasion, status and vote closure are distinct. Removed suggested_by_user_id after verifying there was no consumer or writer and no populated row. created_by supplies attribution.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `title` | `character varying(20)` | No | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `image_url` | `character varying(2048)` | No | ''::character varying | KEEP: external object URL reference; image bytes remain outside PostgreSQL. |
| `group_id` | `uuid` | Yes | — | KEEP: group context relationship or delivery snapshot. |
| `created_by` | `character varying(128)` | No | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `status` | `outing_status` | No | 'draft'::outing_status | KEEP: domain state consumed by its feature workflow. |
| `type` | `outing_type` | No | 'group'::outing_type | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `occasion` | `outing_occasion` | No | 'none'::outing_occasion | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `scheduled_at` | `timestamp(6) with time zone` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `ends_at` | `timestamp(6) with time zone` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `location_place_id` | `uuid` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `location_name` | `character varying(100)` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `location_area` | `character varying(100)` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `location_latitude` | `double precision` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `location_longitude` | `double precision` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `vote_deadline_hours` | `smallint` | Yes | — | KEEP: user-selected duration for forms/API; vote_ends_at is the absolute server closing instant, not redundant state. |
| `vote_ends_at` | `timestamp(6) with time zone` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `vote_closed_at` | `timestamp(6) with time zone` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |
| `vote_close_reason` | `vote_close_reason` | Yes | — | KEEP: server resolution reason; distinct from lifecycle status and closure timestamp. |
| `winning_option_id` | `uuid` | Yes | — | KEEP: server-selected winner protected by same-outing composite FK. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |
| `create_request_key` | `character varying(80)` | Yes | — | KEEP: Group plans and special events with schedule, venue and server-owned lifecycle; its active backend contract stores/returns this value.. |

### Primary keys, foreign keys, unique/check constraints

- `outings_coordinate_bounds`: `CHECK (location_latitude >= '-90'::integer::double precision AND location_latitude <= 90::double precision AND location_longitude >= '-180'::integer::double precision AND location_longitude <= 180::double precision)`; validated=true.
- `outings_created_by_fkey`: `FOREIGN KEY (created_by) REFERENCES users(id)`; validated=true.
- `outings_ends_after_scheduled`: `CHECK (scheduled_at IS NULL OR ends_at IS NULL OR ends_at > scheduled_at)`; validated=true.
- `outings_group_id_fkey`: `FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE SET NULL`; validated=true.
- `outings_location_place_id_fkey`: `FOREIGN KEY (location_place_id) REFERENCES places(id) ON DELETE SET NULL`; validated=true.
- `outings_pkey`: `PRIMARY KEY (id)`; validated=true.
- `outings_type_group_consistency`: `CHECK (type = 'group'::outing_type AND group_id IS NOT NULL OR type = 'special_event'::outing_type AND group_id IS NULL)`; validated=true.
- `outings_vote_deadline_range`: `CHECK (vote_deadline_hours IS NULL OR vote_deadline_hours >= 1 AND vote_deadline_hours <= 72)`; validated=true.
- `outings_winning_option_id_id_fkey`: `FOREIGN KEY (winning_option_id, id) REFERENCES outing_vote_options(id, outing_id)`; validated=true.

### Every index

- `idx_outings_created_by`: `CREATE INDEX idx_outings_created_by ON public.outings USING btree (created_by)`; valid=true; observed scans=20. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_outings_group`: `CREATE INDEX idx_outings_group ON public.outings USING btree (group_id)`; valid=true; observed scans=155. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_outings_location_place`: `CREATE INDEX idx_outings_location_place ON public.outings USING btree (location_place_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_outings_scheduled`: `CREATE INDEX idx_outings_scheduled ON public.outings USING btree (scheduled_at)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_outings_vote_ends_at`: `CREATE INDEX idx_outings_vote_ends_at ON public.outings USING btree (vote_ends_at)`; valid=true; observed scans=1245. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_outings_voting_deadline`: `CREATE INDEX idx_outings_voting_deadline ON public.outings USING btree (status, vote_ends_at)`; valid=true; observed scans=244. Scan counts are workload evidence, not sufficient grounds for removal.
- `outings_pkey`: `CREATE UNIQUE INDEX outings_pkey ON public.outings USING btree (id)`; valid=true; observed scans=295. Scan counts are workload evidence, not sufficient grounds for removal.
- `uq_outings_creator_request`: `CREATE UNIQUE INDEX uq_outings_creator_request ON public.outings USING btree (created_by, create_request_key)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.

## place_hours

- Business purpose: Weekly opening hours including closed days.
- Feature: Places API / external catalog management.
- Backend usage: /api/places/:id/hours → places/place-details.usecase.ts; datasources/places/place.datasource.ts.
- Flutter usage: No hours consumer in Flutter; the backend exposes hours CRUD..
- Existing rows: 0.
- Table decision: KEEP.
- Redundancy, missing fields, relationship and simplification assessment: Unique place/day is correct. Overnight opening intervals remain valid; do not require close time to be later on the same day.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `place_id` | `uuid` | No | — | KEEP: Weekly opening hours including closed days; its active backend contract stores/returns this value.. |
| `day` | `weekday` | No | — | KEEP: Weekly opening hours including closed days; its active backend contract stores/returns this value.. |
| `opens_at` | `time(6) without time zone` | Yes | — | KEEP: Weekly opening hours including closed days; its active backend contract stores/returns this value.. |
| `closes_at` | `time(6) without time zone` | Yes | — | KEEP: Weekly opening hours including closed days; its active backend contract stores/returns this value.. |
| `is_closed` | `boolean` | No | false | KEEP: Weekly opening hours including closed days; its active backend contract stores/returns this value.. |

### Primary keys, foreign keys, unique/check constraints

- `place_hours_pkey`: `PRIMARY KEY (id)`; validated=true.
- `place_hours_place_id_fkey`: `FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE`; validated=true.

### Every index

- `place_hours_pkey`: `CREATE UNIQUE INDEX place_hours_pkey ON public.place_hours USING btree (id)`; valid=true; observed scans=1. Scan counts are workload evidence, not sufficient grounds for removal.
- `place_hours_place_id_day_key`: `CREATE UNIQUE INDEX place_hours_place_id_day_key ON public.place_hours USING btree (place_id, day)`; valid=true; observed scans=4. Scan counts are workload evidence, not sufficient grounds for removal.

## place_images

- Business purpose: Ordered gallery image references and captions for a catalog place.
- Feature: Places API / external catalog management.
- Backend usage: /api/places/:id/images → places/place-details.usecase.ts; datasources/places/place.datasource.ts.
- Flutter usage: No gallery consumer in Flutter; the backend exposes gallery CRUD..
- Existing rows: 0.
- Table decision: KEEP.
- Redundancy, missing fields, relationship and simplification assessment: KEEP: active catalog API. Store external object URLs only; do not store image bytes or invent an unused asset table.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `place_id` | `uuid` | No | — | KEEP: Ordered gallery image references and captions for a catalog place; its active backend contract stores/returns this value.. |
| `image_url` | `character varying(2048)` | No | — | KEEP: external object URL reference; image bytes remain outside PostgreSQL. |
| `caption` | `character varying(200)` | Yes | — | KEEP: Ordered gallery image references and captions for a catalog place; its active backend contract stores/returns this value.. |
| `sort_order` | `integer` | No | 0 | KEEP: explicit presentation ordering. |

### Primary keys, foreign keys, unique/check constraints

- `place_images_pkey`: `PRIMARY KEY (id)`; validated=true.
- `place_images_place_id_fkey`: `FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_place_images_place`: `CREATE INDEX idx_place_images_place ON public.place_images USING btree (place_id, sort_order)`; valid=true; observed scans=3. Scan counts are workload evidence, not sufficient grounds for removal.
- `place_images_pkey`: `CREATE UNIQUE INDEX place_images_pkey ON public.place_images USING btree (id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.

## place_prices

- Business purpose: Itemized prices independent of a place summary price range.
- Feature: Places API / external catalog management.
- Backend usage: /api/places/:id/prices → places/place-details.usecase.ts; datasources/places/place.datasource.ts.
- Flutter usage: No itemized-price consumer in Flutter; the backend exposes itemized-price CRUD..
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: KEEP: active catalog API. Enforce nonnegative amounts; no evidence supports merging itemized prices into the summary range.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `place_id` | `uuid` | No | — | KEEP: Itemized prices independent of a place summary price range; its active backend contract stores/returns this value.. |
| `label` | `character varying(80)` | No | — | KEEP: Itemized prices independent of a place summary price range; its active backend contract stores/returns this value.. |
| `amount` | `numeric(12,2)` | No | — | KEEP: Itemized prices independent of a place summary price range; its active backend contract stores/returns this value.. |
| `currency` | `character(3)` | No | 'EGP'::bpchar | KEEP: Itemized prices independent of a place summary price range; its active backend contract stores/returns this value.. |

### Primary keys, foreign keys, unique/check constraints

- `place_prices_nonnegative`: `CHECK (amount >= 0::numeric)`; validated=true.
- `place_prices_pkey`: `PRIMARY KEY (id)`; validated=true.
- `place_prices_place_id_fkey`: `FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_place_prices_place`: `CREATE INDEX idx_place_prices_place ON public.place_prices USING btree (place_id)`; valid=true; observed scans=3. Scan counts are workload evidence, not sufficient grounds for removal.
- `place_prices_pkey`: `CREATE UNIQUE INDEX place_prices_pkey ON public.place_prices USING btree (id)`; valid=true; observed scans=2. Scan counts are workload evidence, not sufficient grounds for removal.

## places

- Business purpose: Reusable discovery catalog and nearby location search.
- Feature: Discover / maps / outing picker.
- Backend usage: /api/places; /api/places/nearby → places/find-nearby-places.usecase.ts; datasources/places/place.datasource.ts.
- Flutter usage: discover/data/datasources/discover_remote_datasource.dart; discover/domain/entities/suggested_place.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: Catalog price summary and itemized place_prices are different granularity. Cover is the selected card image, not a duplicate gallery row. No upload service exists.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `name` | `character varying(100)` | No | — | KEEP: user-facing display label. |
| `area` | `character varying(100)` | No | ''::character varying | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `vibe` | `outing_vibe` | No | 'food'::outing_vibe | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `description` | `character varying(1000)` | No | ''::character varying | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `cover_image_url` | `character varying(2048)` | No | ''::character varying | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `price_level` | `price_level` | No | 'moderate'::price_level | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `price_min` | `numeric(12,2)` | Yes | — | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `price_max` | `numeric(12,2)` | Yes | — | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `currency` | `character(3)` | No | 'EGP'::bpchar | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `latitude` | `double precision` | Yes | — | KEEP: geographic latitude for map/distance semantics. |
| `longitude` | `double precision` | Yes | — | KEEP: geographic longitude for map/distance semantics. |
| `featured` | `boolean` | No | false | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `is_active` | `boolean` | No | true | KEEP: Reusable discovery catalog and nearby location search; its active backend contract stores/returns this value.. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |

### Primary keys, foreign keys, unique/check constraints

- `places_coordinate_bounds`: `CHECK (latitude >= '-90'::integer::double precision AND latitude <= 90::double precision AND longitude >= '-180'::integer::double precision AND longitude <= 180::double precision)`; validated=true.
- `places_pkey`: `PRIMARY KEY (id)`; validated=true.
- `places_price_bounds`: `CHECK (price_min >= 0::numeric AND price_max >= 0::numeric AND price_min <= price_max)`; validated=true.

### Every index

- `idx_places_lat_lng`: `CREATE INDEX idx_places_lat_lng ON public.places USING btree (latitude, longitude)`; valid=true; observed scans=33. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_places_vibe`: `CREATE INDEX idx_places_vibe ON public.places USING btree (vibe)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `places_pkey`: `CREATE UNIQUE INDEX places_pkey ON public.places USING btree (id)`; valid=true; observed scans=27. Scan counts are workload evidence, not sufficient grounds for removal.

## saved_outings

- Business purpose: User bookmarks of published outings.
- Feature: Saved outings.
- Backend usage: /api/outings/saved; /api/outings/:id/save → outings/saved.usecase.ts.
- Flutter usage: outings/domain/entities/saved_outing.dart; outings/presentation/providers/saved_outings_provider.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: Composite PK enforces one bookmark per pair. saved_at determines user ordering; the (user_id, saved_at DESC) index serves that query, retaining reverse FK index.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `outing_id` | `uuid` | No | — | KEEP: outing context relationship or delivery snapshot. |
| `saved_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: bookmark ordering. |

### Primary keys, foreign keys, unique/check constraints

- `saved_outings_outing_id_fkey`: `FOREIGN KEY (outing_id) REFERENCES outings(id) ON DELETE CASCADE`; validated=true.
- `saved_outings_pkey`: `PRIMARY KEY (user_id, outing_id)`; validated=true.
- `saved_outings_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_saved_outings_outing`: `CREATE INDEX idx_saved_outings_outing ON public.saved_outings USING btree (outing_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_saved_outings_user_saved`: `CREATE INDEX idx_saved_outings_user_saved ON public.saved_outings USING btree (user_id, saved_at DESC)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `saved_outings_pkey`: `CREATE UNIQUE INDEX saved_outings_pkey ON public.saved_outings USING btree (user_id, outing_id)`; valid=true; observed scans=168. Scan counts are workload evidence, not sufficient grounds for removal.

## saved_places

- Business purpose: User bookmarks of discovery places.
- Feature: Saved places API / partial client wiring.
- Backend usage: /api/places/saved; /api/places/:id/save → outings/saved-places.usecase.ts.
- Flutter usage: discover/data/datasources/saved_places_remote_datasource.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: KEEP despite zero live rows: approved saved-place scenario and active API. No reason to merge with saved_outings (different target FKs).

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `place_id` | `uuid` | No | — | KEEP: User bookmarks of discovery places; its active backend contract stores/returns this value.. |
| `saved_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: bookmark ordering. |

### Primary keys, foreign keys, unique/check constraints

- `saved_places_pkey`: `PRIMARY KEY (user_id, place_id)`; validated=true.
- `saved_places_place_id_fkey`: `FOREIGN KEY (place_id) REFERENCES places(id) ON DELETE CASCADE`; validated=true.
- `saved_places_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_saved_places_place`: `CREATE INDEX idx_saved_places_place ON public.saved_places USING btree (place_id)`; valid=true; observed scans=1. Scan counts are workload evidence, not sufficient grounds for removal.
- `idx_saved_places_user_saved`: `CREATE INDEX idx_saved_places_user_saved ON public.saved_places USING btree (user_id, saved_at DESC)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `saved_places_pkey`: `CREATE UNIQUE INDEX saved_places_pkey ON public.saved_places USING btree (user_id, place_id)`; valid=true; observed scans=111. Scan counts are workload evidence, not sufficient grounds for removal.

## user_fcm_tokens

- Business purpose: Current installation push tokens owned by one user.
- Feature: FCM registration / push delivery.
- Backend usage: /api/users/cuser/fcm-token → users/fcm-token.usecase.ts; services/notifications/channels/push.channel.ts.
- Flutter usage: notifications/data/datasources/fcm_token_remote_datasource.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: Global token uniqueness makes unique(user_id,token) redundant. The user_id index and atomic upsert by token replace it, avoiding delete-then-insert races.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `uuid` | No | gen_random_uuid() | KEEP: stable row identity and relationships. |
| `user_id` | `character varying(128)` | No | — | KEEP: stable user relationship / account isolation. |
| `token` | `character varying(512)` | No | — | KEEP: Current installation push tokens owned by one user; its active backend contract stores/returns this value.. |
| `platform` | `character varying(20)` | Yes | — | KEEP: Current installation push tokens owned by one user; its active backend contract stores/returns this value.. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |

### Primary keys, foreign keys, unique/check constraints

- `user_fcm_tokens_pkey`: `PRIMARY KEY (id)`; validated=true.
- `user_fcm_tokens_user_id_fkey`: `FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE`; validated=true.

### Every index

- `idx_user_fcm_tokens_user`: `CREATE INDEX idx_user_fcm_tokens_user ON public.user_fcm_tokens USING btree (user_id)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `uq_user_fcm_tokens_token`: `CREATE UNIQUE INDEX uq_user_fcm_tokens_token ON public.user_fcm_tokens USING btree (token)`; valid=true; observed scans=53. Scan counts are workload evidence, not sufficient grounds for removal.
- `user_fcm_tokens_pkey`: `CREATE UNIQUE INDEX user_fcm_tokens_pkey ON public.user_fcm_tokens USING btree (id)`; valid=true; observed scans=1. Scan counts are workload evidence, not sufficient grounds for removal.

## users

- Business purpose: Canonical application profile keyed by stable Firebase UID.
- Feature: Auth / Settings / phone lookup.
- Backend usage: /api/auth/signup; /api/auth/login; /api/users/sync; /api/users/cuser → auth/signup.usecase.ts; auth/login.usecase.ts; users/sync-user.usecase.ts; datasources/users/user.datasource.ts.
- Flutter usage: auth/data/models/user_model.dart; auth/domain/entities/user.dart.
- Existing rows: 0.
- Table decision: MODIFY.
- Redundancy, missing fields, relationship and simplification assessment: The stable Firebase UID keys all relationships. The unique, required E.164 phone is the lookup and invitation address. The cleanup preflight found no missing phones.

| Column | SQL type | Nullable | Default | Classification and purpose |
|---|---|---|---|---|
| `id` | `character varying(128)` | No | — | KEEP: stable existing Firebase UID primary key. Do not re-key to phone or regenerate IDs. |
| `name` | `character varying(30)` | No | — | KEEP: user-facing display label. |
| `phone` | `character varying(16)` | No | — | MODIFY: unique E.164 lookup. The live schema requires both E.164 format and NOT NULL. |
| `password_hash` | `character varying(255)` | Yes | — | KEEP: application bcrypt credential used by phone/password login, confirmation and change-password. Public user JSON only includes has_password. |
| `image_url` | `character varying(2048)` | Yes | — | KEEP: external object URL reference; image bytes remain outside PostgreSQL. |
| `created_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: creation chronology / audit history. |
| `updated_at` | `timestamp(6) with time zone` | No | CURRENT_TIMESTAMP | KEEP: last mutation chronology / user ordering. |

### Primary keys, foreign keys, unique/check constraints

- `users_phone_e164`: `CHECK (phone::text ~ '^[+][1-9][0-9]{1,14}$'::text)`; validated=true.
- `users_pkey`: `PRIMARY KEY (id)`; validated=true.

### Every index

- `users_phone_key`: `CREATE UNIQUE INDEX users_phone_key ON public.users USING btree (phone)`; valid=true; observed scans=0. Scan counts are workload evidence, not sufficient grounds for removal.
- `users_pkey`: `CREATE UNIQUE INDEX users_pkey ON public.users USING btree (id)`; valid=true; observed scans=367. Scan counts are workload evidence, not sufficient grounds for removal.

## All enum types

- `attendance_status`: `going`, `not_going`, `maybe`. KEEP: used by active domain fields.
- `group_role`: `owner`, `member`. KEEP: used by active domain fields.
- `invitation_status`: `pending`, `accepted`, `declined`, `expired`, `revoked`. KEEP: used by active domain fields.
- `notification_channel`: `whatsapp`, `push`. MODIFY: push and WhatsApp remain after approved removal of email and SMS.
- `notification_event_status`: `pending`, `processing`, `sent`, `failed`, `dead`. KEEP: used by active domain fields.
- `notification_event_type`: `group_invite`, `outing_invite`, `outing_updated`, `attendance_changed`, `chat_message`, `voting_closed_early`, `voting_deadline_reached`, `winner_selected`, `tie_break_selected`, `outing_confirmed`, `outing_cancelled`. KEEP: used by active domain fields.
- `notification_type`: `outing`, `group`, `chat`, `vote`, `invitation`, `system`. KEEP: used by active domain fields.
- `outing_occasion`: `none`, `birthday`, `wedding`. KEEP: used by active domain fields.
- `outing_status`: `draft`, `voting`, `confirmed`, `cancelled`, `past`. KEEP: used by active domain fields.
- `outing_type`: `group`, `special_event`. KEEP: used by active domain fields.
- `outing_vibe`: `food`, `activity`, `outdoor`, `movie`. KEEP: used by active domain fields.
- `price_level`: `free`, `budget`, `moderate`, `expensive`, `luxury`. KEEP: used by active domain fields.
- `vote_close_reason`: `all_voted`, `deadline`, `unique_winner`, `tie_break`, `zero_votes`. KEEP: used by active domain fields.
- `weekday`: `monday`, `tuesday`, `wednesday`, `thursday`, `friday`, `saturday`, `sunday`. KEEP: used by active domain fields.

## Removed columns

| Table | Column | Previous SQL type | Nullable | Previous default | Decision |
|---|---|---|---|---|---|
| `outings` | `suggested_by_user_id` | `character varying(128)` | Yes | — | REMOVE. Unused optional attribution. created_by retains authorship. |
| `users` | `email` | `character varying(254)` | Yes | — | REMOVE. Legacy email address. Phone/password is the supported flow. |
| `users` | `password_updated_at` | `timestamp(6) with time zone` | Yes | — | REMOVE. Legacy credential timestamp with no current reader. |
