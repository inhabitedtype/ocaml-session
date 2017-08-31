open Session_cohttp

module Make(B:Backend with type +'a io = 'a Lwt.t) = Make(Lwt)(B)
