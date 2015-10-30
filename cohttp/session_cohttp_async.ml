open Async_kernel
open Session_cohttp

module Make(B:Backend with type +'a io = 'a Deferred.t) = Make(Deferred)(B)
