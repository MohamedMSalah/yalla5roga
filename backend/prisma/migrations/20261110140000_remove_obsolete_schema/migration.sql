-- Review and explicit approval required before moving into prisma/migrations.
BEGIN;
SET LOCAL lock_timeout = '5s';

LOCK TABLE "users", "outings", "notification_events", "notification_delivery_logs" IN ACCESS EXCLUSIVE MODE;
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM "users" WHERE "email" IS NOT NULL OR "phone" IS NULL)
     OR EXISTS (SELECT 1 FROM "outings" WHERE "suggested_by_user_id" IS NOT NULL)
     OR EXISTS (SELECT 1 FROM "notification_events" WHERE "channel" IN ('sms', 'email'))
     OR EXISTS (SELECT 1 FROM "notification_delivery_logs" WHERE "channel" IN ('sms', 'email')) THEN
    RAISE EXCEPTION 'Destructive cleanup preflight failed; review the current backup and data';
  END IF;
END $$;

ALTER TABLE "users"
  DROP COLUMN "email",
  DROP COLUMN "password_updated_at",
  ALTER COLUMN "phone" SET NOT NULL;
ALTER TABLE "outings" DROP COLUMN "suggested_by_user_id";
DROP INDEX "idx_group_invitations_phone";
DROP INDEX "idx_outings_status";
DROP INDEX "idx_chat_messages_outing_sent";
DROP INDEX "user_fcm_tokens_user_id_token_key";

-- PostgreSQL cannot remove individual enum labels in place. Restore the
-- outbox's push default after recasting the two columns.
ALTER TABLE "notification_events" ALTER COLUMN "channel" DROP DEFAULT;
ALTER TYPE "notification_channel" RENAME TO "notification_channel_legacy";
CREATE TYPE "notification_channel" AS ENUM ('whatsapp', 'push');
ALTER TABLE "notification_events" ALTER COLUMN "channel" TYPE "notification_channel"
  USING ("channel"::text::"notification_channel");
ALTER TABLE "notification_delivery_logs" ALTER COLUMN "channel" TYPE "notification_channel"
  USING ("channel"::text::"notification_channel");
ALTER TABLE "notification_events" ALTER COLUMN "channel" SET DEFAULT 'push';
DROP TYPE "notification_channel_legacy";

COMMIT;
