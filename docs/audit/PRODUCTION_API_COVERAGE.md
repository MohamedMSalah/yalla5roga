# Production API route coverage

Express registrations were enumerated with the repository consumer audit. The 114 documented operations below were reached over isolated loopback HTTP using the served OpenAPI document. Each PASS refers to the status, envelope, request ID, Server-Timing and documented response schema exercised in the boundary suite. The development mock storage operations are excluded by the production router.

Protected endpoints were exercised without a bearer token in this sweep. Database cases use a disposable PostgreSQL database. Authenticated success, ownership, edge cases and concurrency have separate focused tests, with remaining coverage listed in the readiness report.

| Method | Express route | Flutter consumer evidence | Executed boundary | Status |
| --- | --- | --- | --- | --- |
| POST | `/api/auth/change-password` | features/auth/data/datasources/auth_remote_datasource.dart:187 | 401 | PASS |
| POST | `/api/auth/login` | features/auth/data/datasources/auth_remote_datasource.dart (shared _postSession) | 400 | PASS |
| POST | `/api/auth/recovery/reset` | features/auth/data/repositories/auth_repository_impl.dart → auth_remote_datasource.dart (recovery) | 400 | PASS |
| POST | `/api/auth/recovery/start` | features/auth/data/repositories/auth_repository_impl.dart → auth_remote_datasource.dart (recovery) | 400 | PASS |
| POST | `/api/auth/recovery/verify` | features/auth/data/repositories/auth_repository_impl.dart → auth_remote_datasource.dart (recovery) | 400 | PASS |
| POST | `/api/auth/signup` | features/auth/data/datasources/auth_remote_datasource.dart (shared _postSession) | 400 | PASS |
| POST | `/api/auth/verify-password` | features/auth/data/datasources/auth_remote_datasource.dart:172 | 401 | PASS |
| GET | `/api/groups` | No static Flutter consumer located | 401 | PASS |
| POST | `/api/groups` | features/groups/data/datasources/groups_remote_datasource.dart:138 | 401 | PASS |
| DELETE | `/api/groups/:id` | features/groups/data/datasources/groups_remote_datasource.dart (delete with detail path) | 401 | PASS |
| GET | `/api/groups/:id` | features/groups/data/datasources/groups_remote_datasource.dart:119 | 401 | PASS |
| PATCH | `/api/groups/:id` | features/groups/data/datasources/groups_remote_datasource.dart:169 | 401 | PASS |
| POST | `/api/groups/:id/invitations` | features/groups/data/datasources/groups_remote_datasource.dart:242 | 401 | PASS |
| GET | `/api/groups/:id/members` | features/groups/data/datasources/groups_remote_datasource.dart:286 | 401 | PASS |
| POST | `/api/groups/:id/members` | features/groups/data/datasources/groups_remote_datasource.dart:191 | 401 | PASS |
| DELETE | `/api/groups/:id/members/:userId` | features/groups/data/datasources/groups_remote_datasource.dart (removeMember, leaveGroup) | 401 | PASS |
| DELETE | `/api/groups/:id/pending-memberships/:invitationId` | features/groups/data/datasources/groups_remote_datasource.dart (remove pending member) | 401 | PASS |
| GET | `/api/groups/cuser` | features/groups/data/datasources/groups_remote_datasource.dart:80 | 401 | PASS |
| GET | `/api/invitations` | features/invitations/data/datasources/invitations_remote_datasource.dart:23 | 401 | PASS |
| POST | `/api/invitations/:invitationId/accept` | features/invitations/data/datasources/invitations_remote_datasource.dart:39 | 401 | PASS |
| POST | `/api/invitations/:invitationId/decline` | features/invitations/data/datasources/invitations_remote_datasource.dart:57 | 401 | PASS |
| DELETE | `/api/media/:id` | core/media/media_upload_service.dart:192 | 401 | PASS |
| POST | `/api/media/:id/confirm` | core/media/media_upload_service.dart:184 | 401 | PASS |
| GET | `/api/media/:id/url` | No static Flutter consumer located | 401 | PASS |
| POST | `/api/media/signed-urls` | core/media/media_url_resolver.dart:182 | 401 | PASS |
| POST | `/api/media/upload-url` | core/media/media_upload_service.dart:164 | 401 | PASS |
| GET | `/api/notifications` | features/notifications/data/datasources/notifications_remote_datasource.dart:38 | 401 | PASS |
| PATCH | `/api/notifications/:id/read` | features/notifications/data/datasources/notifications_remote_datasource.dart:97 | 401 | PASS |
| GET | `/api/notifications/:id/system-payload` | features/notifications/data/services/local_notifications_service.dart:297 | 401 | PASS |
| GET | `/api/notifications/preferences` | No static Flutter consumer located | 401 | PASS |
| PATCH | `/api/notifications/preferences` | features/notifications/data/datasources/notifications_remote_datasource.dart:74 | 401 | PASS |
| PATCH | `/api/notifications/read` | features/notifications/data/datasources/notifications_remote_datasource.dart:84 | 401 | PASS |
| GET | `/api/outings` | No static Flutter consumer located | 401 | PASS |
| POST | `/api/outings` | features/outings/data/datasources/outings_remote_datasource.dart:539 | 401 | PASS |
| DELETE | `/api/outings/:id` | features/outings/data/datasources/outings_remote_datasource.dart:192 | 401 | PASS |
| GET | `/api/outings/:id` | features/outings/data/datasources/outings_remote_datasource.dart:310 | 401 | PASS |
| PATCH | `/api/outings/:id` | features/outings/data/datasources/outings_remote_datasource.dart:404 | 401 | PASS |
| GET | `/api/outings/:id/arrivals` | features/outings/data/datasources/outing_arrivals_remote_datasource.dart:13 | 401 | PASS |
| PUT | `/api/outings/:id/arrivals/self` | features/outings/data/datasources/outing_arrivals_remote_datasource.dart:56 | 401 | PASS |
| GET | `/api/outings/:id/attendance` | features/outings/data/datasources/outings_remote_datasource.dart:984 | 401 | PASS |
| PUT | `/api/outings/:id/attendance` | features/outings/data/datasources/outings_remote_datasource.dart:765 | 401 | PASS |
| POST | `/api/outings/:id/cancel` | features/outings/data/datasources/outings_remote_datasource.dart:413 | 401 | PASS |
| PUT | `/api/outings/:id/confirmed-venue` | features/outings/data/datasources/outings_remote_datasource.dart:665 | 401 | PASS |
| GET | `/api/outings/:id/guests` | features/outings/data/datasources/outings_remote_datasource.dart:447 | 401 | PASS |
| POST | `/api/outings/:id/guests` | features/outings/data/datasources/outings_remote_datasource.dart:551 | 401 | PASS |
| DELETE | `/api/outings/:id/guests/:userId` | features/outings/data/datasources/outings_remote_datasource.dart:419 | 401 | PASS |
| POST | `/api/outings/:id/invitations/accept` | features/outings/data/datasources/outings_remote_datasource.dart and the interactive notification handler | 401 | PASS |
| POST | `/api/outings/:id/invitations/decline` | features/outings/data/datasources/outings_remote_datasource.dart and the interactive notification handler | 401 | PASS |
| DELETE | `/api/outings/:id/save` | features/outings/data/datasources/saved_outings_remote_datasource.dart:123 | 401 | PASS |
| POST | `/api/outings/:id/save` | features/outings/data/datasources/saved_outings_remote_datasource.dart:119 | 401 | PASS |
| POST | `/api/outings/:id/tie-break` | features/outings/data/datasources/outings_remote_datasource.dart:685 | 401 | PASS |
| GET | `/api/outings/:id/vote-options` | features/outings/data/datasources/outings_remote_datasource.dart:844 | 401 | PASS |
| POST | `/api/outings/:id/vote-options` | No Flutter write call located. Creation embeds initial options in POST /api/outings. | 401 | PASS |
| PUT | `/api/outings/:id/vote-options` | No Flutter write call located. Revote writes through POST /api/outings/:id/voting/revote. | 401 | PASS |
| DELETE | `/api/outings/:id/vote-options/:optionId` | No static Flutter consumer located | 401 | PASS |
| DELETE | `/api/outings/:id/votes` | No static Flutter consumer located | 401 | PASS |
| GET | `/api/outings/:id/votes` | No static Flutter consumer located | 401 | PASS |
| POST | `/api/outings/:id/votes` | features/outings/data/datasources/outings_remote_datasource.dart:648 | 401 | PASS |
| PUT | `/api/outings/:id/votes` | features/outings/data/datasources/outings_remote_datasource.dart:623 | 401 | PASS |
| DELETE | `/api/outings/:id/votes/:optionId` | features/outings/data/datasources/outings_remote_datasource.dart:737 | 401 | PASS |
| GET | `/api/outings/:id/voting-state` | features/outings/data/datasources/outings_remote_datasource.dart:897 | 401 | PASS |
| POST | `/api/outings/:id/voting/revote` | features/outings/data/datasources/outings_remote_datasource.dart:716 | 401 | PASS |
| GET | `/api/outings/:outingId/messages` | features/chat/data/datasources/outing_chat_remote_datasource.dart:41 | 401 | PASS |
| POST | `/api/outings/:outingId/messages` | features/chat/data/datasources/outing_chat_remote_datasource.dart:72<br>features/notifications/data/services/interactive_notification_handler.dart:109 | 401 | PASS |
| DELETE | `/api/outings/:outingId/messages/:messageId` | features/chat/data/datasources/outing_chat_remote_datasource.dart (deleteMessage) | 401 | PASS |
| PATCH | `/api/outings/:outingId/messages/:messageId` | features/chat/data/datasources/outing_chat_remote_datasource.dart (editMessage) | 401 | PASS |
| PATCH | `/api/outings/:outingId/read` | features/chat/data/datasources/outing_chat_remote_datasource.dart:102<br>features/notifications/data/services/interactive_notification_handler.dart:135 | 401 | PASS |
| GET | `/api/outings/cuser` | features/outings/data/datasources/outings_remote_datasource.dart:208 | 401 | PASS |
| GET | `/api/outings/drafts` | features/outings/data/datasources/saved_outings_remote_datasource.dart:18 | 401 | PASS |
| POST | `/api/outings/drafts` | features/outings/data/datasources/saved_outings_remote_datasource.dart:24 | 401 | PASS |
| DELETE | `/api/outings/drafts/:id` | features/outings/data/datasources/saved_outings_remote_datasource.dart:42 | 401 | PASS |
| PATCH | `/api/outings/drafts/:id` | features/outings/data/datasources/saved_outings_remote_datasource.dart:33 | 401 | PASS |
| GET | `/api/outings/saved` | features/outings/data/datasources/saved_outings_remote_datasource.dart:104 | 401 | PASS |
| GET | `/api/place-brands/:id` | No static Flutter consumer located | 400 | PASS |
| GET | `/api/place-brands/:id/branches` | No static Flutter consumer located | 400 | PASS |
| GET | `/api/places` | features/discover/data/datasources/discover_remote_datasource.dart:106<br>features/discover/data/datasources/discover_remote_datasource.dart:128<br>features/discover/data/datasources/discover_remote_datasource.dart:226<br>features/discover/data/datasources/discover_remote_datasource.dart:243 | 200 | PASS |
| POST | `/api/places` | No Flutter write call located. Device-local places use SQLite. | 401 | PASS |
| DELETE | `/api/places/:id` | No static Flutter consumer located | 401 | PASS |
| GET | `/api/places/:id` | features/discover/data/datasources/discover_remote_datasource.dart:187<br>features/discover/data/datasources/discover_remote_datasource.dart:256 | 404 | PASS |
| PATCH | `/api/places/:id` | No static Flutter consumer located | 401 | PASS |
| GET | `/api/places/:id/hours` | No static Flutter consumer located | 400 | PASS |
| PUT | `/api/places/:id/hours` | No static Flutter consumer located | 401 | PASS |
| DELETE | `/api/places/:id/hours/:hourId` | No static Flutter consumer located | 401 | PASS |
| GET | `/api/places/:id/images` | No static Flutter consumer located | 400 | PASS |
| POST | `/api/places/:id/images` | No static Flutter consumer located | 401 | PASS |
| DELETE | `/api/places/:id/images/:imageId` | No static Flutter consumer located | 401 | PASS |
| GET | `/api/places/:id/prices` | No static Flutter consumer located | 400 | PASS |
| POST | `/api/places/:id/prices` | No static Flutter consumer located | 401 | PASS |
| DELETE | `/api/places/:id/prices/:priceId` | No static Flutter consumer located | 401 | PASS |
| DELETE | `/api/places/:id/save` | features/discover/data/datasources/saved_places_remote_datasource.dart:38 | 401 | PASS |
| POST | `/api/places/:id/save` | features/discover/data/datasources/saved_places_remote_datasource.dart:34 | 401 | PASS |
| GET | `/api/places/categories` | features/discover/data/datasources/discover_remote_datasource.dart:92 | 200 | PASS |
| GET | `/api/places/changes` | features/discover/data/datasources/discover_remote_datasource.dart:83 | 400 | PASS |
| POST | `/api/places/geocoding` | features/outings/data/repositories/geocoding_http_repository.dart:45 | 401 | PASS |
| GET | `/api/places/geojson` | No static Flutter consumer located | 400 | PASS |
| GET | `/api/places/licenses` | No static Flutter consumer located | 200 | PASS |
| GET | `/api/places/nearby` | features/discover/data/datasources/discover_remote_datasource.dart:205 | 400 | PASS |
| GET | `/api/places/recommendations` | features/discover/data/datasources/discover_remote_datasource.dart:34 | 400 | PASS |
| GET | `/api/places/saved` | features/discover/data/datasources/saved_places_remote_datasource.dart:20 | 401 | PASS |
| POST | `/api/places/sync` | No static Flutter consumer located | 401 | PASS |
| GET | `/api/places/sync/history` | No static Flutter consumer located | 401 | PASS |
| GET | `/api/places/sync/status` | No static Flutter consumer located | 401 | PASS |
| GET | `/api/places/version` | features/discover/data/datasources/discover_remote_datasource.dart:47 | 200 | PASS |
| GET | `/api/places/vibes` | features/discover/data/datasources/discover_remote_datasource.dart:92 | 200 | PASS |
| GET | `/api/users` | No static Flutter consumer located | 401 | PASS |
| DELETE | `/api/users/:id` | No static Flutter consumer located | 401 | PASS |
| GET | `/api/users/:id` | No static Flutter consumer located | 401 | PASS |
| DELETE | `/api/users/cuser` | features/auth/data/datasources/auth_remote_datasource.dart:68 | 401 | PASS |
| GET | `/api/users/cuser` | features/auth/data/datasources/auth_remote_datasource.dart:160 | 401 | PASS |
| PATCH | `/api/users/cuser` | features/auth/data/datasources/auth_remote_datasource.dart:147 | 401 | PASS |
| DELETE | `/api/users/cuser/fcm-token` | No static Flutter consumer located | 401 | PASS |
| POST | `/api/users/cuser/fcm-token` | features/notifications/data/datasources/fcm_token_remote_datasource.dart:15 | 401 | PASS |
| DELETE | `/api/users/cuser/fcm-token/:token` | features/notifications/data/datasources/fcm_token_remote_datasource.dart:32 | 401 | PASS |
| POST | `/api/users/sync` | features/auth/data/datasources/auth_remote_datasource.dart (shared _postUser) | 401 | PASS |

The API boundary sweep covers 114 operations. Infrastructure probes, metrics, telemetry and Socket.IO have separate assertions in the backend suite.

## Additional status assertions

The isolated k6 fixture also asserted successful responses on these routes. Sample counts come from the one-VU run. Fixture authentication substitutes Firebase verification. This workload checks statuses, with schema and negative-case tests recorded separately.

| Method and route | Status | Samples |
| --- | ---: | ---: |
| GET `/api/groups/cuser` | 200 | 9 |
| GET `/api/groups/:id` | 200 | 9 |
| GET `/api/groups/:id/members` | 200 | 9 |
| GET `/api/outings/cuser` | 200 | 9 |
| GET `/api/outings/:id` | 200 | 9 |
| GET `/api/outings/:id/voting-state` | 200 | 9 |
| GET `/api/places` | 200 | 9 |
| GET `/api/places/recommendations` | 200 | 9 |
| GET `/api/places/geojson` | 200 | 9 |
| GET `/api/notifications` | 200 | 9 |
| GET `/api/outings/:outingId/messages` | 200 | 8 |
| POST `/api/outings/:outingId/messages` | 201 | 8 |
