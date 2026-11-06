-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "attendance_status" AS ENUM ('going', 'not_going', 'maybe');

-- CreateEnum
CREATE TYPE "group_role" AS ENUM ('owner', 'member');

-- CreateEnum
CREATE TYPE "notification_type" AS ENUM ('outing', 'group', 'chat', 'vote', 'invitation', 'system');

-- CreateEnum
CREATE TYPE "outing_occasion" AS ENUM ('none', 'birthday', 'wedding');

-- CreateEnum
CREATE TYPE "outing_type" AS ENUM ('group', 'special_event');

-- CreateEnum
CREATE TYPE "outing_status" AS ENUM ('draft', 'voting', 'confirmed', 'cancelled', 'past');

-- CreateEnum
CREATE TYPE "vote_close_reason" AS ENUM ('all_voted', 'deadline', 'unique_winner', 'tie_break', 'zero_votes');

-- CreateEnum
CREATE TYPE "outing_vibe" AS ENUM ('food', 'activity', 'outdoor', 'movie');

-- CreateEnum
CREATE TYPE "price_level" AS ENUM ('free', 'budget', 'moderate', 'expensive', 'luxury');

-- CreateEnum
CREATE TYPE "weekday" AS ENUM ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday');

-- CreateEnum
CREATE TYPE "message_delivery_status" AS ENUM ('pending', 'sent', 'delivered', 'seen');

-- CreateEnum
CREATE TYPE "invitation_status" AS ENUM ('pending', 'accepted', 'declined', 'expired', 'revoked');

-- CreateEnum
CREATE TYPE "notification_event_type" AS ENUM ('group_invite', 'outing_invite', 'outing_updated', 'attendance_changed', 'chat_message', 'voting_closed_early', 'voting_deadline_reached', 'winner_selected', 'tie_break_selected', 'outing_confirmed', 'outing_cancelled');

-- CreateEnum
CREATE TYPE "notification_channel" AS ENUM ('whatsapp', 'push', 'sms', 'email');

-- CreateEnum
CREATE TYPE "notification_event_status" AS ENUM ('pending', 'processing', 'sent', 'failed', 'dead');

-- CreateTable
CREATE TABLE "users" (
    "id" VARCHAR(128) NOT NULL,
    "name" VARCHAR(30) NOT NULL,
    "phone" VARCHAR(16),
    "email" VARCHAR(254),
    "password_hash" VARCHAR(255),
    "password_updated_at" TIMESTAMPTZ(6),
    "image_url" VARCHAR(2048),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "groups" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(30) NOT NULL,
    "bio" VARCHAR(160) NOT NULL DEFAULT '',
    "image_url" VARCHAR(2048) NOT NULL DEFAULT '',
    "created_by" VARCHAR(128) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "group_members" (
    "group_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "role" "group_role" NOT NULL DEFAULT 'member',
    "joined_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_members_pkey" PRIMARY KEY ("group_id","user_id")
);

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

-- CreateTable
CREATE TABLE "places" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(100) NOT NULL,
    "area" VARCHAR(100) NOT NULL DEFAULT '',
    "vibe" "outing_vibe" NOT NULL DEFAULT 'food',
    "description" VARCHAR(1000) NOT NULL DEFAULT '',
    "cover_image_url" VARCHAR(2048) NOT NULL DEFAULT '',
    "price_level" "price_level" NOT NULL DEFAULT 'moderate',
    "price_min" DECIMAL(12,2),
    "price_max" DECIMAL(12,2),
    "currency" CHAR(3) NOT NULL DEFAULT 'EGP',
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "featured" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "places_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "place_images" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "place_id" UUID NOT NULL,
    "image_url" VARCHAR(2048) NOT NULL,
    "caption" VARCHAR(200),
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "place_images_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "place_prices" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "place_id" UUID NOT NULL,
    "label" VARCHAR(80) NOT NULL,
    "amount" DECIMAL(12,2) NOT NULL,
    "currency" CHAR(3) NOT NULL DEFAULT 'EGP',

    CONSTRAINT "place_prices_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "place_hours" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "place_id" UUID NOT NULL,
    "day" "weekday" NOT NULL,
    "opens_at" TIME(6),
    "closes_at" TIME(6),
    "is_closed" BOOLEAN NOT NULL DEFAULT false,

    CONSTRAINT "place_hours_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "title" VARCHAR(20) NOT NULL,
    "image_url" VARCHAR(2048) NOT NULL DEFAULT '',
    "group_id" UUID,
    "created_by" VARCHAR(128) NOT NULL,
    "status" "outing_status" NOT NULL DEFAULT 'draft',
    "type" "outing_type" NOT NULL DEFAULT 'group',
    "occasion" "outing_occasion" NOT NULL DEFAULT 'none',
    "scheduled_at" TIMESTAMPTZ(6),
    "ends_at" TIMESTAMPTZ(6),
    "location_place_id" UUID,
    "location_name" VARCHAR(100),
    "location_area" VARCHAR(100),
    "location_latitude" DOUBLE PRECISION,
    "location_longitude" DOUBLE PRECISION,
    "vote_deadline_hours" SMALLINT,
    "vote_ends_at" TIMESTAMPTZ(6),
    "vote_closed_at" TIMESTAMPTZ(6),
    "vote_close_reason" "vote_close_reason",
    "winning_option_id" UUID,
    "suggested_by_user_id" VARCHAR(128),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outing_guests" (
    "outing_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "invited_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outing_guests_pkey" PRIMARY KEY ("outing_id","user_id")
);

-- CreateTable
CREATE TABLE "outing_attendance" (
    "outing_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "status" "attendance_status" NOT NULL,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outing_attendance_pkey" PRIMARY KEY ("outing_id","user_id")
);

-- CreateTable
CREATE TABLE "outing_vote_options" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "outing_id" UUID NOT NULL,
    "place_id" UUID,
    "label" VARCHAR(100) NOT NULL,
    "area" VARCHAR(100) NOT NULL DEFAULT '',
    "image_url" VARCHAR(2048) NOT NULL DEFAULT '',
    "vibe" "outing_vibe" NOT NULL DEFAULT 'food',
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "sort_order" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "outing_vote_options_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outing_votes" (
    "outing_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "option_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outing_votes_pkey" PRIMARY KEY ("outing_id","user_id")
);

-- CreateTable
CREATE TABLE "outing_drafts" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" VARCHAR(128) NOT NULL,
    "title" VARCHAR(20) NOT NULL DEFAULT '',
    "image_url" VARCHAR(2048) NOT NULL DEFAULT '',
    "group_id" UUID,
    "occasion" "outing_occasion" NOT NULL DEFAULT 'none',
    "special_event" BOOLEAN NOT NULL DEFAULT false,
    "vibe" "outing_vibe" NOT NULL DEFAULT 'food',
    "scheduled_date" DATE,
    "scheduled_hour" SMALLINT,
    "scheduled_minute" SMALLINT,
    "location_name" VARCHAR(100),
    "location_area" VARCHAR(100),
    "location_latitude" DOUBLE PRECISION,
    "location_longitude" DOUBLE PRECISION,
    "let_vote" BOOLEAN NOT NULL DEFAULT false,
    "vote_deadline_hours" SMALLINT,
    "guest_ids" JSONB NOT NULL DEFAULT '[]',
    "selected_places" JSONB NOT NULL DEFAULT '[]',
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outing_drafts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chat_messages" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "outing_id" UUID NOT NULL,
    "sender_id" VARCHAR(128) NOT NULL,
    "text" VARCHAR(2000) NOT NULL,
    "delivery_status" "message_delivery_status" NOT NULL DEFAULT 'sent',
    "sent_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "client_message_id" UUID,

    CONSTRAINT "chat_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "chat_reads" (
    "outing_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "last_read_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "chat_reads_pkey" PRIMARY KEY ("outing_id","user_id")
);

-- CreateTable
CREATE TABLE "notifications" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" VARCHAR(128) NOT NULL,
    "body" VARCHAR(500) NOT NULL,
    "image_url" VARCHAR(2048),
    "type" "notification_type" NOT NULL DEFAULT 'system',
    "outing_id" UUID,
    "group_id" UUID,
    "action_required" BOOLEAN NOT NULL DEFAULT false,
    "is_read" BOOLEAN NOT NULL DEFAULT false,
    "event_key" VARCHAR(191),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_fcm_tokens" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" VARCHAR(128) NOT NULL,
    "token" VARCHAR(512) NOT NULL,
    "platform" VARCHAR(20),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_fcm_tokens_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "saved_outings" (
    "user_id" VARCHAR(128) NOT NULL,
    "outing_id" UUID NOT NULL,
    "saved_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "saved_outings_pkey" PRIMARY KEY ("user_id","outing_id")
);

-- CreateTable
CREATE TABLE "saved_places" (
    "user_id" VARCHAR(128) NOT NULL,
    "place_id" UUID NOT NULL,
    "saved_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "saved_places_pkey" PRIMARY KEY ("user_id","place_id")
);

-- CreateTable
CREATE TABLE "notification_events" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "type" "notification_event_type" NOT NULL,
    "channel" "notification_channel" NOT NULL DEFAULT 'push',
    "status" "notification_event_status" NOT NULL DEFAULT 'pending',
    "recipient_phone" VARCHAR(16),
    "recipient_user_id" VARCHAR(128),
    "group_id" UUID,
    "invitation_id" UUID,
    "outing_id" UUID,
    "event_key" VARCHAR(191),
    "payload" JSONB NOT NULL,
    "attempts" SMALLINT NOT NULL DEFAULT 0,
    "max_attempts" SMALLINT NOT NULL DEFAULT 5,
    "next_attempt_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_error" VARCHAR(1000),
    "sent_at" TIMESTAMPTZ(6),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notification_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "notification_delivery_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "event_id" UUID NOT NULL,
    "channel" "notification_channel" NOT NULL,
    "provider" VARCHAR(40) NOT NULL,
    "provider_message_id" VARCHAR(128),
    "status" VARCHAR(20) NOT NULL,
    "response" JSONB,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notification_delivery_logs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE INDEX "idx_group_members_user" ON "group_members"("user_id");

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

-- CreateIndex
CREATE INDEX "idx_places_vibe" ON "places"("vibe");

-- CreateIndex
CREATE INDEX "idx_places_lat_lng" ON "places"("latitude", "longitude");

-- CreateIndex
CREATE INDEX "idx_place_images_place" ON "place_images"("place_id", "sort_order");

-- CreateIndex
CREATE INDEX "idx_place_prices_place" ON "place_prices"("place_id");

-- CreateIndex
CREATE UNIQUE INDEX "place_hours_place_id_day_key" ON "place_hours"("place_id", "day");

-- CreateIndex
CREATE INDEX "idx_outings_status" ON "outings"("status");

-- CreateIndex
CREATE INDEX "idx_outings_group" ON "outings"("group_id");

-- CreateIndex
CREATE INDEX "idx_outings_scheduled" ON "outings"("scheduled_at");

-- CreateIndex
CREATE INDEX "idx_outings_created_by" ON "outings"("created_by");

-- CreateIndex
CREATE INDEX "idx_outings_vote_ends_at" ON "outings"("vote_ends_at");

-- CreateIndex
CREATE INDEX "idx_outings_voting_deadline" ON "outings"("status", "vote_ends_at");

-- CreateIndex
CREATE INDEX "idx_outing_guests_user" ON "outing_guests"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "outing_vote_options_outing_id_place_id_key" ON "outing_vote_options"("outing_id", "place_id");

-- CreateIndex
CREATE UNIQUE INDEX "uq_vote_options_id_outing" ON "outing_vote_options"("id", "outing_id");

-- CreateIndex
CREATE INDEX "idx_outing_votes_option" ON "outing_votes"("option_id");

-- CreateIndex
CREATE INDEX "idx_outing_drafts_user" ON "outing_drafts"("user_id");

-- CreateIndex
CREATE INDEX "idx_chat_messages_outing_sent" ON "chat_messages"("outing_id", "sent_at" DESC);

-- CreateIndex
CREATE INDEX "idx_chat_messages_outing_sent_id" ON "chat_messages"("outing_id", "sent_at" DESC, "id" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "uq_chat_messages_client_msg" ON "chat_messages"("outing_id", "sender_id", "client_message_id");

-- CreateIndex
CREATE UNIQUE INDEX "notifications_event_key_key" ON "notifications"("event_key");

-- CreateIndex
CREATE INDEX "idx_notifications_user_created" ON "notifications"("user_id", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "user_fcm_tokens_user_id_token_key" ON "user_fcm_tokens"("user_id", "token");

-- CreateIndex
CREATE UNIQUE INDEX "uq_user_fcm_tokens_token" ON "user_fcm_tokens"("token");

-- CreateIndex
CREATE INDEX "idx_saved_places_place" ON "saved_places"("place_id");

-- CreateIndex
CREATE UNIQUE INDEX "notification_events_event_key_key" ON "notification_events"("event_key");

-- CreateIndex
CREATE INDEX "idx_notification_events_claim" ON "notification_events"("status", "next_attempt_at");

-- CreateIndex
CREATE INDEX "idx_notification_events_invitation" ON "notification_events"("invitation_id");

-- CreateIndex
CREATE INDEX "idx_notification_events_group" ON "notification_events"("group_id");

-- CreateIndex
CREATE INDEX "idx_notification_events_outing" ON "notification_events"("outing_id");

-- CreateIndex
CREATE INDEX "idx_notification_events_phone" ON "notification_events"("recipient_phone");

-- CreateIndex
CREATE INDEX "idx_notification_delivery_logs_event" ON "notification_delivery_logs"("event_id");

-- AddForeignKey
ALTER TABLE "groups" ADD CONSTRAINT "groups_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "group_invitations" ADD CONSTRAINT "group_invitations_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "group_invitations" ADD CONSTRAINT "group_invitations_invited_by_user_id_fkey" FOREIGN KEY ("invited_by_user_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "group_invitations" ADD CONSTRAINT "group_invitations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "place_images" ADD CONSTRAINT "place_images_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "place_prices" ADD CONSTRAINT "place_prices_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "place_hours" ADD CONSTRAINT "place_hours_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outings" ADD CONSTRAINT "outings_winning_option_id_id_fkey" FOREIGN KEY ("winning_option_id", "id") REFERENCES "outing_vote_options"("id", "outing_id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outings" ADD CONSTRAINT "outings_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outings" ADD CONSTRAINT "outings_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outings" ADD CONSTRAINT "outings_location_place_id_fkey" FOREIGN KEY ("location_place_id") REFERENCES "places"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outings" ADD CONSTRAINT "outings_suggested_by_user_id_fkey" FOREIGN KEY ("suggested_by_user_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_guests" ADD CONSTRAINT "outing_guests_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_guests" ADD CONSTRAINT "outing_guests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_attendance" ADD CONSTRAINT "outing_attendance_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_attendance" ADD CONSTRAINT "outing_attendance_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_vote_options" ADD CONSTRAINT "outing_vote_options_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_vote_options" ADD CONSTRAINT "outing_vote_options_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_votes" ADD CONSTRAINT "outing_votes_option_id_outing_id_fkey" FOREIGN KEY ("option_id", "outing_id") REFERENCES "outing_vote_options"("id", "outing_id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_votes" ADD CONSTRAINT "outing_votes_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_votes" ADD CONSTRAINT "outing_votes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_drafts" ADD CONSTRAINT "outing_drafts_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_drafts" ADD CONSTRAINT "outing_drafts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "chat_messages" ADD CONSTRAINT "chat_messages_sender_id_fkey" FOREIGN KEY ("sender_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "chat_reads" ADD CONSTRAINT "chat_reads_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "chat_reads" ADD CONSTRAINT "chat_reads_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_fcm_tokens" ADD CONSTRAINT "user_fcm_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "saved_outings" ADD CONSTRAINT "saved_outings_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "saved_outings" ADD CONSTRAINT "saved_outings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "saved_places" ADD CONSTRAINT "saved_places_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "saved_places" ADD CONSTRAINT "saved_places_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "notification_delivery_logs" ADD CONSTRAINT "notification_delivery_logs_event_id_fkey" FOREIGN KEY ("event_id") REFERENCES "notification_events"("id") ON DELETE CASCADE ON UPDATE NO ACTION;
