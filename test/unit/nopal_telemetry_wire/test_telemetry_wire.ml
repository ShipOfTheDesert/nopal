module Telemetry = Nopal_runtime.Telemetry
module Wire = Nopal_telemetry_wire

let event_testable =
  Alcotest.testable (fun fmt e -> Telemetry.pp_events fmt [ e ]) ( = )

let roundtrip e =
  match Wire.event_of_jv (Wire.event_to_jv e) with
  | Ok decoded -> decoded
  | Error msg -> Alcotest.failf "expected Ok on round-trip, got Error %S" msg

let test_event_roundtrip () =
  let cases =
    [
      Telemetry.Message "Increment";
      Telemetry.Model_transition { before = "0"; after = "1" };
      Telemetry.Command "after";
      Telemetry.Subscription "every";
    ]
  in
  List.iter
    (fun e ->
      Alcotest.(check event_testable) "round-trips unchanged" e (roundtrip e))
    cases

let test_event_of_jv_unknown_kind () =
  let jv = Jv.obj [| ("kind", Jv.of_string "bogus") |] in
  match Wire.event_of_jv jv with
  | Ok _ -> Alcotest.fail "expected Error on unknown kind"
  | Error msg ->
      Alcotest.(check bool)
        "error names the offending kind" true
        (Jv.to_bool
           (Jv.call (Jv.of_string msg) "includes" [| Jv.of_string "bogus" |]))

let test_events_roundtrip_preserves_order () =
  let events =
    [
      Telemetry.Message "a"; Telemetry.Command "perform"; Telemetry.Message "b";
    ]
  in
  match Wire.events_of_jv (Wire.events_to_jv events) with
  | Ok decoded ->
      Alcotest.(check (list event_testable))
        "list decodes in order" events decoded
  | Error msg -> Alcotest.failf "expected Ok, got Error %S" msg

let test_events_of_jv_short_circuits () =
  let good = Wire.event_to_jv (Telemetry.Message "ok") in
  let bad = Jv.obj [| ("kind", Jv.of_string "nope") |] in
  let arr = Jv.of_list Fun.id [ good; bad ] in
  match Wire.events_of_jv arr with
  | Ok _ -> Alcotest.fail "expected Error when one element is malformed"
  | Error _ -> ()

let () =
  Alcotest.run "nopal_telemetry_wire"
    [
      ( "codec",
        [
          Alcotest.test_case "event round-trips" `Quick test_event_roundtrip;
          Alcotest.test_case "unknown kind is Error" `Quick
            test_event_of_jv_unknown_kind;
          Alcotest.test_case "events round-trip preserves order" `Quick
            test_events_roundtrip_preserves_order;
          Alcotest.test_case "events_of_jv short-circuits on bad element" `Quick
            test_events_of_jv_short_circuits;
        ] );
    ]
