module Ident = struct
  type +'a t = 'a

  let return x = x
  let (>>=) m f = f m
  let (>>|) m f = f m

  let (>>=?) m f =
    match m with
    | Result.Ok x      -> f x
    | Result.Error err -> Result.Error err

  let run x = x
end

module IO(IO:S.IO)(Now:S.Now) = struct
  type +'a io = 'a IO.t
  type t = Now.t
  type key = Now.key
  type value = Now.value
  type period = Now.period

  let default_period t = Now.default_period t

  let generate ?expiry ?value t = IO.return (Now.generate ?expiry ?value t)
  let clear t key = IO.return (Now.clear t key)
  let get t key = IO.return (Now.get t key)
  let set ?expiry t key value = IO.return (Now.set ?expiry t key value)
end

module Thread_IO(IO:S.Thread_IO)(Now:S.Now) = struct
  type +'a io = 'a IO.t
  type t = Now.t
  type key = Now.key
  type value = Now.value
  type period = Now.period

  let default_period t = Now.default_period t

  let generate ?expiry ?value t = IO.in_thread (fun () -> Now.generate ?expiry ?value t)
  let clear t key = IO.in_thread (fun () -> Now.clear t key)
  let get t key = IO.in_thread (fun () -> Now.get t key)
  let set ?expiry t key value = IO.in_thread (fun () -> Now.set ?expiry t key value)
end
