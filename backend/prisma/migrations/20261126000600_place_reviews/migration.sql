BEGIN;
SET LOCAL lock_timeout = '5s';

CREATE TYPE place_review_visibility AS ENUM ('visible', 'hidden');
CREATE TYPE place_review_report_reason AS ENUM ('spam', 'harassment', 'inappropriate', 'off_topic', 'other');
CREATE TYPE place_review_report_status AS ENUM ('open', 'dismissed', 'actioned');

CREATE TABLE place_reviews (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  place_id uuid NOT NULL REFERENCES places(id) ON DELETE RESTRICT ON UPDATE NO ACTION,
  user_id varchar(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE NO ACTION,
  rating integer NOT NULL CHECK (rating BETWEEN 1 AND 5),
  review_text varchar(1000) CHECK (review_text IS NULL OR review_text ~ '[^[:space:]]'),
  moderation_status place_review_visibility NOT NULL DEFAULT 'visible',
  created_at timestamptz(3) NOT NULL DEFAULT now(),
  updated_at timestamptz(3) NOT NULL DEFAULT now(),
  UNIQUE (place_id, user_id)
);
CREATE INDEX idx_place_reviews_visibility ON place_reviews (place_id, moderation_status);
CREATE INDEX idx_place_reviews_page ON place_reviews (place_id, created_at DESC, id DESC);
CREATE INDEX idx_place_reviews_user ON place_reviews (user_id);

CREATE TABLE place_rating_statistics (
  place_id uuid PRIMARY KEY REFERENCES places(id) ON DELETE CASCADE ON UPDATE NO ACTION,
  rating_sum integer NOT NULL DEFAULT 0,
  rating_count integer NOT NULL DEFAULT 0,
  written_review_count integer NOT NULL DEFAULT 0,
  one_star_count integer NOT NULL DEFAULT 0,
  two_star_count integer NOT NULL DEFAULT 0,
  three_star_count integer NOT NULL DEFAULT 0,
  four_star_count integer NOT NULL DEFAULT 0,
  five_star_count integer NOT NULL DEFAULT 0,
  updated_at timestamptz(3) NOT NULL DEFAULT now(),
  CHECK (
    least(one_star_count, two_star_count, three_star_count, four_star_count, five_star_count) >= 0
    AND written_review_count BETWEEN 0 AND rating_count
    AND rating_count = one_star_count + two_star_count + three_star_count + four_star_count + five_star_count
    AND rating_sum = one_star_count + 2 * two_star_count + 3 * three_star_count + 4 * four_star_count + 5 * five_star_count
  )
);

CREATE INDEX idx_place_rating_statistics_updated ON place_rating_statistics (updated_at DESC);

CREATE TABLE place_review_reports (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id uuid NOT NULL REFERENCES place_reviews(id) ON DELETE CASCADE ON UPDATE NO ACTION,
  reporter_id varchar(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE NO ACTION,
  reason place_review_report_reason NOT NULL,
  status place_review_report_status NOT NULL DEFAULT 'open',
  created_at timestamptz(3) NOT NULL DEFAULT now(),
  updated_at timestamptz(3) NOT NULL DEFAULT now(),
  UNIQUE (review_id, reporter_id)
);
CREATE INDEX idx_place_review_reports_status ON place_review_reports (status, created_at DESC, id DESC);
CREATE INDEX idx_place_review_reports_reporter ON place_review_reports (reporter_id);

CREATE TABLE place_review_blocks (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  viewer_id varchar(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE NO ACTION,
  author_id varchar(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE ON UPDATE NO ACTION,
  created_at timestamptz(3) NOT NULL DEFAULT now(),
  CHECK (viewer_id <> author_id),
  UNIQUE (viewer_id, author_id)
);
CREATE INDEX idx_place_review_blocks_author ON place_review_blocks (author_id);

CREATE FUNCTION apply_place_review_statistics() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
  branch uuid;
  old_rating integer := 0;
  new_rating integer := 0;
  old_written integer := 0;
  new_written integer := 0;
BEGIN
  IF TG_OP = 'UPDATE' AND (NEW.place_id, NEW.user_id, NEW.id, NEW.created_at)
    IS DISTINCT FROM (OLD.place_id, OLD.user_id, OLD.id, OLD.created_at) THEN
    RAISE EXCEPTION 'Review identity and creation time are immutable';
  END IF;

  IF TG_OP <> 'INSERT' AND OLD.moderation_status = 'visible' THEN
    old_rating := OLD.rating;
    old_written := (OLD.review_text IS NOT NULL)::integer;
  END IF;
  IF TG_OP <> 'DELETE' AND NEW.moderation_status = 'visible' THEN
    new_rating := NEW.rating;
    new_written := (NEW.review_text IS NOT NULL)::integer;
  END IF;
  IF (old_rating, old_written) = (new_rating, new_written) THEN
    RETURN NULL;
  END IF;

  branch := CASE WHEN TG_OP = 'DELETE' THEN OLD.place_id ELSE NEW.place_id END;
  INSERT INTO place_rating_statistics(place_id) VALUES (branch) ON CONFLICT DO NOTHING;
  UPDATE place_rating_statistics SET
    rating_sum = rating_sum + new_rating - old_rating,
    rating_count = rating_count + (new_rating > 0)::integer - (old_rating > 0)::integer,
    written_review_count = written_review_count + new_written - old_written,
    one_star_count = one_star_count + (new_rating = 1)::integer - (old_rating = 1)::integer,
    two_star_count = two_star_count + (new_rating = 2)::integer - (old_rating = 2)::integer,
    three_star_count = three_star_count + (new_rating = 3)::integer - (old_rating = 3)::integer,
    four_star_count = four_star_count + (new_rating = 4)::integer - (old_rating = 4)::integer,
    five_star_count = five_star_count + (new_rating = 5)::integer - (old_rating = 5)::integer,
    updated_at = greatest(clock_timestamp()::timestamptz(3), updated_at + interval '1 millisecond')
  WHERE place_id = branch;
  RETURN NULL;
END;
$$;

CREATE TRIGGER place_reviews_statistics AFTER INSERT OR UPDATE OR DELETE ON place_reviews
  FOR EACH ROW EXECUTE FUNCTION apply_place_review_statistics();

CREATE FUNCTION record_place_rating_catalog_change() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (to_jsonb(OLD) - 'updated_at') = (to_jsonb(NEW) - 'updated_at') THEN
    RETURN NULL;
  END IF;
  PERFORM mark_place_catalog_change('place',
    (CASE WHEN TG_OP = 'DELETE' THEN OLD.place_id ELSE NEW.place_id END)::text);
  PERFORM pg_notify('places_catalog_changed', 'changed');
  RETURN NULL;
END;
$$;

CREATE TRIGGER place_rating_statistics_catalog_change
  AFTER UPDATE OR DELETE ON place_rating_statistics
  FOR EACH ROW EXECUTE FUNCTION record_place_rating_catalog_change();
-- A newly repaired row can be nonzero. The trigger's empty bootstrap rows are ignored.
CREATE TRIGGER place_rating_statistics_catalog_insert
  AFTER INSERT ON place_rating_statistics FOR EACH ROW WHEN (NEW.rating_count > 0)
  EXECUTE FUNCTION record_place_rating_catalog_change();

COMMIT;
