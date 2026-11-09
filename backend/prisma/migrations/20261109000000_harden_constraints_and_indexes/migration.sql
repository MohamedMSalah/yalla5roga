-- Guard documented value invariants even when a future writer bypasses Prisma.
-- NOT VALID avoids failing deployment because of historical rows; PostgreSQL
-- still enforces each constraint for all new and changed rows.
ALTER TABLE "outings"
  ADD CONSTRAINT "outings_type_group_consistency"
    CHECK (("type" = 'group' AND "group_id" IS NOT NULL) OR ("type" = 'special_event' AND "group_id" IS NULL)) NOT VALID,
  ADD CONSTRAINT "outings_ends_after_scheduled"
    CHECK ("scheduled_at" IS NULL OR "ends_at" IS NULL OR "ends_at" > "scheduled_at") NOT VALID,
  ADD CONSTRAINT "outings_vote_deadline_range"
    CHECK ("vote_deadline_hours" IS NULL OR "vote_deadline_hours" BETWEEN 1 AND 72) NOT VALID;

ALTER TABLE "outing_drafts"
  ADD CONSTRAINT "outing_drafts_scheduled_hour_range"
    CHECK ("scheduled_hour" IS NULL OR "scheduled_hour" BETWEEN 0 AND 23) NOT VALID,
  ADD CONSTRAINT "outing_drafts_scheduled_minute_range"
    CHECK ("scheduled_minute" IS NULL OR "scheduled_minute" BETWEEN 0 AND 59) NOT VALID,
  ADD CONSTRAINT "outing_drafts_vote_deadline_range"
    CHECK ("vote_deadline_hours" IS NULL OR "vote_deadline_hours" BETWEEN 1 AND 72) NOT VALID;

CREATE INDEX "idx_groups_created_by" ON "groups"("created_by");
CREATE INDEX "idx_group_invitations_invited_by" ON "group_invitations"("invited_by_user_id");
CREATE INDEX "idx_outings_suggested_by" ON "outings"("suggested_by_user_id");
CREATE INDEX "idx_outings_location_place" ON "outings"("location_place_id");
CREATE INDEX "idx_outing_attendance_user" ON "outing_attendance"("user_id");
CREATE INDEX "idx_outing_vote_options_place" ON "outing_vote_options"("place_id");
CREATE INDEX "idx_outing_votes_user" ON "outing_votes"("user_id");
CREATE INDEX "idx_chat_messages_sender" ON "chat_messages"("sender_id");
CREATE INDEX "idx_chat_reads_user" ON "chat_reads"("user_id");
CREATE INDEX "idx_notifications_outing" ON "notifications"("outing_id");
CREATE INDEX "idx_notifications_group" ON "notifications"("group_id");
CREATE INDEX "idx_saved_outings_outing" ON "saved_outings"("outing_id");

-- Group-level seen state is represented by chat_reads, not a mutable message flag.
ALTER TABLE "chat_messages" DROP COLUMN "delivery_status";
DROP TYPE "message_delivery_status";
