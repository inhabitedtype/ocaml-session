(** Cohttp-aware session management for your everyday needs. *)

open Cohttp
open Result

(** The signature for a Cohttp-compatible backend. *)
module type Backend = Session.S.Future
  with type key = string
   and type value = string
   and type period = int64

(** The signature for a Cohttp session manager. *)
module type S = sig
  type +'a io
  (** The type of a blocking computation that will produce a value of type ['a] *)

  type backend
  (** The type of a handle on the store. *)

  type key
  (** The type of a session key. *)

  type value
  (** The type of a session value. *)

  type period
  (** The type of a session expiry period. *)

  type t = private
    { key : key  (** They key for the session in the backend and in cookies. *)
    ; mutable value : value (** The value for the session stored in the backend. *)
    ; mutable expiry_period : period (** The period from now in seconds that the session will expire. *)
    ; mutable modified : bool (** Whether the session data or expiry have been modified *)
    }
  (** The session type.

      This type is marked private, so the record fields can be accessed and
      pattern-matched as usual. However, values of this type cannot be
      constructed directly. To create a new session, use {!generate}. To
      retrieve an existing [session], use {!of_key} or {!of_header}. To modify
      {!expiry_period} or {!value}, use {!set}. Finally, use {!to_cookie_hdr}
      to smartly generate [Set-Cookie] and related headers. *)

  val of_key : backend -> key -> (t, Session.S.error) result io
  (** [of_key backend key] fetches the session associated with [key] from the
      backend, if present and unexpired. *)

  val of_header : backend -> string -> Header.t -> (t option, Session.S.error) result io
  (** [of_header backend cookie_key header] retrieves the session key from
      the cookies in [header]. If [cookie_key] is not present in any cookies in
      [header], then this function will return [None]. If a session key is
      found, it will call [{!val:of_key} backend key]. If both lookups were
      successful, then this function will return [Some session]. If no key was
      found in [header], it will return [None]. *)

  val of_header_or_create : ?expiry:period -> backend -> string -> string -> Header.t -> t io
  (** [of_header_or_create ?expiry backend cookie_key default header] retrieves
      the session key from the cookies in [header]. If [cookie_key] is not
      present in any cookies in the [header] or if the session is not a valid
      one, a new session will be using [expiry] for the expiration period and
      [default] as the value. *)

  val to_cookie_hdrs :
    ?discard:bool -> ?path:string -> ?domain:string ->
    ?secure:bool -> ?http_only:bool ->
    string -> t -> (string * string) list
  (** [to_cookie_hdr cookie_key session] will generate response
      headers to communicate session changes to the client. This function takes
      into account the {!modified} field of the {{!type:t}session} type, and
      will not generate headers if they are not needed. *)

  val clear_hdrs :
    ?path:string -> ?domain:string ->
    string -> (string * string) list
  (** [clear_hdrs cookie_key] will generate response headers to
      communicate that the client should evict the session with key
      [cookie_key]. *)

  val generate : ?expiry:period -> backend -> value -> t io
  (** [generate ?expiry backend value] will allocate a new session in the backend
      [backend]. The session will expire [expiry] seconds from now, defaulting to
      [default_period backend] if one is not explicitly specified. *)

  val clear : backend -> t -> unit io
  (** [clear backend session] removes [session] from [backend]. The backend
      may choose to persist the session value beyond this call, but any
      subsequent operations involving [key] should behave as if [key] is
      not present in the backend.

      The {!value} and {!expiry_period} of [session] will be zero'd out, and the
      {!modified} flag will be set. Calling {!to_cookie_hdr} on a cleared
      session will generate the appropriate headers directing the client to
      clear the associated cookie. *)

  val set : ?expiry:period -> ?value:value -> backend -> t -> unit io
  (** [set ?expiry ?value backend session] sets the [value] for the session
      associated [key] in [backend] and sets the session to expire [expiry]
      seconds from now. If [expiry] is not provided, the expiry period reported
      by [default_period backend] will be used instead. If no value is provided, then
      only the expiry will be updated. *)
end

(** Create a Cohttp session manager given an appropriate backend. *)
module Make(IO:Session.S.IO)(B:Backend with type +'a io = 'a IO.t) : S
  with type +'a io = 'a B.io
   and type backend = B.t
   and type key = B.key
   and type value = B.value
   and type period = B.period
