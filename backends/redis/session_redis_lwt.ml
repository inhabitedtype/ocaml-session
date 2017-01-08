(*----------------------------------------------------------------------------
    Copyright 2016 Docker, Inc.

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

module R = Redis_lwt.Client

open Lwt.Infix

type 'a io = 'a Lwt.t
type key = string
type value = string

(* Note: [R.pttl] uses [int] to represent ms, which is too small on 32-bit so we use [R.ttl] instead. *)
type period = int64

type t = {
  pool : R.connection Lwt_pool.t;
  mutable period : period;
}

let _default_period =
  (* One week. If this changes, change module documentation. *)
  Int64.of_int (60 * 60 * 24 * 7)

let gensym () =
  Cstruct.to_string Nocrypto.(Base64.encode (Rng.generate 30))

let redis_key k = "session:" ^ k

let of_connection_pool pool = {
  pool;
  period = _default_period;
}

let default_period t = t.period

let set_default_period t period =
  t.period <- period

let clear (t:t) key =
  let key = redis_key key in
  Lwt_pool.use t.pool @@ fun conn ->
  R.del conn [key] >|= fun (_:int) -> ()

let get (t:t) key =
  let key = redis_key key in
  Lwt_pool.use t.pool @@ fun conn ->
  R.get conn key >>= function
  | None -> Lwt.return (Result.Error Session.S.Not_found)
  | Some "-" -> Lwt.return (Result.Error Session.S.Not_set)
  | Some encoded_value ->
    (* Redis supports pipelining, but we can't use it due to
       https://github.com/0xffea/ocaml-redis/issues/42, so we
       wait for the value to arrive before asking for the ttl. *)
    R.ttl conn key >|= function
    | None -> Result.Error Session.S.Not_found
    | Some s_to_live ->
      assert (encoded_value.[0] = '+');
      let value = String.sub encoded_value 1 (String.length encoded_value - 1) in
      Result.Ok (value, Int64.of_int s_to_live)

let set_opt ?expiry t key value =
  let key = redis_key key in
  let ex =
    match expiry with
    | None -> default_period t
    | Some x -> x
  in
  let value =
    match value with
    | None -> "-"
    | Some v -> "+" ^ v
  in
  if ex < 0L then Lwt.return_unit
  else (
    Lwt_pool.use t.pool @@ fun conn ->
    R.set conn ~ex:(Int64.to_int ex) key value >|= fun (_:bool) -> ()
  )

let set ?expiry t key value = set_opt ?expiry t key (Some value)

let generate ?expiry ?value (t:t) =
  let key = gensym () in
  set_opt ?expiry t key value >|= fun () ->
  key
