open Async

module Session = struct
  module Backend = struct
    include Session.Lift.IO(Deferred)(Session.Memory)
    let create () = Session.Memory.create ()
  end
  include Session_cohttp_async.Make(Backend)

  let increment t session =
    let value = string_of_int (1 + int_of_string session.value) in
    set t ~value session
end

open Cohttp_async

let cookie = "__counter_session"

let main () =
  let port = 8080 in
  let mem = Session.Backend.create () in
  let handler ~body:_ _ { Request.headers; _ } =
    Session.of_header_or_create mem cookie "0" headers >>= fun session ->
    Session.increment mem session >>= fun () ->
    let headers = Cohttp.Header.of_list (Session.to_cookie_hdrs cookie session)
    and body    = `String (session.Session.value) in
    Server.respond ~headers ~body `OK
  in
  Server.create ~on_handler_error:`Raise (Tcp.on_port port) handler
  >>> fun _server ->
    Log.Global.info "cohttp_async_counter: listening on 0.0.0.0:%d%!" port

let _ =
  Mirage_crypto_rng_unix.initialize ();
  Scheduler.go_main ~main ()
