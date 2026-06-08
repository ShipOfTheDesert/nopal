(* Structural coverage for the kitchen-sink wizard section (RFC 0112).

   Sub_wizard is the router-free visual twin of examples/router_demo: it steps
   through local {step; depth} state rather than driving the History API. The
   real routing behaviour is covered natively by test_router_demo.ml; this
   asserts the section's own update transitions and that its view emits the
   call-site interaction anchors the E2E specs target. *)

open Nopal_test.Test_renderer
module Sub_wizard = Kitchen_sink_app__Sub_wizard

let vp = Nopal_element.Viewport.desktop

(* --- update: step transitions and depth accounting --- *)

let next_advances_and_deepens () =
  let model, _ = Sub_wizard.init () in
  let model', _ =
    Sub_wizard.update model (Sub_wizard.Next Sub_wizard.Step_two)
  in
  Alcotest.(check bool)
    "step advanced to Step_two" true
    (model'.Sub_wizard.step = Sub_wizard.Step_two);
  Alcotest.(check int)
    "depth deepened"
    (model.Sub_wizard.depth + 1)
    model'.Sub_wizard.depth

let jump_to_summary_replaces_without_deepening () =
  let model, _ = Sub_wizard.init () in
  let model', _ =
    Sub_wizard.update model (Sub_wizard.Next Sub_wizard.Step_two)
  in
  let final, _ = Sub_wizard.update model' Sub_wizard.Jump_to_summary in
  Alcotest.(check bool)
    "step is Summary" true
    (final.Sub_wizard.step = Sub_wizard.Summary);
  Alcotest.(check int)
    "replace leaves depth unchanged" model'.Sub_wizard.depth
    final.Sub_wizard.depth

let back_returns_to_previous_step () =
  let model, _ = Sub_wizard.init () in
  let model', _ =
    Sub_wizard.update model (Sub_wizard.Next Sub_wizard.Step_two)
  in
  let final, _ = Sub_wizard.update model' Sub_wizard.Back in
  Alcotest.(check bool)
    "step returned to Step_one" true
    (final.Sub_wizard.step = Sub_wizard.Step_one);
  Alcotest.(check int)
    "depth decremented" model.Sub_wizard.depth final.Sub_wizard.depth

let back_from_first_step_floors_depth_at_one () =
  let model, _ = Sub_wizard.init () in
  let final, _ = Sub_wizard.update model Sub_wizard.Back in
  Alcotest.(check bool)
    "step stays Step_one" true
    (final.Sub_wizard.step = Sub_wizard.Step_one);
  Alcotest.(check int) "depth never drops below 1" 1 final.Sub_wizard.depth

(* --- view: call-site interaction anchors the E2E specs target --- *)

let view_emits_navigation_anchors () =
  let model, _ = Sub_wizard.init () in
  let root = tree (render (Sub_wizard.view vp model)) in
  let has action =
    Option.is_some (find (By_attr ("data-action", action)) root)
  in
  Alcotest.(check bool) "wizard-next anchor present" true (has "wizard-next");
  Alcotest.(check bool) "wizard-back anchor present" true (has "wizard-back");
  Alcotest.(check bool)
    "wizard-jump-summary anchor present" true
    (has "wizard-jump-summary")

let () =
  Alcotest.run "kitchen_sink_wizard_section"
    [
      ( "update",
        [
          Alcotest.test_case "next advances and deepens" `Quick
            next_advances_and_deepens;
          Alcotest.test_case "jump to summary replaces without deepening" `Quick
            jump_to_summary_replaces_without_deepening;
          Alcotest.test_case "back returns to previous step" `Quick
            back_returns_to_previous_step;
          Alcotest.test_case "back from first step floors depth at one" `Quick
            back_from_first_step_floors_depth_at_one;
        ] );
      ( "view",
        [
          Alcotest.test_case "view emits navigation anchors" `Quick
            view_emits_navigation_anchors;
        ] );
    ]
