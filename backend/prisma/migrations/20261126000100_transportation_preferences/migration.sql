CREATE TYPE "transportation_mode" AS ENUM ('CAR', 'MOTORCYCLE', 'METRO', 'WALKING');

ALTER TABLE "users" ADD COLUMN "default_transportation_mode" "transportation_mode";
ALTER TABLE "saved_locations" ADD COLUMN "preferred_transportation_mode" "transportation_mode";
ALTER TABLE "saved_places" ADD COLUMN "preferred_transportation_mode" "transportation_mode";
