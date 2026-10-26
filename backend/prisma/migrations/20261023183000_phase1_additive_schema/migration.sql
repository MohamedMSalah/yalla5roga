-- AlterEnum
ALTER TYPE "invitation_status" ADD VALUE 'declined' AFTER 'accepted';

-- AlterEnum
ALTER TYPE "outing_status" ADD VALUE 'cancelled';

-- AlterTable
ALTER TABLE "chat_messages" ADD COLUMN     "client_message_id" UUID;

-- AlterTable
ALTER TABLE "groups" ALTER COLUMN "image_url" SET DEFAULT '';

-- AlterTable
ALTER TABLE "outings" ADD COLUMN     "ends_at" TIMESTAMPTZ(6);

-- AlterTable
ALTER TABLE "places" ADD COLUMN     "is_active" BOOLEAN NOT NULL DEFAULT true;

-- CreateIndex
CREATE UNIQUE INDEX "uq_chat_messages_client_msg" ON "chat_messages"("outing_id", "sender_id", "client_message_id");

-- CreateIndex
CREATE INDEX "idx_outing_guests_user" ON "outing_guests"("user_id");

-- CreateIndex
CREATE INDEX "idx_outings_created_by" ON "outings"("created_by");

-- CreateIndex
CREATE INDEX "idx_place_images_place" ON "place_images"("place_id", "sort_order");

-- CreateIndex
CREATE INDEX "idx_place_prices_place" ON "place_prices"("place_id");

-- CreateIndex
CREATE INDEX "idx_places_lat_lng" ON "places"("latitude", "longitude");
