-- Preserve every existing selection; expand uniqueness to one row per option.
BEGIN;
SET LOCAL lock_timeout = '5s';
ALTER TABLE "outing_votes" DROP CONSTRAINT "outing_votes_pkey";
ALTER TABLE "outing_votes" ADD CONSTRAINT "outing_votes_pkey" PRIMARY KEY ("outing_id", "user_id", "option_id");
COMMIT;
