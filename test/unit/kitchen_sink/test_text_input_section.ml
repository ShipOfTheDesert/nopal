(* Structural cases for the text-input kitchen-sink section's restyled input.
   The section applies the three overrides a downstream consumer forked the
   component for, so what these cases assert is that each one reaches the node
   it names and that the label click completes the click-to-focus chain through
   the application's own update — the half a view function cannot do.

   Every expected value is written out here as a literal rather than read back
   from the section's own style bindings: comparing the section to itself would
   pass whatever the section happened to say. *)

open Nopal_test.Test_renderer
module Section = Kitchen_sink_app__Kitchen_sink_text_input
module Style = Nopal_style.Style
module Text = Nopal_style.Text

let vp = Nopal_element.Viewport.desktop
let restyled_box = "text-input-restyled"
let control_id = "delivery-note"
let label_id = "delivery-note-label"

let rendered () =
  let model, _ = Section.init () in
  (model, render (Section.view vp model))

let node_or_fail what = function
  | Some node -> node
  | None -> Alcotest.failf "%s not found in the rendered section" what

let label_node root =
  node_or_fail "the restyled label element"
    (find (By_attr ("id", label_id)) root)

(* The label must be a label element and not merely the node that happens to
   carry the id: locating by id alone pins the association's value and not its
   placement. A box whose only child is the label's text node is the shape the
   component promises. *)
let test_label_is_a_box_around_its_own_text () =
  let _model, r = rendered () in
  match label_node (tree r) with
  | Element { tag; children = [ Text { content; _ } ]; _ } ->
      Alcotest.(check string) "the label element is a box" "box" tag;
      Alcotest.(check string) "the label's own text" "Delivery note" content
  | Element { tag; children; _ } ->
      Alcotest.failf
        "expected a box wrapping exactly the label's text node, got a %s with \
         %d children"
        tag (List.length children)
  | Empty -> Alcotest.fail "the label id landed on an empty node"
  | Text _ -> Alcotest.fail "the label id landed on a text node"

let test_label_weight_override_reaches_the_label () =
  let _model, r = rendered () in
  let label = label_node (tree r) in
  let box_weight =
    match style label with
    | Some s -> s.Style.text.Text.font_weight
    | None -> Alcotest.fail "the label element carries no style at all"
  in
  Alcotest.(check bool)
    "the label box is Semi_bold" true
    (box_weight = Some Nopal_style.Font.Semi_bold);
  (* The text node is handed the style's text component explicitly, because
     nopal_test models no inheritance. *)
  let text_weight =
    match find (By_text "Delivery note") label with
    | Some node -> (
        match text_style node with
        | Some t -> t.Text.font_weight
        | None -> Alcotest.fail "the label's text node carries no text style")
    | None -> Alcotest.fail "the label's text node is missing"
  in
  Alcotest.(check bool)
    "the label's text node is Semi_bold too" true
    (text_weight = Some Nopal_style.Font.Semi_bold)

let test_gap_override_reaches_the_wrapper () =
  let _model, r = rendered () in
  let box =
    node_or_fail "the restyled input's wrapper box"
      (find (By_attr ("data-testid", restyled_box)) (tree r))
  in
  let column = node_or_fail "the wrapper column" (find First_child box) in
  let gap =
    match style column with
    | Some s -> s.Style.layout.gap
    | None -> Alcotest.fail "the wrapper column carries no style at all"
  in
  Alcotest.(check (option (float 0.001))) "the label-to-box gap" (Some 28.0) gap

let test_error_colour_override_reaches_the_error_slot () =
  let _model, r = rendered () in
  let box =
    node_or_fail "the restyled input's wrapper box"
      (find (By_attr ("data-testid", restyled_box)) (tree r))
  in
  let slot =
    node_or_fail "the role=alert error slot"
      (find (By_attr ("role", "alert")) box)
  in
  let expected = Some (Nopal_style.Color.hex "#b3261e") in
  let colour_of = function
    | Some (t : Text.t) -> t.Text.color
    | None -> None
  in
  Alcotest.(check bool)
    "the error slot's own colour" true
    (Option.equal Nopal_style.Color.equal
       (colour_of (Option.map (fun (s : Style.t) -> s.Style.text) (style slot)))
       expected);
  let text_colour =
    match find (By_text "A delivery note is required") slot with
    | Some node -> colour_of (text_style node)
    | None -> Alcotest.fail "the error message's text node is missing"
  in
  Alcotest.(check bool)
    "the error message's text node carries it too" true
    (Option.equal Nopal_style.Color.equal text_colour expected)

(* The whole point of routing the click through the application: the component
   hands it out as a message and the application answers with Cmd.focus. This
   walks that chain end to end — the handler fires, update receives the message,
   and the command names the control's own id. *)
let test_label_click_asks_the_update_for_focus () =
  let model, r = rendered () in
  match box_pointer_down (By_attr ("id", label_id)) ~x:4.0 ~y:4.0 r with
  | Error (Not_found _) ->
      Alcotest.fail "no box carries the restyled label's id"
  | Error (No_handler { tag; event }) ->
      Alcotest.failf "the restyled label (%s) has no %s handler" tag event
  | Ok () -> (
      match messages r with
      | [ msg ] ->
          let _model, cmd = Section.update model msg in
          Alcotest.(check (option string))
            "update answers the label click with Cmd.focus on the control"
            (Some control_id)
            (Nopal_mvu.Cmd.extract_focus cmd)
      | msgs ->
          Alcotest.failf "expected exactly one message, got %d"
            (List.length msgs))

let () =
  Alcotest.run "kitchen_sink_text_input_section"
    [
      ( "restyled input",
        [
          Alcotest.test_case "label is a box around its own text" `Quick
            test_label_is_a_box_around_its_own_text;
          Alcotest.test_case "label weight override reaches the label" `Quick
            test_label_weight_override_reaches_the_label;
          Alcotest.test_case "gap override reaches the wrapper" `Quick
            test_gap_override_reaches_the_wrapper;
          Alcotest.test_case "error colour override reaches the error slot"
            `Quick test_error_colour_override_reaches_the_error_slot;
        ] );
      ( "click to focus",
        [
          Alcotest.test_case "label click asks the update for focus" `Quick
            test_label_click_asks_the_update_for_focus;
        ] );
    ]
