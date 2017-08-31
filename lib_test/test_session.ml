open OUnit

module type Backend = sig
  include Session.S.Now
    with type key = string
     and type value = string
     and type period = int64

  val name : string
  val create : unit -> t
end

module Make(B:Backend) = struct

  let is_ok = function
    | Result.Ok _    -> true
    | Result.Error _ -> false

  let err_to_string = function
    | Session.S.Not_found -> "Not_found"
    | Session.S.Not_set   -> "Not_set"

  let from_ok = function
    | Ok x       -> x
    | Error _err -> assert false

  let (>>|?) m f =
    match m with
    | Ok x      -> Ok (f x)
    | Error err -> Error err

  let result_to_string ~f = function
    | Ok x      -> Printf.sprintf "Ok(%s)" (f x)
    | Error err -> Printf.sprintf "Error(%s)" (err_to_string err)

  let generate () =
    let backend = B.create () in
    let key1 = B.generate backend in
    "session creation does not produce an error"
      @? true;
    let key2 = B.generate ~expiry:0L backend in
    "session creation with non-default expiry does not produce an error"
      @? true;
    "session creation does not produce duplicate keys"
      @? (key1 <> key2);
    let _ = B.generate ~expiry:(-1L) backend in
    "session creation with negative expiry does not produce an error"
      @? true;
  ;;

  let clear () =
    let backend = B.create () in
    let key1 = B.generate backend in
    "session clearing on new session does not produce an error"
      @? (() = B.clear backend key1);
    "session clearing on already cleared session does not produce an error"
      @? (() = B.clear backend key1);
  ;;

  let set () =
    let backend = B.create () in
    let key1 = B.generate backend in
    B.set backend key1 "session data1";
    "setting a session value on new session does not produce an error"
      @? true;
    B.set backend key1 "session data2";
    "setting a session value on an existing session not produce an error"
      @? true;
    let _ = B.generate ~expiry:(-1L) backend in
    "setting a session value and non-default expiry does not produce an error"
      @? true;
  ;;

  let get () =
    let get backend key = B.get backend key >>|? fun (v, _) -> v in
    let printer = result_to_string ~f:(fun x -> Printf.sprintf "%S" x) in
    let backend = B.create () in
    let key1 = B.generate ~expiry:(-10L) backend in
    assert_equal ~msg:"getting a garbage key will produce a Not_found error"
      (Error Session.S.Not_found) (get backend "asdfjk") ~printer;
    assert_equal ~msg:"getting an expired, unset session will produce a Not_found error"
      (Error Session.S.Not_found) (get backend key1) ~printer;

    let key2 = B.generate backend in
    assert_equal ~msg:"getting an unexpired, unset session will produce a Not_set error"
      (Error Session.S.Not_set) (get backend key2) ~printer;
    B.set backend key2 "data2";
    assert_equal ~msg:"getting a session value just after setting returns the same value"
      (Ok "data2") (get backend key2) ~printer;
    B.clear backend key2;
    assert_equal ~msg:"getting a cleared key will produce a Not_found error"
      (Error Session.S.Not_found) (get backend key2) ~printer;

    let key3 = B.generate ~expiry:(-1000L) ~value:"data2" backend in
    assert_equal ~msg:"getting an expired, set key will produce a Not_found error"
      (Error Session.S.Not_found) (get backend key3) ~printer;
  ;;

  let rec was_successful =
    function
      | [] -> true
      | RSuccess _::t
      | RSkip _::t ->
          was_successful t
      | RFailure _::_
      | RError _::_
      | RTodo _::_ ->
          false

  let _ =
    let tests = [
      "generate" >:: generate;
      "clear" >:: clear;
      "set" >:: set;
      "get" >:: get;
    ] in
    let suite = (Printf.sprintf "test %S session backend" B.name) >::: tests in
    let verbose = ref false in
    let set_verbose _ = verbose := true in
    Arg.parse
      [("-verbose", Arg.Unit set_verbose, "Run the test in verbose mode.");]
      (fun x -> raise (Arg.Bad ("Bad argument : " ^ x)))
      ("Usage: " ^ Sys.argv.(0) ^ " [-verbose]");
    if not (was_successful (run_test_tt ~verbose:!verbose suite))
    then exit 1
end
