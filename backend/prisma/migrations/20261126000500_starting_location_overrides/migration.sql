
BEGIN;

CREATE TYPE starting_location_override_source AS ENUM ('DEFAULT', 'PERSONAL_LOCATION', 'SAVED_PLACE', 'MANUAL_POINT');

ALTER TABLE outings ADD COLUMN travel_input_version INTEGER NOT NULL DEFAULT 1;

CREATE TABLE starting_location_overrides (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id VARCHAR(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    meetup_session_id UUID REFERENCES meetup_sessions(id) ON DELETE CASCADE,
    outing_id UUID REFERENCES outings(id) ON DELETE CASCADE,
    location_source starting_location_override_source NOT NULL,
    personal_location_id UUID,
    saved_place_id UUID,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    transportation_mode transportation_mode,
    consent_policy_version VARCHAR(64),
    created_at TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ(6) NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ(6) NOT NULL,
    CONSTRAINT starting_override_personal_fkey FOREIGN KEY (user_id, personal_location_id)
        REFERENCES saved_locations(user_id, id) ON DELETE CASCADE,
    CONSTRAINT starting_override_bookmark_fkey FOREIGN KEY (user_id, saved_place_id)
        REFERENCES saved_places(user_id, place_id) ON DELETE CASCADE,
    CONSTRAINT starting_override_one_context CHECK (num_nonnulls(meetup_session_id, outing_id) = 1),
    CONSTRAINT starting_override_expiry CHECK (expires_at > created_at),
    CONSTRAINT starting_override_source_fields CHECK (
        (location_source = 'DEFAULT' AND num_nonnulls(transportation_mode, consent_policy_version) > 0
            AND num_nonnulls(personal_location_id, saved_place_id, latitude, longitude) = 0)
        OR (location_source = 'PERSONAL_LOCATION' AND personal_location_id IS NOT NULL
            AND consent_policy_version IS NOT NULL AND num_nonnulls(saved_place_id, latitude, longitude) = 0)
        OR (location_source = 'SAVED_PLACE' AND saved_place_id IS NOT NULL
            AND consent_policy_version IS NOT NULL AND num_nonnulls(personal_location_id, latitude, longitude) = 0)
        OR (location_source = 'MANUAL_POINT' AND latitude IS NOT NULL AND longitude IS NOT NULL
            AND latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180
            AND consent_policy_version IS NOT NULL AND num_nonnulls(personal_location_id, saved_place_id) = 0)
    )
);

CREATE UNIQUE INDEX starting_override_owner_session_key ON starting_location_overrides(user_id, meetup_session_id);
CREATE UNIQUE INDEX starting_override_owner_outing_key ON starting_location_overrides(user_id, outing_id);
CREATE INDEX starting_override_session_idx ON starting_location_overrides(meetup_session_id);
CREATE INDEX starting_override_outing_idx ON starting_location_overrides(outing_id);
CREATE INDEX starting_override_expiry_idx ON starting_location_overrides(expires_at);

-- Catch explicit writes and removals through every cascade and cleanup path.
CREATE FUNCTION invalidate_starting_location_override() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    target_session UUID;
    target_outing UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        target_session := OLD.meetup_session_id;
        target_outing := OLD.outing_id;
    ELSE
        target_session := NEW.meetup_session_id;
        target_outing := NEW.outing_id;
    END IF;
    IF target_session IS NOT NULL THEN
        UPDATE meetup_sessions
        SET input_version = input_version + 1, input_digest = NULL,
            calculation_status = 'STALE', updated_at = now()
        WHERE id = target_session AND status = 'ACTIVE';
    ELSE
        UPDATE outings SET travel_input_version = travel_input_version + 1 WHERE id = target_outing;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER starting_override_invalidate
AFTER INSERT OR UPDATE OR DELETE ON starting_location_overrides
FOR EACH ROW EXECUTE FUNCTION invalidate_starting_location_override();

CREATE FUNCTION clear_closed_starting_location_overrides() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    outing_end TIMESTAMPTZ;
BEGIN
    IF TG_TABLE_NAME = 'meetup_sessions' THEN
        IF NEW.status <> 'ACTIVE' THEN
            DELETE FROM starting_location_overrides WHERE meetup_session_id = NEW.id;
        END IF;
    ELSE
        outing_end := COALESCE(NEW.ends_at, NEW.scheduled_at + interval '6 hours');
        IF NEW.status IN ('cancelled', 'past') OR outing_end <= statement_timestamp() THEN
            DELETE FROM starting_location_overrides
            WHERE outing_id = NEW.id OR meetup_session_id IN (
                SELECT id FROM meetup_sessions WHERE outing_id = NEW.id
            );
        ELSIF outing_end IS NOT NULL THEN
            UPDATE starting_location_overrides
            SET expires_at = outing_end, updated_at = now()
            WHERE expires_at > outing_end AND (
                outing_id = NEW.id OR meetup_session_id IN (
                    SELECT id FROM meetup_sessions WHERE outing_id = NEW.id
                )
            );
        ELSE
            DELETE FROM starting_location_overrides WHERE outing_id = NEW.id;
        END IF;

        IF OLD.group_id IS DISTINCT FROM NEW.group_id OR OLD.created_by IS DISTINCT FROM NEW.created_by THEN
            DELETE FROM starting_location_overrides source
            WHERE (
                source.outing_id = NEW.id AND (
                    (source.user_id <> NEW.created_by AND NOT EXISTS (
                        SELECT 1 FROM group_members m WHERE m.group_id = NEW.group_id AND m.user_id = source.user_id
                    ) AND NOT EXISTS (
                        SELECT 1 FROM outing_guests g WHERE g.outing_id = NEW.id AND g.user_id = source.user_id
                            AND g.status = 'accepted'
                    ))
                    OR EXISTS (
                        SELECT 1 FROM user_location_group_exclusions e
                        WHERE e.group_id = NEW.group_id AND e.user_id = source.user_id
                    )
                )
            ) OR source.meetup_session_id IN (
                SELECT id FROM meetup_sessions WHERE outing_id = NEW.id AND group_id IS DISTINCT FROM NEW.group_id
            );
        END IF;
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER starting_override_session_closed
AFTER UPDATE OF status ON meetup_sessions
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status) EXECUTE FUNCTION clear_closed_starting_location_overrides();

CREATE TRIGGER starting_override_outing_closed
AFTER UPDATE OF status, scheduled_at, ends_at, group_id, created_by ON outings
FOR EACH ROW WHEN (OLD.status IS DISTINCT FROM NEW.status OR OLD.scheduled_at IS DISTINCT FROM NEW.scheduled_at
    OR OLD.ends_at IS DISTINCT FROM NEW.ends_at OR OLD.group_id IS DISTINCT FROM NEW.group_id
    OR OLD.created_by IS DISTINCT FROM NEW.created_by) EXECUTE FUNCTION clear_closed_starting_location_overrides();

CREATE FUNCTION clear_group_starting_location_overrides() RETURNS trigger
LANGUAGE plpgsql AS $$
DECLARE
    owner_id VARCHAR(128);
    scope_group UUID;
BEGIN
    IF TG_OP = 'DELETE' THEN
        owner_id := OLD.user_id;
        scope_group := OLD.group_id;
    ELSE
        owner_id := NEW.user_id;
        scope_group := NEW.group_id;
    END IF;
    DELETE FROM starting_location_overrides AS source
    WHERE source.user_id = owner_id AND (
        source.meetup_session_id IN (SELECT id FROM meetup_sessions WHERE group_id = scope_group)
        OR source.outing_id IN (
            SELECT o.id FROM outings o
            WHERE o.group_id = scope_group AND (
                TG_OP = 'INSERT' OR (
                    o.created_by <> owner_id AND NOT EXISTS (
                        SELECT 1 FROM outing_guests g
                        WHERE g.outing_id = o.id AND g.user_id = owner_id AND g.status = 'accepted'
                    )
                )
            )
        )
    );
    RETURN NULL;
END;
$$;

CREATE TRIGGER starting_override_membership_lost
AFTER DELETE ON group_members
FOR EACH ROW EXECUTE FUNCTION clear_group_starting_location_overrides();

CREATE TRIGGER starting_override_group_excluded
AFTER INSERT ON user_location_group_exclusions
FOR EACH ROW EXECUTE FUNCTION clear_group_starting_location_overrides();

CREATE FUNCTION clear_guest_starting_location_override() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM starting_location_overrides AS source USING outings o
    WHERE source.outing_id = OLD.outing_id AND source.user_id = OLD.user_id
        AND o.id = OLD.outing_id AND o.created_by <> OLD.user_id
        AND NOT EXISTS (
            SELECT 1 FROM group_members m WHERE m.group_id = o.group_id AND m.user_id = OLD.user_id
        );
    RETURN NULL;
END;
$$;

CREATE TRIGGER starting_override_guest_removed
AFTER DELETE ON outing_guests
FOR EACH ROW WHEN (OLD.status = 'accepted') EXECUTE FUNCTION clear_guest_starting_location_override();

CREATE TRIGGER starting_override_guest_declined
AFTER UPDATE OF status ON outing_guests
FOR EACH ROW WHEN (OLD.status = 'accepted' AND NEW.status <> 'accepted')
EXECUTE FUNCTION clear_guest_starting_location_override();

COMMIT;
