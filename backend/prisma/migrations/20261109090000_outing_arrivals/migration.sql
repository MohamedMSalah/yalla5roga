CREATE TABLE "outing_arrivals" (
    "outing_id" UUID NOT NULL,
    "user_id" VARCHAR(128) NOT NULL,
    "arrived_at" TIMESTAMPTZ(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "outing_arrivals_pkey" PRIMARY KEY ("outing_id", "user_id"),
    CONSTRAINT "outing_arrivals_outing_id_fkey" FOREIGN KEY ("outing_id")
        REFERENCES "outings"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
    CONSTRAINT "outing_arrivals_user_id_fkey" FOREIGN KEY ("user_id")
        REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE NO ACTION
);
CREATE INDEX "idx_outing_arrivals_user" ON "outing_arrivals"("user_id");

ALTER TABLE "outings" ADD COLUMN "create_request_key" VARCHAR(80);
CREATE UNIQUE INDEX "uq_outings_creator_request"
    ON "outings"("created_by", "create_request_key");
