> **Historical reference — corrected 2026-11-13:** Endpoint paths and PASS claims below describe an older implementation/run and are not current verification. Current registered routes use `/api/outings/:outingId/messages` and `/api/outings/:outingId/read`, `/api/invitations/:invitationId/decline`, and `/api/users/cuser/fcm-token`. There is no registered `POST /api/outings/hydrate`; Flutter hydrates via the existing current-user/detail/voting/attendance GET operations. Prefer `../API_CONTRACTS.md` and the current confirmed-fixes report.

# 2.7 Critical Business Workflows

Workflows below are derived from **implemented** backend use cases and Flutter features. Gaps are called out explicitly.

---

## 1. User onboarding & identity sync

```mermaid
flowchart TD
  A[Open app] --> B{Firebase session + cached_user?}
  B -->|No| C[Splash / Auth UI]
  C --> D{Sign-in method}
  D -->|Phone OTP + email| E[Firebase Auth]
  D -->|Google / Apple| E
  D -->|Email/password| E
  E --> F[Flutter POST /auth/register]
  F -.->|MISMATCH| G[Backend expects /api/users/sync or /api/auth/signup]
  G --> H[(users row in Neon)]
  H --> I[MainShell]
  B -->|Yes| I
```

**Backend invitation claim:** when sync sees a Firebase-verified phone, pending `group_invitations` are accepted into `group_members` (`ClaimGroupInvitationsUseCase`).

---

## 2. Create group & invite by phone

```mermaid
flowchart LR
  A[Member creates group] --> B[POST /api/groups]
  B --> C[groups + group_members owner]
  C --> D[POST /api/groups/:id/invitations]
  D --> E{Invitee already a user?}
  E -->|Yes| F[Add group_members]
  E -->|No| G[Insert group_invitations pending]
  G --> H[Enqueue notification_events WhatsApp]
  H --> I[Worker sends WhatsApp + deep link]
  I --> J[Invitee opens deep link / installs]
  J --> K[Verifies phone + sync claims invitation]
```

Non-user invites now use the notification outbox (`notification_events` → worker → WhatsApp channel). The API still returns `whatsapp_url` (click-to-chat fallback) and `deep_link` (`https://yalla5roga.com/invite/{invitationId}?groupId=…`). Set `WHATSAPP_PROVIDER=meta` with Cloud API credentials to send server-side; `stub` logs locally.

Flutter today: `POST /groups/{id}/members` with `GroupMember.toJson()` (id/name/avatar/role/phone) — **does not match** backend `phoneNumber`-based invite/add schemas. Leave endpoint `POST /groups/{id}/leave` has **no backend route**.

Invite deep links: Flutter `InviteDeepLinkProvider` (`app_links`) parses HTTPS + `yalla5roga://` invites, stashes while logged out, then `MainShell` flushes into `GroupDetailsPage` after groups refresh (membership claimed on sync). Host verification files: `docs/system-design/deep-links/`.

---

## 3. Plan an outing with voting

```mermaid
flowchart TD
  A[Create outing / suggest places] --> B{Backend create}
  B --> C[outings row status voting/upcoming]
  C --> D[Add vote options — place_id or label]
  D --> E[Members cast votes — option_id]
  E --> F{Deadline / finalize}
  F --> G[vote_finalized / location chosen]
  G --> H[Attendance going / not_going]
  H --> I[Outing completion job → past]
```

**Flutter divergence:** single `POST /outings` with nested `places` / `votePlaces`, and vote actions via `optionIndex` / `finalize` / `clear`. Backend separates create, option CRUD, cast/unvote, and update fields.

---

## 4. Outing chat

```mermaid
sequenceDiagram
  participant U as Participant
  participant API as POST/GET /api/chat/outings/:id/messages
  participant Access as assertChatParticipant
  participant DB as chat_messages

  U->>API: Bearer + text (+ clientMessageId)
  API->>Access: creator or guest?
  alt Not participant
    Access-->>U: 403 NOT_A_PARTICIPANT
  else Chat closed past/cancelled
    Access-->>U: 409 CHAT_CLOSED
  else OK
    API->>DB: insert / idempotent replay
    API-->>U: 201 message
  end
```

Flutter path nesting differs; mark-read hits `/outings/:id/chat/read` which is **missing** on backend (table `chat_reads` exists).

---

## 5. Discover places

```mermaid
flowchart LR
  App[Flutter DiscoverProvider] --> GET["GET /places?vibe="]
  GET --> API["Backend GET /api/places"]
  API --> DB[(places)]
  App --> Detail["GET /places/:id"]
  Nearby["GET /api/places/nearby"] -.->|Flutter does not call| App
  Map[Pick location] --> Nom[Nominatim] --> OSM[OSM tiles]
```

Backend also exposes hours/images/prices nested resources; Flutter discover models a flatter `SuggestedPlace`.

---

## 6. Notifications & push

```mermaid
flowchart TD
  DB[(notifications rows)] --> List[GET /api/notifications]
  List --> App[NotificationsProvider]
  App --> Read["PATCH /api/notifications/:id/read"]
  FCM[FCM message] --> Device[Flutter receive]
  Device --> Local[Local notification]
  Device --> Nav[PushNotificationNavigator]
  Token[FCM device token] -.->|prefs only| Prefs
  Prefs -.->|no API| Table[(user_fcm_tokens unused)]
```

Backend does **not** send FCM. Flutter mark-all-read (`POST /notifications/read`) has **no** backend counterpart. Mark-read method differs (`POST` vs `PATCH`).

---

## 7. Saved outings & drafts

| Capability | Backend | Flutter |
|------------|---------|---------|
| Saved outings | `GET/POST/DELETE /api/outings/…/save` | SharedPreferences only |
| Drafts | `/api/outings/drafts` CRUD | SharedPreferences only |

Until Flutter switches to the API, saved/drafts will not sync across devices.
