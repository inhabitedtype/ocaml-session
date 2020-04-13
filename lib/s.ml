(*----------------------------------------------------------------------------
    Copyright (c) 2015 Inhabited Type LLC.

    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

    3. Neither the name of the author nor the names of his contributors
       may be used to endorse or promote products derived from this software
       without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE CONTRIBUTORS ``AS IS'' AND ANY EXPRESS
    OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR
    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
    OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
    HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
    STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
  ----------------------------------------------------------------------------*)

(** Session-related signatures and types. *)


(** The type of a session error.

    These will only be returned by the {!val:S.Now.get} and {!val:S.Future.get}
    operations. *)
type error =
  | Not_found   (** The key was not found. *)
  | Not_set     (** The key was found but had no associated value. *)

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

(** The signature for blocking computations that can run synchronous
    computations in a separate thread *)
module type Thread_IO = sig
  include IO

  val in_thread : (unit -> 'a) -> 'a t
  (** [in_thread f] runs [f ()] in a separate thread, returning a blocking
      computation that will become determined once execution of [f] is complete. *)
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
