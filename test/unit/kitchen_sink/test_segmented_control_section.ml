(* The segmented-control kitchen-sink section, read structurally.

   The structural renderer paints nothing and moves no focus, so whether the
   fill, the dividers and the ring look right is the browser spec's to show.
   What this file pins is what that spec leans on: three controls of five, four
   and two segments with the documented ids and texts, each built with the
   requested design's values, and a refusing control whose update keeps the
   model while the threshold's moves it. The expected ids, texts and design
   values are written out here from the requested design, never read back from
   the section. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_segmented_control
module Style = Nopal_style.Style

let outline_color = Style.hex "#948775"
let divider_color = Style.hex "#CFC6B8"
let selected_fill = Style.hex "#02403A"
let selected_text = Style.hex "#FFFDF9"

let declared_ring : Style.shadow =
  {
    x = 0.0;
    y = 0.0;
    blur = 0.0;
    spread = 2.0;
    color = Style.rgba 11 97 88 0.35;
  }

let shadow_testable =
  let pp fmt (s : Style.shadow) =
    let color = Test_util.color_to_string s.color in
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

let color_testable =
  let pp fmt c = Format.pp_print_string fmt (Test_util.color_to_string c) in
  Alcotest.testable pp Style.equal_color

let rendered msgs =
  snd
    (run_app ~init:Sub.init ~update:Sub.update
       ~view:(fun _viewport model -> Sub.view model)
       msgs)

let control_ids =
  [ "segmented-threshold"; "segmented-window"; "segmented-refusing" ]

let group_of id r =
  match find (By_attr ("id", id)) (tree r) with
  | Some node -> node
  | None -> Alcotest.fail (id ^ ": the section renders no such control")

let children_of = Test_util.children_of

let label_and_segments_box id group =
  match children_of id group with
  | [ label; segments ] -> (label, segments)
  | []
  | [ _ ]
  | _ :: _ :: _ :: _ ->
      Alcotest.failf "%s: expected a group label and a segments box" id

let is_segment node =
  match node with
  | Element { children; _ } ->
      List.exists (fun c -> Test_util.tag_or_kind c = "radio") children
  | Empty
  | Text _ ->
      false

let is_divider node =
  match node with
  | Element { tag = "box"; children = []; _ } -> true
  | Element _
  | Empty
  | Text _ ->
      false

let segments_of id group =
  let _, box = label_and_segments_box id group in
  List.filter is_segment (children_of id box)

let dividers_of id group =
  let _, box = label_and_segments_box id group in
  List.filter is_divider (children_of id box)

let radio_of what segment =
  Test_util.find_or_fail (what ^ ": no radio") (By_tag "radio") segment

let label_of what segment =
  Test_util.find_or_fail (what ^ ": no label") (By_tag "label") segment

let is_checked segment =
  Option.equal String.equal
    (attr "checked" (radio_of "segment" segment))
    (Some "true")

let style_of what node =
  match style node with
  | Some s -> s
  | None -> Alcotest.fail (what ^ ": carries no style")

let section_has_three_controls () =
  let r = rendered [] in
  Alcotest.(check int)
    "the section holds three radiogroups" 3
    (List.length (find_all (By_attr ("role", "radiogroup")) (tree r)));
  List.iter
    (fun (id, group_label, radio_ids, texts) ->
      let group = group_of id r in
      Alcotest.(check (option string))
        (id ^ ": is a radiogroup") (Some "radiogroup") (attr "role" group);
      Alcotest.(check (option string))
        (id ^ ": named by its label box")
        (Some (id ^ "-label"))
        (attr "aria-labelledby" group);
      let label, _ = label_and_segments_box id group in
      Alcotest.(check (option string))
        (id ^ ": the label box comes first")
        (Some (id ^ "-label"))
        (attr "id" label);
      Alcotest.(check string)
        (id ^ ": the label box shows the label")
        group_label (text_content label);
      Alcotest.(check bool)
        (id ^ ": the group stacks its label above its segments")
        true
        (match (style_of id group).Style.layout.direction with
        | Some Style.Column_dir -> true
        | Some Style.Row_dir
        | None ->
            false);
      let segments = segments_of id group in
      Alcotest.(check (list string))
        (id ^ ": radio ids in order")
        radio_ids
        (List.map
           (fun s -> Option.value ~default:"" (attr "id" (radio_of id s)))
           segments);
      Alcotest.(check (list string))
        (id ^ ": segment texts in order")
        texts
        (List.map (fun s -> text_content (label_of id s)) segments))
    [
      ( "segmented-threshold",
        "Alert threshold",
        [
          "segmented-threshold-none";
          "segmented-threshold-15m";
          "segmented-threshold-1h";
          "segmented-threshold-1d";
          "segmented-threshold-custom";
        ],
        [ "None"; "15 min"; "1 hour"; "1 day"; "Custom" ] );
      ( "segmented-window",
        "Time window",
        [
          "segmented-window-7d";
          "segmented-window-30d";
          "segmented-window-90d";
          "segmented-window-all";
        ],
        [ "7d"; "30d"; "90d"; "All" ] );
      ( "segmented-refusing",
        "Refusing control",
        [ "segmented-refusing-kept"; "segmented-refusing-refused" ],
        [ "Kept"; "Refused" ] );
    ]

let section_uses_design_values () =
  let r = rendered [] in
  List.iter
    (fun id ->
      let group = group_of id r in
      let _, box = label_and_segments_box id group in
      (match (style_of (id ^ " segments box") box).Style.paint.border with
      | Some b ->
          Alcotest.(check (float 0.0)) (id ^ ": outline width") 1.0 b.width;
          Alcotest.check color_testable (id ^ ": outline colour") outline_color
            b.color;
          Alcotest.(check (float 0.0)) (id ^ ": outline radius") 6.0 b.radius
      | None -> Alcotest.fail (id ^ ": the segments box has no outline"));
      let dividers = dividers_of id group in
      let segments = segments_of id group in
      Alcotest.(check int)
        (id ^ ": a divider between each pair of segments")
        (List.length segments - 1)
        (List.length dividers);
      List.iter
        (fun d ->
          Alcotest.(check (option color_testable))
            (id ^ ": divider colour") (Some divider_color)
            (style_of "divider" d).Style.paint.background)
        dividers;
      let selected, plain = List.partition is_checked segments in
      Alcotest.(check int)
        (id ^ ": one selected segment")
        1 (List.length selected);
      List.iter
        (fun s ->
          Alcotest.(check (option color_testable))
            (id ^ ": the selected segment is filled")
            (Some selected_fill) (style_of "segment" s).Style.paint.background;
          let text = (style_of "label" (label_of id s)).Style.text in
          Alcotest.(check (option color_testable))
            (id ^ ": the selected label's colour")
            (Some selected_text) text.Nopal_style.Text.color;
          Alcotest.(check bool)
            (id ^ ": the selected label's weight is 500")
            true
            (Option.equal Nopal_style.Font.equal_weight
               text.Nopal_style.Text.font_weight (Some Nopal_style.Font.Medium)))
        selected;
      List.iter
        (fun s ->
          Alcotest.(check bool)
            (id ^ ": an unselected segment is not filled")
            false
            (Option.equal Style.equal_color
               (style_of "segment" s).Style.paint.background
               (Some selected_fill)))
        plain;
      List.iter
        (fun s ->
          let layout = (style_of "segment" s).Style.layout in
          Alcotest.(check bool)
            (id ^ ": every segment is 38 high")
            true
            (match layout.height with
            | Some (Style.Fixed h) -> Float.equal h 38.0
            | Some (Style.Fill | Style.Hug | Style.Fraction _)
            | None ->
                false);
          let ring =
            match interaction s with
            | Some { focused_within = Some st; _ } -> st.Style.paint.shadow
            | Some { focused_within = None; _ }
            | None ->
                Alcotest.fail (id ^ ": a segment sets no focus-within style")
          in
          Alcotest.(check (option shadow_testable))
            (id ^ ": the focus-within shadow is the ring")
            (Some declared_ring) ring)
        segments)
    control_ids

let checked_radio id r =
  List.filter_map
    (fun s -> if is_checked s then attr "id" (radio_of id s) else None)
    (segments_of id (group_of id r))

let refusing_fixture_keeps_model () =
  let model, _ = Sub.init () in
  let refused, _ = Sub.update model (Sub.Refusing_selected "refused") in
  Alcotest.(check bool)
    "the refusing control's update keeps the model" true (refused = model);
  Alcotest.(check (list string))
    "the refusing control still checks the kept segment"
    [ "segmented-refusing-kept" ]
    (checked_radio "segmented-refusing"
       (rendered [ Sub.Refusing_selected "refused" ]));
  let moved, _ = Sub.update model (Sub.Threshold_selected "1d") in
  Alcotest.(check bool)
    "the threshold's update changes the model" false (moved = model);
  Alcotest.(check (list string))
    "the threshold checks the newly selected segment"
    [ "segmented-threshold-1d" ]
    (checked_radio "segmented-threshold"
       (rendered [ Sub.Threshold_selected "1d" ]))

let () =
  Alcotest.run "Segmented control section"
    [
      ( "segmented control",
        [
          Alcotest.test_case "section_has_three_controls" `Quick
            section_has_three_controls;
          Alcotest.test_case "section_uses_design_values" `Quick
            section_uses_design_values;
          Alcotest.test_case "refusing_fixture_keeps_model" `Quick
            refusing_fixture_keeps_model;
        ] );
    ]
