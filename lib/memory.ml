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

type key = string
type value = string
type period = int64

type session =
  { value : value option
  ; expiry : period }

type t =
  { store : (key, session) Hashtbl.t
  ; mutable default_period : period }

let gensym () =
  Cstruct.to_string Nocrypto.(Base64.encode (Rng.generate 30))

let create () =
  { store = Hashtbl.create 10
    (* One week. If this changes, change module documentation. *)
  ; default_period = Int64.of_int (60 * 60 * 24 * 7) }

let now () =
  Int64.of_float (Unix.time ())

let default_period t =
  t.default_period

let set_default_period t period =
  t.default_period <- period

let clear t key =
  Hashtbl.remove t.store key

let get t key =
  try
    let result = Hashtbl.find t.store key in
    let period = Int64.(sub result.expiry (now ())) in
    if Int64.compare period 0L < 0 then
      Result.Error S.Expired
    else match result.value with
    | None       -> Result.Error S.Not_set
    | Some value -> Result.Ok(value, period)
  with Not_found -> Result.Error S.Not_found

let _set ?expiry ?value t key =
  let expiry =
    match expiry with
    | None        -> Int64.(add (now ()) (default_period t))
    | Some expiry -> Int64.(add (now ()) expiry)
  in
  let session = { expiry; value } in
  Hashtbl.replace t.store key session

let set ?expiry t key value =
  _set ?expiry ~value t key

let generate ?expiry ?value t =
  let key = gensym () in
  _set ?expiry ?value t key;
  key
