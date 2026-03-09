open Nopal_test.Test_renderer
module E = Nopal_element.Element
module Ix = Nopal_style.Interaction
module S = Nopal_style.Style

let hover_style =
  S.with_paint (fun p -> { p with background = Some (S.hex "#aaa") }) S.default

let pressed_style =
  S.with_paint (fun p -> { p with background = Some (S.hex "#888") }) S.default

let focused_style =
  S.with_paint
    (fun p ->
      {
        p with
        border =
          Some { S.default_border with color = S.hex "#00f"; width = 2.0 };
      })
    S.default

(* 1. Button with default interaction has Interaction.default *)
let test_render_button_no_interaction () =
  let r = render (E.button (E.text "ok")) in
  let btn = find (By_tag "button") (tree r) in
  match btn with
  | Some node ->
      Alcotest.(check (option bool))
        "default interaction" (Some true)
        (Option.map (Ix.equal Ix.default) (interaction node))
  | None -> Alcotest.fail "button not found"

(* 2. Button with hover style carries it through *)
let test_render_button_with_hover () =
  let ix = { Ix.default with hover = Some hover_style } in
  let r = render (E.button ~interaction:ix (E.text "ok")) in
  let btn = find (By_tag "button") (tree r) in
  match btn with
  | Some node ->
      Alcotest.(check (option bool))
        "hover interaction preserved" (Some true)
        (Option.map (Ix.equal ix) (interaction node))
  | None -> Alcotest.fail "button not found"

(* 3. Box with all three states set *)
let test_render_box_with_all_states () =
  let ix =
    {
      Ix.hover = Some hover_style;
      pressed = Some pressed_style;
      focused = Some focused_style;
    }
  in
  let r = render (E.box ~interaction:ix [ E.text "card" ]) in
  let bx = find (By_tag "box") (tree r) in
  match bx with
  | Some node ->
      Alcotest.(check (option bool))
        "all states preserved" (Some true)
        (Option.map (Ix.equal ix) (interaction node))
  | None -> Alcotest.fail "box not found"

(* 4. has_hover returns true when hover is set *)
let test_has_hover_true () =
  let ix = { Ix.default with hover = Some hover_style } in
  let r = render (E.button ~interaction:ix (E.text "ok")) in
  let btn = find (By_tag "button") (tree r) in
  match btn with
  | Some node -> Alcotest.(check bool) "has_hover is true" true (has_hover node)
  | None -> Alcotest.fail "button not found"

(* 5. has_hover returns false when hover is not set *)
let test_has_hover_false () =
  let r = render (E.button (E.text "ok")) in
  let btn = find (By_tag "button") (tree r) in
  match btn with
  | Some node ->
      Alcotest.(check bool) "has_hover is false" false (has_hover node)
  | None -> Alcotest.fail "button not found"

(* 6. has_pressed returns true when pressed is set *)
let test_has_pressed_true () =
  let ix = { Ix.default with pressed = Some pressed_style } in
  let r = render (E.button ~interaction:ix (E.text "ok")) in
  let btn = find (By_tag "button") (tree r) in
  match btn with
  | Some node ->
      Alcotest.(check bool) "has_pressed is true" true (has_pressed node)
  | None -> Alcotest.fail "button not found"

(* 7. has_focused returns true when focused is set *)
let test_has_focused_true () =
  let ix = { Ix.default with focused = Some focused_style } in
  let r = render (E.input ~interaction:ix "val") in
  let inp = find (By_tag "input") (tree r) in
  match inp with
  | Some node ->
      Alcotest.(check bool) "has_focused is true" true (has_focused node)
  | None -> Alcotest.fail "input not found"

(* 8. Text node returns None for interaction *)
let test_interaction_none_for_text () =
  let r = render (E.text "hello") in
  Alcotest.(check bool)
    "text has no interaction" true
    (Option.is_none (interaction (tree r)))

(* 9. Empty node returns None for interaction *)
let test_interaction_none_for_empty () =
  let r = render E.empty in
  Alcotest.(check bool)
    "empty has no interaction" true
    (Option.is_none (interaction (tree r)))

let () =
  Alcotest.run "Test_interaction_rendering"
    [
      ( "interaction_rendering",
        [
          Alcotest.test_case "render_button_no_interaction" `Quick
            test_render_button_no_interaction;
          Alcotest.test_case "render_button_with_hover" `Quick
            test_render_button_with_hover;
          Alcotest.test_case "render_box_with_all_states" `Quick
            test_render_box_with_all_states;
          Alcotest.test_case "has_hover_true" `Quick test_has_hover_true;
          Alcotest.test_case "has_hover_false" `Quick test_has_hover_false;
          Alcotest.test_case "has_pressed_true" `Quick test_has_pressed_true;
          Alcotest.test_case "has_focused_true" `Quick test_has_focused_true;
          Alcotest.test_case "interaction_none_for_text" `Quick
            test_interaction_none_for_text;
          Alcotest.test_case "interaction_none_for_empty" `Quick
            test_interaction_none_for_empty;
        ] );
    ]
