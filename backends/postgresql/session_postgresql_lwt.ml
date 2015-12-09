include Session.Lift.Thread_IO(struct
  include Lwt

  let (>>|) a b = a >|= b

  let in_thread f = Lwt_preemptive.detach f ()
end)(Session_postgresql)


let connect
    ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl
    ?conninfo ?startonly () =
  Lwt_preemptive.detach (fun () ->
    Session_postgresql.connect
       ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl
       ?conninfo ?startonly ())
    ()

let set_default_period t period =
  Session_postgresql.set_default_period t period
