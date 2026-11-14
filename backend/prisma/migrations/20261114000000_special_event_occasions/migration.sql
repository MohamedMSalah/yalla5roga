BEGIN;
SET LOCAL lock_timeout = '5s';
-- Additive enum extension; existing IDs, relationships and rows are preserved.
ALTER TYPE "outing_occasion" ADD VALUE IF NOT EXISTS 'celebration';
ALTER TYPE "outing_occasion" ADD VALUE IF NOT EXISTS 'other';

-- NOT VALID preserves the existing historical-row policy. New/updated rows
-- must pair regular outings with a group and special events with an occasion.
ALTER TABLE "outings" DROP CONSTRAINT "outings_type_group_consistency";
ALTER TABLE "outings" ADD CONSTRAINT "outings_type_group_consistency"
  CHECK (("type" = 'group' AND "group_id" IS NOT NULL AND "occasion" = 'none')
    OR ("type" = 'special_event' AND "occasion" <> 'none')) NOT VALID;
COMMIT;
