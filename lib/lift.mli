(*----------------------------------------------------------------------------
    Copyright (c) 2015 Inhabited Type LLC.

    All rights reserved.

    Redistribution and use in source and binary forms, with or without
    modification, are permitted provided that the following conditions
    are met:

    1. Redistributions of source code must retain the above copyright
       notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
       notice, this list of conditions and the following disclaimer in the
       documentation and/or other materials provided with the distribution.

    3. Neither the name of the author nor the names of his contributors
       may be used to endorse or promote products derived from this software
       without specific prior written permission.

    THIS SOFTWARE IS PROVIDED BY THE CONTRIBUTORS ``AS IS'' AND ANY EXPRESS
    OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
    WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
    DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS OR CONTRIBUTORS BE LIABLE FOR
    ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
    OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
    HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
    STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
    ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
    POSSIBILITY OF SUCH DAMAGE.
  ----------------------------------------------------------------------------*)

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
module IO(IO:S.IO)(Now:S.Now) : S.Future
  with type +'a io = 'a IO.t
   and type t = Now.t
   and type key = Now.key
   and type value = Now.value
   and type period = Now.period

(** Lift a synchronous {!S.Now} backend to an asynchronous {!S.Future}
    interface, using threads. This may add concurrency to the program,
    depending on how [in_thread] is implemented. *)
module Thread_IO(IO:S.Thread_IO)(Now:S.Now) : S.Future
  with type +'a io = 'a IO.t
   and type t = Now.t
   and type key = Now.key
   and type value = Now.value
   and type period = Now.period
