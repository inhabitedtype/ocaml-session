(** Lift {!S.Now} to {!S.Future} *)

(** The identity monad as a stub for blocking computations.

    Using this module in lifting will not change the blocking characteristics
    of the backend. It's here merely to facilitate interoperability. *)
module Ident : sig
  include S.IO

  val run : 'a t -> 'a
  (** [run m] "runs" the computation within the identity monad, returning the
      value. *)
end

(** Lift a synchronous {!S.Now} backend to an asynchronous {!S.Future}
    interface. *)
module Make(IO:S.IO)(Now:S.Now) : S.Future
  with type +'a io = 'a IO.t
   and type t = Now.t
   and type key = Now.key
   and type value = Now.value
   and type period = Now.period
