BEGIN;
ALTER TYPE notification_event_type ADD VALUE IF NOT EXISTS 'smart_meetup_changed';
ALTER TYPE notification_channel ADD VALUE IF NOT EXISTS 'realtime';

ALTER TABLE meetup_calculations ADD COLUMN candidate_place_ids UUID[] NOT NULL DEFAULT '{}';
UPDATE meetup_calculations c SET candidate_place_ids = candidates.ids
FROM (
    SELECT calculation_id, array_agg(place_id ORDER BY place_id) AS ids
    FROM meetup_recommendations GROUP BY calculation_id
) candidates WHERE candidates.calculation_id = c.id;
CREATE INDEX meetup_calculations_candidate_places_idx ON meetup_calculations USING GIN (candidate_place_ids);

-- The existing outbox also carries Meetup hints. The database rejects extra payload fields
-- and recipient identifiers on this channel.
ALTER TABLE notification_events ADD CONSTRAINT notification_events_meetup_payload_check CHECK (
    (channel::text = 'realtime') = (type::text = 'smart_meetup_changed') AND (
        channel::text <> 'realtime' OR (
            event_key IS NOT NULL AND num_nonnulls(recipient_phone, recipient_user_id, group_id, outing_id, invitation_id) = 0
            AND jsonb_typeof(payload) = 'object'
            AND payload ?& ARRAY['sessionId', 'inputVersion', 'changeType']
            AND payload - ARRAY['sessionId', 'inputVersion', 'changeType', 'calculationAttempt'] = '{}'::jsonb
            AND jsonb_typeof(payload->'sessionId') = 'string'
            AND payload->>'sessionId' ~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$'
            AND jsonb_typeof(payload->'inputVersion') = 'number'
            AND payload->>'inputVersion' ~ '^[1-9][0-9]*$'
            AND jsonb_typeof(payload->'changeType') = 'string'
            AND payload->>'changeType' IN ('SESSION_UPDATED', 'SESSION_EXPIRED', 'READINESS_CHANGED',
                'PREFERENCES_CHANGED', 'RESULTS_INVALIDATED', 'CALCULATION_COMPLETED')
            AND (payload ? 'calculationAttempt') =
                (payload->>'changeType' IN ('RESULTS_INVALIDATED', 'CALCULATION_COMPLETED'))
            AND (NOT payload ? 'calculationAttempt' OR (
                jsonb_typeof(payload->'calculationAttempt') = 'number'
                AND payload->>'calculationAttempt' ~ '^[1-9][0-9]*$'
            ))
        )
    )
);
CREATE INDEX notification_events_meetup_finished_idx ON notification_events (created_at)
WHERE event_key LIKE 'smart-meetup:%' AND status IN ('sent', 'dead');

CREATE FUNCTION enqueue_meetup_change(session_id UUID, input_version INTEGER, change_type TEXT,
    calculation_attempt INTEGER DEFAULT NULL) RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO notification_events (type, channel, event_key, payload)
    VALUES ('smart_meetup_changed', 'realtime',
        concat_ws(':', 'smart-meetup', session_id, input_version,
            CASE WHEN change_type IN ('READINESS_CHANGED', 'PREFERENCES_CHANGED') THEN 'INPUT' ELSE change_type END,
            calculation_attempt),
        jsonb_strip_nulls(jsonb_build_object('sessionId', session_id, 'inputVersion', input_version,
            'changeType', change_type, 'calculationAttempt', calculation_attempt)))
    ON CONFLICT (event_key) DO UPDATE SET payload = EXCLUDED.payload
    WHERE notification_events.payload->>'changeType' = 'READINESS_CHANGED'
        AND EXCLUDED.payload->>'changeType' = 'PREFERENCES_CHANGED';
END;
$$;

CREATE FUNCTION advance_closed_meetup_version() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.input_version := GREATEST(NEW.input_version, OLD.input_version + 1);
    NEW.calculation_status := 'STALE';
    RETURN NEW;
END;
$$;
CREATE TRIGGER meetup_session_close_version BEFORE UPDATE OF status ON meetup_sessions
FOR EACH ROW WHEN (OLD.status = 'ACTIVE' AND NEW.status <> 'ACTIVE')
EXECUTE FUNCTION advance_closed_meetup_version();

CREATE FUNCTION record_meetup_session_change() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM enqueue_meetup_change(OLD.id, OLD.input_version + 1, 'SESSION_UPDATED');
    ELSIF NEW.status IS DISTINCT FROM OLD.status THEN
        PERFORM enqueue_meetup_change(NEW.id, NEW.input_version,
            CASE WHEN NEW.status = 'EXPIRED' THEN 'SESSION_EXPIRED' ELSE 'SESSION_UPDATED' END);
    ELSIF NEW.input_version <> OLD.input_version THEN
        PERFORM enqueue_meetup_change(NEW.id, NEW.input_version, 'READINESS_CHANGED');
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_session_change AFTER UPDATE OF input_version, status OR DELETE ON meetup_sessions
FOR EACH ROW EXECUTE FUNCTION record_meetup_session_change();

CREATE FUNCTION record_meetup_calculation_change() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND NEW.calculation_status = OLD.calculation_status THEN RETURN NULL; END IF;
    IF NOT EXISTS (
        SELECT 1 FROM meetup_sessions s WHERE s.id = NEW.meetup_session_id
        AND s.status = 'ACTIVE' AND s.input_version = NEW.input_version
    ) THEN RETURN NULL; END IF;
    IF NEW.calculation_status = 'STALE' THEN
        PERFORM enqueue_meetup_change(NEW.meetup_session_id, NEW.input_version, 'RESULTS_INVALIDATED', NEW.attempt);
    ELSIF NEW.calculation_status IN ('READY', 'PARTIAL', 'NO_MATCHING_VENUES', 'FAILED') THEN
        PERFORM enqueue_meetup_change(NEW.meetup_session_id, NEW.input_version, 'CALCULATION_COMPLETED', NEW.attempt);
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_calculation_change AFTER INSERT OR UPDATE OF calculation_status ON meetup_calculations
FOR EACH ROW EXECUTE FUNCTION record_meetup_calculation_change();

-- A cascade can remove both a default and an override. Reuse the dirty
-- session row of this transaction; a later transaction still advances it.
CREATE FUNCTION meetup_inputs_already_dirty(digest CHAR(64), row_xid XID)
RETURNS BOOLEAN LANGUAGE sql AS $$
    SELECT digest IS NULL AND row_xid = pg_current_xact_id()::xid;
$$;

CREATE OR REPLACE FUNCTION invalidate_starting_location_override() RETURNS trigger
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
        WHERE id = target_session AND status = 'ACTIVE'
            AND NOT meetup_inputs_already_dirty(input_digest, xmin);
    ELSE
        UPDATE outings SET travel_input_version = travel_input_version + 1 WHERE id = target_outing;
    END IF;
    RETURN NULL;
END;
$$;

-- Select the owner's own Quick Meetup and the current group sessions the owner participates in.
-- Reference changes target only the affected source. An authorized temporary point takes
-- precedence over the default and exclusions apply only to their specific group.
CREATE FUNCTION invalidate_meetup_user_inputs(owner_id VARCHAR, reason TEXT, reference_id UUID DEFAULT NULL)
RETURNS VOID LANGUAGE sql AS $$
    WITH affected AS (
        SELECT s.id
        FROM meetup_sessions s
        LEFT JOIN user_location_privacy p ON p.user_id = owner_id
        LEFT JOIN default_starting_locations d ON d.user_id = owner_id
        LEFT JOIN starting_location_overrides o ON o.meetup_session_id = s.id
            AND o.user_id = owner_id AND o.expires_at > statement_timestamp()
        LEFT JOIN places temp_place ON temp_place.id = o.saved_place_id
        LEFT JOIN saved_places temp_bookmark ON temp_bookmark.user_id = owner_id AND temp_bookmark.place_id = o.saved_place_id
        LEFT JOIN saved_locations temp_personal ON temp_personal.user_id = owner_id AND temp_personal.id = o.personal_location_id
        LEFT JOIN saved_places default_bookmark ON default_bookmark.user_id = owner_id AND default_bookmark.place_id = d.saved_place_id
        LEFT JOIN saved_locations default_personal ON default_personal.user_id = owner_id AND default_personal.id = d.saved_location_id
        CROSS JOIN LATERAL (
            SELECT COALESCE(o.location_source IN ('MANUAL_POINT', 'PERSONAL_LOCATION')
                OR (o.location_source = 'SAVED_PLACE' AND temp_place.is_active AND temp_place.status = 'active'
                    AND temp_place.latitude BETWEEN -90 AND 90 AND temp_place.longitude BETWEEN -180 AND 180), FALSE)
                AS temporary,
                (COALESCE(p.automatic_meetup_location_usage_enabled, FALSE)
                    OR COALESCE(o.location_source = 'DEFAULT' AND o.consent_policy_version IS NOT NULL, FALSE))
                AS default_allowed
        ) effective
        WHERE s.status = 'ACTIVE' AND s.expires_at > statement_timestamp()
          AND NOT meetup_inputs_already_dirty(s.input_digest, s.xmin)
          AND ((s.session_type = 'STANDALONE' AND s.created_by_user_id = owner_id) OR EXISTS (
            SELECT 1 FROM group_members m WHERE m.group_id = s.group_id AND m.user_id = owner_id
          ))
          AND (reason = 'EXCLUSION' OR NOT EXISTS (
            SELECT 1 FROM user_location_group_exclusions e WHERE e.user_id = owner_id AND e.group_id = s.group_id
          ))
          AND CASE reason
            WHEN 'EXCLUSION' THEN s.group_id = reference_id
            WHEN 'CONSENT' THEN NOT effective.temporary
            WHEN 'VISIBILITY' THEN s.session_type = 'GROUP' AND effective.default_allowed AND NOT effective.temporary
                AND d.user_id IS NOT NULL
            WHEN 'DEFAULT' THEN effective.default_allowed AND NOT effective.temporary
            WHEN 'PERSONAL' THEN o.personal_location_id = reference_id
                OR (effective.default_allowed AND NOT effective.temporary AND d.saved_location_id = reference_id)
            WHEN 'BOOKMARK' THEN o.saved_place_id = reference_id
                OR (effective.default_allowed AND NOT effective.temporary AND d.saved_place_id = reference_id)
            WHEN 'TRANSPORT' THEN COALESCE(o.transportation_mode, CASE
                WHEN effective.temporary THEN COALESCE(temp_personal.preferred_transportation_mode, temp_bookmark.preferred_transportation_mode)
                WHEN effective.default_allowed THEN COALESCE(default_personal.preferred_transportation_mode, default_bookmark.preferred_transportation_mode)
            END) IS NULL AND (
                s.session_type = 'STANDALONE' OR effective.temporary OR (effective.default_allowed AND d.user_id IS NOT NULL)
            )
            ELSE FALSE
          END
        ORDER BY s.id FOR UPDATE OF s
    )
    UPDATE meetup_sessions s SET input_version = s.input_version + 1, input_digest = NULL,
        calculation_status = 'STALE', updated_at = statement_timestamp()
    FROM affected WHERE s.id = affected.id;
$$;

CREATE FUNCTION invalidate_meetup_membership_inputs() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    scope_group UUID;
BEGIN
    scope_group := CASE WHEN TG_OP = 'DELETE' THEN OLD.group_id ELSE NEW.group_id END;
    WITH affected AS (
        SELECT id FROM meetup_sessions WHERE group_id = scope_group
            AND status = 'ACTIVE' AND expires_at > statement_timestamp()
            AND NOT meetup_inputs_already_dirty(input_digest, xmin)
        ORDER BY id FOR UPDATE
    )
    UPDATE meetup_sessions s SET input_version = s.input_version + 1, input_digest = NULL,
        calculation_status = 'STALE', updated_at = statement_timestamp()
    FROM affected WHERE s.id = affected.id;
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_group_membership_inputs AFTER INSERT OR DELETE ON group_members
FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_membership_inputs();

CREATE FUNCTION invalidate_meetup_default_inputs() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND ROW(OLD.saved_location_id, OLD.saved_place_id)
        IS NOT DISTINCT FROM ROW(NEW.saved_location_id, NEW.saved_place_id) THEN RETURN NULL; END IF;
    PERFORM invalidate_meetup_user_inputs(CASE WHEN TG_OP = 'DELETE' THEN OLD.user_id ELSE NEW.user_id END, 'DEFAULT');
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_default_inputs AFTER INSERT OR UPDATE OR DELETE ON default_starting_locations
FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_default_inputs();

CREATE FUNCTION invalidate_meetup_personal_location_inputs() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM invalidate_meetup_user_inputs(NEW.user_id, 'PERSONAL', NEW.id);
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_personal_location_inputs AFTER UPDATE ON saved_locations FOR EACH ROW WHEN (
    ROW(OLD.name, OLD.latitude, OLD.longitude, OLD.place_id, OLD.preferred_transportation_mode,
        OLD.location_type, OLD.approximate_area, OLD.address)
    IS DISTINCT FROM ROW(NEW.name, NEW.latitude, NEW.longitude, NEW.place_id, NEW.preferred_transportation_mode,
        NEW.location_type, NEW.approximate_area, NEW.address)
) EXECUTE FUNCTION invalidate_meetup_personal_location_inputs();

CREATE FUNCTION invalidate_meetup_transport_inputs() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_TABLE_NAME = 'users' THEN
        PERFORM invalidate_meetup_user_inputs(NEW.id, 'TRANSPORT');
    ELSE
        PERFORM invalidate_meetup_user_inputs(NEW.user_id, 'BOOKMARK', NEW.place_id);
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_account_transport_inputs AFTER UPDATE OF default_transportation_mode ON users
FOR EACH ROW WHEN (OLD.default_transportation_mode IS DISTINCT FROM NEW.default_transportation_mode)
EXECUTE FUNCTION invalidate_meetup_transport_inputs();
CREATE TRIGGER meetup_bookmark_transport_inputs AFTER UPDATE OF preferred_transportation_mode ON saved_places
FOR EACH ROW WHEN (OLD.preferred_transportation_mode IS DISTINCT FROM NEW.preferred_transportation_mode)
EXECUTE FUNCTION invalidate_meetup_transport_inputs();

CREATE FUNCTION invalidate_meetup_privacy_inputs() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM invalidate_meetup_user_inputs(OLD.user_id, 'CONSENT');
    ELSIF (TG_OP = 'INSERT' AND NEW.automatic_meetup_location_usage_enabled) OR (TG_OP = 'UPDATE' AND
        ROW(OLD.automatic_meetup_location_usage_enabled, OLD.location_usage_consent_at, OLD.consent_policy_version)
        IS DISTINCT FROM ROW(NEW.automatic_meetup_location_usage_enabled, NEW.location_usage_consent_at,
            NEW.consent_policy_version)) THEN
        PERFORM invalidate_meetup_user_inputs(NEW.user_id, 'CONSENT');
    ELSIF COALESCE(OLD.location_visibility, 'APPROXIMATE') <> NEW.location_visibility THEN
        PERFORM invalidate_meetup_user_inputs(NEW.user_id, 'VISIBILITY');
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_privacy_inputs AFTER INSERT OR UPDATE OR DELETE ON user_location_privacy
FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_privacy_inputs();

CREATE FUNCTION invalidate_meetup_exclusion_inputs() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM invalidate_meetup_user_inputs(OLD.user_id, 'EXCLUSION', OLD.group_id);
    ELSE
        PERFORM invalidate_meetup_user_inputs(NEW.user_id, 'EXCLUSION', NEW.group_id);
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_group_exclusion_inputs AFTER INSERT OR DELETE ON user_location_group_exclusions
FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_exclusion_inputs();

CREATE FUNCTION invalidate_meetup_outing_scope() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    -- The current outing/group relationship is part of the REST and room policy.
    UPDATE meetup_sessions SET input_version = input_version + 1, input_digest = NULL,
        calculation_status = 'STALE', updated_at = statement_timestamp()
    WHERE outing_id = NEW.id AND status = 'ACTIVE' AND NOT meetup_inputs_already_dirty(input_digest, xmin);
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_outing_scope AFTER UPDATE OF group_id ON outings
FOR EACH ROW WHEN (OLD.group_id IS DISTINCT FROM NEW.group_id)
EXECUTE FUNCTION invalidate_meetup_outing_scope();

CREATE FUNCTION invalidate_meetup_candidates(place_ids UUID[], reason TEXT) RETURNS VOID LANGUAGE sql AS $$
    UPDATE meetup_calculations c SET calculation_status = 'STALE', updated_at = statement_timestamp()
    FROM meetup_sessions s LEFT JOIN meetup_preferences p ON p.meetup_session_id = s.id
    WHERE s.id = c.meetup_session_id AND s.status = 'ACTIVE'
      AND c.input_version = s.input_version AND c.expires_at > statement_timestamp()
      AND c.calculation_status IN ('READY', 'PARTIAL', 'NO_MATCHING_VENUES')
      AND c.candidate_place_ids && place_ids
      AND CASE reason
        WHEN 'HOURS' THEN p.require_open_at_meetup_time
        WHEN 'DETAILED_PRICE' THEN 'BUDGET_FRIENDLY' = ANY(p.additional_priorities)
        WHEN 'CATEGORY_VISIBILITY' THEN EXISTS (
            SELECT 1 FROM meetup_preference_categories f WHERE f.meetup_session_id = s.id
        )
        WHEN 'RATING' THEN p.minimum_rating IS NOT NULL OR 'TOP_RATED' = ANY(p.additional_priorities)
            OR EXISTS (SELECT 1 FROM meetup_recommendations r WHERE r.calculation_id = c.id AND r.place_id = ANY(place_ids))
        ELSE TRUE
      END;
$$;

CREATE OR REPLACE FUNCTION invalidate_meetup_calculations_for_place() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' THEN
        PERFORM invalidate_meetup_candidates(ARRAY[OLD.id], 'VENUE');
        RETURN OLD;
    END IF;
    IF ROW(NEW.status, NEW.is_active, NEW.latitude, NEW.longitude, NEW.category_id, NEW.price_level, NEW.currency)
        IS DISTINCT FROM ROW(OLD.status, OLD.is_active, OLD.latitude, OLD.longitude, OLD.category_id, OLD.price_level,
            OLD.currency) THEN
        PERFORM invalidate_meetup_candidates(ARRAY[OLD.id], 'VENUE');
    ELSIF NEW.opening_hours IS DISTINCT FROM OLD.opening_hours THEN
        PERFORM invalidate_meetup_candidates(ARRAY[OLD.id], 'HOURS');
    END IF;
    RETURN NEW;
END;
$$;
DROP TRIGGER meetup_calculations_place_invalidation ON places;
CREATE TRIGGER meetup_calculations_place_invalidation
BEFORE UPDATE OF status, is_active, latitude, longitude, category_id, price_level, currency, opening_hours OR DELETE ON places
FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_calculations_for_place();

CREATE FUNCTION invalidate_meetup_candidate_fact() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND (to_jsonb(NEW) - 'updated_at') = (to_jsonb(OLD) - 'updated_at') THEN
        RETURN NULL;
    END IF;
    IF TG_OP <> 'DELETE' THEN PERFORM invalidate_meetup_candidates(ARRAY[NEW.place_id], TG_ARGV[0]); END IF;
    IF TG_OP = 'DELETE' OR (TG_OP = 'UPDATE' AND NEW.place_id <> OLD.place_id) THEN
        PERFORM invalidate_meetup_candidates(ARRAY[OLD.place_id], TG_ARGV[0]);
    END IF;
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_candidate_rating_change AFTER INSERT OR UPDATE OF rating_sum, rating_count OR DELETE
ON place_rating_statistics FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_candidate_fact('RATING');
CREATE TRIGGER meetup_candidate_prices_change AFTER INSERT OR UPDATE OR DELETE ON place_prices
FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_candidate_fact('DETAILED_PRICE');
CREATE TRIGGER meetup_candidate_hours_change AFTER INSERT OR UPDATE OR DELETE ON place_hours
FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_candidate_fact('HOURS');

CREATE FUNCTION invalidate_meetup_candidate_category() RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    PERFORM invalidate_meetup_candidates(ARRAY(SELECT id FROM places WHERE category_id = NEW.id), 'CATEGORY_VISIBILITY');
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_candidate_category_visibility AFTER UPDATE OF is_active ON place_categories
FOR EACH ROW WHEN (OLD.is_active IS DISTINCT FROM NEW.is_active)
EXECUTE FUNCTION invalidate_meetup_candidate_category();

CREATE FUNCTION invalidate_meetup_catalog_starting_points() RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
    source RECORD;
BEGIN
    FOR source IN
        SELECT user_id, 'BOOKMARK' AS kind, NEW.id AS reference FROM default_starting_locations WHERE saved_place_id = NEW.id
        UNION
        SELECT user_id, 'BOOKMARK', NEW.id FROM starting_location_overrides WHERE saved_place_id = NEW.id AND meetup_session_id IS NOT NULL
        UNION
        SELECT user_id, 'PERSONAL', id FROM saved_locations WHERE place_id = NEW.id
        ORDER BY 1, 2, 3
    LOOP
        PERFORM invalidate_meetup_user_inputs(source.user_id, source.kind, source.reference);
    END LOOP;
    RETURN NULL;
END;
$$;
CREATE TRIGGER meetup_catalog_starting_points AFTER UPDATE OF status, is_active, latitude, longitude, district ON places
FOR EACH ROW WHEN (
    ROW(OLD.status, OLD.is_active, OLD.latitude, OLD.longitude, OLD.district)
    IS DISTINCT FROM ROW(NEW.status, NEW.is_active, NEW.latitude, NEW.longitude, NEW.district)
) EXECUTE FUNCTION invalidate_meetup_catalog_starting_points();

COMMIT;
