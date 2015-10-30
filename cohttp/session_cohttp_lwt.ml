open Session_cohttp

module Lwt = struct
  include Lwt

  let (>>|) = Lwt.(>|=)
end

module Make(B:Backend with type +'a io = 'a Lwt.t) = Make(Lwt)(B)
