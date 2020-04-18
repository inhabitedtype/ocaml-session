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

open Webmachine

module type Backend = Session_cohttp.Backend

module type S = sig
  include Session_cohttp.S

  class ['body] manager : cookie_key:string -> backend -> object
    method private session_of_rd : 'body Rd.t -> (t option, Session.S.error) result io
    method private session_of_rd_or_create : ?expiry:period -> value -> 'body Rd.t -> t io
    method private session_set : ?expiry:period -> value -> 'body Rd.t -> unit io
    method private session_clear : 'body Rd.t -> unit io

    method private session_set_hdrs :
      ?discard:bool ->
      ?path:string ->
      ?domain:string ->
      ?secure:bool ->
      ?http_only:bool ->
      'body Rd.t -> 'body Rd.t

    method private session_variances : string list
  end
end

module Make(IO:Session.S.IO)(B:Backend with type +'a io = 'a IO.t) = struct
  include Session_cohttp.Make(IO)(B)

  type s = [ `Uninitialized | `Cached of t | `Cleared ]

  open IO

  let (>>|) a f =
    a >>= fun x -> return (f x)

  class ['body] manager ~cookie_key backend =
    let __session : s ref = ref `Uninitialized in
    let __accessed = ref false in
    let __error    = ref None in

    let __get_raw_session () =
      __accessed := true;
      !__session
    in
    let __cache_session session =
      __accessed := true;
      __session := `Cached session
    in
    let __error_session err =
      __error := Some err
    in
  object(self)
    method private session_of_rd rd =
      match __get_raw_session () with
      | `Uninitialized  ->
        of_header backend cookie_key rd.Webmachine.Rd.req_headers
        >>| begin function
          | Ok (Some session) -> __cache_session session; Ok (Some session)
          | Ok None           -> Ok None
          | Error err         -> __error_session err; Error err
        end
        (* XXX(seliopou): What if the session has been cleared? *)
      | `Cached session -> return (Ok (Some session))
      | `Cleared        -> return (Ok None)

    method private session_of_rd_or_create ?expiry default rd =
      self#session_of_rd rd
      >>= begin function
        | Ok (Some session) -> return session
        | _                 ->
          generate ?expiry backend default
          >>| fun session ->
            __cache_session session;
            session
      end

    method private session_set ?expiry value rd =
      match __get_raw_session () with
      | `Uninitialized | `Cleared ->
        self#session_of_rd_or_create ?expiry value rd >>| fun _ -> ()
      | `Cached session ->
        set ?expiry ~value backend session

    method private session_clear (rd:'body Webmachine.Rd.t) =
      self#session_of_rd rd
      >>= function
        | Ok (Some session) -> clear backend session
        | _                 -> return ()

    method private session_clear_hdrs ?path ?domain rd =
      let set_cookie = clear_hdrs ?path ?domain cookie_key in
      Webmachine.Rd.with_resp_headers (fun header ->
        Cohttp.Header.add_list header set_cookie) rd

    method private session_set_hdrs ?discard ?path ?domain ?secure ?http_only (rd:'body Webmachine.Rd.t) =
      match __get_raw_session (), !__error with
      | (`Uninitialized, Some _) | (`Cleared, _) ->
        self#session_clear_hdrs ?path ?domain rd
      | `Uninitialized, None ->
        rd
      | `Cached session, _ ->
        let set_cookie = to_cookie_hdrs
          ?discard ?path ?domain ?secure ?http_only cookie_key session
        in
        let set_cookie = List.filter (fun (h, _) -> h <> "vary") set_cookie in
        Webmachine.Rd.with_resp_headers (fun header ->
          Cohttp.Header.add_list header set_cookie) rd

    method private session_variances =
      if !__accessed then ["cookie"] else []
  end
end
