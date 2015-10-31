CREATE TABLE IF NOT EXISTS session (
  session_key       char(40),
  created_on        timestamp (2) with time zone    DEFAULT NOW(),
  expire_date       timestamp (2) with time zone,
  session_data      text
);

CREATE INDEX session_key_idx ON session (session_key);
