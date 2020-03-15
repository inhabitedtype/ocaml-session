module Session = struct
  module Backend = struct
    include Session.Lift.IO(Lwt)(Session.Memory)
    let create () = Session.Memory.create ()
  end
  include Session_cohttp_lwt.Make(Backend)

  let increment t session =
    let value = string_of_int (1 + int_of_string session.value) in
    set t ~value session
end

open Lwt.Infix
open Cohttp_lwt_unix

let cookie = "__counter_session"

let main () =
  let port = 8080 in
  let mem = Session.Backend.create () in
  let callback conn { Request.headers } body =
    Session.of_header_or_create mem cookie "0" headers >>= fun session ->
    Session.increment mem session >>= fun () ->
    let headers = Cohttp.Header.of_list (Session.to_cookie_hdrs cookie session)
    and body    = `String (session.Session.value) in
    Server.respond ~headers ~body ~status:`OK ()
  in
  let config = Server.make ~callback () in
  Server.create ~mode:(`TCP(`Port port)) config
  >|= fun () ->
    Printf.eprintf "cohttp_lwt_counter: lsitening on 0.0.0.0:%d\n%!" port

let () =
  Mirage_crypto_rng_unix.initialize ();
  Lwt_main.run (main ())
