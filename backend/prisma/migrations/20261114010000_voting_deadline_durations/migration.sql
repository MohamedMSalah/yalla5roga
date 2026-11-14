-- Preserve existing duration columns and all rows; support the seven-day preset.
BEGIN;
SET LOCAL lock_timeout = '5s';
ALTER TABLE "outings"
  DROP CONSTRAINT "outings_vote_deadline_range",
  ADD CONSTRAINT "outings_vote_deadline_range"
    CHECK ("vote_deadline_hours" IS NULL OR "vote_deadline_hours" BETWEEN 1 AND 168);
ALTER TABLE "outing_drafts"
  DROP CONSTRAINT "outing_drafts_vote_deadline_range",
  ADD CONSTRAINT "outing_drafts_vote_deadline_range"
    CHECK ("vote_deadline_hours" IS NULL OR "vote_deadline_hours" BETWEEN 1 AND 168);
COMMIT;
