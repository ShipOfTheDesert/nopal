(* The radio-group-in-a-row kitchen-sink section, read structurally.

   The structural renderer lays nothing out, so whether the options really sit
   side by side is the browser spec's to show. What this file pins is what that
   spec leans on: a group named by a visible label, an options box whose style
   asks for a row with a gap, a group style that spaces the label from the
   options, and a selection that reaches the model. The expected label, ids and
   values are the section's documented ones, written out here rather than read
   back from the section. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_radio_row
module Style = Nopal_style.Style

let rendered msgs =
  snd
    (run_app ~init:Sub.init ~update:Sub.update
       ~view:(fun _viewport model -> Sub.view model)
       msgs)

let group_of r =
  match find (By_attr ("role", "radiogroup")) (tree r) with
  | Some node -> node
  | None -> Alcotest.fail "the section renders no radiogroup"

let layout_of what node =
  match style node with
  | Some s -> s.Style.layout
  | None -> Alcotest.fail (what ^ ": carries no style")

let children_of node =
  match node with
  | Element { children; _ } -> children
  | Empty
  | Text _ ->
      []

let check_positive_gap what (layout : Style.layout) =
  match layout.gap with
  | Some g ->
      Alcotest.(check bool) (what ^ ": the gap is above zero") true (g > 0.0)
  | None -> Alcotest.fail (what ^ ": sets no gap")

let section_group_has_visible_label () =
  let r = rendered [] in
  let group = group_of r in
  match attr "aria-labelledby" group with
  | None -> Alcotest.fail "the group is not named by aria-labelledby"
  | Some label_id -> (
      Alcotest.(check string)
        "the name points at the group's label id" "radio-row-size-label"
        label_id;
      match find (By_attr ("id", label_id)) group with
      | Some label ->
          Alcotest.(check string)
            "the label element carries the label text" "Size"
            (text_content label)
      | None -> Alcotest.fail "no element inside the group carries the label id"
      )

(* The options box is the one child of the group that holds the radios: found
   by what it holds rather than by its position, so the label box can never be
   mistaken for it. *)
let section_options_box_is_a_row () =
  let group = group_of (rendered []) in
  let holds_radios child = find_all (By_tag "radio") child <> [] in
  match List.filter holds_radios (children_of group) with
  | [ options_box ] ->
      let layout = layout_of "the options box" options_box in
      Alcotest.(check bool)
        "the options box lays its children out as a row" true
        (match layout.direction with
        | Some Style.Row_dir -> true
        | Some Style.Column_dir
        | None ->
            false);
      Alcotest.(check int)
        "the options box holds all three radios" 3
        (List.length (find_all (By_tag "radio") options_box));
      check_positive_gap "the options box" layout
  | children ->
      Alcotest.failf
        "expected one child of the group holding the radios, got %d"
        (List.length children)

let section_group_style_spaces_label_from_options () =
  let group = group_of (rendered []) in
  check_positive_gap "the group box" (layout_of "the group box" group)

let checked_of id r =
  match find (By_attr ("id", id)) (tree r) with
  | Some node -> attr "checked" node
  | None -> Alcotest.fail (id ^ ": the section renders no such radio")

let section_select_dispatches () =
  let r = rendered [] in
  (match click (By_attr ("id", "radio-row-size-large")) r with
  | Ok () -> ()
  | Error (Not_found _) -> Alcotest.fail "no radio for large"
  | Error (No_handler _) -> Alcotest.fail "selecting large dispatches nothing");
  let dispatched = messages r in
  (match dispatched with
  | [ Sub.Selected value ] ->
      Alcotest.(check string) "the message names the chosen value" "large" value
  | msgs ->
      Alcotest.failf "expected one Selected message, got %d" (List.length msgs));
  let after = rendered dispatched in
  Alcotest.(check (option string))
    "large is checked after update" (Some "true")
    (checked_of "radio-row-size-large" after);
  Alcotest.(check (option string))
    "medium is no longer checked" (Some "false")
    (checked_of "radio-row-size-medium" after)

let () =
  Alcotest.run "Radio row section"
    [
      ( "radio row",
        [
          Alcotest.test_case "section_group_has_visible_label" `Quick
            section_group_has_visible_label;
          Alcotest.test_case "section_options_box_is_a_row" `Quick
            section_options_box_is_a_row;
          Alcotest.test_case "section_group_style_spaces_label_from_options"
            `Quick section_group_style_spaces_label_from_options;
          Alcotest.test_case "section_select_dispatches" `Quick
            section_select_dispatches;
        ] );
    ]
