module Backend = struct
  include Session.Memory
  let name = "memory"
end

module Test = Test_session.Make(Backend)
