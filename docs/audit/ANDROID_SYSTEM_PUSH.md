# Android system push implementation — 2026-11-14

Android external system notification handling extends the existing inbox, PostgreSQL outbox, Firebase Admin sender, Provider repositories and Socket.IO coordinator. In-app history/read states remain in Neon. No Firestore, Firebase Realtime Database, new state framework or dependency was added. WhatsApp service/channel/template files were not modified by this task. Unrelated and concurrent workspace edits were preserved; this report lists only task-owned changes, including small integrations in shared files.

## Migration and rollout

`backend/prisma/migrations/20261114030000_android_system_notifications/migration.sql` adds two JSON attributes (`users.notification_preferences`, `notifications.data`), a constrained `user_fcm_tokens.notification_version` capability (default 1; supported 1/2), and missing event enum values. Existing rows/tables/IDs/relationships remain. The migration was applied only inside disposable verification schemas, not to the application Neon schema. Apply the reviewed migration before deploying the updated backend. Updated clients register notificationVersion=2 and receive data-only native action delivery; old Android registrations retain ordinary OS-visible pushes until upgraded. Private previews default hidden/redacted.

## API changes

| Operation | Change |
|---|---|
| GET /api/notifications/preferences | New authenticated caller-only resolved preference defaults |
| PATCH /api/notifications/preferences | New strict partial boolean update, serialized against concurrent preference changes |
| GET /api/notifications/{id}/system-payload | New ownership/access/state/preference-checked no-store display resolution; available=false without content when stale/inaccessible |
| GET /api/notifications | Preserves category/envelope/pagination; adds global unreadCount, preferences and structured routing/display data |
| POST /api/users/cuser/fcm-token | Existing route accepts optional notificationVersion=1/2; updated client uses 2; token ownership/reassignment unchanged |
| PATCH /api/outings/{outingId}/chat/read | Existing route now atomically clears that user's chat inbox rows for the conversation and emits cross-device read controls |
| Existing chat message POST/PATCH/DELETE | Preserved request/response/authorization/edit window; transactional notification creation and current-content/tombstone propagation |
| Existing group/outing/invitation/voting/attendance APIs | Same routes and business permissions; their successful mutations persist relevant inbox/outbox events transactionally |

Reply, Mark as Read and invitation actions reuse existing APIs. No duplicate notification-reply or invitation-action API was introduced. Swagger documents new request/response schemas, optional token capability and changed inbox/read behavior.

## Notification types and actions

| Events | Native behavior / destination |
|---|---|
| chat_message | Canonical sender — outing title, current preview, MessagingStyle, timestamps and conversation grouping/summary; Reply + Mark as Read; specific authorized message focus/highlight |
| chat_updated / chat_deleted | Silent update/dismiss of active message notification; PostgreSQL preview updates/tombstones; never regenerate deleted text |
| group_invite | Pending invitation only; Accept / Decline; body opens existing Settings → Invitations page/history |
| invitation_resolved / conversation_read | Silent dismissal of only the relevant invitation/message/conversation or explicit owned read-all set |
| group_created / membership_activated / member_joined / member_left | Group Details; membership confirmation only after acceptance (creator activation remains immediate) |
| outing_created / outing_updated / outing_cancelled / outing_confirmed / outing_invite | Authorized current outing details/invitation target |
| voting_started / voting_closed / winner_selected / tie_break_selected | Voting section with forced backend refresh; no per-vote notification spam |
| Candidate reset (outing_updated + voting-section hint) | Current voting section; reset persists with candidate transaction |
| voting_deadline_approaching | Idempotent reminder within one hour of actual deadline; closed/expired voting suppressed |
| outing_reminder / venue_reminder | Idempotent upcoming schedule and confirmed venue reminders |
| rsvp_opened / attendance_changed | Existing independent RSVP state, no implicit vote or physical arrival |
| arrival_reminder / arrival_changed | Confirmed pinned venue + valid attendance window; navigate to existing GPS verification; no notification presence action |

The product has no configured separate RSVP deadline, so no RSVP-deadline reminder field/rule was invented. Confirmed venues remain immutable; valid winner/tie-break/owner-confirmation transitions notify, and invalid postconfirmation venue changes remain rejected. Group update routing and legacy event aliases are preserved.

The existing Settings push switch now saves through the notification Provider/repository. Category, mentions, priority and lock-screen booleans are supported by the preference API/provider; this task does not add a separate category-preferences screen. Existing invitations already display pending/accepted/declined history and are reused.

## Reliability and account boundaries

Business transactions persist deterministic inbox IDs, event IDs and unique event keys; FCM runs only after commit. The existing worker recovers expired processing leases, counts bounded attempts, backs off and drains on shutdown. Multicast batches are capped at 500; existing delivery logs remember successful token-row IDs and retries exclude those devices. Definitive invalid/unregistered token responses remove only the still-owning token; generic invalid-argument does not erase registrations. Transport is at least once; stable native IDs/event deduplication handle the crash window between FCM success and delivery logging.

A centralized native-action dispatcher persists account-bound drafts before HTTP, derives stable reply UUIDs, checks the intended recipient before/after asynchronous work and uses existing Dio authentication/interceptors. Backend message/read/invitation ownership is authoritative. Reply success requires the canonical backend message acknowledgement. Failed network/auth actions retain drafts and explicit Retry; automatic resume/reconnect retries are bounded to five with backoff, terminal 4xx conflicts do not automatically repeat, and records have seven-day/100-record bounds. Completed records discard reply text. Explicit logout best-effort unregisters/deletes the token before signout; failures cannot block signout. Offline logout can leave a server registration pending later cleanup/reassignment; stale-account receipt/actions remain rejected.

Only FCM creates new system alerts. Socket.IO/API catch-up refreshes the existing inbox/provider and reconciles active native state without reposting dismissed notifications. Foreground active-chat alerts are suppressed. Resume always catches up unread state independently of auth sync, retries eligible actions after the shared one-time account synchronization, and preserves existing offline history. No per-notification users/sync call or additional socket subscription is introduced. Foreground/native display failures cannot break inbox state.

## Verification

Final results are in [ANDROID_PUSH_OPENAPI_RESULTS.json](ANDROID_PUSH_OPENAPI_RESULTS.json). All business scenarios invoke routes selected by operationId from the served Swagger/OpenAPI document and validate documented response schemas. The suite uses real PostgreSQL migrations and an automatically removed isolated schema. Fixture setup/time shifts use only that schema. Firebase identity and FCM transport are controlled boundaries, so these checks do not prove real token verification or physical push delivery. No unit/use-case execution substitutes for the HTTP operations. Background workers run normally and their results are observed through inbox/outing APIs; FCM payload/partial-retry observations are recorded at the controlled provider boundary.

- API coverage: persistent/deduplicated chat and replies, ownership/read counts and conversation isolation, invitation Accept/Decline/history/verified identity linking, group membership events, outing create/update/confirm/cancel, multiple-place voting/deadline/winner idempotency, reminder/GPS rules, token capability/reassignment/invalid cleanup, unauthorized requests and duplicate prevention.
- Static checks: Prisma validation/generation and backend TypeScript no-emit compilation; targeted Dart MCP analysis; Dart formatting; XML/resource parsing and git diff whitespace checks.
- No Flutter application tests, runtime launch/hot reload, emulator/physical-device tests, UI automation, iOS compilation or live push-provider send was run.

## Android manual verification still required

1. Fresh install and upgrade with foreground, background, process-terminated and authenticated cold-start delivery. A settings force-stop requires reopening per Firebase platform restrictions; OEM battery restrictions may delay execution.
2. Android 13+ permission allow/deny/regrant; all category channel names/importance, saved Arabic/English labels, group summaries, expanded MessagingStyle, launcher branding/icon tint and supported badge/count behavior.
3. Direct Reply without opening UI, canonical acknowledgement, duplicate callback/retry deduplication, expired authentication, no connectivity, preserved draft/Retry, process death and account-switch isolation. Verify no premature success/dismissal.
4. Mark as Read with two unread conversations and multiple devices; only selected conversation clears and badges reconcile on resume.
5. Pending group invitation Accept/Decline, conflict/repeated actions, Settings → Invitations body navigation and accepted/declined history; no membership notification before acceptance.
6. Mention priority preferences, exact-message focus/highlight (including older messages), active-chat suppression and edits/deletions while queued/visible. Check inaccessible/deleted resource feedback.
7. Hidden lock-screen content with preview disabled, unlocked action behavior, secure PendingIntent/native receiver behavior and background execution on supported Android versions.
8. Current backend voting state/deadline reminders and confirmed-venue arrival navigation; GPS must still prove actual attendance. Offline history and missed-notification recovery must remain account-scoped.

Platform references: [Firebase Flutter delivery and force-stop limits](https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages), [Android RemoteInput](https://developer.android.com/reference/android/app/RemoteInput), [Android grouping and summary requirements](https://developer.android.com/develop/ui/views/notifications/group).

## Documentation Updates

Updated product authority, notification architecture, API/auth contracts, database attributes, business/user workflows, Flutter/backend/system architecture, project map and ADR-022. System architecture and sequence diagrams are updated; ER relationships are unchanged (only attributes/enum values were added). Earlier foreground-only Android and ordinary-chat-only tap wording was superseded. Application-schema deployment and manual Android evidence remain explicitly outstanding; no unresolved intended-behavior conflict is claimed resolved by device testing.

## Changed files

### Backend, migration and HTTP verification

- `backend/prisma/schema.prisma`
- `backend/prisma/migrations/20261114030000_android_system_notifications/migration.sql`
- `backend/src/config/swagger.ts`
- `backend/src/controllers/groups/group.controller.ts`
- `backend/src/controllers/outings/outing.controller.ts`
- `backend/src/controllers/notifications/notification.controller.ts`
- `backend/src/datasources/chat/chat.datasource.ts`
- `backend/src/datasources/groups/group-invitation.datasource.ts`
- `backend/src/datasources/groups/group.datasource.ts`
- `backend/src/datasources/notifications/notification.datasource.ts`
- `backend/src/datasources/notifications/notification-event.datasource.ts`
- `backend/src/datasources/outings/outing.datasource.ts`
- `backend/src/jobs/notification-worker.job.ts`
- `backend/src/jobs/notification-reminders.job.ts`
- `backend/src/realtime/data-changes.ts`
- `backend/src/repositories/notifications/notification.repository.ts`
- `backend/src/routes/notifications/notification.inbox.routes.ts`
- `backend/src/routes/users/user.fcm.routes.ts`
- `backend/src/services/chat/chat-mentions.ts`
- `backend/src/services/notifications/channels/push.channel.ts`
- `backend/src/services/notifications/dispatch-notification.ts`
- `backend/src/services/notifications/notification-target.ts`
- `backend/src/services/notifications/outing-notifier.ts`
- `backend/src/services/notifications/persist-notification.ts`
- `backend/src/services/notifications/group-notifier.ts`
- `backend/src/services/notifications/outing-events.ts`
- `backend/src/services/notifications/notification-preferences.ts`
- `backend/src/services/notifications/resolve-push.ts`
- `backend/src/services/outings/vote-resolution.ts`
- `backend/src/types/users/user.types.ts`
- `backend/src/usecases/notifications/notification-state.usecase.ts`
- `backend/src/usecases/users/fcm-token.usecase.ts`
- `backend/src/usecases/chat/send-message.usecase.ts`
- `backend/src/usecases/chat/mutate-message.usecase.ts`
- `backend/src/usecases/chat/mark-chat-read.usecase.ts`
- `backend/src/usecases/outings/arrivals.usecase.ts`
- `backend/src/usecases/outings/attendance.usecase.ts`
- `backend/src/usecases/outings/create-outing.usecase.ts`
- `backend/src/usecases/outings/update-outing.usecase.ts`
- `backend/src/usecases/outings/guests.usecase.ts`
- `backend/src/usecases/outings/voting.usecase.ts`
- `backend/scripts/android-push-openapi-verification.ts`

### Flutter and Android

- `flutter/android/app/src/main/AndroidManifest.xml`
- `flutter/android/app/src/main/res/raw/keep.xml`
- `flutter/lib/core/di/app_dependencies.dart`
- `flutter/lib/core/network/app_sync_provider.dart`
- `flutter/lib/features/auth/data/datasources/firebase_auth_service.dart`
- `flutter/lib/features/chat/presentation/pages/outing_chat_page.dart`
- `flutter/lib/features/chat/presentation/providers/outing_chat_provider.dart`
- `flutter/lib/features/chat/presentation/widgets/message_bubble.dart`
- `flutter/lib/features/chat/presentation/widgets/outing_chat_message_list.dart`
- `flutter/lib/features/notifications/data/datasources/fcm_token_remote_datasource.dart`
- `flutter/lib/features/notifications/data/datasources/notifications_remote_datasource.dart`
- `flutter/lib/features/notifications/data/models/notification_model.dart`
- `flutter/lib/features/notifications/data/repositories/notifications_repository_impl.dart`
- `flutter/lib/features/notifications/data/repositories/push_messaging_repository_impl.dart`
- `flutter/lib/features/notifications/data/services/fcm_background_handler.dart`
- `flutter/lib/features/notifications/data/services/fcm_messaging_service.dart`
- `flutter/lib/features/notifications/data/services/interactive_notification_handler.dart`
- `flutter/lib/features/notifications/data/services/local_notifications_service.dart`
- `flutter/lib/features/notifications/data/services/notification_action_dispatcher.dart`
- `flutter/lib/features/notifications/data/services/notification_background_runtime.dart`
- `flutter/lib/features/notifications/domain/entities/notification_item.dart`
- `flutter/lib/features/notifications/domain/entities/push_notification_payload.dart`
- `flutter/lib/features/notifications/domain/repositories/notification_preferences_repository.dart`
- `flutter/lib/features/notifications/presentation/navigation/push_notification_navigator.dart`
- `flutter/lib/features/notifications/presentation/providers/fcm_provider.dart`
- `flutter/lib/features/notifications/presentation/providers/notifications_provider.dart`
- `flutter/lib/features/setting/presentation/widgets/settings_preferences_section.dart`

### Canonical documentation

- `docs/PRODUCT_SCENARIOS.md`
- `docs/NOTIFICATIONS.md`
- `docs/API_CONTRACTS.md`
- `docs/DATABASE_ARCHITECTURE.md`
- `docs/BUSINESS_LOGIC.md`
- `docs/USER_SCENARIOS.md`
- `docs/AUTHENTICATION_AND_AUTHORIZATION.md`
- `docs/FLUTTER_ARCHITECTURE.md`
- `docs/BACKEND_ARCHITECTURE.md`
- `docs/SYSTEM_DESIGN.md`
- `docs/SYSTEM_ARCHITECTURE.md`
- `docs/PROJECT_STRUCTURE.md`
- `docs/ARCHITECTURE_DECISIONS.md`

### Task evidence

- `docs/audit/ANDROID_SYSTEM_PUSH.md`
- `docs/audit/ANDROID_PUSH_OPENAPI_RESULTS.json`
