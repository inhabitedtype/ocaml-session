open Async.Std

include Session.Lift.Thread_IO(struct
  include Deferred

  let in_thread f = In_thread.run f
end)(Session_postgresql)


let connect
    ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl
    ?conninfo ?startonly () =
  In_thread.run (fun () ->
    Session_postgresql.connect
       ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl
       ?conninfo ?startonly ())

let set_default_period t period =
  Session_postgresql.set_default_period t period

module Pool = struct
  type +'a io = 'a Deferred.t

  type t =
    { pool : Postgresql.connection Throttle.t
    ; mutable default_period : period
    }

  type key = string
  type value = string
  type period = int64

  let __de_default t = function
    | None        -> t.default_period
    | Some expiry -> expiry

  let generate ?expiry ?value t =
    Throttle.enqueue t.pool (fun conn ->
      let expiry = __de_default t expiry in
      generate ~expiry ?value conn)

  let clear t key =
    Throttle.enqueue t.pool (fun conn ->
      clear conn key)

  let get t key =
    Throttle.enqueue t.pool (fun conn ->
      get conn key)

  let set ?expiry t key value =
    Throttle.enqueue t.pool (fun conn ->
      let expiry = __de_default t expiry in
      set ~expiry conn key value)

  let default_period { default_period } =
    default_period

  let set_default_period t period =
    t.default_period <- period

  let of_throttle pool =
    { pool; default_period = Int64.of_int (60 * 60 * 24 * 7) }

end
