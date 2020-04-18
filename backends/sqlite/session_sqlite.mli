(** SQLite3 backend *)

include Session.S.Now with
  type key = string and
  type value = string and
  type period = Int64.t

val create : Sqlite3.db -> t
