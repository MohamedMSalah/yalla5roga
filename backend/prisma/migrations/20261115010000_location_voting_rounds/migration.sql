-- Add round history without changing existing outing, ballot or RSVP values.
ALTER TABLE outings ADD COLUMN current_voting_round integer NOT NULL DEFAULT 1,
 ADD COLUMN resolution_method varchar(24), ADD COLUMN resolved_at timestamptz;
ALTER TABLE outings ADD CONSTRAINT outings_round_positive CHECK(current_voting_round > 0);
CREATE TABLE outing_voting_rounds (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), outing_id uuid NOT NULL REFERENCES outings(id) ON DELETE CASCADE,
 round_number integer NOT NULL CHECK(round_number > 0), starts_at timestamptz NOT NULL DEFAULT now(), ends_at timestamptz,
 status varchar(24) NOT NULL DEFAULT 'active' CHECK(status IN ('active','tie_pending','closed','confirmed','cancelled')),
 created_at timestamptz NOT NULL DEFAULT now(), updated_at timestamptz NOT NULL DEFAULT now(), UNIQUE(outing_id,round_number)
);
CREATE UNIQUE INDEX outing_one_active_round ON outing_voting_rounds(outing_id) WHERE status='active';
CREATE INDEX outing_voting_rounds_status_ends_at_idx ON outing_voting_rounds(status,ends_at);
CREATE TABLE outing_voting_round_options (
 outing_id uuid NOT NULL, round_number integer NOT NULL, option_id uuid NOT NULL,
 vote_count integer NOT NULL DEFAULT 0 CHECK(vote_count >= 0), is_tied boolean NOT NULL DEFAULT false,
 PRIMARY KEY(outing_id,round_number,option_id),
 FOREIGN KEY(outing_id,round_number) REFERENCES outing_voting_rounds(outing_id,round_number) ON DELETE CASCADE,
 FOREIGN KEY(option_id,outing_id) REFERENCES outing_vote_options(id,outing_id) ON DELETE CASCADE
);
INSERT INTO outing_voting_rounds(outing_id,round_number,starts_at,ends_at,status)
 SELECT id,1,created_at,vote_ends_at,CASE WHEN status='confirmed' THEN 'confirmed' WHEN status IN ('cancelled','past') THEN 'closed' WHEN vote_closed_at IS NOT NULL THEN 'tie_pending' ELSE 'active' END FROM outings;
INSERT INTO outing_voting_round_options(outing_id,round_number,option_id,vote_count)
 SELECT o.outing_id,1,o.id,count(v.option_id)::int FROM outing_vote_options o LEFT JOIN outing_votes v ON v.option_id=o.id AND v.outing_id=o.outing_id GROUP BY o.outing_id,o.id;
UPDATE outing_voting_round_options o SET is_tied=true FROM outing_voting_rounds r
 WHERE r.outing_id=o.outing_id AND r.round_number=o.round_number AND r.status='tie_pending'
 AND o.vote_count=(SELECT max(x.vote_count) FROM outing_voting_round_options x WHERE x.outing_id=o.outing_id AND x.round_number=o.round_number);
ALTER TABLE outing_votes ADD COLUMN round_number integer NOT NULL DEFAULT 1;
ALTER TABLE outing_votes DROP CONSTRAINT outing_votes_pkey;
ALTER TABLE outing_votes ADD PRIMARY KEY(outing_id,user_id,option_id,round_number);
ALTER TABLE outing_votes ADD CONSTRAINT outing_votes_round_option_fkey FOREIGN KEY(outing_id,round_number,option_id) REFERENCES outing_voting_round_options(outing_id,round_number,option_id);
ALTER TABLE outings ADD CONSTRAINT outings_current_round_fkey FOREIGN KEY(id,current_voting_round) REFERENCES outing_voting_rounds(outing_id,round_number) DEFERRABLE INITIALLY DEFERRED;
-- New outings initialize round 1 in the same transaction, including legacy callers.
CREATE FUNCTION initialize_outing_voting_round() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 INSERT INTO outing_voting_rounds(outing_id,round_number,starts_at,ends_at,status) VALUES(NEW.id,1,NEW.created_at,NEW.vote_ends_at,CASE WHEN NEW.status='confirmed' THEN 'confirmed' ELSE 'active' END);
 RETURN NEW; END $$;
CREATE TRIGGER outing_voting_round_init AFTER INSERT ON outings FOR EACH ROW EXECUTE FUNCTION initialize_outing_voting_round();
CREATE FUNCTION initialize_outing_round_option() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
 INSERT INTO outing_voting_round_options(outing_id,round_number,option_id) VALUES(NEW.outing_id,1,NEW.id);
 RETURN NEW; END $$;
CREATE TRIGGER outing_round_option_init AFTER INSERT ON outing_vote_options FOR EACH ROW EXECUTE FUNCTION initialize_outing_round_option();
