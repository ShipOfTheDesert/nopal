(* Unit coverage for the handle-based [Store] (RFC 0118, REQ-F6) and its IPC
   decode seams (REQ-F5 regression, store.e2e.ts).

   REQ-F6 makes the store a loaded handle: [load] returns an abstract [t] that
   every op must carry, so a store you never loaded is unrepresentable. The
   round-trip test drives that through [tauri_shim.js]'s rid-keyed store mock —
   the [rid] [load] returns is threaded into [set]/[get], and the value survives
   the round-trip via the per-rid store map.

   The decode seams remain: tauri-plugin-store v2 rejects invokes with a plain
   STRING (serde-serialized command errors), not a JS [Error], and [get]
   resolves the [[value, found]] pair, not a bare value. *)

module Store = Nopal_tauri.Store
module Task = Nopal_mvu.Task

let jv_error msg = Jv.new' (Jv.get Jv.global "Error") [| Jv.of_string msg |]
let store_path = "nopal_store.json"
let reset () = ignore (Jv.call Jv.global "__nopal_reset_subs" [||])

let set_invoke_failure b =
  ignore (Jv.call Jv.global "__nopal_set_invoke_failure" [| Jv.of_bool b |])

(* Run a task to completion synchronously and return its delivered value, or
   [None] if it never resolved. The shim's store commands resolve through a
   SYNCHRONOUS thenable, so [Ipc.invoke_result]'s single [then'] settles inside
   the test (a real Tauri host resolves asynchronously — that window is
   irrelevant to the wire-shape and resolve-vs-hang contracts under test). *)
let run_sync task =
  let out = ref None in
  Task.run task (fun v -> out := Some v);
  !out

let test_error_to_string_passes_string_rejection_through () =
  Alcotest.(check string)
    "plain string rejection is the message itself" "missing required key rid"
    (Store.error_to_string (Jv.of_string "missing required key rid"))

let test_error_to_string_reads_error_object_message () =
  Alcotest.(check string)
    "Error object yields its .message" "boom"
    (Store.error_to_string (jv_error "boom"))

let test_error_to_string_total_on_null () =
  Alcotest.(check string)
    "null rejection still produces a string" "unknown error"
    (Store.error_to_string Jv.null)

let test_decode_get_response_found () =
  match
    Store.decode_get_response
      (Jv.of_jv_array [| Jv.of_string "e2e-relaunch-value-42"; Jv.true' |])
  with
  | Ok (Some v) ->
      Alcotest.(check string)
        "found value is returned" "e2e-relaunch-value-42" v
  | Ok None -> Alcotest.fail "expected Ok (Some _), got Ok None"
  | Error e -> Alcotest.failf "expected Ok (Some _), got Error %s" e

let test_decode_get_response_absent () =
  match Store.decode_get_response (Jv.of_jv_array [| Jv.null; Jv.false' |]) with
  | Ok None -> ()
  | Ok (Some v) -> Alcotest.failf "expected Ok None, got Ok (Some %s)" v
  | Error e -> Alcotest.failf "expected Ok None, got Error %s" e

(* REQ-F6: [load] yields a handle; [set]/[get] thread the rid it carries, and a
   value written under a key reads back through the same handle. Exercises the
   full [load] → [get None] → [set] → [get Some] protocol over the shim's
   rid-keyed store. *)
let test_load_then_get_set_roundtrip_via_shim () =
  reset ();
  match run_sync (Store.load store_path) with
  | None -> Alcotest.fail "load hung — never resolved"
  | Some (Error e) -> Alcotest.failf "load resolved Error: %s" e
  | Some (Ok handle) -> (
      (match run_sync (Store.get handle "k1") with
      | Some (Ok None) -> ()
      | Some (Ok (Some v)) ->
          Alcotest.failf "absent key should read None, got Some %s" v
      | Some (Error e) -> Alcotest.failf "get(absent) resolved Error: %s" e
      | None -> Alcotest.fail "get(absent) hung");
      (match run_sync (Store.set handle "k1" "v1") with
      | Some (Ok ()) -> ()
      | Some (Error e) -> Alcotest.failf "set resolved Error: %s" e
      | None -> Alcotest.fail "set hung");
      match run_sync (Store.get handle "k1") with
      | Some (Ok (Some v)) ->
          Alcotest.(check string) "round-trip value via rid handle" "v1" v
      | Some (Ok None) -> Alcotest.fail "expected Some after set, got None"
      | Some (Error e) -> Alcotest.failf "get resolved Error: %s" e
      | None -> Alcotest.fail "get hung")

(* REQ-F5/REQ-F6: a rid-keyed op whose IPC rejects resolves [Error] rather than
   hanging. [load] succeeds first (failure off) to obtain the handle, then the
   shim is told to reject so [set] settles [Error]. *)
let test_op_failure_resolves_error () =
  reset ();
  match run_sync (Store.load store_path) with
  | Some (Ok handle) -> (
      set_invoke_failure true;
      match run_sync (Store.set handle "k" "v") with
      | Some (Error msg) ->
          Alcotest.(check bool)
            "failed store op resolves a non-empty Error" true
            (String.length msg > 0)
      | Some (Ok ()) -> Alcotest.fail "expected Error, op resolved Ok"
      | None -> Alcotest.fail "store op hung on failure — never resolved")
  | Some (Error e) -> Alcotest.failf "precondition: load resolved Error %s" e
  | None -> Alcotest.fail "precondition: load hung"

let () =
  Alcotest.run "nopal_tauri_store"
    [
      ( "error_to_string",
        [
          Alcotest.test_case "string rejection passes through" `Quick
            test_error_to_string_passes_string_rejection_through;
          Alcotest.test_case "Error object message is read" `Quick
            test_error_to_string_reads_error_object_message;
          Alcotest.test_case "total on null" `Quick
            test_error_to_string_total_on_null;
        ] );
      ( "decode_get_response",
        [
          Alcotest.test_case "found pair yields Some value" `Quick
            test_decode_get_response_found;
          Alcotest.test_case "absent pair yields None" `Quick
            test_decode_get_response_absent;
        ] );
      ( "handle_protocol",
        [
          Alcotest.test_case "load → set → get round-trips via rid" `Quick
            test_load_then_get_set_roundtrip_via_shim;
          Alcotest.test_case "rid-keyed op failure resolves Error" `Quick
            test_op_failure_resolves_error;
        ] );
    ]
