CREATE INDEX CONCURRENTLY "idx_places_catalog_updated"
    ON "places"("status", "is_active", "updated_at" DESC, "id");
