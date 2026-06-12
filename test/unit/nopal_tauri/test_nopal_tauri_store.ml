(* Unit coverage for the [Store] IPC decode seams (REQ-F5 regression,
   store.e2e.ts).

   tauri-plugin-store v2 rejects invokes with a plain STRING (serde-serialized
   command errors), not a JS [Error] — the original [error_to_string] read
   [.message] off the rejection and threw on strings, so the task never
   resolved and neither TauriStoreSetOk nor TauriStoreSetError reached
   telemetry. [decode_get_response] covers the v2 [get] wire shape: a
   [[value, found]] pair, not a bare value. *)

module Store = Nopal_tauri.Store

let jv_error msg = Jv.new' (Jv.get Jv.global "Error") [| Jv.of_string msg |]

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
    ]
