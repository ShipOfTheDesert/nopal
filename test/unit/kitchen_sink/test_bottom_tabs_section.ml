(* Native telemetry coverage for the kitchen-sink bottom-tabs section
   (RFC 0114 Task 3 / ADR 0108). Drives the real MVU loop via
   {!Nopal_test.Telemetry_test} and asserts the per-tab stack-depth
   preservation contract (REQ-F3): switching away from a tab and back leaves
   that tab's navigation depth untouched.

   This is the MVU-layer (telemetry) twin of the Playwright preservation spec —
   the depth is observable purely through the serialized model, no browser. *)

module Sub = Kitchen_sink_app__Sub_bottom_tabs
module Harness = Nopal_test.Telemetry_test

let app_module =
  (module Sub : Nopal_mvu.App.S
    with type model = Sub.model
     and type msg = Sub.msg)

let run msgs =
  Harness.run_with_telemetry app_module ~serialize_model:Sub.serialize_model
    msgs

let tab_switch_preserves_stack_depth () =
  let final, events =
    run
      [
        Sub.Select "profile";
        Sub.Push Sub.Profile_detail;
        Sub.Select "home";
        Sub.Select "profile";
      ]
  in
  (* Profile was driven two deep and must still read depth 2 after the round
     trip through home — the defining preservation contract. The trailing [;]
     rules out a [profile_depth=2] match inside a larger depth. *)
  Harness.assert_model_contains events ~fragment:"profile_depth=2;";
  (* Negative: home never received the push, so its depth must remain 1. *)
  let model_str = Sub.serialize_model final in
  Alcotest.(check bool)
    "home stack not deepened (no depth 2)" false
    (Test_util.string_contains model_str ~sub:"home_depth=2;");
  Alcotest.(check bool)
    "home stack preserved at root depth" true
    (Test_util.string_contains model_str ~sub:"home_depth=1;")

let () =
  Alcotest.run "kitchen_sink_bottom_tabs_section"
    [
      ( "preservation",
        [
          Alcotest.test_case "tab switch preserves each tab's stack depth"
            `Quick tab_switch_preserves_stack_depth;
        ] );
    ]
