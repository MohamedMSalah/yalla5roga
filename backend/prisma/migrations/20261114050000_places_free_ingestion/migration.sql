-- AlterTable
ALTER TABLE "places" ALTER COLUMN "source_id" SET DATA TYPE VARCHAR(128);

-- Replace only the old check, preserving rows and all place relationships.
ALTER TABLE places DROP CONSTRAINT places_source_check;
ALTER TABLE places ADD CONSTRAINT places_source_check CHECK (
  source IN ('manual','osm','overture') AND
  (source='manual' OR (source_id IS NOT NULL AND source_region IN ('EG-C','EG-GZ') AND
    ((source='osm' AND source_type IN ('node','way','relation')) OR
     (source='overture' AND source_type='place')))));

-- AlterTable
ALTER TABLE "place_vibes" ADD COLUMN     "confidence" DOUBLE PRECISION,
ADD COLUMN     "evidence" JSONB NOT NULL DEFAULT '{}';
ALTER TABLE place_vibes ADD CONSTRAINT place_vibes_confidence_check CHECK(confidence BETWEEN 0 AND 1);

-- AlterTable
ALTER TABLE "place_sync_runs" ADD COLUMN     "processed_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "source" VARCHAR(16) NOT NULL DEFAULT 'osm';

-- AlterTable
ALTER TABLE "place_images" ADD COLUMN     "attribution" VARCHAR(1000),
ADD COLUMN     "license" VARCHAR(128),
ADD COLUMN     "source" VARCHAR(16) NOT NULL DEFAULT 'manual',
ADD COLUMN     "source_url" VARCHAR(2048);

-- AlterTable
ALTER TABLE "place_prices" ADD COLUMN     "evidence" JSONB NOT NULL DEFAULT '{}',
ADD COLUMN     "source" VARCHAR(16) NOT NULL DEFAULT 'manual';

-- AlterTable
ALTER TABLE "place_hours" ADD COLUMN     "expression" VARCHAR(1000),
ADD COLUMN     "source" VARCHAR(16) NOT NULL DEFAULT 'manual';

-- CreateTable
CREATE TABLE "place_sync_logs" (
    "id" UUID NOT NULL DEFAULT gen_random_uuid(),
    "run_id" UUID NOT NULL,
    "level" VARCHAR(16) NOT NULL,
    "code" VARCHAR(64) NOT NULL,
    "source_id" VARCHAR(160),
    "details" JSONB NOT NULL DEFAULT '{}',
    "created_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "place_sync_logs_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "place_source_records" (
    "source" VARCHAR(16) NOT NULL,
    "source_type" VARCHAR(16) NOT NULL,
    "source_id" VARCHAR(128) NOT NULL,
    "place_id" UUID NOT NULL,
    "release" VARCHAR(128) NOT NULL,
    "region" VARCHAR(16) NOT NULL,
    "license" VARCHAR(128) NOT NULL,
    "attribution" VARCHAR(1000) NOT NULL,
    "evidence" JSONB NOT NULL,
    "last_seen_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "missing_count" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "place_source_records_pkey" PRIMARY KEY ("source","source_type","source_id")
);

-- CreateIndex
CREATE INDEX "idx_place_sync_logs_run" ON "place_sync_logs"("run_id", "created_at");

-- CreateIndex
CREATE INDEX "idx_place_sources_place" ON "place_source_records"("place_id");

-- CreateIndex
CREATE INDEX "idx_place_sources_coverage" ON "place_source_records"("source", "region", "last_seen_at");

-- AddForeignKey
ALTER TABLE "place_sync_logs" ADD CONSTRAINT "place_sync_logs_run_id_fkey" FOREIGN KEY ("run_id") REFERENCES "place_sync_runs"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "place_source_records" ADD CONSTRAINT "place_source_records_place_id_fkey" FOREIGN KEY ("place_id") REFERENCES "places"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
