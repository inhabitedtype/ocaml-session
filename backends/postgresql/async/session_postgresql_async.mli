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

open Async

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
