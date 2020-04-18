module Backend = struct
  include Session_postgresql
  let name = "postgresql"

  let create () =
    let t = connect ~dbname:"i3_test" () in
    let open Postgresql in
    ignore (t#exec ~expect:[Command_ok] "DELETE FROM session");
    t
end

let () =
  let open Postgresql in
  Printexc.register_printer @@ function
    | Error e -> Some (Printf.sprintf "Postgresql.Error(%S)" (string_of_error e))
    | _ -> None

let () = Mirage_crypto_rng_unix.initialize ()
module Test = Test_session.Make(Backend)
