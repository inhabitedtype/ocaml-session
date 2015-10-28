open Postgresql

type t = connection
type key = string
type value = string
type period = int64

module W = struct
  type data =
    { conn : connection
    ; mutable period : period }

  module T : Weak.S with type data := data =
    Weak.Make(struct
      type t = data

      let equal a b = a.conn = b.conn
      let hash a = Hashtbl.hash a.conn
    end)

  include T
end

let _default_period =
  (* One week. If this changes, change module documentation. *)
  Int64.of_int (60 * 60 * 24 * 7)

let _default_period_table =
  W.create 5

let connect ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl ?conninfo ?startonly () =
  let conn = new connection ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl ?conninfo ?startonly () in
  W.add _default_period_table { W.conn; period = _default_period };
  conn

let gensym =
  let index = ref 0 in
  fun () ->
    let idx = !index in
    index := idx + 1;
    "postgresql-key-insecure-" ^ (string_of_int idx)

let now () =
  Int64.of_float (Unix.time ())

let default_period t =
  let w = W.find _default_period_table { W.conn = t; period = _default_period } in
  w.W.period

let set_default_period t period =
  let w = W.find _default_period_table { W.conn = t; period } in
  w.W.period <- period

let clear (t:t) key =
  let params = [| key |] in
  let _ = t#exec ~expect:[Command_ok] ~params
    "DELETE FROM session WHERE session_key = $1;"
  in
  ()

let get (t:t) key =
  let params = [| key |] in
  let result = t#exec ~expect:[Tuples_ok] ~params
    "SELECT CAST(EXTRACT(epoch FROM expire_date) AS INT8), session_data
       FROM session WHERE session_key = $1"
  in
  if result#ntuples = 0 then
    Result.Error Session.S.Not_found
  else begin
    assert (result#ntuples = 1);
    assert (result#nfields = 2);
    assert (result#ftype 0 = INT8);
    assert (result#ftype 1 = TEXT);
    let expiry = Scanf.sscanf (result#getvalue 0 0) "%Ld" (fun x -> x) in
    let period = Int64.(sub expiry (now ())) in
    if Int64.compare period 0L < 0 then
      Result.Error Session.S.Expired
    else if result#getvalue 0 1 = null then
      Result.Error Session.S.Not_set
    else
      Result.Ok (result#getvalue 0 1, period)
  end

let _prepare_expiry t = function
  | None        -> Printf.sprintf "%Ld seconds" (default_period t)
  | Some expiry -> Printf.sprintf "%Ld seconds" expiry

let _set ?expiry ?(value=null) (t:t) key =
  let params = [| key; _prepare_expiry t expiry; value |] in
  let _ = t#exec ~expect:[Command_ok] ~params
    "UPDATE session SET session_data = $3, expire_date = NOW() + CAST($2 AS INTERVAL)
       WHERE session_key = $1"
  in
  ()

let set ?expiry t key value =
  _set ?expiry ~value t key

let generate ?expiry ?(value=null) (t:t) =
  let key : key = gensym () in
  let params = [| key; _prepare_expiry t expiry; value |] in
  let _ = t#exec ~expect:[Command_ok] ~params
    "INSERT INTO session(session_key, expire_date, session_data)
       VALUES ($1, NOW() + CAST($2 AS INTERVAL), $3)"
  in
  key
