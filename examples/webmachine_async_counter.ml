open Async

module Session = struct
  module Backend = struct
    include Session.Lift.IO(Deferred)(Session.Memory)
    let create () = Session.Memory.create ()
  end
  include Session_webmachine.Make(Deferred)(Backend)
end

let cookie_key = "__counter_session"

module Rd = Webmachine.Rd
include Webmachine.Make(Cohttp_async.Io)

open Cohttp_async

class counter backend = object(self)
  inherit [Body.t] resource
  inherit [Body.t] Session.manager ~cookie_key backend

  method private increment session rd =
    let value = string_of_int (1 + int_of_string session.Session.value) in
    self#session_set value rd

  method private to_plain rd =
    self#session_of_rd_or_create "0" rd >>= fun session ->
    self#increment session rd >>= fun () ->
      continue (`String session.Session.value) rd

  method allowed_methods rd =
    continue [`GET] rd

  method content_types_accepted rd =
    continue [] rd

  method content_types_provided rd =
    continue [
      "text/plain", self#to_plain
    ] rd

  method finish_request rd =
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
  let handler ~body _ request =
    dispatch ~body ~request
    >>| begin function
      | None        -> (`Not_found, Cohttp.Header.init (), `String "Not found", [])
      | Some result -> result
    end
    >>= fun (status, headers, body, _) ->
      Server.respond ~headers ~body `OK
  in
  Server.create ~on_handler_error:`Raise (Tcp.on_port port) handler
  >>> fun server ->
    Log.Global.info "webmachine_async_counter: listening on 0.0.0.0:%d%!" port

let _ =
  Nocrypto_entropy_unix.initialize ();
  Scheduler.go_main ~main ()
