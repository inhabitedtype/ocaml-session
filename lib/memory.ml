type key = string
type value = string
type period = int64

type session =
  { value : value option
  ; expiry : period }

type t =
  { store : (key, session) Hashtbl.t
  ; mutable default_period : period }

let gensym () =
  Cstruct.to_string Nocrypto.(Base64.encode (Rng.generate 30))

let create () =
  { store = Hashtbl.create 10
    (* One week. If this changes, change module documentation. *)
  ; default_period = Int64.of_int (60 * 60 * 24 * 7) }

let now () =
  Int64.of_float (Unix.time ())

let default_period t =
  t.default_period

let set_default_period t period =
  t.default_period <- period

let clear t key =
  Hashtbl.remove t.store key

let get t key =
  try
    let result = Hashtbl.find t.store key in
    let period = Int64.(sub result.expiry (now ())) in
    if Int64.compare period 0L < 0 then
      Result.Error S.Expired
    else match result.value with
    | None       -> Result.Error S.Not_set
    | Some value -> Result.Ok(value, period)
  with Not_found -> Result.Error S.Not_found

let _set ?expiry ?value t key =
  let expiry =
    match expiry with
    | None        -> Int64.(add (now ()) (default_period t))
    | Some expiry -> Int64.(add (now ()) expiry)
  in
  let session = { expiry; value } in
  Hashtbl.replace t.store key session

let set ?expiry t key value =
  _set ?expiry ~value t key

let generate ?expiry ?value t =
  let key = gensym () in
  _set ?expiry ?value t key;
  key
