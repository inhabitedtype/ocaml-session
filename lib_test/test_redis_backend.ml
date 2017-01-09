open Lwt.Infix

module C = Session_redis_lwt

let test_server = { Redis_lwt.Client.host = "127.0.0.1"; port = 6379 }

module Backend = struct
  type 'a io = 'a
  type t = C.t
  type key = C.key
  type value = C.value
  type period = int64

  let name = "redis"

  let pool = Lwt_pool.create 1 (fun () -> Redis_lwt.Client.connect test_server)

  let create () =
    C.of_connection_pool pool

  let default_period t = C.default_period t

  let generate ?expiry ?value t =
    Lwt_main.run (C.generate ?expiry ?value t)

  let clear t key = Lwt_main.run (C.clear t key)

  let get t key =
    Lwt_main.run (C.get t key)

  let set ?expiry t key value =
    Lwt_main.run (C.set ?expiry t key value)
end

let () = Nocrypto_entropy_unix.initialize ()
module Test = Test_session.Make(Backend)
