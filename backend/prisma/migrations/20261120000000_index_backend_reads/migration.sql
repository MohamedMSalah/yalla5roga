BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE INDEX "idx_outing_votes_round_user"
    ON "outing_votes"("outing_id", "round_number", "user_id");

CREATE INDEX "idx_notifications_user_read_created"
    ON "notifications"("user_id", "is_read", "created_at");

COMMIT;
