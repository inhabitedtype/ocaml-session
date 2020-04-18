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

open Cohttp

module type Backend = Session.S.Future
  with type key = string
   and type value = string
   and type period = int64

module type S = sig
  type +'a io

  type backend

  type key
  type value
  type period

  type t = private
    { key : key
    ; mutable value : value
    ; mutable expiry_period : period
    ; mutable modified : bool
    }

  val of_key : backend -> key -> (t, Session.S.error) result io
  val of_header : backend -> string -> Header.t -> (t option, Session.S.error) result io
  val of_header_or_create : ?expiry:period -> backend -> string -> value -> Header.t -> t io
  val to_cookie_hdrs :
    ?discard:bool -> ?path:string -> ?domain:string ->
    ?secure:bool -> ?http_only:bool ->
    string -> t -> (string * string) list

  val clear_hdrs :
    ?path:string -> ?domain:string ->
    string -> (string * string) list

  val generate : ?expiry:period -> backend -> value -> t io
  val clear : backend -> t -> unit io
  val set : ?expiry:period -> ?value:value -> backend -> t -> unit io
end

module Make(IO:Session.S.IO)(B:Backend with type +'a io = 'a IO.t) = struct
  type +'a io = 'a B.io
  type backend = B.t

  type key = B.key
  type value = B.value
  type period = B.period


  type t =
    { key : key
    ; mutable value : value
    ; mutable expiry_period : period
    ; mutable modified : bool
    }

  open IO

  let (>>|) a f =
    a >>= fun x -> return (f x)

  let (>>|?) m f =
    m >>| function
      | Ok x      -> Ok (f x)
      | Error err -> Error err

  let generate ?expiry backend value =
    let expiry =
      match expiry with
      | None        -> B.default_period backend
      | Some expiry -> expiry
    in
    B.generate ~expiry ~value:value backend
    >>| fun key ->
      { value; key; expiry_period = expiry; modified = true }

  let clear backend session =
    B.clear backend session.key
    >>| fun () -> begin
      session.value <- "";
      session.expiry_period <- 0L;
      session.modified <- true;
    end

  let set ?expiry ?value backend session =
    let value =
      match value with
      | None       -> session.value
      | Some value -> value
    in
    let expiry_period =
      match expiry with
      | None        -> B.default_period backend
      | Some period -> period
    in
    B.set ?expiry backend session.key value
    >>| fun () -> begin
      session.value <- value;
      session.expiry_period <- expiry_period;
      session.modified <- true;
    end

  let of_key backend key =
    B.get backend key
    >>| function
      | Ok (value, expiry_period) ->
        Ok { value; key; expiry_period; modified = false }
      | Error err ->
        Error err

  let of_header backend cookie_key header =
    let cookies = Cookie.Cookie_hdr.extract header in
    try
      let key = List.assoc cookie_key cookies in
      of_key backend key >>|? fun session -> Some session
    with Not_found ->
      return (Ok None)

  let of_header_or_create ?expiry backend cookie_key default header =
    of_header backend cookie_key header
    >>= function
      | Ok (Some session) -> return session
      | _                 -> generate ?expiry backend default

  let to_cookie_hdrs ?(discard=false) ?path ?domain ?secure ?http_only cookie_key session =
    if session.modified then
      let cookie = cookie_key, session.key
      and expiration =
        if discard
          then `Session
          else `Max_age session.expiry_period
      in
      let hdr, val_ =
        Cookie.(Set_cookie_hdr.serialize
          (Set_cookie_hdr.make ~expiration ?path ?domain ?secure ?http_only cookie))
      in
      [(hdr, val_); ("vary", "cookie")]
    else
      [("vary", "cookie")]

  let clear_hdrs ?path ?domain cookie_key =
    to_cookie_hdrs ?path ?domain cookie_key {
        key = ""
      ; value = ""
      ; expiry_period = 0L
      ; modified = true }
end
