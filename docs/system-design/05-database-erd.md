# 2.5 Database ERD

Source of truth: `backend/prisma/schema.prisma` (+ SQL-only constraints/indexes in migrations under `prisma/migrations/`).

```mermaid
erDiagram
  users ||--o{ groups : created_by
  users ||--o{ group_members : membership
  groups ||--o{ group_members : has
  users ||--o{ group_invitations : invited_by
  users ||--o{ group_invitations : invitee
  groups ||--o{ group_invitations : has

  users ||--o{ outings : created_by
  users ||--o{ outings : suggested_by
  groups ||--o{ outings : owns
  places ||--o{ outings : location_place

  outings ||--o{ outing_attendance : has
  users ||--o{ outing_attendance : marks
  outings ||--o{ outing_guests : has
  users ||--o{ outing_guests : invited
  outings ||--o{ outing_vote_options : has
  places ||--o{ outing_vote_options : option_place
  outings ||--o{ outing_votes : has
  users ||--o{ outing_votes : casts
  outing_vote_options ||--o{ outing_votes : receives

  users ||--o{ outing_drafts : owns
  groups ||--o{ outing_drafts : optional
  users ||--o{ saved_outings : bookmarks
  outings ||--o{ saved_outings : bookmarked

  places ||--o{ place_hours : has
  places ||--o{ place_images : has
  places ||--o{ place_prices : has

  outings ||--o{ chat_messages : has
  users ||--o{ chat_messages : sends
  outings ||--o{ chat_reads : has
  users ||--o{ chat_reads : tracks

  users ||--o{ notifications : receives
  outings ||--o{ notifications : about
  groups ||--o{ notifications : about
  users ||--o{ user_fcm_tokens : devices

  users {
    varchar id PK "Firebase UID"
    varchar name
    varchar phone UK "nullable"
    varchar email UK "nullable"
    varchar password_hash "nullable"
    timestamptz password_updated_at
    varchar image_url
    timestamptz created_at
    timestamptz updated_at
  }

  groups {
    uuid id PK
    varchar name
    varchar bio
    varchar image_url
    varchar created_by FK
    timestamptz created_at
    timestamptz updated_at
  }

  group_members {
    uuid group_id PK_FK
    varchar user_id PK_FK
    enum role "owner|member"
    timestamptz joined_at
  }

  group_invitations {
    uuid id PK
    uuid group_id FK
    varchar invited_by_user_id FK
    varchar invited_phone
    varchar user_id FK "nullable"
    enum status
    timestamptz expires_at
    timestamptz created_at
    timestamptz updated_at
  }

  outings {
    uuid id PK
    varchar title
    varchar image_url
    uuid group_id FK "nullable"
    varchar created_by FK
    enum status
    enum occasion
    timestamptz scheduled_at
    timestamptz ends_at
    uuid location_place_id FK
    varchar location_name
    varchar location_area
    float latitude
    float longitude
    smallint vote_deadline_hours
    timestamptz vote_ends_at
    boolean vote_finalized
    varchar suggested_by_user_id FK
    timestamptz created_at
    timestamptz updated_at
  }

  outing_attendance {
    uuid outing_id PK_FK
    varchar user_id PK_FK
    enum status
    timestamptz updated_at
  }

  outing_guests {
    uuid outing_id PK_FK
    varchar user_id PK_FK
    timestamptz invited_at
  }

  outing_vote_options {
    uuid id PK
    uuid outing_id FK
    uuid place_id FK "nullable"
    varchar label
    varchar area
    varchar image_url
    enum vibe
    float latitude
    float longitude
    int sort_order
  }

  outing_votes {
    uuid outing_id PK_FK
    varchar user_id PK_FK
    uuid option_id PK_FK
    timestamptz created_at
  }

  outing_drafts {
    uuid id PK
    varchar user_id FK
    uuid group_id FK
    json guest_ids
    json selected_places
  }

  saved_outings {
    varchar user_id PK_FK
    uuid outing_id PK_FK
    timestamptz saved_at
  }

  places {
    uuid id PK
    varchar name
    varchar area
    enum vibe
    varchar description
    varchar cover_image_url
    enum price_level
    decimal price_min
    decimal price_max
    char currency
    float latitude
    float longitude
    boolean featured
    boolean is_active
  }

  place_hours {
    uuid id PK
    uuid place_id FK
    enum day
    time opens_at
    time closes_at
    boolean is_closed
  }

  place_images {
    uuid id PK
    uuid place_id FK
    varchar image_url
    varchar caption
    int sort_order
  }

  place_prices {
    uuid id PK
    uuid place_id FK
    varchar label
    decimal amount
    char currency
  }

  chat_messages {
    uuid id PK
    uuid outing_id FK
    varchar sender_id FK
    varchar text
    enum delivery_status "deprecated"
    timestamptz sent_at
    uuid client_message_id "nullable"
  }

  chat_reads {
    uuid outing_id PK_FK
    varchar user_id PK_FK
    timestamptz last_read_at
  }

  notifications {
    uuid id PK
    varchar user_id FK
    varchar body
    varchar image_url
    enum type
    uuid outing_id FK
    uuid group_id FK
    boolean action_required
    boolean is_read
    timestamptz created_at
  }

  user_fcm_tokens {
    uuid id PK
    varchar user_id FK
    varchar token UK
    varchar platform
    timestamptz created_at
    timestamptz updated_at
  }
```

## Relationship cardinality summary

| Relationship | Type | Delete behavior |
|--------------|------|-----------------|
| users → group_members | 1:N | Cascade |
| groups → group_members | 1:N | Cascade |
| groups → group_invitations | 1:N | Cascade |
| invitation invitee user | N:1 optional | SetNull |
| groups.created_by → users | N:1 | NoAction |
| outings → attendance/guests/votes/options/chat/saved | 1:N | Cascade from children |
| outing_votes → options composite FK `(option_id, outing_id)` | N:1 | Cascade |
| places → hours/images/prices | 1:N | Cascade |
| users → notifications / fcm_tokens / drafts | 1:N | Cascade |

## Important indexes & unique constraints

**In Prisma schema**

- `users.phone`, `users.email` unique
- `group_members (group_id, user_id)` composite PK; index on `user_id`
- `outing_vote_options` unique `(outing_id, place_id)` and `(id, outing_id)`
- `outing_votes` PK `(outing_id, user_id, option_id)`; index on `option_id`
- `chat_messages` unique `(outing_id, sender_id, client_message_id)`; indexes on `(outing_id, sent_at desc[, id])`
- `user_fcm_tokens` unique `(user_id, token)` and unique `token`
- `place_hours` unique `(place_id, day)`
- Outings indexes: status, group_id, scheduled_at, created_by
- Places indexes: vibe, (latitude, longitude)
- Notifications: `(user_id, created_at desc)`

**SQL-only (migrations; not fully expressible in Prisma)**

- Partial unique index: one pending invitation per `(group_id, invited_phone)`
- Partial expiry index on pending invitations
- Partial indexes `idx_outings_voting_due`, `idx_outings_upcoming_due`
- CHECK constraints: E.164 phone, lat/lng pairs, outing end > start, group/occasion rules, etc.

## Enums

`attendance_status`, `group_role`, `notification_type`, `outing_occasion`, `outing_status`, `outing_vibe`, `price_level`, `weekday`, `message_delivery_status`, `invitation_status` — see schema lines 355–426.
