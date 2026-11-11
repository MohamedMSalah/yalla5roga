# Group and outing feature audit

The [automatic GPS attendance follow-up](AUTOMATIC_GPS_ATTENDANCE.md) supersedes the earlier arrival workflow in this report.

## Original findings

- The checked-out Prisma schema and create service already supported many outings per group. Group Details iterated over all cached outings. However, a lookup for an unloaded outing could return the first cached outing, and concurrent detail requests merged against snapshots captured before their requests completed.
- RSVP rows already used the outing and user composite key. Flutter waited for an unrelated details refresh after each write, omitted attendance from several detail states, and treated equal-sized snapshots as unchanged even when selections had changed.
- Place voting persisted rows and ordered options. Flutter discarded the viewer’s selected option and used separate options and votes calls. The creator had a server-managed tie-break but no direct proposed-venue choice.
- Physical arrival accepted draft venues and omitted RSVP eligibility, capture time, verification method and an organizer fallback. Published fixed-venue plans from Flutter were sent as drafts.
- Chat messages had sender IDs but the REST and Socket.IO payloads lacked a profile name. The outgoing bubble hid the name. History was unbounded and a failed REST send could appear successful from the local cache.
- Group invitations already had persistent pending membership, verified-phone claim, and an outbox. Flutter still opened a WhatsApp prompt and a click-to-chat fallback. The disabled provider could report a simulated send.

## Changes by layer

| Layer | Files and behavior |
| --- | --- |
| Prisma | `backend/prisma/schema.prisma` and migrations `20261110150000_arrival_verification`, `20261110150100_owner_confirmed_venue`. Extend existing arrival records and the vote close reason enum. Preserve all IDs, keys and records. |
| API | `backend/src/controllers/{outings,chat}`, `routes/outings`, `routes/groups/group.invitations.routes.ts`, `validators/{outings,chat}`, and `config/swagger.ts`. Added creator venue confirmation and organizer check-in. Extended RSVP summaries, voting-state and paginated chat responses. |
| Outing services | `backend/src/usecases/outings/{attendance,arrivals,voting}.usecase.ts`, `datasources/outings/outing.datasource.ts`, and `services/outings/{arrival-policy,outing-participants,vote-resolution}.ts`. Keep all mutations outing-scoped, use an idempotent RSVP upsert, and use the shared venue resolution lock. `config/database.ts` bounds the wait and transaction duration for remote row locks. |
| Chat services | `backend/src/datasources/chat/chat.datasource.ts`, `repositories/chat`, `types/chat/chat.types.ts`, `usecases/chat/{list-messages,send-message}.usecase.ts`, and `realtime/chat-emitter.ts`. Project sender names with the message data. Reuse the chat index and client-message deduplication key. |
| Group invitations | `backend/src/usecases/groups/invite-to-group.usecase.ts`, `config/notifications.ts`, and the WhatsApp channel and dispatcher in `services/notifications`. Keep existing phone normalization, pending membership and automatic claims. Separate provider acceptance from membership. Retry temporary failures with bounded backoff. |
| Flutter outings | `outings_remote_datasource.dart`, `outings_repository_impl.dart`, `outings_repository.dart`, `outings_provider.dart`, `create_outing_provider.dart`, `place_vote.dart`, `event_page.dart` and `outing_vote_widget.dart`. Restore selection, tally all three RSVP responses, and publish pinned venues as confirmed. |
| Flutter arrivals | `outing_arrivals_remote_datasource.dart`, `outing_arrival.dart`, `outing_arrival_service.dart` and `outing_arrivals_section.dart`. Bind consent to account, outing, venue and schedule. Display the roster, verification method and manual options. |
| Flutter chat | `chat_message.dart`, `chat_message_model.dart`, `outing_chat_message_merge.dart`, `outing_chat_remote_datasource.dart`, both chat repositories, `outing_chat_provider.dart`, `outing_chat_page.dart` and `outing_chat_message_list.dart`. Render the name on both bubble types, page older messages, and preserve ID-based Socket.IO deduplication. |
| Flutter groups | `create_group_page.dart`, `groups_provider.dart`, `group_invite_result.dart`, `add_member_phone_sheet.dart` and `pick_device_contacts_page.dart`. Remove the WhatsApp modal and launcher. Collect recipient consent inline and support Egyptian and international contact numbers. Shared labels, input components and route constants remain in `flutter/lib/core`. |

## Operational details

The scheduled check-in window defaults to 360 minutes and ends earlier if the outing has an earlier end time. The default radius is 100 m and the maximum reported horizontal accuracy is 50 m. Configure these with `OUTING_ARRIVAL_WINDOW_MINUTES`, `OUTING_ARRIVAL_RADIUS_METERS`, and `OUTING_ARRIVAL_MAX_ACCURACY_METERS`. The server checks both sample freshness and the sum of distance and reported uncertainty. It stores the first check-in and GPS-derived metrics. Exact user coordinates are discarded. Client GPS is advisory evidence. The current mobile path uses foreground location, and denied or unavailable GPS can be handled by the organizer’s in-person confirmation. The existing creator Goes by default rule and automatic unique-winner resolution remain in force. A confirmed venue is locked under the approved lifecycle.

Set `WHATSAPP_PROVIDER=meta`, `WHATSAPP_ACCESS_TOKEN`, `WHATSAPP_PHONE_NUMBER_ID`, `WHATSAPP_API_VERSION`, `WHATSAPP_INVITE_TEMPLATE`, `WHATSAPP_INVITE_TEMPLATE_LANG`, and the public `APP_DOWNLOAD_URL` or `INVITE_DEEP_LINK_BASE`. The approved group template takes the inviter name, group name, and invite link in that order. The outbox stores one event per pending invitation ID. A Meta message ID proves provider acceptance. Recipient delivery would require a delivery receipt. A transport failure after acceptance can leave the send outcome ambiguous.

## Documentation updates

The product, user journey, business rules, API, database, backend, Flutter, system architecture and system design documents reflect these paths. The product lifecycle and system-design arrival diagrams were updated. The project structure guide identifies the targeted integration harness, and the Cursor Flutter and backend context files reflect outing isolation, location consent and server-side invitation delivery.
