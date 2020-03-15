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

open Postgresql

type t = connection
type key = string
type value = string
type period = int64

module W = struct
  type data =
    { conn : connection
    ; mutable period : period }

  module T : Weak.S with type data := data =
    Weak.Make(struct
      type t = data

      let equal a b = a.conn = b.conn
      let hash a = Hashtbl.hash a.conn
    end)

  include T
end

let _default_period =
  (* One week. If this changes, change module documentation. *)
  Int64.of_int (60 * 60 * 24 * 7)

let _default_period_table =
  W.create 5

let connect ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl ?conninfo ?startonly () =
  new connection ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl ?conninfo ?startonly ()

let gensym () =
  Base64.encode_exn (Cstruct.to_string (Mirage_crypto_rng.generate 30))

let now () =
  Int64.of_float (Unix.time ())

let default_period t =
  try
    let w = W.find _default_period_table { W.conn = t; period = _default_period } in
    w.W.period
  with Not_found -> _default_period

let set_default_period t period =
  let w = W.find _default_period_table { W.conn = t; period } in
  w.W.period <- period

let clear (t:t) key =
  let params = [| key |] in
  let _ = t#exec ~expect:[Command_ok] ~params
    "DELETE FROM session WHERE session_key = $1;"
  in
  ()

let get (t:t) key =
  let params = [| key |] in
  let result = t#exec ~expect:[Tuples_ok] ~params
    "SELECT CAST(EXTRACT(epoch FROM expire_date) AS INT8), session_data
       FROM session WHERE session_key = $1"
  in
  if result#ntuples = 0 then
    Result.Error Session.S.Not_found
  else begin
    assert (result#ntuples = 1);
    assert (result#nfields = 2);
    assert (result#ftype 0 = INT8);
    assert (result#ftype 1 = TEXT);
    let expiry = Scanf.sscanf (result#getvalue 0 0) "%Ld" (fun x -> x) in
    let period = Int64.(sub expiry (now ())) in
    if Int64.compare period 0L < 0 then
      Result.Error Session.S.Not_found
    else if result#getvalue 0 1 = null then
      Result.Error Session.S.Not_set
    else
      Result.Ok (result#getvalue 0 1, period)
  end

let _prepare_expiry t = function
  | None        -> Printf.sprintf "%Ld seconds" (default_period t)
  | Some expiry -> Printf.sprintf "%Ld seconds" expiry

let _set ?expiry ?(value=null) (t:t) key =
  let params = [| key; _prepare_expiry t expiry; value |] in
  let _ = t#exec ~expect:[Command_ok] ~params
    "UPDATE session SET session_data = $3, expire_date = NOW() + CAST($2 AS INTERVAL)
       WHERE session_key = $1"
  in
  ()

let set ?expiry t key value =
  _set ?expiry ~value t key

let generate ?expiry ?(value=null) (t:t) =
  let key : key = gensym () in
  let params = [| key; _prepare_expiry t expiry; value |] in
  let _ = t#exec ~expect:[Command_ok] ~params
    "INSERT INTO session(session_key, expire_date, session_data)
       VALUES ($1, NOW() + CAST($2 AS INTERVAL), $3)"
  in
  key
