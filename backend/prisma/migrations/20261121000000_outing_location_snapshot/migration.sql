BEGIN;

ALTER TABLE outings
  ADD COLUMN location_category_id varchar(64),
  ADD COLUMN location_address varchar(500);
ALTER TABLE outing_vote_options
  ADD COLUMN category_id varchar(64),
  ADD COLUMN address varchar(500);

COMMIT;
