(* Native telemetry harness tests (RFC 0110 Stage 4).

   These exercise [Nopal_test.Telemetry_test]: driving a real app through the
   MVU loop while recording, the dump-then-re-raise behaviour on application
   exceptions, and the OCaml-side assertion helpers (which match on the public
   [Nopal_runtime.Telemetry.event] surface). *)

module Telemetry = Nopal_runtime.Telemetry
module Harness = Nopal_test.Telemetry_test

let event_testable =
  let pp fmt e = Telemetry.pp_events fmt [ e ] in
  Alcotest.testable pp ( = )

(* Substring test for asserting on diagnostic messages. *)
let contains haystack needle =
  let nlen = String.length needle and hlen = String.length haystack in
  if nlen = 0 then true
  else if nlen > hlen then false
  else
    let rec at i =
      if i + nlen > hlen then false
      else if String.sub haystack i nlen = needle then true
      else at (i + 1)
    in
    at 0

(* A counter app: [update] sums the message into the model, never issues a
   command, and has no subscriptions — so the recorded log is exactly the
   message/transition pairs for the driven sequence. *)
module Counter_app : Nopal_mvu.App.S with type model = int and type msg = int =
struct
  type model = int
  type msg = int

  let init () = (0, Nopal_mvu.Cmd.none)
  let update model msg = (model + msg, Nopal_mvu.Cmd.none)
  let view _vp model = Nopal_element.Element.text (string_of_int model)
  let subscriptions _model = Nopal_mvu.Sub.none
end

(* A pre-built, heap-allocated exception value so the re-raise can be checked by
   physical identity (a reconstructed/wrapped exception would not be [==]). *)
exception Boom of string

let the_boom = Boom "update failed at msg 2"

(* Raises [the_boom] when it sees the message 2, otherwise sums like the
   counter. Drives the dump-then-re-raise path. *)
module Raising_app : Nopal_mvu.App.S with type model = int and type msg = int =
struct
  type model = int
  type msg = int

  let init () = (0, Nopal_mvu.Cmd.none)

  let update model msg =
    if msg = 2 then raise the_boom else (model + msg, Nopal_mvu.Cmd.none)

  let view _vp model = Nopal_element.Element.text (string_of_int model)
  let subscriptions _model = Nopal_mvu.Sub.none
end

let test_harness_drives_and_records () =
  let final, events =
    Harness.run_with_telemetry
      (module Counter_app)
      ~serialize_msg:string_of_int ~serialize_model:string_of_int [ 1; 2 ]
  in
  Alcotest.(check int) "final model is the running sum" 3 final;
  Alcotest.(check (list event_testable))
    "ordered message/transition history for the driven sequence"
    [
      Telemetry.Message "1";
      Telemetry.Model_transition { before = "0"; after = "1" };
      Telemetry.Message "2";
      Telemetry.Model_transition { before = "1"; after = "3" };
    ]
    events

let test_app_exception_dumps_and_reraises () =
  let raised =
    match
      Harness.run_with_telemetry
        (module Raising_app)
        ~serialize_msg:string_of_int ~serialize_model:string_of_int [ 1; 2; 3 ]
    with
    | _model, _events -> None
    | exception e -> Some e
  in
  (match raised with
  | Some e ->
      Alcotest.(check bool)
        "the SAME exception value is re-raised (physical identity)" true
        (e == the_boom)
  | None ->
      Alcotest.fail "expected run_with_telemetry to re-raise the app exception");
  (* A subsequent run is unaffected by the failed one: it starts from an empty
     log and records only its own sequence. *)
  let _final, events =
    Harness.run_with_telemetry
      (module Counter_app)
      ~serialize_msg:string_of_int ~serialize_model:string_of_int [ 7 ]
  in
  Alcotest.(check (list event_testable))
    "subsequent run records only its own events"
    [
      Telemetry.Message "7";
      Telemetry.Model_transition { before = "0"; after = "7" };
    ]
    events

let test_assert_dispatched_diagnostic () =
  let events = [ Telemetry.Message "hello"; Telemetry.Command "perform" ] in
  (* Present fragment passes without raising. *)
  Harness.assert_dispatched events ~fragment:"ell";
  (* Absent fragment raises [Failure] whose message lists the actual events. *)
  let msg =
    try
      Harness.assert_dispatched events ~fragment:"absent";
      Alcotest.fail "expected assert_dispatched to raise on an absent fragment"
    with
    | Failure m -> m
  in
  Alcotest.(check bool)
    "diagnostic names the missing fragment" true (contains msg "absent");
  Alcotest.(check bool)
    "diagnostic dumps the actual recorded events" true (contains msg "hello")

let test_assert_sequence_allows_gaps_rejects_disorder () =
  let events =
    [
      Telemetry.Message "alpha";
      Telemetry.Command "perform";
      Telemetry.Message "beta";
      Telemetry.Subscription "every";
      Telemetry.Message "gamma";
    ]
  in
  (* In order, with unrelated Command/Subscription events between — passes. *)
  Harness.assert_sequence events ~fragments:[ "alpha"; "beta"; "gamma" ];
  (* Out of order — fails. *)
  let raised =
    try
      Harness.assert_sequence events ~fragments:[ "gamma"; "alpha" ];
      false
    with
    | Failure _ -> true
  in
  Alcotest.(check bool) "out-of-order fragments are rejected" true raised

let test_assert_model_contains () =
  let events =
    [ Telemetry.Model_transition { before = "count: 0"; after = "count: 5" } ]
  in
  Harness.assert_model_contains events ~fragment:"count: 5";
  let raised =
    try
      Harness.assert_model_contains events ~fragment:"count: 9";
      false
    with
    | Failure _ -> true
  in
  Alcotest.(check bool) "absent model fragment is rejected" true raised

let () =
  Alcotest.run "telemetry_harness"
    [
      ( "Harness",
        [
          Alcotest.test_case "drives and records" `Quick
            test_harness_drives_and_records;
          Alcotest.test_case "app exception dumps and re-raises" `Quick
            test_app_exception_dumps_and_reraises;
        ] );
      ( "Assertions",
        [
          Alcotest.test_case "assert_dispatched diagnostic" `Quick
            test_assert_dispatched_diagnostic;
          Alcotest.test_case "assert_sequence allows gaps, rejects disorder"
            `Quick test_assert_sequence_allows_gaps_rejects_disorder;
          Alcotest.test_case "assert_model_contains" `Quick
            test_assert_model_contains;
        ] );
    ]
