-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "attendance_status" AS ENUM ('going', 'not_going', 'not_voted');

-- CreateEnum
CREATE TYPE "group_role" AS ENUM ('owner', 'member');

-- CreateEnum
CREATE TYPE "notification_type" AS ENUM ('outing', 'group', 'chat', 'vote', 'invitation', 'system');

-- CreateEnum
CREATE TYPE "outing_occasion" AS ENUM ('none', 'birthday', 'wedding');

-- CreateEnum
CREATE TYPE "outing_status" AS ENUM ('upcoming', 'voting', 'past');

-- CreateEnum
CREATE TYPE "outing_vibe" AS ENUM ('food', 'activity', 'outdoor', 'movie');

-- CreateEnum
CREATE TYPE "price_level" AS ENUM ('free', 'budget', 'moderate', 'expensive', 'luxury');

-- CreateEnum
CREATE TYPE "weekday" AS ENUM ('monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday');

-- CreateEnum
CREATE TYPE "message_delivery_status" AS ENUM ('pending', 'sent', 'delivered', 'seen');

-- CreateTable
CREATE TABLE "group_members" (
    "group_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "role" "group_role" NOT NULL DEFAULT 'member',
    "joined_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "group_members_pkey" PRIMARY KEY ("group_id","user_id")
);

-- CreateTable
CREATE TABLE "groups" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "name" VARCHAR(30) NOT NULL,
    "bio" VARCHAR(160) NOT NULL DEFAULT '',
    "image_url" VARCHAR(2048) NOT NULL,
    "created_by" VARCHAR(128) NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "groups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "outing_attendance" (
    "outing_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "status" "attendance_status" NOT NULL DEFAULT 'not_voted',
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outing_attendance_pkey" PRIMARY KEY ("outing_id","user_id")
);

-- CreateTable
CREATE TABLE "outing_guests" (
    "outing_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "invited_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outing_guests_pkey" PRIMARY KEY ("outing_id","user_id")
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
CREATE TABLE "outings" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "title" VARCHAR(20) NOT NULL,
    "image_url" VARCHAR(2048) NOT NULL DEFAULT '',
    "group_id" UUID,
    "created_by" VARCHAR(128) NOT NULL,
    "status" "outing_status" NOT NULL DEFAULT 'upcoming',
    "occasion" "outing_occasion" NOT NULL DEFAULT 'none',
    "scheduled_at" TIMESTAMPTZ(6),
    "location_place_id" UUID,
    "location_name" VARCHAR(100),
    "location_area" VARCHAR(100),
    "location_latitude" DOUBLE PRECISION,
    "location_longitude" DOUBLE PRECISION,
    "vote_deadline_hours" SMALLINT,
    "vote_ends_at" TIMESTAMPTZ(6),
    "vote_finalized" BOOLEAN NOT NULL DEFAULT false,
    "suggested_by_user_id" VARCHAR(128),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outings_pkey" PRIMARY KEY ("id")
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
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "places_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "users" (
    "id" VARCHAR(128) NOT NULL,
    "name" VARCHAR(30) NOT NULL,
    "phone" VARCHAR(13) NOT NULL,
    "email" VARCHAR(254),
    "image_url" VARCHAR(2048),
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
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
CREATE TABLE "chat_messages" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "outing_id" UUID NOT NULL,
    "sender_id" VARCHAR(128) NOT NULL,
    "text" VARCHAR(2000) NOT NULL,
    "delivery_status" "message_delivery_status" NOT NULL DEFAULT 'sent',
    "sent_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

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
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "notifications_pkey" PRIMARY KEY ("id")
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
CREATE TABLE "outing_votes" (
    "outing_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "option_id" UUID NOT NULL,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "outing_votes_pkey" PRIMARY KEY ("outing_id","user_id","option_id")
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
CREATE TABLE "saved_outings" (
    "user_id" VARCHAR(128) NOT NULL,
    "outing_id" UUID NOT NULL,
    "saved_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "saved_outings_pkey" PRIMARY KEY ("user_id","outing_id")
);

-- CreateIndex
CREATE INDEX "idx_group_members_user" ON "group_members"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "outing_vote_options_outing_id_place_id_key" ON "outing_vote_options"("outing_id", "place_id");

-- CreateIndex
CREATE INDEX "idx_outings_status" ON "outings"("status");

-- CreateIndex
CREATE INDEX "idx_outings_group" ON "outings"("group_id");

-- CreateIndex
CREATE INDEX "idx_outings_scheduled" ON "outings"("scheduled_at");

-- CreateIndex
CREATE INDEX "idx_places_vibe" ON "places"("vibe");

-- CreateIndex
CREATE UNIQUE INDEX "users_phone_key" ON "users"("phone");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "user_fcm_tokens_user_id_token_key" ON "user_fcm_tokens"("user_id", "token");

-- CreateIndex
CREATE INDEX "idx_chat_messages_outing_sent" ON "chat_messages"("outing_id", "sent_at" DESC);

-- CreateIndex
CREATE INDEX "idx_notifications_user_created" ON "notifications"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "idx_outing_drafts_user" ON "outing_drafts"("user_id");

-- CreateIndex
CREATE INDEX "idx_outing_votes_option" ON "outing_votes"("option_id");

-- CreateIndex
CREATE UNIQUE INDEX "place_hours_place_id_day_key" ON "place_hours"("place_id", "day");

-- AddForeignKey
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "group_members" ADD CONSTRAINT "group_members_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "groups" ADD CONSTRAINT "groups_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_attendance" ADD CONSTRAINT "outing_attendance_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_attendance" ADD CONSTRAINT "outing_attendance_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_guests" ADD CONSTRAINT "outing_guests_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_guests" ADD CONSTRAINT "outing_guests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_vote_options" ADD CONSTRAINT "outing_vote_options_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_vote_options" ADD CONSTRAINT "outing_vote_options_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outings" ADD CONSTRAINT "outings_created_by_fkey" FOREIGN KEY ("created_by") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outings" ADD CONSTRAINT "outings_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outings" ADD CONSTRAINT "outings_location_place_id_fkey" FOREIGN KEY ("location_place_id") REFERENCES "places"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outings" ADD CONSTRAINT "outings_suggested_by_user_id_fkey" FOREIGN KEY ("suggested_by_user_id") REFERENCES "users"("id") ON DELETE NO ACTION ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "place_images" ADD CONSTRAINT "place_images_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "place_prices" ADD CONSTRAINT "place_prices_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "user_fcm_tokens" ADD CONSTRAINT "user_fcm_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

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
ALTER TABLE "outing_drafts" ADD CONSTRAINT "outing_drafts_group_id_fkey" FOREIGN KEY ("group_id") REFERENCES "groups"("id") ON DELETE SET NULL ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_drafts" ADD CONSTRAINT "outing_drafts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_votes" ADD CONSTRAINT "outing_votes_option_id_fkey" FOREIGN KEY ("option_id") REFERENCES "outing_vote_options"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_votes" ADD CONSTRAINT "outing_votes_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "outing_votes" ADD CONSTRAINT "outing_votes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "place_hours" ADD CONSTRAINT "place_hours_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "saved_outings" ADD CONSTRAINT "saved_outings_outing_id_fkey" FOREIGN KEY ("outing_id") REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

-- AddForeignKey
ALTER TABLE "saved_outings" ADD CONSTRAINT "saved_outings_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION;

