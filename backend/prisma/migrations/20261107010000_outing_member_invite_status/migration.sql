-- Additive: invitation status on outing membership rows (no Guest role).
-- Existing rows become accepted Members.

ALTER TABLE "outing_guests"
ADD COLUMN IF NOT EXISTS "status" "invitation_status" NOT NULL DEFAULT 'accepted';

CREATE INDEX IF NOT EXISTS "idx_outing_guests_status"
ON "outing_guests"("outing_id", "status");
