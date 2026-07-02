(* Behavioural tests for the IndexedDB backend against the in-memory shim in
   indexeddb_shim.js. The two scenarios share one [Store] (one database / one
   object store), so they are sequenced — the [clear] scenario runs only inside
   the roundtrip scenario's resolver — to keep [clear] from racing the
   roundtrip's [get]. Assertions are deferred behind [_flush] until every chained
   request has resolved (mirrors test_nopal_http_web). *)

module Store = Nopal_storage_web.Make ()
open Nopal_mvu.Task.Syntax

let flush_then_run k =
  let flush = Jv.get Jv.global "_flush" in
  ignore (Jv.apply flush [| Jv.callback ~arity:1 (fun _ -> k ()) |])

(* Reads one of the shim's connection-lifecycle counters (see
   indexeddb_shim.js: [__idbOpenCount] / [__idbCloseCount]). *)
let idb_counter name = Jv.to_int (Jv.apply (Jv.get Jv.global name) [||])

let () =
  let roundtrip = ref None in
  let corrupt = ref None in
  let cleared_keys = ref None in
  let local_storage = Jv.get Jv.global "localStorage" in
  (* A localStorage entry that [clear] must leave alone (REQ-N3). *)
  ignore
    (Jv.call local_storage "setItem"
       [| Jv.of_string "ls_survivor"; Jv.of_string "still here" |]);
  let roundtrip_task =
    let* _ = Store.set ~key:"alpha" ~value:"hello world" in
    Store.get "alpha"
  in
  (* The shim pre-seeded a non-string under "__corrupt__"; reading it must
     surface an [Error], not a coerced value. Sequenced before [clear_task] so
     the seeded value still exists when it runs. *)
  let corrupt_task = Store.get "__corrupt__" in
  let clear_task =
    let* _ = Store.set ~key:"beta" ~value:"to be cleared" in
    let* _ = Store.clear () in
    Store.keys ()
  in
  Nopal_mvu.Task.run roundtrip_task (fun r ->
      roundtrip := Some r;
      Nopal_mvu.Task.run corrupt_task (fun rc ->
          corrupt := Some rc;
          Nopal_mvu.Task.run clear_task (fun r2 -> cleared_keys := Some r2)));
  flush_then_run (fun () ->
      Alcotest.run "nopal_storage_web"
        [
          ( "indexeddb",
            [
              Alcotest.test_case "set/get roundtrip" `Quick (fun () ->
                  match !roundtrip with
                  | Some (Ok (Some v)) ->
                      Alcotest.(check string)
                        "value round-trips through IndexedDB" "hello world" v
                  | Some (Ok None) ->
                      Alcotest.fail "expected Some value but got Ok None"
                  | Some (Error e) ->
                      Alcotest.fail
                        ("expected Ok (Some _) but got error: "
                        ^ Nopal_storage.message e)
                  | None -> Alcotest.fail "roundtrip task never resolved");
              Alcotest.test_case "non-string value surfaces as Error" `Quick
                (fun () ->
                  match !corrupt with
                  | Some (Error (Nopal_storage.Backend_error _)) -> ()
                  | Some (Error e) ->
                      Alcotest.failf "expected Backend_error, got: %s"
                        (Nopal_storage.message e)
                  | Some (Ok _) ->
                      Alcotest.fail
                        "expected Error for a non-string value, got Ok"
                  | None -> Alcotest.fail "corrupt task never resolved");
              Alcotest.test_case "clear only clears object store" `Quick
                (fun () ->
                  (match !cleared_keys with
                  | Some (Ok keys) ->
                      Alcotest.(check (list string))
                        "kv object store emptied by clear" [] keys
                  | Some (Error e) ->
                      Alcotest.fail
                        ("expected Ok [] but got error: "
                        ^ Nopal_storage.message e)
                  | None -> Alcotest.fail "clear task never resolved");
                  let survivor =
                    Jv.call local_storage "getItem"
                      [| Jv.of_string "ls_survivor" |]
                  in
                  Alcotest.(check bool)
                    "localStorage entry survives clear ()" true
                    ((not (Jv.is_null survivor))
                    && Jv.to_string survivor = "still here"));
              (* By the time [_flush] fires, every operation above (set/get for
                 the roundtrip, get for corrupt, set/clear/keys for clear) has
                 resolved. Each opens a fresh connection, so the handle each
                 left open must have been closed — otherwise a future
                 schema-version upgrade blocks on the un-closed connections. *)
              Alcotest.test_case "each op closes its IndexedDB handle" `Quick
                (fun () ->
                  let opens = idb_counter "__idbOpenCount" in
                  let closes = idb_counter "__idbCloseCount" in
                  Alcotest.(check bool)
                    "at least one connection was opened" true (opens > 0);
                  Alcotest.(check int)
                    "every opened connection was closed" opens closes);
            ] );
        ])
