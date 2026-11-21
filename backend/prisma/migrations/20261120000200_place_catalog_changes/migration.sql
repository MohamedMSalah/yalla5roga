BEGIN;

-- A pending transaction can have a lower xid than a committed transaction.
-- Readers only cross revisions strictly below the statement snapshot's xmin.
CREATE TABLE place_catalog_changes (
  kind text NOT NULL,
  entity_id text NOT NULL,
  revision xid8 NOT NULL DEFAULT pg_current_xact_id(),
  PRIMARY KEY (kind, entity_id)
);
CREATE INDEX idx_place_catalog_changes_revision
  ON place_catalog_changes (revision, kind, entity_id);

CREATE FUNCTION mark_place_catalog_change(change_kind text, change_id text)
RETURNS void LANGUAGE sql AS $$
  INSERT INTO place_catalog_changes (kind, entity_id)
  VALUES (change_kind, change_id)
  ON CONFLICT (kind, entity_id)
  DO UPDATE SET revision = pg_current_xact_id()
  WHERE place_catalog_changes.revision <> pg_current_xact_id();
$$;

CREATE FUNCTION record_place_catalog_change() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  old_row jsonb;
  new_row jsonb;
  old_id text;
  new_id text;
BEGIN
  old_row := to_jsonb(OLD);
  new_row := to_jsonb(NEW);
  IF TG_OP = 'UPDATE' AND TG_TABLE_NAME = 'places' AND
     (old_row - ARRAY['updated_at','last_seen_at','last_synced_at','missing_sync_count','source_tags','normalized_name','normalized_address']) =
     (new_row - ARRAY['updated_at','last_seen_at','last_synced_at','missing_sync_count','source_tags','normalized_name','normalized_address']) THEN
    RETURN NULL;
  END IF;
  IF TG_OP = 'UPDATE' AND (
     (TG_TABLE_NAME = 'place_brands' AND
       old_row -> 'id' = new_row -> 'id' AND old_row -> 'name' = new_row -> 'name') OR
     (TG_TABLE_NAME IN ('place_categories', 'vibes') AND
       old_row - 'updated_at' = new_row - 'updated_at') OR
     (TG_TABLE_NAME = 'place_vibes' AND
       old_row -> 'place_id' = new_row -> 'place_id' AND old_row -> 'vibe_id' = new_row -> 'vibe_id')
  ) THEN
    RETURN NULL;
  END IF;
  old_id := old_row ->> TG_ARGV[1];
  new_id := new_row ->> TG_ARGV[1];
  IF old_id IS NOT NULL AND old_id IS DISTINCT FROM new_id THEN
    PERFORM mark_place_catalog_change(TG_ARGV[0], old_id);
  END IF;
  IF new_id IS NOT NULL THEN
    PERFORM mark_place_catalog_change(TG_ARGV[0], new_id);
  END IF;
  RETURN NULL;
END;
$$;

CREATE TRIGGER places_catalog_change AFTER INSERT OR UPDATE OR DELETE ON places
  FOR EACH ROW EXECUTE FUNCTION record_place_catalog_change('place', 'id');
CREATE TRIGGER images_catalog_change AFTER INSERT OR UPDATE OR DELETE ON place_images
  FOR EACH ROW EXECUTE FUNCTION record_place_catalog_change('place', 'place_id');
CREATE TRIGGER prices_catalog_change AFTER INSERT OR UPDATE OR DELETE ON place_prices
  FOR EACH ROW EXECUTE FUNCTION record_place_catalog_change('place', 'place_id');
CREATE TRIGGER hours_catalog_change AFTER INSERT OR UPDATE OR DELETE ON place_hours
  FOR EACH ROW EXECUTE FUNCTION record_place_catalog_change('place', 'place_id');
CREATE TRIGGER place_vibes_catalog_change AFTER INSERT OR UPDATE OR DELETE ON place_vibes
  FOR EACH ROW EXECUTE FUNCTION record_place_catalog_change('place', 'place_id');
CREATE TRIGGER brands_catalog_change AFTER INSERT OR UPDATE OR DELETE ON place_brands
  FOR EACH ROW EXECUTE FUNCTION record_place_catalog_change('brand', 'id');
CREATE TRIGGER categories_catalog_change AFTER INSERT OR UPDATE OR DELETE ON place_categories
  FOR EACH ROW EXECUTE FUNCTION record_place_catalog_change('category', 'id');
CREATE TRIGGER vibes_catalog_change AFTER INSERT OR UPDATE OR DELETE ON vibes
  FOR EACH ROW EXECUTE FUNCTION record_place_catalog_change('vibe', 'id');

INSERT INTO place_catalog_changes (kind, entity_id)
SELECT 'place', id::text FROM places WHERE is_active AND status = 'active'
UNION ALL SELECT 'brand', id::text FROM place_brands
UNION ALL SELECT 'category', id FROM place_categories
UNION ALL SELECT 'vibe', id FROM vibes
ON CONFLICT DO NOTHING;

COMMIT;
