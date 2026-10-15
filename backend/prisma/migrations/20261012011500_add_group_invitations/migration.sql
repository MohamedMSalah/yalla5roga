-- CreateEnum
CREATE TYPE "invitation_status" AS ENUM ('pending', 'accepted', 'expired', 'revoked');

-- CreateTable
CREATE TABLE "group_invitations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "group_id" UUID NOT NULL,
    "invited_by_user_id" VARCHAR(128) NOT NULL,
    "invited_phone" VARCHAR(16) NOT NULL,
    "user_id" VARCHAR(128),
    "status" "invitation_status" NOT NULL DEFAULT 'pending',
    "expires_at" TIMESTAMPTZ(6) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_invitations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "idx_group_invitations_group" ON "group_invitations"("group_id");

-- CreateIndex
CREATE INDEX "idx_group_invitations_phone" ON "group_invitations"("invited_phone");

-- CreateIndex
CREATE INDEX "idx_group_invitations_status" ON "group_invitations"("status");

-- CreateIndex
CREATE INDEX "idx_group_invitations_phone_status" ON "group_invitations"("invited_phone", "status");

-- CreateIndex
CREATE INDEX "idx_group_invitations_user" ON "group_invitations"("user_id");

-- One pending invitation per group and normalized phone.
-- Prisma cannot express this predicate, so do not drop it in a later diff.
CREATE UNIQUE INDEX "group_invitations_pending_phone_key"
ON "group_invitations" ("group_id", "invited_phone")
WHERE "status" = 'pending';

-- AddForeignKey
ALTER TABLE "group_invitations" ADD CONSTRAINT "group_invitations_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "group_invitations" ADD CONSTRAINT "group_invitations_invited_by_user_id_fkey" FOREIGN KEY ("invited_by_user_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "group_invitations" ADD CONSTRAINT "group_invitations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION;
