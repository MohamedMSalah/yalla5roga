BEGIN;
CREATE TYPE meetup_session_type AS ENUM ('GROUP', 'STANDALONE');
CREATE TYPE meetup_session_status AS ENUM ('ACTIVE', 'CANCELLED', 'EXPIRED');
CREATE TYPE meetup_calculation_status AS ENUM ('ROUTING_UNAVAILABLE', 'INSUFFICIENT_DATA', 'QUEUED', 'CALCULATING', 'READY', 'PARTIAL', 'STALE', 'FAILED');
CREATE TYPE meetup_optimization AS ENUM ('BALANCED', 'SHORTEST_TOTAL_TIME');

CREATE TABLE meetup_sessions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  session_type meetup_session_type NOT NULL,
  group_id uuid REFERENCES groups(id) ON DELETE CASCADE,
  outing_id uuid REFERENCES outings(id) ON DELETE CASCADE,
  created_by_user_id varchar(128) NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status meetup_session_status NOT NULL DEFAULT 'ACTIVE',
  calculation_status meetup_calculation_status NOT NULL DEFAULT 'ROUTING_UNAVAILABLE',
  optimization meetup_optimization NOT NULL DEFAULT 'BALANCED',
  input_version integer NOT NULL DEFAULT 1 CHECK (input_version > 0),
  input_digest char(64),
  created_at timestamptz(6) NOT NULL DEFAULT now(),
  updated_at timestamptz(6) NOT NULL DEFAULT now(),
  expires_at timestamptz(6) NOT NULL,
  CHECK ((session_type = 'GROUP') = (group_id IS NOT NULL))
);
CREATE INDEX meetup_sessions_group_id_status_idx ON meetup_sessions(group_id, status);
CREATE INDEX meetup_sessions_created_by_user_id_idx ON meetup_sessions(created_by_user_id);
CREATE INDEX meetup_sessions_outing_id_idx ON meetup_sessions(outing_id);
CREATE INDEX meetup_sessions_expires_at_idx ON meetup_sessions(expires_at);
CREATE UNIQUE INDEX meetup_active_group ON meetup_sessions(group_id)
  WHERE status = 'ACTIVE' AND session_type = 'GROUP' AND outing_id IS NULL;
CREATE UNIQUE INDEX meetup_active_group_outing ON meetup_sessions(group_id, outing_id)
  WHERE status = 'ACTIVE' AND session_type = 'GROUP' AND outing_id IS NOT NULL;
COMMIT;
