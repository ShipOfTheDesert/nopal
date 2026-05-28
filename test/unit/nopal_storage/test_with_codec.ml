(** Behavioural tests for the typed [With_codec] wrapper over [In_memory]
    (REQ-F4, REQ-F2). *)

let run_sync : 'a Nopal_mvu.Task.t -> 'a =
 fun task ->
  let result = ref None in
  Nopal_mvu.Task.run task (fun value -> result := Some value);
  match !result with
  | Some value -> value
  | None -> Alcotest.fail "task did not resolve synchronously"

(* A small structured value to round-trip through encode/decode. *)
type point = { x : int; y : int }

let encode_point p = Printf.sprintf "%d,%d" p.x p.y

let decode_point s =
  match String.split_on_char ',' s with
  | [ a; b ] -> (
      match (int_of_string_opt a, int_of_string_opt b) with
      | Some x, Some y -> Ok { x; y }
      | _ -> Error "components are not integers")
  | _ -> Error "expected two comma-separated components"

let point_testable =
  Alcotest.testable
    (fun fmt { x; y } -> Format.fprintf fmt "(%d, %d)" x y)
    (fun a b -> a.x = b.x && a.y = b.y)

let test_typed_roundtrip () =
  let module Store = Nopal_storage.In_memory () in
  let module Codec = Nopal_storage.With_codec (Store) in
  let value = { x = 3; y = 4 } in
  let (_ : (unit, Nopal_storage.error) result) =
    run_sync (Codec.set ~key:"p" ~value ~encode:encode_point)
  in
  match run_sync (Codec.get "p" ~decode:decode_point) with
  | Ok (Some decoded) ->
      Alcotest.(check point_testable) "decoded value round-trips" value decoded
  | Ok None -> Alcotest.fail "expected Some, got None"
  | Error (Storage e) ->
      Alcotest.failf "expected Ok, got Storage error %s"
        (Nopal_storage.message e)
  | Error (Decode msg) -> Alcotest.failf "expected Ok, got Decode error %s" msg

let test_typed_decode_failure_returns_decode_error () =
  let module Store = Nopal_storage.In_memory () in
  let module Codec = Nopal_storage.With_codec (Store) in
  (* Store a raw string the decoder cannot parse. *)
  let (_ : (unit, Nopal_storage.error) result) =
    run_sync (Store.set ~key:"p" ~value:"not-a-point")
  in
  match run_sync (Codec.get "p" ~decode:decode_point) with
  | Error (Decode _) -> ()
  | Ok _ -> Alcotest.fail "expected Decode error, got Ok"
  | Error (Storage e) ->
      Alcotest.failf "expected Decode error, got Storage %s"
        (Nopal_storage.message e)

let test_typed_get_absent_skips_decode () =
  let module Store = Nopal_storage.In_memory () in
  let module Codec = Nopal_storage.With_codec (Store) in
  let decode_called = ref false in
  let decode _ =
    decode_called := true;
    Error "decode should not have been called"
  in
  let result = run_sync (Codec.get "missing" ~decode) in
  (match result with
  | Ok None -> ()
  | Ok (Some _) -> Alcotest.fail "expected None for a missing key"
  | Error (Decode msg) -> Alcotest.failf "unexpected Decode error %s" msg
  | Error (Storage e) ->
      Alcotest.failf "unexpected Storage error %s" (Nopal_storage.message e));
  Alcotest.(check bool)
    "decode was not invoked for an absent key" false !decode_called

let () =
  Alcotest.run "nopal_storage (With_codec)"
    [
      ( "typed wrapper",
        [
          Alcotest.test_case "typed roundtrip" `Quick test_typed_roundtrip;
          Alcotest.test_case "decode failure returns Decode error" `Quick
            test_typed_decode_failure_returns_decode_error;
          Alcotest.test_case "get absent skips decode" `Quick
            test_typed_get_absent_skips_decode;
        ] );
    ]
