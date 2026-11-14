# Phase 5 — Outing chat and notifications

Implemented 2026-11-14. Existing Phase 4 and other concurrent working-tree edits were retained. No deployment or application-data migration was performed.

## Delivered

- Outing-only incoming/outgoing theme-aware bubbles with canonical sender names/avatars, localized times, same-day/five-minute grouping and date separators. Own messages expose Edit/Delete on long press; editing is limited to the first minute after sending, and delete remains available while chat is open; deleted messages use a localized tombstone. Delayed canonical echoes cannot restore a tombstone.
- Text-only multiline composer, existing stable-ID @member/all suggestions, localized send/cancel-edit controls. APIs and socket listeners remain outside widgets.
- Existing room-acknowledged Connected/Reconnecting state plus Offline; existing durable pending/failed queue, explicit Retry with the same client UUID, REST/socket deduplication, history paging and authenticated reconnect. New-message fade/near-bottom scrolling uses AppMotion and honors reduced motion; reading older messages does not auto-scroll to an incoming message.
- Read-only composer/explanation and no edit/delete/retry controls after scheduled start + two hours, or when past/cancelled. The backend guard enforces the same policy for sends, native replies and mutations. The existing six-hour outing-completion default is unchanged; chat closes independently.
- All/Unread inbox chips/count, shared notification cards with event-category titles, descriptions, avatars/icons, localized relative timestamps, read/unread surfaces/dots and loading/empty/error/retry states. Existing notification event aliases remain supported; no producers were invented.
- Authorized destinations: group/membership → Group Details; group invitation → Invitations; outing invitation → Invitations with the specific refreshed outing entry → existing EventPage decision controls; outing/update/GPS → Outing Details; message → regular outing-specific chat; voting/RSVP → relevant detail section. Back uses existing GetX route stack.
- Android local RemoteInput Reply and Mark as read; iOS text-input/read categories plus APNs category and native response/cold-start bridge. Actions open the app and use the current Firebase session, validate recipient identity, pin chat request user identity, reuse the outbox UUID for reply deduplication and mark the inbox item read only after success. HTTP 404 is a failure.

## Architecture and storage

`core/widgets/notification_card.dart` and `connection_indicator.dart` are shared callback-driven presentation. Chat's `MessageBubble`, `MessageComposer`, `MentionSuggestions` and `ChatDateSeparator` remain feature-local; legacy composer/picker/card names are compatibility aliases/exports. OutingInvitationTarget composes the shared card and existing outing destination.

PATCH/DELETE message routes are additive. MutateMessageUseCase → existing ChatRepository/ChatDatasource checks participation, sender ownership and open state; edit canonicalizes mentions without new notification fan-out. Empty text is the deletion tombstone in the existing column. IDs, client-ID uniqueness, timestamps, read cursors and room/event payloads remain compatible; no schema migration. Post-write fan-out uses the existing current-participant-filtered outing:message emitter. Bounded forced recovery replaces canonical messages/tombstones from up to three 40-row pages, retains queue/live updates and exposes older cursor history.

## Verification

- `dart format`: completed for chat, notifications, changed invitation entry/page, shared components, localization and outing chat policy.
- `flutter analyze --no-pub`: no errors; 5 existing warnings (four auth warnings and one Settings unused-import warning) and 12 pre-existing style infos remain. Full-project analysis is not clean; this report does not claim otherwise.
- Backend `tsc --noEmit`: passed.
- `backend/scripts/phase5-openapi-verification.ts`: **55 checks passed** through served Swagger/OpenAPI operation IDs and HTTP, including missing/invalid auth, nonparticipant/other-sender/wrong-outing refusal, text bounds, canonical mentions, edit/history, tombstone deletion/retry safety, past/cancelled history and mutation refusal, two-hour closure/119-minute open state, and cursor pagination. Request authentication used a controlled Firebase verifier; this does not prove live Firebase authentication. A disposable PostgreSQL schema was created with the normal migration chain and removed in finally; no delivery workers started. Results: PHASE_5_OPENAPI_RESULTS.json.
- No Flutter, device, emulator, widget, integration or UI tests ran. No app launch/hot reload, visual screenshots, native build, Socket.IO runtime probe or physical FCM delivery test ran. Existing realtime wiring was inspected statically, not newly certified end to end.

## Platform limits

Android OS-rendered **background/terminated FCM notifications do not gain Reply/Mark as read buttons**: the existing visible FCM payload/delivery remains, and Dart local-notification actions apply to locally displayed foreground notifications. Implementing background Android actions requires additional native message rendering/handling; data-only replacement was intentionally avoided to preserve delivery behavior. iOS category and remote-action bridge are implemented but cannot be compiled or device-verified on this Windows host. Native actions require foreground/current-session authentication; silent background API execution is not promised. iOS action-label categories register with the saved locale at initialization. Legacy pushes without a stable outbox UUID cannot execute a deduplicated reply and report failure. Other desktop/web native-action capabilities are not claimed.

Phone/wide/foldable, English/Arabic RTL, light/dark, keyboard, screen-reader and large-text rendering were addressed in code using existing Responsive/L10n/Material components, but remain visually unverified under the no-launch constraint.

## Documentation Updates

Updated PRODUCT_SCENARIOS, BUSINESS_LOGIC, USER_SCENARIOS and SYSTEM_DESIGN for approved closure/mutation/navigation behavior; API_CONTRACTS and BACKEND_ARCHITECTURE for additive message operations; AUTHENTICATION_AND_AUTHORIZATION for own-message/native-action checks; DATABASE_ARCHITECTURE for tombstones/no migration; FLUTTER_ARCHITECTURE and PROJECT_STRUCTURE for extracted widgets/recovery; NOTIFICATIONS for routing/actions/platform limitations; DESIGN.md for the preserved visual foundation. Existing architecture diagrams remain valid and were not changed. Remaining limitations are platform/runtime verification and notification aliases with no existing producer, as described above.


## Owner reference refinement — 2026-11-14

Matched the attached reference structure using the existing palette/tokens: chat title/outing subtitle, compact end-aligned connection badge, Today/Yesterday date pills, names above bubbles, outer-edge avatars and rounded composer dock. Send replaces recording; attachments are absent. The @ control inserts a mention trigger at the cursor and uses existing suggestions. Long press opens the shared action sheet for own persisted messages; Edit is disabled after one minute, and the active edit composer cancels at that boundary with localized feedback. Client selection and submission recheck time, while backend use case and atomic write predicate enforce now < sent_at + 60 seconds. Delete is not limited to the first minute. No realtime, FCM, auth transport, Provider or schema pattern changes.

Extended the existing OpenAPI-only verification with inside-window edit, 60-second refusal, unchanged content after refusal and deletion beyond the edit window: all 55 checks passed and the disposable schema was removed. No UI/device/emulator tests or app launch were performed. Reference matching is based on source implementation and the supplied screenshot; rendered theme/RTL/keyboard checks remain unverified.
