(* Native Telemetry_test coverage for the router-demo wizard (RFC 0112 Task 4).

   Drives the real MVU loop via {!Nopal_test.Telemetry_test} and asserts the
   update -> Message / Model_transition mapping for push / replace / back. The
   mock NAV platform's [back] is a no-op and never fires popstate, so
   [Route_changed] does not fire here — the real popstate->message path is the
   job of [router-navigation.spec.ts]. These cases assert what the browser
   cannot: that push deepens history, replace does not, and back returns to the
   prior step, all observable through [depth] without a browser. *)

module App = Router_demo_app
module Harness = Nopal_test.Telemetry_test

(* A mock NAV platform: push/replace record the path; [back] is a no-op (the
   native harness has no popstate to drive [Route_changed]). *)
let make_router () =
  let current = ref "/" in
  let platform =
    (module struct
      let current_path () = !current
      let push_state path = current := path
      let replace_state path = current := path
      let back () = ()
      let on_popstate _callback () = ()
    end : Nopal_platform.Platform.NAV)
  in
  Nopal_platform.Router.create ~platform ~parse:App.parse ~to_path:App.to_path
    ~not_found:App.Step_one

let app_module router =
  (module struct
    type model = App.model
    type msg = App.msg

    let init = App.init router
    let update = App.update router
    let view = App.view
    let subscriptions = App.subscriptions router
  end : Nopal_mvu.App.S
    with type model = App.model
     and type msg = App.msg)

let run msgs =
  Harness.run_with_telemetry
    (app_module (make_router ()))
    ~serialize_msg:App.serialize_msg ~serialize_model:App.serialize_model msgs

let next_pushes_step_and_deepens () =
  let initial, _ = run [] in
  let final, events = run [ App.Next App.Step_two ] in
  Harness.assert_dispatched events ~fragment:"Next Step_two";
  Harness.assert_model_contains events ~fragment:"step=Step_two;";
  Alcotest.(check bool)
    "push deepens history depth" true
    (final.App.depth > initial.App.depth)

let jump_to_summary_replaces_without_deepening () =
  let after_next, _ = run [ App.Next App.Step_two ] in
  let final, events = run [ App.Next App.Step_two; App.Jump_to_summary ] in
  Harness.assert_model_contains events ~fragment:"step=Summary;";
  (* Replace must leave depth where the prior push left it; a push would have
     deepened it further. Comparing the two runs encodes the contract without
     hard-coding the absolute depth. *)
  Alcotest.(check int)
    "replace leaves history depth unchanged" after_next.App.depth
    final.App.depth

let back_returns_to_previous_step () =
  let after_next, _ = run [ App.Next App.Step_two ] in
  let final, events = run [ App.Next App.Step_two; App.Back ] in
  Harness.assert_sequence events ~fragments:[ "Next Step_two"; "Back" ];
  Harness.assert_model_contains events ~fragment:"step=Step_one;";
  Alcotest.(check bool)
    "back decreases history depth" true
    (final.App.depth < after_next.App.depth)

(* [parse] is partial: it reports only the segments it knows and returns [None]
   for anything else, leaving the fallback to the router's [~not_found]. A known
   segment must parse; an unknown one (including the root) must not. *)
let parse_maps_known_segments () =
  let eq label expected actual =
    Alcotest.(check bool) label true (expected = actual)
  in
  eq "step-two parses" (Some App.Step_two) (App.parse "step-two");
  eq "step-three parses" (Some App.Step_three)
    (App.parse "/router_demo/step-three");
  eq "summary parses" (Some App.Summary) (App.parse "summary")

let parse_returns_none_for_unknown () =
  Alcotest.(check bool)
    "unknown segment is None" true
    (App.parse "/bogus" = None);
  Alcotest.(check bool) "root is None" true (App.parse "/" = None)

(* With [parse] partial, an unknown initial path must resolve through the
   router's [~not_found] (here [Step_one]) rather than a hard-coded arm. *)
let current_falls_back_to_not_found () =
  let current = ref "/bogus" in
  let platform =
    (module struct
      let current_path () = !current
      let push_state path = current := path
      let replace_state path = current := path
      let back () = ()
      let on_popstate _callback () = ()
    end : Nopal_platform.Platform.NAV)
  in
  let router =
    Nopal_platform.Router.create ~platform ~parse:App.parse ~to_path:App.to_path
      ~not_found:App.Step_one
  in
  Alcotest.(check bool)
    "unknown path resolves to not_found" true
    (Nopal_platform.Router.current router = App.Step_one)

let () =
  Alcotest.run "router_demo"
    [
      ( "wizard navigation",
        [
          Alcotest.test_case "next pushes step and deepens" `Quick
            next_pushes_step_and_deepens;
          Alcotest.test_case "jump to summary replaces without deepening" `Quick
            jump_to_summary_replaces_without_deepening;
          Alcotest.test_case "back returns to previous step" `Quick
            back_returns_to_previous_step;
        ] );
      ( "path parsing",
        [
          Alcotest.test_case "parse maps known segments" `Quick
            parse_maps_known_segments;
          Alcotest.test_case "parse returns None for unknown" `Quick
            parse_returns_none_for_unknown;
          Alcotest.test_case "current falls back to not_found" `Quick
            current_falls_back_to_not_found;
        ] );
    ]
