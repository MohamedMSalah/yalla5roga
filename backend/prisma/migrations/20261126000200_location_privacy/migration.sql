BEGIN;

CREATE TYPE "location_visibility" AS ENUM ('APPROXIMATE', 'HIDDEN');

CREATE TABLE "user_location_privacy" (
  "user_id" VARCHAR(128) PRIMARY KEY REFERENCES "users" ("id") ON DELETE CASCADE,
  "location_visibility" "location_visibility" NOT NULL DEFAULT 'APPROXIMATE',
  "automatic_meetup_location_usage_enabled" BOOLEAN NOT NULL DEFAULT false,
  "location_usage_consent_at" TIMESTAMPTZ(6),
  "consent_policy_version" VARCHAR(64),
  "authorization_revision" UUID NOT NULL DEFAULT gen_random_uuid(),
  "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "user_location_privacy_consent_check" CHECK (
    ("automatic_meetup_location_usage_enabled" AND "location_usage_consent_at" IS NOT NULL
      AND "consent_policy_version" IS NOT NULL AND btrim("consent_policy_version") <> '')
    OR
    (NOT "automatic_meetup_location_usage_enabled" AND "location_usage_consent_at" IS NULL
      AND "consent_policy_version" IS NULL)
  )
);

CREATE TABLE "user_location_group_exclusions" (
  "user_id" VARCHAR(128) NOT NULL REFERENCES "users" ("id") ON DELETE CASCADE,
  "group_id" UUID NOT NULL REFERENCES "groups" ("id") ON DELETE CASCADE,
  "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY ("user_id", "group_id")
);

CREATE INDEX "idx_location_exclusions_group" ON "user_location_group_exclusions" ("group_id");

COMMIT;
