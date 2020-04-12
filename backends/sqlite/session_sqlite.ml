type key = string
type value = string
type period = int64

let default_period = Int64.of_int (60 * 60 * 24 * 7)

let failf fmt =
  fmt |> Format.kasprintf failwith

let or_fail ~cmd x =
  match x with
  | Sqlite3.Rc.OK -> ()
  | err -> failf "Sqlite3: %s (executing %S)" (Sqlite3.Rc.to_string err) cmd

module Db = struct
  let no_callback _ = failwith "[exec] used with a query!"

  let dump_item f x = Format.pp_print_string f (Sqlite3.Data.to_string_debug x)
  let comma f () = Format.pp_print_string f ", "
  let dump_row = Format.pp_print_list ~pp_sep:comma dump_item

  let exec_stmt ?(cb=no_callback) stmt =
    let rec loop () =
      match Sqlite3.step stmt with
      | Sqlite3.Rc.DONE -> ()
      | Sqlite3.Rc.ROW ->
        let cols = Sqlite3.data_count stmt in
        cb @@ List.init cols (fun i -> Sqlite3.column stmt i);
        loop ()
      | x -> failf "Sqlite3 exec error: %s" (Sqlite3.Rc.to_string x)
    in
    loop ()

  let bind stmt values =
    Sqlite3.reset stmt |> or_fail ~cmd:"reset";
    List.iteri (fun i v -> Sqlite3.bind stmt (i + 1) v |> or_fail ~cmd:"bind") values

  let exec stmt values =
    bind stmt values;
    exec_stmt stmt

  let query stmt values =
    bind stmt values;
    let results = ref [] in
    let cb row =
      results := row :: !results
    in
    exec_stmt ~cb stmt;
    List.rev !results

  let query_some stmt values =
    match query stmt values with
    | [] -> None
    | [row] -> Some row
    | _ -> failwith "Multiple results from SQL query!"
end

type t = {
  get : Sqlite3.stmt;
  set : Sqlite3.stmt;
  clear : Sqlite3.stmt;
  expire : Sqlite3.stmt;
  mutable next_expire_due : Int64.t;
}

let gensym () =
  Base64.encode_string (Cstruct.to_string (Mirage_crypto_rng.generate 30))

let now () =
  Int64.of_float (Unix.time ())

let clear t key =
  Db.exec t.clear Sqlite3.Data.[ TEXT key ]

let expire_old t =
  Db.exec t.expire Sqlite3.Data.[ INT (now ()) ]

let get t key =
  match Db.query_some t.get Sqlite3.Data.[ TEXT key ] with
  | None -> Error Session.S.Not_found
  | Some Sqlite3.Data.[ value; INT expires ] ->
    let period = Int64.(sub expires (now ())) in
    if Int64.compare period 0L < 0 then (
      clear t key;
      Error Session.S.Not_found
    ) else (
      match value with
      | NULL       -> Error Session.S.Not_set
      | TEXT value -> Ok (value, period)
      | _ -> failf "Invalid value in row!"
    )
  | Some row -> failf "get: invalid row: %a" Db.dump_row row

let _set ?expiry ?value t key =
  let expiry =
    match expiry with
    | None        -> Int64.(add (now ()) default_period)
    | Some expiry -> Int64.(add (now ()) expiry)
  in
  let value =
    match value with
    | None -> Sqlite3.Data.NULL
    | Some value -> Sqlite3.Data.TEXT value
  in
  Db.exec t.set Sqlite3.Data.[ TEXT key; value; INT expiry ]

let set ?expiry t key value =
  _set ?expiry ~value t key

let generate ?expiry ?value t =
  let now = now () in
  if t.next_expire_due <= now then (
    expire_old t;
    t.next_expire_due <- Int64.add now default_period
  );
  let key = gensym () in
  _set ?expiry ?value t key;
  key

let create db =
  Sqlite3.exec db "CREATE TABLE IF NOT EXISTS ocaml_session ( \
                   key       TEXT NOT NULL, \
                   value     TEXT, \
                   expires   INTEGER NOT NULL, \
                   PRIMARY KEY (key))" |> or_fail ~cmd:"create table";
  let get = Sqlite3.prepare db "SELECT value, expires FROM ocaml_session WHERE key = ?" in
  let set = Sqlite3.prepare db "INSERT OR REPLACE INTO ocaml_session \
                                (key, value, expires) \
                                VALUES (?, ?, ?)" in
  let expire = Sqlite3.prepare db "DELETE FROM ocaml_session WHERE expires < ?" in
  let clear = Sqlite3.prepare db "DELETE FROM ocaml_session WHERE key = ?" in
  let next_expire_due = now () in
  { get; set; clear; expire; next_expire_due }

let default_period _ = default_period
