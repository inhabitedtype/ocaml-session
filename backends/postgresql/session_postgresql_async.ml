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

open Async.Std

include Session.Lift.Thread_IO(struct
  include Deferred

  let in_thread f = In_thread.run f
end)(Session_postgresql)


let connect
    ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl
    ?conninfo ?startonly () =
  In_thread.run (fun () ->
    Session_postgresql.connect
       ?host ?hostaddr ?port ?dbname ?user ?password ?options ?tty ?requiressl
       ?conninfo ?startonly ())

let set_default_period t period =
  Session_postgresql.set_default_period t period

module Pool = struct
  type +'a io = 'a Deferred.t

  type t =
    { pool : Postgresql.connection Throttle.t
    ; mutable default_period : period
    }

  type key = string
  type value = string
  type period = int64

  let __de_default t = function
    | None        -> t.default_period
    | Some expiry -> expiry

  let generate ?expiry ?value t =
    Throttle.enqueue t.pool (fun conn ->
      let expiry = __de_default t expiry in
      generate ~expiry ?value conn)

  let clear t key =
    Throttle.enqueue t.pool (fun conn ->
      clear conn key)

  let get t key =
    Throttle.enqueue t.pool (fun conn ->
      get conn key)

  let set ?expiry t key value =
    Throttle.enqueue t.pool (fun conn ->
      let expiry = __de_default t expiry in
      set ~expiry conn key value)

  let default_period { default_period } =
    default_period

  let set_default_period t period =
    t.default_period <- period

  let of_throttle pool =
    { pool; default_period = Int64.of_int (60 * 60 * 24 * 7) }

end
