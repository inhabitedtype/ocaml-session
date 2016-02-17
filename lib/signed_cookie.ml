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

module String = struct
  include String

  let rsplit2 ~on str =
    try
      let i = String.rindex str on in
      Some String.(sub str 0 i, sub str (i + 1) (length str - i - 1))
    with (Not_found | Invalid_argument _) -> None
end

type t =
  { secret : string
  ; salt   : string
  ; mutable default_period : period }

let create ?(salt="salt.signer") secret =
  { secret
  ; salt
    (* One week. If this changes, change module documentation. *)
  ; default_period = Int64.of_int (60 * 60 * 24 * 7) }

let now () =
  Int64.of_float (Unix.time ())

let default_period t =
  t.default_period

let set_default_period t period =
  t.default_period <- period

let derive_key t =
  Nocrypto.Hash.mac `SHA1
    ~key:(Cstruct.of_string t.secret)
    (Cstruct.of_string t.salt)

let constant_time_compare' a b init =
  let len = String.length a in
  let result = ref init in
  for i=0 to len-1 do
    result := !result lor Char.(compare a.[i] b.[i])
  done;
  !result = 0

let constant_time_compare a b =
  if String.length a <> String.length b then
    constant_time_compare' b b 1
  else
    constant_time_compare' a b 0

let get_signature t value =
  value
  |> Cstruct.of_string
  |> Nocrypto.Hash.mac `SHA1 ~key:(derive_key t)
  |> Nocrypto.Base64.encode
  |> Cstruct.to_string

let sign t data =
  String.concat "." [data; get_signature t data]

let verified t value signature =
  if constant_time_compare signature (get_signature t value)
  then Some value
  else None

let unsign t data =
  match String.rsplit2 ~on:'.' data with
  | Some (value, signature) -> verified t value signature
  | None -> None

let get t key =
  match unsign t key with
  | None       -> Result.Error S.Not_found
  | Some value ->
    value
    |> Cstruct.of_string
    |> Nocrypto.Base64.decode
    |> Cstruct.to_string
    |> fun v -> Result.Ok(v, 0L) (* XXX(seliopou): value must contain expiry *)

let generate ?expiry ?value t =
  let data =
    match value with
    | None       -> ""
    | Some value -> value
  in
  data
  |> Cstruct.of_string
  |> Nocrypto.Base64.encode
  |> Cstruct.to_string
  |> sign t

let set ?expiry t key value =
  generate ?expiry ~value t
