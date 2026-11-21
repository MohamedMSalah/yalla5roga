# API route and Flutter consumer inventory

The Express router registers 116 API operations in this configuration. Swagger documents 114. Development mock-storage helpers are intentionally absent from Swagger.

Regenerate with `pnpm audit:routes` from `backend`. Direct matches show the library-relative Flutter file and line. Indirect path references require call-site review. A missing Flutter match leaves the operation available to Swagger, administrative tools, external clients and older releases.

| Method | API route | Flutter consumer evidence |
| --- | --- | --- |
| POST | `/api/auth/change-password` | features/auth/data/datasources/auth_remote_datasource.dart:187 |
| POST | `/api/auth/login` | features/auth/data/datasources/auth_remote_datasource.dart (shared _postSession) |
| POST | `/api/auth/recovery/reset` | features/auth/data/repositories/auth_repository_impl.dart → auth_remote_datasource.dart (recovery) |
| POST | `/api/auth/recovery/start` | features/auth/data/repositories/auth_repository_impl.dart → auth_remote_datasource.dart (recovery) |
| POST | `/api/auth/recovery/verify` | features/auth/data/repositories/auth_repository_impl.dart → auth_remote_datasource.dart (recovery) |
| POST | `/api/auth/signup` | features/auth/data/datasources/auth_remote_datasource.dart (shared _postSession) |
| POST | `/api/auth/verify-password` | features/auth/data/datasources/auth_remote_datasource.dart:172 |
| GET | `/api/groups` | No static Flutter consumer located |
| POST | `/api/groups` | features/groups/data/datasources/groups_remote_datasource.dart:138 |
| DELETE | `/api/groups/:id` | features/groups/data/datasources/groups_remote_datasource.dart (delete with detail path) |
| GET | `/api/groups/:id` | features/groups/data/datasources/groups_remote_datasource.dart:119 |
| PATCH | `/api/groups/:id` | features/groups/data/datasources/groups_remote_datasource.dart:169 |
| POST | `/api/groups/:id/invitations` | features/groups/data/datasources/groups_remote_datasource.dart:242 |
| GET | `/api/groups/:id/members` | features/groups/data/datasources/groups_remote_datasource.dart:286 |
| POST | `/api/groups/:id/members` | features/groups/data/datasources/groups_remote_datasource.dart:191 |
| DELETE | `/api/groups/:id/members/:userId` | features/groups/data/datasources/groups_remote_datasource.dart (removeMember, leaveGroup) |
| DELETE | `/api/groups/:id/pending-memberships/:invitationId` | features/groups/data/datasources/groups_remote_datasource.dart (remove pending member) |
| GET | `/api/groups/cuser` | features/groups/data/datasources/groups_remote_datasource.dart:80 |
| GET | `/api/invitations` | features/invitations/data/datasources/invitations_remote_datasource.dart:23 |
| POST | `/api/invitations/:invitationId/accept` | features/invitations/data/datasources/invitations_remote_datasource.dart:39 |
| POST | `/api/invitations/:invitationId/decline` | features/invitations/data/datasources/invitations_remote_datasource.dart:57 |
| DELETE | `/api/media/:id` | core/media/media_upload_service.dart:192 |
| POST | `/api/media/:id/confirm` | core/media/media_upload_service.dart:184 |
| GET | `/api/media/:id/url` | No static Flutter consumer located |
| GET | `/api/media/mock-download/:key` | Development storage adapter via returned URL |
| PUT | `/api/media/mock-upload/:key` | Development storage adapter via returned URL |
| POST | `/api/media/signed-urls` | core/media/media_url_resolver.dart:182 |
| POST | `/api/media/upload-url` | core/media/media_upload_service.dart:164 |
| GET | `/api/notifications` | features/notifications/data/datasources/notifications_remote_datasource.dart:38 |
| PATCH | `/api/notifications/:id/read` | features/notifications/data/datasources/notifications_remote_datasource.dart:97 |
| GET | `/api/notifications/:id/system-payload` | features/notifications/data/services/local_notifications_service.dart:297 |
| GET | `/api/notifications/preferences` | No static Flutter consumer located |
| PATCH | `/api/notifications/preferences` | features/notifications/data/datasources/notifications_remote_datasource.dart:74 |
| PATCH | `/api/notifications/read` | features/notifications/data/datasources/notifications_remote_datasource.dart:84 |
| GET | `/api/outings` | No static Flutter consumer located |
| POST | `/api/outings` | features/outings/data/datasources/outings_remote_datasource.dart:539 |
| DELETE | `/api/outings/:id` | features/outings/data/datasources/outings_remote_datasource.dart:192 |
| GET | `/api/outings/:id` | features/outings/data/datasources/outings_remote_datasource.dart:310 |
| PATCH | `/api/outings/:id` | features/outings/data/datasources/outings_remote_datasource.dart:404 |
| GET | `/api/outings/:id/arrivals` | features/outings/data/datasources/outing_arrivals_remote_datasource.dart:13 |
| PUT | `/api/outings/:id/arrivals/self` | features/outings/data/datasources/outing_arrivals_remote_datasource.dart:56 |
| GET | `/api/outings/:id/attendance` | features/outings/data/datasources/outings_remote_datasource.dart:984 |
| PUT | `/api/outings/:id/attendance` | features/outings/data/datasources/outings_remote_datasource.dart:765 |
| POST | `/api/outings/:id/cancel` | features/outings/data/datasources/outings_remote_datasource.dart:413 |
| PUT | `/api/outings/:id/confirmed-venue` | features/outings/data/datasources/outings_remote_datasource.dart:665 |
| GET | `/api/outings/:id/guests` | features/outings/data/datasources/outings_remote_datasource.dart:447 |
| POST | `/api/outings/:id/guests` | features/outings/data/datasources/outings_remote_datasource.dart:551 |
| DELETE | `/api/outings/:id/guests/:userId` | features/outings/data/datasources/outings_remote_datasource.dart:419 |
| POST | `/api/outings/:id/invitations/accept` | features/outings/data/datasources/outings_remote_datasource.dart and the interactive notification handler |
| POST | `/api/outings/:id/invitations/decline` | features/outings/data/datasources/outings_remote_datasource.dart and the interactive notification handler |
| DELETE | `/api/outings/:id/save` | features/outings/data/datasources/saved_outings_remote_datasource.dart:123 |
| POST | `/api/outings/:id/save` | features/outings/data/datasources/saved_outings_remote_datasource.dart:119 |
| POST | `/api/outings/:id/tie-break` | features/outings/data/datasources/outings_remote_datasource.dart:685 |
| GET | `/api/outings/:id/vote-options` | features/outings/data/datasources/outings_remote_datasource.dart:844 |
| POST | `/api/outings/:id/vote-options` | No Flutter write call located. Creation embeds initial options in POST /api/outings. |
| PUT | `/api/outings/:id/vote-options` | No Flutter write call located. Revote writes through POST /api/outings/:id/voting/revote. |
| DELETE | `/api/outings/:id/vote-options/:optionId` | No static Flutter consumer located |
| DELETE | `/api/outings/:id/votes` | No static Flutter consumer located |
| GET | `/api/outings/:id/votes` | No static Flutter consumer located |
| POST | `/api/outings/:id/votes` | features/outings/data/datasources/outings_remote_datasource.dart:648 |
| PUT | `/api/outings/:id/votes` | features/outings/data/datasources/outings_remote_datasource.dart:623 |
| DELETE | `/api/outings/:id/votes/:optionId` | features/outings/data/datasources/outings_remote_datasource.dart:737 |
| GET | `/api/outings/:id/voting-state` | features/outings/data/datasources/outings_remote_datasource.dart:897 |
| POST | `/api/outings/:id/voting/revote` | features/outings/data/datasources/outings_remote_datasource.dart:716 |
| GET | `/api/outings/:outingId/messages` | features/chat/data/datasources/outing_chat_remote_datasource.dart:41 |
| POST | `/api/outings/:outingId/messages` | features/chat/data/datasources/outing_chat_remote_datasource.dart:72<br>features/notifications/data/services/interactive_notification_handler.dart:109 |
| DELETE | `/api/outings/:outingId/messages/:messageId` | features/chat/data/datasources/outing_chat_remote_datasource.dart (deleteMessage) |
| PATCH | `/api/outings/:outingId/messages/:messageId` | features/chat/data/datasources/outing_chat_remote_datasource.dart (editMessage) |
| PATCH | `/api/outings/:outingId/read` | features/chat/data/datasources/outing_chat_remote_datasource.dart:102<br>features/notifications/data/services/interactive_notification_handler.dart:135 |
| GET | `/api/outings/cuser` | features/outings/data/datasources/outings_remote_datasource.dart:208 |
| GET | `/api/outings/drafts` | features/outings/data/datasources/saved_outings_remote_datasource.dart:18 |
| POST | `/api/outings/drafts` | features/outings/data/datasources/saved_outings_remote_datasource.dart:24 |
| DELETE | `/api/outings/drafts/:id` | features/outings/data/datasources/saved_outings_remote_datasource.dart:42 |
| PATCH | `/api/outings/drafts/:id` | features/outings/data/datasources/saved_outings_remote_datasource.dart:33 |
| GET | `/api/outings/saved` | features/outings/data/datasources/saved_outings_remote_datasource.dart:104 |
| GET | `/api/place-brands/:id` | No static Flutter consumer located |
| GET | `/api/place-brands/:id/branches` | No static Flutter consumer located |
| GET | `/api/places` | features/discover/data/datasources/discover_remote_datasource.dart:106<br>features/discover/data/datasources/discover_remote_datasource.dart:128<br>features/discover/data/datasources/discover_remote_datasource.dart:226<br>features/discover/data/datasources/discover_remote_datasource.dart:243 |
| POST | `/api/places` | No Flutter write call located. Device-local places use SQLite. |
| DELETE | `/api/places/:id` | No static Flutter consumer located |
| GET | `/api/places/:id` | features/discover/data/datasources/discover_remote_datasource.dart:187<br>features/discover/data/datasources/discover_remote_datasource.dart:256 |
| PATCH | `/api/places/:id` | No static Flutter consumer located |
| GET | `/api/places/:id/hours` | No static Flutter consumer located |
| PUT | `/api/places/:id/hours` | No static Flutter consumer located |
| DELETE | `/api/places/:id/hours/:hourId` | No static Flutter consumer located |
| GET | `/api/places/:id/images` | No static Flutter consumer located |
| POST | `/api/places/:id/images` | No static Flutter consumer located |
| DELETE | `/api/places/:id/images/:imageId` | No static Flutter consumer located |
| GET | `/api/places/:id/prices` | No static Flutter consumer located |
| POST | `/api/places/:id/prices` | No static Flutter consumer located |
| DELETE | `/api/places/:id/prices/:priceId` | No static Flutter consumer located |
| DELETE | `/api/places/:id/save` | features/discover/data/datasources/saved_places_remote_datasource.dart:38 |
| POST | `/api/places/:id/save` | features/discover/data/datasources/saved_places_remote_datasource.dart:34 |
| GET | `/api/places/categories` | features/discover/data/datasources/discover_remote_datasource.dart:92 |
| GET | `/api/places/changes` | features/discover/data/datasources/discover_remote_datasource.dart:83 |
| POST | `/api/places/geocoding` | features/outings/data/repositories/geocoding_http_repository.dart:45 |
| GET | `/api/places/geojson` | No static Flutter consumer located |
| GET | `/api/places/licenses` | No static Flutter consumer located |
| GET | `/api/places/nearby` | features/discover/data/datasources/discover_remote_datasource.dart:205 |
| GET | `/api/places/recommendations` | features/discover/data/datasources/discover_remote_datasource.dart:34 |
| GET | `/api/places/saved` | features/discover/data/datasources/saved_places_remote_datasource.dart:20 |
| POST | `/api/places/sync` | No static Flutter consumer located |
| GET | `/api/places/sync/history` | No static Flutter consumer located |
| GET | `/api/places/sync/status` | No static Flutter consumer located |
| GET | `/api/places/version` | features/discover/data/datasources/discover_remote_datasource.dart:47 |
| GET | `/api/places/vibes` | features/discover/data/datasources/discover_remote_datasource.dart:92 |
| GET | `/api/users` | No static Flutter consumer located |
| DELETE | `/api/users/:id` | No static Flutter consumer located |
| GET | `/api/users/:id` | No static Flutter consumer located |
| DELETE | `/api/users/cuser` | features/auth/data/datasources/auth_remote_datasource.dart:68 |
| GET | `/api/users/cuser` | features/auth/data/datasources/auth_remote_datasource.dart:160 |
| PATCH | `/api/users/cuser` | features/auth/data/datasources/auth_remote_datasource.dart:147 |
| DELETE | `/api/users/cuser/fcm-token` | No static Flutter consumer located |
| POST | `/api/users/cuser/fcm-token` | features/notifications/data/datasources/fcm_token_remote_datasource.dart:15 |
| DELETE | `/api/users/cuser/fcm-token/:token` | features/notifications/data/datasources/fcm_token_remote_datasource.dart:32 |
| POST | `/api/users/sync` | features/auth/data/datasources/auth_remote_datasource.dart (shared _postUser) |

HTTP infrastructure routes

| Surface | Consumer |
| --- | --- |
| GET `/`, `/health`, `/health/live`, `/health/ready` | Hosting probes and operator checks |
| GET `/health/dependencies`, `/metrics` | Authenticated operator and Prometheus |
| GET `/api-docs/openapi.json`, Swagger UI | Developer tooling and contract suite |
| POST `/monitoring/mobile` | Optional Flutter MobileTelemetry batches |
| `/socket.io` | Shared Flutter OutingChatSocketClient |
