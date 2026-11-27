BEGIN;

CREATE UNIQUE INDEX meetup_active_standalone_owner ON meetup_sessions(created_by_user_id)
  WHERE status = 'ACTIVE' AND session_type = 'STANDALONE';

CREATE TABLE meetup_manual_participants (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  meetup_session_id uuid NOT NULL REFERENCES meetup_sessions(id) ON DELETE CASCADE,
  display_name varchar(60) CHECK (char_length(btrim(display_name)) BETWEEN 1 AND 60),
  approximate_area varchar(96) CHECK (char_length(btrim(approximate_area)) BETWEEN 1 AND 96),
  latitude double precision NOT NULL CHECK (latitude BETWEEN -90 AND 90),
  longitude double precision NOT NULL CHECK (longitude BETWEEN -180 AND 180),
  transportation_mode transportation_mode,
  created_at timestamptz(6) NOT NULL DEFAULT now(),
  updated_at timestamptz(6) NOT NULL DEFAULT now()
);

CREATE INDEX meetup_manual_participants_meetup_session_id_idx
  ON meetup_manual_participants(meetup_session_id);

COMMIT;
