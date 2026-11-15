-- Additive: no place UUID, ancillary row, or outing/vote reference is replaced.
SET lock_timeout = '5s';
CREATE TABLE IF NOT EXISTS place_brands (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), name varchar(100) NOT NULL,
 normalized_name varchar(200) NOT NULL, identity_key varchar(160) UNIQUE,
 description varchar(1000), logo_url varchar(2048), website varchar(2048),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS place_brand_aliases (
 brand_id uuid NOT NULL REFERENCES place_brands(id) ON DELETE RESTRICT,
 normalized_name varchar(200) NOT NULL, name varchar(100) NOT NULL,
 PRIMARY KEY(brand_id,normalized_name)
);
ALTER TABLE places ADD COLUMN IF NOT EXISTS brand_id uuid REFERENCES place_brands(id) ON DELETE RESTRICT;
ALTER TABLE places ADD COLUMN IF NOT EXISTS branch_name varchar(100);
ALTER TABLE places ADD COLUMN IF NOT EXISTS normalized_name varchar(200) NOT NULL DEFAULT '';
ALTER TABLE places ADD COLUMN IF NOT EXISTS normalized_address varchar(1000) NOT NULL DEFAULT '';
CREATE OR REPLACE FUNCTION normalize_place_text(value text) RETURNS text
LANGUAGE sql IMMUTABLE PARALLEL SAFE AS $$
 SELECT trim(regexp_replace(translate(regexp_replace(lower(normalize(coalesce(value,''), NFKD)),
 '[̀-ًͯ-ٰٟـ]', '', 'g'), 'أإآٱى', 'ااااي'), '[^[:alnum:]]+', ' ', 'g'))
$$;
CREATE OR REPLACE FUNCTION normalize_place_fields() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
 NEW.normalized_name := normalize_place_text(NEW.name);
 NEW.normalized_address := normalize_place_text(NEW.address);
 RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS places_normalized_fields ON places;
CREATE TRIGGER places_normalized_fields BEFORE INSERT OR UPDATE OF name,address ON places
 FOR EACH ROW EXECUTE FUNCTION normalize_place_fields();
UPDATE places SET normalized_name=normalize_place_text(name), normalized_address=normalize_place_text(address)
 WHERE normalized_name IS DISTINCT FROM normalize_place_text(name) OR normalized_address IS DISTINCT FROM normalize_place_text(address);
CREATE INDEX IF NOT EXISTS idx_places_brand_status ON places(brand_id,status);
CREATE INDEX IF NOT EXISTS idx_places_normalized_name ON places(normalized_name);
CREATE INDEX IF NOT EXISTS idx_place_brands_normalized_name ON place_brands(normalized_name);
CREATE INDEX IF NOT EXISTS idx_place_brand_alias_lookup ON place_brand_aliases(normalized_name);
-- source_type is part of the external source namespace (osm:node vs osm:way).
-- Keep existing triple keys; this also enforces identities when source_type is NULL.
CREATE UNIQUE INDEX IF NOT EXISTS places_external_identity_key ON places
 ((source || ':' || coalesce(source_type,'')),source_id) WHERE source_id IS NOT NULL;
-- Only authoritative brand Wikidata identity is sufficient for automatic historical grouping.
-- Equal place names, websites, or nearby coordinates are deliberately insufficient.
INSERT INTO place_brands(name,normalized_name,identity_key)
 SELECT min(left(source_tags->'tags'->>'brand',100)),normalize_place_text(min(left(source_tags->'tags'->>'brand',100))),
 'wikidata:' || (source_tags->'tags'->>'brand:wikidata')
 FROM places WHERE source_tags->'tags'->>'brand:wikidata' ~ '^Q[1-9][0-9]*$'
 AND length(trim(source_tags->'tags'->>'brand'))>1 AND latitude IS NOT NULL AND longitude IS NOT NULL
 GROUP BY source_tags->'tags'->>'brand:wikidata' ON CONFLICT(identity_key) DO NOTHING;
UPDATE places p SET brand_id=b.id FROM place_brands b WHERE p.brand_id IS NULL
 AND b.identity_key='wikidata:' || (p.source_tags->'tags'->>'brand:wikidata')
 AND p.latitude IS NOT NULL AND p.longitude IS NOT NULL;
INSERT INTO place_brand_aliases(brand_id,normalized_name,name)
 SELECT DISTINCT ON (p.brand_id,normalize_place_text(a.name)) p.brand_id,normalize_place_text(a.name),left(a.name,100)
 FROM places p CROSS JOIN LATERAL (VALUES (p.source_tags->'tags'->>'brand'),
 (p.source_tags->'tags'->>'brand:en'),(p.source_tags->'tags'->>'brand:ar')) a(name)
 WHERE p.brand_id IS NOT NULL AND length(normalize_place_text(a.name))>1
 ON CONFLICT DO NOTHING;
-- Existing coordinate-less independent legacy records remain valid.
DO $$ BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_constraint WHERE conname='places_brand_coordinates_check' AND conrelid='places'::regclass) THEN
 ALTER TABLE places ADD CONSTRAINT places_brand_coordinates_check CHECK
 (brand_id IS NULL OR (latitude IS NOT NULL AND longitude IS NOT NULL)) NOT VALID;
 END IF;
END $$;
