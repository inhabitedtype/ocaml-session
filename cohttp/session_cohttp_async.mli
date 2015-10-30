(** Async-based session manager for Cohttp. *)

open Async_kernel
open Session_cohttp

(** Create an Async-bases session manager given a compatible backend. *)
module Make(B:Backend with type +'a io = 'a Deferred.t) : S
  with type +'a io = 'a Deferred.t
   and type backend = B.t
   and type key = string
   and type value = string
   and type period = int64
