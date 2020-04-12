module Backend = struct
  include Session_sqlite

  let name = "sqlite"

  let create () =
    let db = Sqlite3.db_open ~memory:true ":memory:" in
    create db
end

let () = Mirage_crypto_rng_unix.initialize ()
module Test = Test_session.Make(Backend)
