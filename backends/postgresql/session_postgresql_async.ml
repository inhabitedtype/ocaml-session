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
