(** In-memory backend using the {!S.Now} signature.

    The default expiry period is one week. *)

include S.Now
  with type key = string
   and type value = string
   and type period = int64

val create : unit -> t
(** [create ()] returns the handle on a new in-memory store. *)

val set_default_period : t -> period -> unit
(** [set_default_period t period] sets the default expiry period of [t]. This
    will only affect future operations. *)
