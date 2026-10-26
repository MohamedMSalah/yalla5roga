-- Phase 2.1 and 2.2 of yalla-5roga-schema-review.md.
-- Generated with `prisma migrate diff`, then reordered so the new composite
-- foreign key exists before the single-column one is dropped.
-- Pre-checks (Section 8): query 4 (votes on another outing's option) = 0 rows,
-- query 5 (one token for several users) = 0 rows.

-- CreateIndex (2.1: a device token belongs to one user)
CREATE UNIQUE INDEX "uq_user_fcm_tokens_token" ON "user_fcm_tokens"("token");

-- CreateIndex (2.2: target for the composite foreign key)
CREATE UNIQUE INDEX "uq_vote_options_id_outing" ON "outing_vote_options"("id", "outing_id");

-- AddForeignKey (2.2: a vote can only reference an option of its own outing)
ALTER TABLE "outing_votes" ADD CONSTRAINT "outing_votes_option_id_outing_id_fkey" FOREIGN KEY ("option_id", "outing_id") REFERENCES "outing_vote_options"("id", "outing_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- DropForeignKey (2.2: replaced by the composite key above)
ALTER TABLE "outing_votes" DROP CONSTRAINT "outing_votes_option_id_fkey";
