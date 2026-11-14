-- Additive only. Existing inbox, outbox and WhatsApp rows are preserved.
ALTER TABLE users ADD COLUMN notification_preferences jsonb NOT NULL DEFAULT '{}';
ALTER TABLE notifications ADD COLUMN data jsonb NOT NULL DEFAULT '{}';
-- Existing installations keep OS-rendered pushes until they advertise v2.
ALTER TABLE user_fcm_tokens ADD COLUMN notification_version smallint NOT NULL DEFAULT 1;
ALTER TABLE user_fcm_tokens ADD CONSTRAINT notification_version_supported CHECK (notification_version IN (1, 2));
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'group_created';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'member_joined';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'member_left';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'membership_activated';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'outing_created';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'outing_reminder';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'voting_started';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'voting_deadline_approaching';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'voting_closed';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'rsvp_opened';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'venue_reminder';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'arrival_reminder';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'arrival_changed';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'chat_updated';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'chat_deleted';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'conversation_read';
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'invitation_resolved';
