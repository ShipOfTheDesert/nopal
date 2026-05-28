(** Behavioural tests for the abstract storage interface, exercised against the
    native [In_memory] backend (REQ-F1, REQ-F3). *)

(* Runs a synchronously-resolving task and returns its value. [In_memory] tasks
   resolve immediately, so the resolver fires before [run] returns. *)
let run_sync : 'a Nopal_mvu.Task.t -> 'a =
 fun task ->
  let result = ref None in
  Nopal_mvu.Task.run task (fun value -> result := Some value);
  match !result with
  | Some value -> value
  | None -> Alcotest.fail "task did not resolve synchronously"

let error_testable =
  Alcotest.testable
    (fun fmt e -> Format.pp_print_string fmt (Nopal_storage.message e))
    ( = )

(* Unwraps an [Ok] key list (sorted for order-independent comparison) or fails. *)
let ok_keys = function
  | Ok keys -> List.sort String.compare keys
  | Error e ->
      Alcotest.failf "expected Ok keys, got Error %s" (Nopal_storage.message e)

let test_set_then_get_returns_value () =
  let module Store = Nopal_storage.In_memory () in
  let (_ : (unit, Nopal_storage.error) result) =
    run_sync (Store.set ~key:"greeting" ~value:"hello")
  in
  Alcotest.(check (result (option string) error_testable))
    "get returns the stored value" (Ok (Some "hello"))
    (run_sync (Store.get "greeting"))

let test_get_absent_returns_none () =
  let module Store = Nopal_storage.In_memory () in
  Alcotest.(check (result (option string) error_testable))
    "get of an unknown key is Ok None" (Ok None)
    (run_sync (Store.get "missing"))

let test_delete_removes_value () =
  let module Store = Nopal_storage.In_memory () in
  let (_ : (unit, Nopal_storage.error) result) =
    run_sync (Store.set ~key:"k" ~value:"v")
  in
  let (_ : (unit, Nopal_storage.error) result) = run_sync (Store.delete "k") in
  Alcotest.(check (result (option string) error_testable))
    "get after delete is Ok None" (Ok None)
    (run_sync (Store.get "k"))

let test_keys_prefix_filters () =
  let module Store = Nopal_storage.In_memory () in
  List.iter
    (fun key ->
      let (_ : (unit, Nopal_storage.error) result) =
        run_sync (Store.set ~key ~value:"x")
      in
      ())
    [ "a:1"; "a:2"; "b:1" ];
  Alcotest.(check (list string))
    "prefix a: returns only matching keys" [ "a:1"; "a:2" ]
    (ok_keys (run_sync (Store.keys ~prefix:"a:" ())));
  Alcotest.(check (list string))
    "no prefix returns all keys" [ "a:1"; "a:2"; "b:1" ]
    (ok_keys (run_sync (Store.keys ())))

let test_clear_empties_store () =
  let module Store = Nopal_storage.In_memory () in
  let (_ : (unit, Nopal_storage.error) result) =
    run_sync (Store.set ~key:"k" ~value:"v")
  in
  let (_ : (unit, Nopal_storage.error) result) = run_sync (Store.clear ()) in
  Alcotest.(check (list string))
    "keys after clear is empty" []
    (ok_keys (run_sync (Store.keys ())))

let test_reset_isolates_state () =
  let module Store = Nopal_storage.In_memory () in
  let (_ : (unit, Nopal_storage.error) result) =
    run_sync (Store.set ~key:"k" ~value:"v")
  in
  Store.reset ();
  Alcotest.(check (result (option string) error_testable))
    "get after reset is Ok None" (Ok None)
    (run_sync (Store.get "k"))

let () =
  Alcotest.run "nopal_storage (In_memory)"
    [
      ( "key-value operations",
        [
          Alcotest.test_case "set then get returns value" `Quick
            test_set_then_get_returns_value;
          Alcotest.test_case "get absent returns none" `Quick
            test_get_absent_returns_none;
          Alcotest.test_case "delete removes value" `Quick
            test_delete_removes_value;
          Alcotest.test_case "keys prefix filters" `Quick
            test_keys_prefix_filters;
          Alcotest.test_case "clear empties store" `Quick
            test_clear_empties_store;
          Alcotest.test_case "reset isolates state" `Quick
            test_reset_isolates_state;
        ] );
    ]
