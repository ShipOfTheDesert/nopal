(* Runtime integration tests for telemetry recording (RFC 0110 Stage 3).

   These drive real apps through [create_with_telemetry] and assert on the
   recorded event log via the public [Nopal_runtime.Telemetry] query surface —
   no white-box access is needed, because recording is observed end to end
   through the same query API applications use. *)
module Telemetry = Nopal_runtime.Telemetry

let event_testable =
  let pp fmt e = Telemetry.pp_events fmt [ e ] in
  Alcotest.testable pp ( = )

(* App with no subscriptions. [update] issues a [perform] command only for the
   message 99, so command recording can be exercised independently of the
   message/transition recording (every other message returns [Cmd.none]). *)
module Telemetry_app :
  Nopal_mvu.App.S with type model = int and type msg = int = struct
  type model = int
  type msg = int

  let init () = (0, Nopal_mvu.Cmd.none)

  let update model msg =
    let cmd =
      if msg = 99 then Nopal_mvu.Cmd.perform (fun _dispatch -> ())
      else Nopal_mvu.Cmd.none
    in
    (model + msg, cmd)

  let view _vp model = Nopal_element.Element.text (string_of_int model)
  let subscriptions _model = Nopal_mvu.Sub.none
end

module R = Nopal_runtime.Runtime.Make (Telemetry_app)

(* App whose single custom subscription dispatches one message as it is set up,
   so a subscription firing can be observed at the Sub_manager seam. The key is
   stable across models, so the subscription is set up exactly once. *)
module Sub_telemetry_app :
  Nopal_mvu.App.S with type model = int and type msg = int = struct
  type model = int
  type msg = int

  let init () = (0, Nopal_mvu.Cmd.none)
  let update model msg = (model + msg, Nopal_mvu.Cmd.none)
  let view _vp model = Nopal_element.Element.text (string_of_int model)

  let subscriptions _model =
    Nopal_mvu.Sub.custom "sub-fire" (fun dispatch ->
        dispatch 100;
        fun () -> ())
end

module RS = Nopal_runtime.Runtime.Make (Sub_telemetry_app)

let test_dispatch_records_message_and_transition () =
  let rt, handle =
    R.create_with_telemetry ~serialize_msg:string_of_int
      ~serialize_model:string_of_int ()
  in
  R.start rt;
  R.dispatch rt 5;
  Alcotest.(check (list event_testable))
    "message then transition, no command recorded for Cmd.none"
    [
      Telemetry.Message "5";
      Telemetry.Model_transition { before = "0"; after = "5" };
    ]
    (Telemetry.events handle)

let test_dispatch_records_command () =
  let rt, handle =
    R.create_with_telemetry ~serialize_msg:string_of_int
      ~serialize_model:string_of_int ()
  in
  R.start rt;
  R.dispatch rt 99;
  Alcotest.(check (list event_testable))
    "non-none command recorded with its Cmd.describe label"
    [
      Telemetry.Message "99";
      Telemetry.Model_transition { before = "0"; after = "99" };
      Telemetry.Command "perform";
    ]
    (Telemetry.events handle)

let test_subscription_fire_records_event () =
  let rt, handle =
    RS.create_with_telemetry ~serialize_msg:string_of_int
      ~serialize_model:string_of_int ()
  in
  RS.start rt;
  Alcotest.(check (list event_testable))
    "subscription event immediately precedes the resulting message"
    [
      Telemetry.Subscription "custom";
      Telemetry.Message "100";
      Telemetry.Model_transition { before = "0"; after = "100" };
    ]
    (Telemetry.events handle)

let test_plain_runtime_records_nothing () =
  let plain = R.create () in
  R.start plain;
  R.dispatch plain 5;
  R.dispatch plain 99;
  let rt, handle =
    R.create_with_telemetry ~serialize_msg:string_of_int
      ~serialize_model:string_of_int ()
  in
  R.start rt;
  R.dispatch rt 5;
  R.dispatch rt 99;
  Alcotest.(check int)
    "plain runtime's final model identical to the telemetry run" (R.model rt)
    (R.model plain);
  Alcotest.(check bool)
    "telemetry run did record events (so the model comparison is meaningful)"
    true
    (List.length (Telemetry.events handle) > 0)

let test_omitted_serialiser_yields_placeholder () =
  let rt, handle = R.create_with_telemetry () in
  R.start rt;
  R.dispatch rt 5;
  Alcotest.(check (list event_testable))
    "omitted serialisers record <opaque>; the event is not dropped"
    [
      Telemetry.Message "<opaque>";
      Telemetry.Model_transition { before = "<opaque>"; after = "<opaque>" };
    ]
    (Telemetry.events handle)

let () =
  Alcotest.run "runtime_telemetry"
    [
      ( "Recording",
        [
          Alcotest.test_case "dispatch records message and transition" `Quick
            test_dispatch_records_message_and_transition;
          Alcotest.test_case "dispatch records command" `Quick
            test_dispatch_records_command;
          Alcotest.test_case "subscription fire records event" `Quick
            test_subscription_fire_records_event;
          Alcotest.test_case "plain runtime records nothing" `Quick
            test_plain_runtime_records_nothing;
          Alcotest.test_case "omitted serialiser yields placeholder" `Quick
            test_omitted_serialiser_yields_placeholder;
        ] );
    ]
