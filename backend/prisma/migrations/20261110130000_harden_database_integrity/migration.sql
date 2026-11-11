BEGIN;
SET LOCAL lock_timeout = '5s';

-- Existing records are preserved. Abort before creating the index if pending
-- invitation duplicates require an explicit reconciliation decision.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM "group_invitations"
    WHERE "status" = 'pending'
    GROUP BY "group_id", "invited_phone"
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION 'Duplicate pending group invitations require review';
  END IF;
END $$;

ALTER TABLE "users"
  ADD CONSTRAINT "users_phone_e164" CHECK ("phone" ~ '^[+][1-9][0-9]{1,14}$');
ALTER TABLE "group_invitations"
  ADD CONSTRAINT "group_invitations_phone_e164" CHECK ("invited_phone" ~ '^[+][1-9][0-9]{1,14}$');

CREATE UNIQUE INDEX "uq_group_invitations_pending_phone"
  ON "group_invitations"("group_id", "invited_phone")
  WHERE "status" = 'pending';

ALTER TABLE "outing_guests" ALTER COLUMN "status" SET DEFAULT 'pending';
ALTER TABLE "outings"
  VALIDATE CONSTRAINT "outings_type_group_consistency",
  VALIDATE CONSTRAINT "outings_ends_after_scheduled",
  VALIDATE CONSTRAINT "outings_vote_deadline_range",
  ADD CONSTRAINT "outings_coordinate_bounds"
    CHECK ("location_latitude" BETWEEN -90 AND 90 AND "location_longitude" BETWEEN -180 AND 180);

ALTER TABLE "outing_drafts"
  VALIDATE CONSTRAINT "outing_drafts_scheduled_hour_range",
  VALIDATE CONSTRAINT "outing_drafts_scheduled_minute_range",
  VALIDATE CONSTRAINT "outing_drafts_vote_deadline_range",
  ADD CONSTRAINT "outing_drafts_array_fields"
    CHECK (jsonb_typeof("guest_ids") = 'array' AND jsonb_typeof("selected_places") = 'array'),
  ADD CONSTRAINT "outing_drafts_coordinate_bounds"
    CHECK ("location_latitude" BETWEEN -90 AND 90 AND "location_longitude" BETWEEN -180 AND 180);

ALTER TABLE "outing_vote_options" ADD CONSTRAINT "outing_vote_options_coordinate_bounds"
  CHECK ("latitude" BETWEEN -90 AND 90 AND "longitude" BETWEEN -180 AND 180);
ALTER TABLE "places"
  ADD CONSTRAINT "places_coordinate_bounds"
    CHECK ("latitude" BETWEEN -90 AND 90 AND "longitude" BETWEEN -180 AND 180),
  ADD CONSTRAINT "places_price_bounds"
    CHECK ("price_min" >= 0 AND "price_max" >= 0 AND "price_min" <= "price_max");
ALTER TABLE "place_prices" ADD CONSTRAINT "place_prices_nonnegative"
  CHECK ("amount" >= 0);

CREATE INDEX "idx_user_fcm_tokens_user" ON "user_fcm_tokens"("user_id");
CREATE INDEX "idx_saved_outings_user_saved" ON "saved_outings"("user_id", "saved_at" DESC);
CREATE INDEX "idx_saved_places_user_saved" ON "saved_places"("user_id", "saved_at" DESC);

COMMIT;
