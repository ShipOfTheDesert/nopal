(* The hidden-radio kitchen-sink section, read structurally.

   The structural renderer paints nothing and moves no focus, so whether a
   hidden radio takes no space and whether a row's ring shows only while its
   radio has focus is the browser spec's to show. What this file pins is what
   that spec leans on: every radio hidden, every option label a native label
   for its radio, every row carrying the ring as its focus-within state, an
   options box laid out as a row, and a selection that reaches the model. The
   expected ids, values and ring are the section's documented ones, written out
   here rather than read back from the section. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_hidden_radio
module Style = Nopal_style.Style

let option_ids =
  [
    "hidden-radio-shipping-standard";
    "hidden-radio-shipping-express";
    "hidden-radio-shipping-overnight";
  ]

let declared_ring : Style.shadow =
  { x = 0.0; y = 0.0; blur = 0.0; spread = 2.0; color = Style.rgba 2 64 58 0.5 }

let shadow_testable =
  let pp fmt (s : Style.shadow) =
    let color =
      match s.color with
      | Style.Rgba { r; g; b; a } -> Printf.sprintf "rgba(%d,%d,%d,%g)" r g b a
      | Style.Hex h -> h
      | Style.Named n -> n
      | Style.Transparent -> "transparent"
    in
    Format.fprintf fmt "{x=%g; y=%g; blur=%g; spread=%g; color=%s}" s.x s.y
      s.blur s.spread color
  in
  let equal (a : Style.shadow) (b : Style.shadow) =
    Float.equal a.x b.x
    && Float.equal a.y b.y
    && Float.equal a.blur b.blur
    && Float.equal a.spread b.spread
    && Style.equal_color a.color b.color
  in
  Alcotest.testable pp equal

let rendered msgs =
  snd
    (run_app ~init:Sub.init ~update:Sub.update
       ~view:(fun _viewport model -> Sub.view model)
       msgs)

let group_of r =
  match find (By_attr ("role", "radiogroup")) (tree r) with
  | Some node -> node
  | None -> Alcotest.fail "the section renders no radiogroup"

let children_of node =
  match node with
  | Element { children; _ } -> children
  | Empty
  | Text _ ->
      []

let section_built_with_hidden_inputs () =
  let r = rendered [] in
  let group = group_of r in
  Alcotest.(check int)
    "the group holds three radios" 3
    (List.length (find_all (By_tag "radio") group));
  List.iter
    (fun id ->
      Alcotest.(check (result Test_util.presentation_testable Alcotest.reject))
        (id ^ ": the radio is visually hidden")
        (Ok Nopal_style.Presentation.Visually_hidden)
        (Result.map_error ignore (radio_presentation (By_attr ("id", id)) r));
      let label =
        Test_util.find_or_fail
          (id ^ ": no element carries the option's label id")
          (By_attr ("id", id ^ "-label"))
          group
      in
      Alcotest.(check string)
        (id ^ ": the option label is a native label")
        "label"
        (Test_util.tag_of "label" label);
      Alcotest.(check (option string))
        (id ^ ": the label points at its radio")
        (Some id) (attr "for" label))
    option_ids

let ring_of what row =
  match interaction row with
  | None -> Alcotest.fail (what ^ ": carries no interaction")
  | Some { focused_within = None; _ } ->
      Alcotest.fail (what ^ ": sets no focus-within style")
  | Some { focused_within = Some s; _ } -> s.Style.paint.shadow

let section_rows_carry_focused_within_ring () =
  let rows = find_all (By_tag "row") (group_of (rendered [])) in
  Alcotest.(check int) "one row per option" 3 (List.length rows);
  List.iteri
    (fun i row ->
      Alcotest.(check (option shadow_testable))
        (Printf.sprintf "row %d: the focus-within shadow is the ring" i)
        (Some declared_ring) (ring_of "row" row))
    rows

(* The options box is the one child of the group that holds the radios: found
   by what it holds rather than by its position, so the label box can never be
   mistaken for it. *)
let section_options_box_is_a_row () =
  let group = group_of (rendered []) in
  let holds_radios child = find_all (By_tag "radio") child <> [] in
  match List.filter holds_radios (children_of group) with
  | [ options_box ] ->
      let layout =
        match style options_box with
        | Some s -> s.Style.layout
        | None -> Alcotest.fail "the options box carries no style"
      in
      Alcotest.(check bool)
        "the options box lays its children out as a row" true
        (match layout.direction with
        | Some Style.Row_dir -> true
        | Some Style.Column_dir
        | None ->
            false)
  | children ->
      Alcotest.failf
        "expected one child of the group holding the radios, got %d"
        (List.length children)

let checked_of id r =
  match find (By_attr ("id", id)) (tree r) with
  | Some node -> attr "checked" node
  | None -> Alcotest.fail (id ^ ": the section renders no such radio")

let section_select_dispatches () =
  let r = rendered [] in
  (match click (By_attr ("id", "hidden-radio-shipping-overnight")) r with
  | Ok () -> ()
  | Error (Not_found _) -> Alcotest.fail "no radio for overnight"
  | Error (No_handler _) ->
      Alcotest.fail "selecting overnight dispatches nothing");
  let dispatched = messages r in
  (match dispatched with
  | [ Sub.Selected value ] ->
      Alcotest.(check string)
        "the message names the chosen value" "overnight" value
  | msgs ->
      Alcotest.failf "expected one Selected message, got %d" (List.length msgs));
  let after = rendered dispatched in
  Alcotest.(check (option string))
    "overnight is checked after update" (Some "true")
    (checked_of "hidden-radio-shipping-overnight" after);
  Alcotest.(check (option string))
    "express is no longer checked" (Some "false")
    (checked_of "hidden-radio-shipping-express" after)

let () =
  Alcotest.run "Hidden radio section"
    [
      ( "hidden radio",
        [
          Alcotest.test_case "section_built_with_hidden_inputs" `Quick
            section_built_with_hidden_inputs;
          Alcotest.test_case "section_rows_carry_focused_within_ring" `Quick
            section_rows_carry_focused_within_ring;
          Alcotest.test_case "section_options_box_is_a_row" `Quick
            section_options_box_is_a_row;
          Alcotest.test_case "section_select_dispatches" `Quick
            section_select_dispatches;
        ] );
    ]
