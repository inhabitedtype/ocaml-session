CREATE TABLE IF NOT EXISTS session (
  session_key       char(40),
  expire_date       timestamp (2) with time zone,
  session_data      text
);

CREATE INDEX session_key_idx ON session (session_key);
