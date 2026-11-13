-- Media assets: metadata rows for objects stored in Cloudflare R2.
-- Additive migration — no existing tables or rows are modified.

CREATE TYPE "media_visibility" AS ENUM ('public', 'private');
CREATE TYPE "media_status" AS ENUM ('pending', 'ready', 'failed');
CREATE TYPE "media_purpose" AS ENUM ('profile', 'group', 'outing', 'place', 'chat');

CREATE TABLE "media_assets" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "object_key" VARCHAR(512) NOT NULL,
    "bucket" VARCHAR(255) NOT NULL,
    "mime_type" VARCHAR(100) NOT NULL,
    "file_size" INTEGER NOT NULL,
    "visibility" "media_visibility" NOT NULL DEFAULT 'private',
    "status" "media_status" NOT NULL DEFAULT 'pending',
    "owner_id" VARCHAR(128) NOT NULL,
    "purpose" "media_purpose" NOT NULL,
    "user_id" VARCHAR(128),
    "group_id" UUID,
    "outing_id" UUID,
    "place_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "verified_at" TIMESTAMPTZ(6),
    "upload_expires_at" TIMESTAMPTZ(6),

    CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id")
);

-- Owner rows cascade with the account; entity links are soft (SetNull) so
-- historical media metadata survives group/outing/place deletion.
ALTER TABLE "media_assets"
  ADD CONSTRAINT "media_assets_owner_id_fkey"
  FOREIGN KEY ("owner_id") REFERENCES "users"("id")
  ON DELETE CASCADE ON UPDATE NO ACTION;

ALTER TABLE "media_assets"
  ADD CONSTRAINT "media_assets_user_id_fkey"
  FOREIGN KEY ("user_id") REFERENCES "users"("id")
  ON DELETE SET NULL ON UPDATE NO ACTION;

ALTER TABLE "media_assets"
  ADD CONSTRAINT "media_assets_group_id_fkey"
  FOREIGN KEY ("group_id") REFERENCES "groups"("id")
  ON DELETE SET NULL ON UPDATE NO ACTION;

ALTER TABLE "media_assets"
  ADD CONSTRAINT "media_assets_outing_id_fkey"
  FOREIGN KEY ("outing_id") REFERENCES "outings"("id")
  ON DELETE SET NULL ON UPDATE NO ACTION;

ALTER TABLE "media_assets"
  ADD CONSTRAINT "media_assets_place_id_fkey"
  FOREIGN KEY ("place_id") REFERENCES "places"("id")
  ON DELETE SET NULL ON UPDATE NO ACTION;

CREATE UNIQUE INDEX "media_assets_object_key_key" ON "media_assets"("object_key");
CREATE INDEX "idx_media_assets_owner" ON "media_assets"("owner_id");
CREATE INDEX "idx_media_assets_cleanup" ON "media_assets"("status","upload_expires_at");
CREATE INDEX "idx_media_assets_user" ON "media_assets"("user_id");
CREATE INDEX "idx_media_assets_group" ON "media_assets"("group_id");
CREATE INDEX "idx_media_assets_outing" ON "media_assets"("outing_id");
CREATE INDEX "idx_media_assets_place" ON "media_assets"("place_id");
