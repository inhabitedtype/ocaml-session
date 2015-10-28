(** Session-related signatures and types. *)

open Result


(** The type of a session error.

    These will only be returned by the {!val:S.Now.get} and {!val:S.Future.get}
    operations. *)
type error =
  | Not_found   (** The key was not found. *)
  | Not_set     (** The key was found but had no associated value. *)
  | Expired     (** The key has expired. It may still be in the backend. *)

(** The signature for synchronous backends.

    This signature should be used for backends that don't expose an
    asynchronous interface, such as an in-memory backend or a backend that only
    has a blocking interface. *)
module type Now = sig
  type t
  (** The type of a handle on the backend. *)

  type key
  (** The type of a session key. *)

  type value
  (** The type of a session value. *)

  type period
  (** The type of a session expiry period. *)

  val default_period : t -> period
  (** [default_period t] returns default period after which session keys will
      expire. Depending on the backend, this value may vary over time. *)

  val generate : ?expiry:period -> ?value:value -> t -> key
  (** [generate ?expiry ?value t] will allocate a new session in the backend
      [t] and return its associated [key]. The session will expire [expiry]
      seconds from now, defaulting to [default_period t] if one is not
      explicitly specified.

      The key should be unique, though it may not be in order to allow
      implementations that use randomness or hashing to conform to this
      interface. *)

  val clear : t -> key -> unit
  (** [clear t key] removes [key] from the backend [t]. The backend may choose
      to persist the session value beyond this call, but any subsequent calls
      operations involving [key] should behave as if [key] is not present in
      the backend. *)

  val get : t -> key -> (value * period, error) result
  (** [get t key] returns the session value, if present and unexpired, together
      with its expiry period as of now. *)

  val set : ?expiry:period -> t -> key -> value -> unit
  (** [set ?expiry t key value] sets the [value] for the session associated
      [key] in backend [t] and sets the session to expire [expiry] seconds from
      now. If [expiry] is not provided, the expiry period reported by
      [default_period t] will be used instead. *)
end

(** The signature for a blocking computations. *)
module type IO = sig
  type +'a t
  (** The type of blocking computation that will produce a value of type ['a] *)

  val return : 'a -> 'a t
  val (>>=) : 'a t -> ('a -> 'b t) -> 'b t
end

(** The signature for asynchronous backends. *)
module type Future = sig
  type +'a io
  (** The type of a blocking computation that will produce a value of type ['a] *)

  type t
  (** The type of a handle on the backend. *)

  type key
  (** The type of a session key. *)

  type value
  (** The type of a session value. *)

  type period
  (** The type of a session expiry period. *)

  val default_period : t -> period
  (** [default_period t] returns default period after which session keys will
      expire. Depending on the backend, this value may vary over time. *)

  val generate : ?expiry:period -> ?value:value -> t -> key io
  (** [generate ?expiry ?value t] will allocate a new session in the backend
      [t] and return its associated [key]. The session will expire [expiry]
      seconds from now, defaulting to [default_period t] if one is not
      explicitly specified.

      The key should be unique, though it may not be in order to allow
      implementations that use randomness or hashing to conform to this
      interface. *)

  val clear : t -> key -> unit io
  (** [clear t key] removes [key] from the backend [t]. The backend may choose
      to persist the session value beyond this call. If it does any subsequent
      operations involving [key] behave as if it was not there. *)

  val get : t -> key -> (value * period, error) result io
  (** [get t key] returns the session value, if present and unexpired, together
      with its expiry period as of now. *)

  val set : ?expiry:period -> t -> key -> value -> unit io
  (** [set ?expiry t key value] sets the [value] for the session associated
      [key] in backend [t] and sets the session to expire [expiry] seconds from
      now. If [expiry] is not provided, the expiry period reported by
      [default_period t] will be used instead. *)
end
