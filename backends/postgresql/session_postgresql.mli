(** PostgreSQL backend using the {!Session.S.Now} signature.

    The default expiry period is one week. The code expects the following
    table and index to be in place:

{v CREATE TABLE IF NOT EXISTS session (
  session_key       char(40),
  expire_date       timestamp (2) with time zone,
  session_data      text
);

CREATE INDEX session_key_idx ON session (session_key); v} *)

include Session.S.Now
  with type t = Postgresql.connection
   and type key = string
   and type value = string
   and type period = int64

val connect :
  ?host:string ->
  ?hostaddr:string ->
  ?port:string ->
  ?dbname:string ->
  ?user:string ->
  ?password:string ->
  ?options:string ->
  ?tty:string ->
  ?requiressl:string ->
  ?conninfo:string ->
  ?startonly:bool ->
  unit -> t
(** Create a connection to a postgresql database.

    This is an alias for the connection constructor. If you have an existing
    connection to a database with the appropriate tables set up, you are more
    than welcome to use it. *)

val set_default_period : t -> period -> unit
(** [set_default_period t period] sets the default expiry period of [t]. This
    will only affect future operations. *)
