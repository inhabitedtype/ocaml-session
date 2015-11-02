module Backend = struct
  include Session.Memory
  let name = "memory"
end

let () = Nocrypto_entropy_unix.initialize ()
module Test = Test_session.Make(Backend)
