BEGIN;

ALTER TYPE notification_event_type ADD VALUE 'meetup_location_requested';

CREATE TYPE departure_reminder_status AS ENUM ('pending', 'sent');

CREATE TABLE departure_reminder_preferences (
    user_id VARCHAR(128) PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    enabled BOOLEAN NOT NULL DEFAULT FALSE,
    preparation_buffer_minutes SMALLINT NOT NULL DEFAULT 10
        CHECK (preparation_buffer_minutes IN (0, 5, 10, 15, 30)),
    updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT now()
);

CREATE TABLE departure_reminders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    outing_id UUID NOT NULL REFERENCES outings(id) ON DELETE CASCADE,
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    scheduled_send_at TIMESTAMPTZ(6) NOT NULL,
    estimate_reference VARCHAR(128) NOT NULL,
    input_fingerprint CHAR(64) NOT NULL,
    deduplication_key CHAR(64) NOT NULL UNIQUE,
    duration_seconds INTEGER NOT NULL CHECK (duration_seconds BETWEEN 0 AND 604800),
    status departure_reminder_status NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
    sent_at TIMESTAMPTZ(6),
    UNIQUE (outing_id, user_id),
    CHECK ((status = 'sent') = (sent_at IS NOT NULL))
);

CREATE INDEX departure_reminders_user_id_idx ON departure_reminders(user_id);
CREATE INDEX departure_reminders_status_scheduled_send_at_idx ON departure_reminders(status, scheduled_send_at);

CREATE FUNCTION invalidate_departure_reminders_for_outing() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM departure_reminders WHERE outing_id = NEW.id AND status = 'pending';
    RETURN NULL;
END;
$$;
CREATE TRIGGER departure_outing_changed AFTER UPDATE OF scheduled_at, ends_at, status, location_place_id,
    location_latitude, location_longitude, group_id, created_by ON outings
FOR EACH ROW WHEN (
    ROW(OLD.scheduled_at, OLD.ends_at, OLD.status, OLD.location_place_id, OLD.location_latitude,
        OLD.location_longitude, OLD.group_id, OLD.created_by)
    IS DISTINCT FROM
    ROW(NEW.scheduled_at, NEW.ends_at, NEW.status, NEW.location_place_id, NEW.location_latitude,
        NEW.location_longitude, NEW.group_id, NEW.created_by)
) EXECUTE FUNCTION invalidate_departure_reminders_for_outing();

CREATE FUNCTION invalidate_departure_reminders_for_user() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE owner_uid VARCHAR(128);
BEGIN
    IF TG_TABLE_NAME = 'users' THEN owner_uid := NEW.id;
    ELSE owner_uid := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;
    END IF;
    DELETE FROM departure_reminders WHERE user_id = owner_uid AND status = 'pending';
    RETURN NULL;
END;
$$;
CREATE TRIGGER departure_account_changed AFTER UPDATE OF default_transportation_mode, notification_preferences ON users
FOR EACH ROW WHEN (
    ROW(OLD.default_transportation_mode, OLD.notification_preferences)
    IS DISTINCT FROM ROW(NEW.default_transportation_mode, NEW.notification_preferences)
) EXECUTE FUNCTION invalidate_departure_reminders_for_user();
CREATE TRIGGER departure_preferences_changed AFTER INSERT OR UPDATE OR DELETE ON departure_reminder_preferences
FOR EACH ROW EXECUTE FUNCTION invalidate_departure_reminders_for_user();
CREATE TRIGGER departure_default_changed AFTER INSERT OR UPDATE OR DELETE ON default_starting_locations
FOR EACH ROW EXECUTE FUNCTION invalidate_departure_reminders_for_user();
CREATE TRIGGER departure_privacy_changed AFTER INSERT OR UPDATE OR DELETE ON user_location_privacy
FOR EACH ROW EXECUTE FUNCTION invalidate_departure_reminders_for_user();

CREATE FUNCTION invalidate_departure_reminder_for_participant() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE change_outing UUID;
DECLARE change_user VARCHAR(128);
BEGIN
    change_outing := CASE WHEN TG_OP = 'DELETE' THEN OLD.outing_id ELSE NEW.outing_id END;
    change_user := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;
    IF change_outing IS NOT NULL THEN
        DELETE FROM departure_reminders WHERE outing_id = change_outing AND user_id = change_user AND status = 'pending';
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER departure_override_changed AFTER INSERT OR UPDATE OR DELETE ON starting_location_overrides
FOR EACH ROW EXECUTE FUNCTION invalidate_departure_reminder_for_participant();
CREATE TRIGGER departure_rsvp_changed AFTER UPDATE OF status ON outing_attendance
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION invalidate_departure_reminder_for_participant();
CREATE TRIGGER departure_rsvp_removed AFTER DELETE ON outing_attendance
FOR EACH ROW EXECUTE FUNCTION invalidate_departure_reminder_for_participant();
CREATE TRIGGER departure_guest_changed AFTER UPDATE OF status ON outing_guests
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION invalidate_departure_reminder_for_participant();
CREATE TRIGGER departure_guest_removed AFTER DELETE ON outing_guests
FOR EACH ROW EXECUTE FUNCTION invalidate_departure_reminder_for_participant();

CREATE FUNCTION invalidate_departure_reminders_for_group_member() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE member_uid VARCHAR(128);
DECLARE group_key UUID;
BEGIN
    member_uid := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;
    group_key := CASE WHEN TG_OP = 'DELETE' THEN OLD.group_id ELSE NEW.group_id END;
    DELETE FROM departure_reminders r USING outings o
    WHERE r.outing_id = o.id AND o.group_id = group_key AND r.user_id = member_uid AND r.status = 'pending';
    RETURN NULL;
END;
$$;
CREATE TRIGGER departure_group_left AFTER DELETE ON group_members
FOR EACH ROW EXECUTE FUNCTION invalidate_departure_reminders_for_group_member();
CREATE TRIGGER departure_group_exclusion_changed AFTER INSERT OR DELETE ON user_location_group_exclusions
FOR EACH ROW EXECUTE FUNCTION invalidate_departure_reminders_for_group_member();

CREATE FUNCTION invalidate_departure_reminders_for_location() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE owner_uid VARCHAR(128);
DECLARE ref_id UUID;
BEGIN
    owner_uid := CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END;
    IF TG_TABLE_NAME = 'saved_locations' THEN
        ref_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.id ELSE NEW.id END;
        DELETE FROM departure_reminders r WHERE r.user_id = owner_uid AND r.status = 'pending' AND (
            EXISTS (SELECT 1 FROM default_starting_locations d WHERE d.user_id = owner_uid AND d.saved_location_id = ref_id)
            OR EXISTS (SELECT 1 FROM starting_location_overrides s WHERE s.user_id = owner_uid
                AND s.outing_id = r.outing_id AND s.personal_location_id = ref_id)
        );
    ELSE
        ref_id := CASE WHEN TG_OP = 'DELETE' THEN OLD.place_id ELSE NEW.place_id END;
        DELETE FROM departure_reminders r WHERE r.user_id = owner_uid AND r.status = 'pending' AND (
            EXISTS (SELECT 1 FROM default_starting_locations d WHERE d.user_id = owner_uid AND d.saved_place_id = ref_id)
            OR EXISTS (SELECT 1 FROM starting_location_overrides s WHERE s.user_id = owner_uid
                AND s.outing_id = r.outing_id AND s.saved_place_id = ref_id)
        );
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER departure_saved_location_changed AFTER UPDATE OF latitude, longitude, preferred_transportation_mode ON saved_locations
FOR EACH ROW WHEN (ROW(OLD.latitude, OLD.longitude, OLD.preferred_transportation_mode)
    IS DISTINCT FROM ROW(NEW.latitude, NEW.longitude, NEW.preferred_transportation_mode))
EXECUTE FUNCTION invalidate_departure_reminders_for_location();
CREATE TRIGGER departure_bookmark_changed AFTER UPDATE OF preferred_transportation_mode ON saved_places
FOR EACH ROW WHEN (OLD.preferred_transportation_mode IS DISTINCT FROM NEW.preferred_transportation_mode)
EXECUTE FUNCTION invalidate_departure_reminders_for_location();

CREATE FUNCTION invalidate_departure_reminders_for_catalog_place() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM departure_reminders r USING outings o
    WHERE r.outing_id = o.id AND r.status = 'pending' AND (
        o.location_place_id = NEW.id
        OR EXISTS (SELECT 1 FROM default_starting_locations d WHERE d.user_id = r.user_id AND d.saved_place_id = NEW.id)
        OR EXISTS (SELECT 1 FROM starting_location_overrides s WHERE s.user_id = r.user_id
            AND s.outing_id = r.outing_id AND s.saved_place_id = NEW.id)
    );
    RETURN NULL;
END;
$$;
CREATE TRIGGER departure_catalog_place_changed AFTER UPDATE OF latitude, longitude, status, is_active ON places
FOR EACH ROW WHEN (ROW(OLD.latitude, OLD.longitude, OLD.status, OLD.is_active)
    IS DISTINCT FROM ROW(NEW.latitude, NEW.longitude, NEW.status, NEW.is_active))
EXECUTE FUNCTION invalidate_departure_reminders_for_catalog_place();

CREATE INDEX notification_location_request_recipient_time_idx ON notification_events (recipient_user_id, created_at DESC)
    WHERE payload->>'notificationType' = 'meetup_location_requested';
CREATE INDEX notification_location_request_sender_time_idx ON notification_events ((payload->>'requesterId'), created_at DESC)
    WHERE payload->>'notificationType' = 'meetup_location_requested';
CREATE INDEX inbox_location_request_sender_idx ON notifications ((data->>'requesterId'))
    WHERE data->>'notificationType' = 'meetup_location_requested';

CREATE FUNCTION delete_account_location_requests() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM notification_events WHERE payload->>'notificationType' = 'meetup_location_requested'
        AND (payload->>'requesterId' = OLD.id OR recipient_user_id = OLD.id);
    DELETE FROM notifications WHERE data->>'notificationType' = 'meetup_location_requested'
        AND data->>'requesterId' = OLD.id;
    RETURN OLD;
END;
$$;
CREATE TRIGGER departure_and_location_request_account_cleanup BEFORE DELETE ON users
FOR EACH ROW EXECUTE FUNCTION delete_account_location_requests();

COMMIT;
