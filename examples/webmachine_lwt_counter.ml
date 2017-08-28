module Session = struct
  module Backend = struct
    include Session.Lift.IO(Lwt)(Session.Memory)
    let create () = Session.Memory.create ()
  end
  include Session_webmachine.Make(Lwt)(Backend)
end

let cookie_key = "__counter_session"

module Rd = Webmachine.Rd
include Webmachine.Make(Cohttp_lwt_unix_io)

open Lwt.Infix
open Cohttp_lwt_unix

class counter backend = object(self)
  inherit [Cohttp_lwt_body.t] resource
  inherit [Cohttp_lwt_body.t] Session.manager ~cookie_key backend

  method private increment session rd =
    let value = string_of_int (1 + int_of_string session.Session.value) in
    self#session_set value rd

  method private to_plain rd =
    self#session_of_rd_or_create "0" rd >>= fun session ->
    self#increment session rd >>= fun () ->
      continue (`String session.Session.value) rd

  method! allowed_methods rd =
    continue [`GET] rd

  method content_types_accepted rd =
    continue [] rd

  method content_types_provided rd =
    continue [
      "text/plain", self#to_plain
    ] rd

  method! finish_request rd =
    let rd = self#session_set_hdrs rd in
    continue () rd
end

let main () =
  let port = 8080 in
  let mem = Session.Backend.create () in
  let routes = [
    "/*", fun () -> new counter mem
  ] in
  let dispatch = dispatch' routes in
  let callback _conn request body =
    dispatch ~body ~request
    >|= begin function
      | None        -> (`Not_found, Cohttp.Header.init (), `String "Not found", [])
      | Some result -> result
    end
    >>= fun (_status, headers, body, _) ->
      Server.respond ~headers ~body ~status:`OK ()
  in
  let config = Server.make ~callback () in
  Server.create ~mode:(`TCP(`Port port)) config
  >|= fun () ->
    Printf.eprintf "cohttp_lwt_counter: lsitening on 0.0.0.0:%d\n%!" port

let () =
  Nocrypto_entropy_unix.initialize ();
  Lwt_main.run (main ())
