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

(** Webmachine-aware session management for your everyday needs. *)

open Webmachine
open Result

(** The signature for a Webmachine-compatible backend. It is the same as a
    Cohttp-compatible backend. *)
module type Backend = Session_cohttp.Backend

(** The signature for a Webmachine session manager *)
module type S = sig
  include Session_cohttp.S

  (** A session manager for Webmachine resources.

      Webmachine resources should inherit this class and use its methods
      internally to query and modify session state. *)
  class ['body] manager : cookie_key:string -> backend -> object
    method private session_of_rd : 'body Rd.t -> (t option, Session.S.error) result io
    (** [#session_get rd] fetches and caches the session associated with [rd],
        if present and unexpired.  *)

    method private session_of_rd_or_create : ?expiry:period -> value -> 'body Rd.t -> t io
    (** [#session_get_or_create ?expiry value rd] fetches and caches the
        session associated with [rd]. If the session is not present or expired,
        then a new session will be created and stored using [expiry] and
        [value]. Creating a new session will not modify [rd], but subsequent
        session calls for this resource will use the newly created, cached
        session. *)

    method private session_set : ?expiry:period -> value -> 'body Rd.t -> unit io
    (** [#session_set ?expiry value rd] sets the [value] for the session
        associated with [rd] in the backend [t] and sets the session to expire
        [expiry] seconds from now. If [expiry] is not provided, then expiry
        reported by [default_period t] will be used instead. *)

    method private session_clear : 'body Rd.t -> unit io
    (** [#clear rd] removes the session associated with [rd] from the
        backend. If a session is cached, its [value] and [expiry_period] will
        be zero'd out, and the [modified] flag will be set. Calling
        {!to_cookie_hdr} on a cleared session will generate the appropriate
        headers directing the client to clear the associated cookie. *)

    method private session_set_hdrs :
      ?discard:bool ->
      ?path:string ->
      ?domain:string ->
      ?secure:bool ->
      ?http_only:bool ->
      'body Rd.t -> 'body Rd.t
    (** [#session_set_hdrs rd] will generate response headers to communicate
        session changes or the clearing of the session to the client. This
        function takes into account the {!modified} field of the
        {{!type:t}session} type, and will not generate headers if they are not
        needed. *)

    method private session_variances : string list
    (** [#session_variances] returns a list of session-related header names
        that should be inclued in the [Vary] header of a reponse. The result
        takes into account whether the session related to the request was
        accessed, modified, or cleared. *)
  end
end

(** Create a Webmachine session manager given an appropriate backend. *)
module Make(IO:Session.S.IO)(B:Backend with type +'a io = 'a IO.t) : S
  with type +'a io = 'a B.io
   and type backend = B.t
   and type key = B.key
   and type value = B.value
   and type period = B.period
