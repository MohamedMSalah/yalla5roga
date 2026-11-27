CREATE TYPE "saved_location_type" AS ENUM ('home', 'work', 'university', 'gym', 'custom');

CREATE TABLE "saved_locations" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "user_id" VARCHAR(128) NOT NULL,
    "name" VARCHAR(100) NOT NULL,
    "location_type" "saved_location_type" NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "approximate_area" VARCHAR(100),
    "address" VARCHAR(1000),
    "place_id" UUID,
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "saved_locations_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "saved_locations_name_check" CHECK (length(btrim("name")) > 0),
    CONSTRAINT "saved_locations_coordinates_check" CHECK (
        "latitude" BETWEEN -90 AND 90 AND "longitude" BETWEEN -180 AND 180
    ),
    CONSTRAINT "saved_locations_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "saved_locations_place_id_fkey"
        FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE SET NULL ON UPDATE NO ACTION
);

CREATE UNIQUE INDEX "saved_locations_user_id_id_key" ON "saved_locations"("user_id", "id");
CREATE INDEX "idx_saved_locations_user_created" ON "saved_locations"("user_id", "created_at" DESC, "id");
CREATE INDEX "idx_saved_locations_place" ON "saved_locations"("place_id");

CREATE TABLE "default_starting_locations" (
    "user_id" VARCHAR(128) NOT NULL,
    "saved_location_id" UUID,
    "saved_place_id" UUID,
    "updated_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "default_starting_locations_pkey" PRIMARY KEY ("user_id"),
    CONSTRAINT "default_starting_locations_source_check" CHECK (
        num_nonnulls("saved_location_id", "saved_place_id") = 1
    ),
    CONSTRAINT "default_starting_locations_user_id_fkey"
        FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "default_starting_locations_personal_fkey"
        FOREIGN KEY ("user_id", "saved_location_id") REFERENCES "saved_locations"("user_id", "id")
        ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "default_starting_locations_bookmark_fkey"
        FOREIGN KEY ("user_id", "saved_place_id") REFERENCES "saved_places"("user_id", "place_id")
        ON DELETE CASCADE ON UPDATE NO ACTION
);
