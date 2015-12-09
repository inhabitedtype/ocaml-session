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
