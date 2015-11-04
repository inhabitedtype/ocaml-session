(** PostgreSQL backend using the {!Session.S.Future} signature with Async.

    The default expiry period is one week. The code expects the following table
    and index to be in pace:

{v CREATE TABLE IF NOT EXISTS session (
  session_key       char(40),
  expire_date       timestamp (2) with time zone,
  session_data      text
);

CREATE INDEX session_key_idx ON session (session_key); v}

    Note that this module does not do utilize non-blocking IO but instead runs
    each synchronous operation in a thread. *)

open Async.Std

include Session.S.Future
  with type t = Postgresql.connection
   and type +'a io = 'a Deferred.t
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
  unit -> t Deferred.t
(** Create a connection to a postgresql database.

    This is an alias for the connection constructor. If you have an existing
    connection to a database with the appropriate tables set up, you are more
    than welcome to use it. *)

val set_default_period : t -> period -> unit
(** [set_default_period t period] sets the default expiry period of [t]. This
    will only affect future operations. *)


(** PostgreSQL backend using the {!Session.S.Future} siganture with Aysnc,
    together with connection pooling via a [Throttle] *)
module Pool : sig
  include Session.S.Future
    with type key = string
     and type value = string
     and type period = int64

  val of_throttle : Postgresql.connection Throttle.t -> t
  (** Createa a connection pool from a connection throttle. *)

  val set_default_period : t -> period -> unit
  (** [set_default_period t period] sets the default expiry period of [t]. This
      will only affect future operations. *)
end
