BEGIN;

ALTER TYPE "meetup_calculation_status" ADD VALUE 'NO_MATCHING_VENUES';

CREATE TABLE "meetup_calculations" (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "meetup_session_id" UUID NOT NULL REFERENCES "meetup_sessions"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    "input_version" INTEGER NOT NULL CHECK ("input_version" > 0),
    "attempt" INTEGER NOT NULL CHECK ("attempt" > 0),
    "calculation_status" "meetup_calculation_status" NOT NULL,
    "input_fingerprint" CHAR(64) NOT NULL,
    "intended_participant_count" INTEGER NOT NULL CHECK ("intended_participant_count" >= 0),
    "included_participant_count" INTEGER NOT NULL CHECK ("included_participant_count" >= 0),
    "unavailable_participant_count" INTEGER NOT NULL CHECK ("unavailable_participant_count" >= 0),
    "is_partial" BOOLEAN NOT NULL,
    "optimization_policy_version" VARCHAR(32) NOT NULL,
    "calculated_at" TIMESTAMPTZ(6),
    "expires_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "safe_failure_code" VARCHAR(64),
    CHECK ("intended_participant_count" = "included_participant_count" + "unavailable_participant_count"),
    CHECK ("is_partial" = ("included_participant_count" > 0 AND "unavailable_participant_count" > 0)),
    CHECK ("calculated_at" IS NULL OR ("expires_at" IS NOT NULL AND "expires_at" > "calculated_at"))
);

CREATE UNIQUE INDEX "meetup_calculations_version_attempt_key"
ON "meetup_calculations"("meetup_session_id", "input_version", "attempt");
CREATE INDEX "meetup_calculations_calculation_status_expires_at_idx"
ON "meetup_calculations"("calculation_status", "expires_at");

CREATE TABLE "meetup_recommendations" (
    "id" UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    "calculation_id" UUID NOT NULL REFERENCES "meetup_calculations"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    "place_id" UUID NOT NULL REFERENCES "places"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    "rank" INTEGER NOT NULL CHECK ("rank" BETWEEN 1 AND 5),
    "average_duration_seconds" DOUBLE PRECISION,
    "maximum_duration_seconds" INTEGER,
    "total_duration_seconds" INTEGER,
    "minimum_duration_seconds" INTEGER,
    "total_distance_meters" DOUBLE PRECISION,
    "duration_spread_seconds" INTEGER,
    "fairness_score" DOUBLE PRECISION,
    "match_score" DOUBLE PRECISION,
    "explanation_codes" TEXT[] NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE UNIQUE INDEX "meetup_recommendations_calculation_id_place_id_key"
ON "meetup_recommendations"("calculation_id", "place_id");
CREATE UNIQUE INDEX "meetup_recommendations_calculation_id_rank_key"
ON "meetup_recommendations"("calculation_id", "rank");
CREATE INDEX "meetup_recommendations_place_id_idx" ON "meetup_recommendations"("place_id");

CREATE FUNCTION invalidate_meetup_calculations_for_session() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.input_version <> OLD.input_version OR NEW.status <> OLD.status THEN
        UPDATE meetup_calculations SET calculation_status = 'STALE', updated_at = CURRENT_TIMESTAMP
        WHERE meetup_session_id = NEW.id AND calculation_status <> 'STALE';
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER meetup_calculations_session_invalidation
AFTER UPDATE OF input_version, status ON meetup_sessions
FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_calculations_for_session();

CREATE FUNCTION invalidate_meetup_calculations_for_place() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF TG_OP = 'DELETE' OR
       ROW(NEW.status, NEW.is_active, NEW.latitude, NEW.longitude)
       IS DISTINCT FROM ROW(OLD.status, OLD.is_active, OLD.latitude, OLD.longitude) THEN
        UPDATE meetup_calculations c SET calculation_status = 'STALE', updated_at = CURRENT_TIMESTAMP
        WHERE c.calculation_status <> 'STALE' AND EXISTS (
            SELECT 1 FROM meetup_recommendations r WHERE r.calculation_id = c.id AND r.place_id = OLD.id
        );
    END IF;
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER meetup_calculations_place_invalidation
BEFORE UPDATE OF status, is_active, latitude, longitude OR DELETE ON places
FOR EACH ROW EXECUTE FUNCTION invalidate_meetup_calculations_for_place();

COMMIT;
