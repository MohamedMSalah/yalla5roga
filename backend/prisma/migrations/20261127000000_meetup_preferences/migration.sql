BEGIN;

CREATE TYPE "travel_fairness_mode" AS ENUM ('BALANCED', 'EQUAL_TRAVEL', 'FASTEST_OVERALL');
CREATE TYPE "meetup_budget_level" AS ENUM ('AFFORDABLE', 'MODERATE', 'EXPENSIVE');
CREATE TYPE "meetup_optimization_priority" AS ENUM ('TOP_RATED', 'BUDGET_FRIENDLY', 'SHORTEST_DISTANCE');

CREATE TABLE "meetup_preferences" (
    "meetup_session_id" UUID PRIMARY KEY REFERENCES "meetup_sessions"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    "travel_fairness_mode" "travel_fairness_mode" NOT NULL DEFAULT 'BALANCED',
    "selected_budget_levels" "meetup_budget_level"[] NOT NULL DEFAULT '{}',
    "minimum_rating" DECIMAL(2,1) CHECK ("minimum_rating" IN (3.0, 4.0, 4.5)),
    "maximum_travel_duration_seconds" INTEGER CHECK ("maximum_travel_duration_seconds" IN (900, 1800, 2700, 3600, 5400)),
    "additional_priorities" "meetup_optimization_priority"[] NOT NULL DEFAULT '{}',
    "planned_meetup_at" TIMESTAMPTZ(6),
    "require_open_at_meetup_time" BOOLEAN NOT NULL DEFAULT false,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "meetup_preference_categories" (
    "meetup_session_id" UUID NOT NULL REFERENCES "meetup_preferences"("meetup_session_id") ON DELETE CASCADE ON UPDATE NO ACTION,
    "category_id" VARCHAR(64) NOT NULL REFERENCES "place_categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
    PRIMARY KEY ("meetup_session_id", "category_id")
);

CREATE INDEX "meetup_preference_categories_category_id_idx" ON "meetup_preference_categories"("category_id");

COMMIT;
