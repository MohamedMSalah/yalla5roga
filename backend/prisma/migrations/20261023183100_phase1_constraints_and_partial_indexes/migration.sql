-- Hand-written migration (Phase 1 of yalla-5roga-schema-review.md, Section 7).
-- Prisma cannot model partial indexes or CHECK constraints, so a later
-- `prisma migrate diff` must not drop anything created here.
--
-- Constraints from Section 7 that already exist in the database under
-- another name were left out on purpose (verified with pg_constraint):
--   chk_users_phone_e164          -> users_phone_check (stricter, Egypt mobile)
--   chk_places_lat_range          -> places_latitude_check
--   chk_places_lng_range          -> places_longitude_check
--   chk_places_price_range        -> places_check
--   chk_place_prices_amount_nonneg-> place_prices_amount_check
--   chk_outings_vote_hours_positive -> outings_vote_deadline_hours_check (1..72)

-- ===== Partial indexes for background jobs =====
CREATE INDEX IF NOT EXISTS idx_outings_voting_due
  ON outings (vote_ends_at)
  WHERE status = 'voting' AND vote_finalized = false;

CREATE INDEX IF NOT EXISTS idx_outings_upcoming_due
  ON outings (scheduled_at)
  WHERE status = 'upcoming';

-- ===== E.164 phone format =====
ALTER TABLE group_invitations
  ADD CONSTRAINT chk_group_invitations_phone_e164
  CHECK (invited_phone ~ '^\+[1-9][0-9]{7,14}$');

-- ===== Places =====
ALTER TABLE places
  ADD CONSTRAINT chk_places_lat_lng_pair
  CHECK ((latitude IS NULL) = (longitude IS NULL));

ALTER TABLE places
  ADD CONSTRAINT chk_places_price_nonneg
  CHECK ((price_min IS NULL OR price_min >= 0) AND (price_max IS NULL OR price_max >= 0));

-- ===== Outings =====
ALTER TABLE outings
  ADD CONSTRAINT chk_outings_end_after_start
  CHECK (ends_at IS NULL OR scheduled_at IS NULL OR ends_at > scheduled_at);
