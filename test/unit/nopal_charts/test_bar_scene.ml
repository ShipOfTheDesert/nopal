open Nopal_charts
open Nopal_scene

type datum = { label : string; value : float; color : Nopal_draw.Color.t }

let sample_data =
  [
    { label = "A"; value = 10.0; color = Nopal_draw.Color.categorical.(0) };
    { label = "B"; value = 20.0; color = Nopal_draw.Color.categorical.(1) };
    { label = "C"; value = 15.0; color = Nopal_draw.Color.categorical.(2) };
  ]

let test_bar_scene_returns_nodes () =
  let nodes =
    Bar.scene ~data:sample_data
      ~label:(fun d -> d.label)
      ~value:(fun d -> d.value)
      ~color:(fun d -> d.color)
      ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_bar_scene_empty_data () =
  let nodes =
    Bar.scene ~data:[]
      ~label:(fun d -> d.label)
      ~value:(fun d -> d.value)
      ~color:(fun d -> d.color)
      ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check int) "empty scene" 0 (List.length nodes)

let test_bar_scene_matches_view () =
  let scene_nodes =
    Bar.scene ~data:sample_data
      ~label:(fun d -> d.label)
      ~value:(fun d -> d.value)
      ~color:(fun d -> d.color)
      ~width:400.0 ~height:300.0 ()
  in
  let view_el =
    Bar.view ~data:sample_data
      ~label:(fun d -> d.label)
      ~value:(fun d -> d.value)
      ~color:(fun d -> d.color)
      ~width:400.0 ~height:300.0 ()
  in
  match Chart_test_helpers.extract_draw view_el with
  | Some (view_scene, _, _, _, _) ->
      Alcotest.(check int)
        "same length" (List.length scene_nodes) (List.length view_scene);
      List.iter2
        (fun a b -> Alcotest.(check bool) "nodes equal" true (Scene.equal a b))
        scene_nodes view_scene
  | None -> Alcotest.fail "expected Draw element from view"

(* --- Bar's self-drawn X axis ------------------------------------------- *)

(* Two complete themes, written field by field rather than as
   [{ Axis.default_appearance with ... }], because every value here is
   behavioural and a fixture that inherited even one default could agree by
   accident with the hardcoded chrome it exists to police. The X theme is the
   one [test_axis.ml] and [test_axis_svg.ml] use, so a single theme runs
   through the whole feature. The Y theme exists only to be different: [Bar]
   reads [y_axis] for its domain, its scale and [Axis.render_y], so a routing
   that reached for [y_axis.appearance] when drawing the X chrome would be
   invisible against a default Y config and is caught here. Every value in
   either theme differs from its own default and from the other theme's, so
   any crossed route renders a value no assertion below accepts. *)
let x_theme =
  {
    Axis.line_color = Nopal_draw.Color.rgb ~r:0.9 ~g:0.1 ~b:0.1;
    line_width = 3.0;
    tick_color = Nopal_draw.Color.rgb ~r:0.1 ~g:0.7 ~b:0.2;
    tick_length = 9.0;
    tick_label_color = Nopal_draw.Color.rgb ~r:0.2 ~g:0.3 ~b:0.8;
    tick_label_size = 17.0;
    axis_label_color = Nopal_draw.Color.rgb ~r:0.6 ~g:0.0 ~b:0.6;
    axis_label_size = 23.0;
  }

let y_theme =
  {
    Axis.line_color = Nopal_draw.Color.rgb ~r:0.0 ~g:0.4 ~b:0.9;
    line_width = 5.0;
    tick_color = Nopal_draw.Color.rgb ~r:0.8 ~g:0.5 ~b:0.0;
    tick_length = 4.0;
    tick_label_color = Nopal_draw.Color.rgb ~r:0.0 ~g:0.5 ~b:0.5;
    tick_label_size = 19.0;
    axis_label_color = Nopal_draw.Color.rgb ~r:0.3 ~g:0.3 ~b:0.0;
    axis_label_size = 27.0;
  }

let themed_x_config : Axis.config =
  {
    label = Some "Quarter";
    min = None;
    max = None;
    tick_count = 5;
    format_tick = string_of_float;
    appearance = x_theme;
  }

let themed_y_config : Axis.config =
  {
    label = Some "Revenue";
    min = None;
    max = None;
    tick_count = 5;
    format_tick = string_of_float;
    appearance = y_theme;
  }

(* Spelled out rather than taken from [Padding.default]: the coordinates the
   locator below matches on are derived from these four numbers. *)
let chart_padding : Padding.t =
  { top = 40.0; right = 20.0; bottom = 40.0; left = 50.0 }

let chart_w = 400.0
let chart_h = 300.0

(* Chart box: x runs 50.0 .. 400.0 -. 20.0 = 380.0, y runs 40.0 .. 300.0 -.
   40.0 = 260.0. The X axis sits on the bottom edge. *)
let axis_left = 50.0
let axis_right = 380.0
let axis_bottom = 260.0

let themed_scene () =
  Bar.scene ~data:sample_data
    ~label:(fun d -> d.label)
    ~value:(fun d -> d.value)
    ~color:(fun d -> d.color)
    ~width:chart_w ~height:chart_h ~padding:chart_padding
    ~x_axis:themed_x_config ~y_axis:themed_y_config ()

(* [Bar] draws this line itself instead of calling [Axis.render_x], so taking
   "the first [Line] node" would silently pick up an [Axis.render_y] node if the
   emission order ever moved. It is identified by its segment instead: the
   bottom edge of the chart box, which is the only line spanning the full chart
   width. The Y axis line is vertical and the Y tick marks stop at x = 50.0. *)
let x_axis_line scenes =
  let spans_the_chart (x1, y1, x2, y2, _) =
    Float.equal x1 axis_left
    && Float.equal y1 axis_bottom
    && Float.equal x2 axis_right
    && Float.equal y2 axis_bottom
  in
  match List.filter spans_the_chart (Chart_test_helpers.lines_of scenes) with
  | [ line ] -> line
  | [] -> Alcotest.fail "expected an X axis line across the bottom of the chart"
  | _ :: _ :: _ -> Alcotest.fail "expected exactly one X axis line"

let text_with_content content scenes =
  match
    List.filter
      (fun (c, _, _) -> String.equal c content)
      (Chart_test_helpers.texts_of scenes)
  with
  | [ text ] -> text
  | [] -> Alcotest.fail ("expected a text node reading " ^ content)
  | _ :: _ :: _ -> Alcotest.fail ("expected one text node reading " ^ content)

(* Expectations are literals, not [x_theme.line_width] and friends: an oracle
   restated from the value under test passes for any routing at all. *)
let test_bar_x_axis_honours_appearance () =
  let scenes = themed_scene () in
  let _, _, _, _, (stroke : Nopal_draw.Paint.stroke) = x_axis_line scenes in
  Alcotest.check Chart_test_helpers.color_testable
    "X axis line carries the X theme's line_color"
    (Nopal_draw.Color.rgb ~r:0.9 ~g:0.1 ~b:0.1)
    (Chart_test_helpers.paint_color stroke.paint);
  Alcotest.(check (float 0.0))
    "X axis line carries the X theme's line_width" 3.0 stroke.width;
  let _, label_size, label_fill = text_with_content "Quarter" scenes in
  Alcotest.(check (float 0.0))
    "X axis label carries the X theme's axis_label_size" 23.0 label_size;
  Alcotest.check Chart_test_helpers.color_testable
    "X axis label carries the X theme's axis_label_color"
    (Nopal_draw.Color.rgb ~r:0.6 ~g:0.0 ~b:0.6)
    (Chart_test_helpers.paint_color label_fill);
  (* The per-bar category labels are series chrome, not axis chrome. Both
     themes carry a tick_label_size (17.0 and 19.0) and a tick_label_color, so
     a routing that reached into them from here would move these three nodes
     off 11.0 and black. *)
  List.iter
    (fun d ->
      let _, size, fill = text_with_content d.label scenes in
      Alcotest.(check (float 0.0))
        ("category label " ^ d.label ^ " keeps its own size")
        11.0 size;
      Alcotest.check Chart_test_helpers.color_testable
        ("category label " ^ d.label ^ " keeps its own colour")
        Nopal_draw.Color.black
        (Chart_test_helpers.paint_color fill))
    sample_data

let rect_solid_fill (node : Nopal_draw.Scene.t) =
  match node with
  | Rect { fill = Solid c; _ } -> Some c
  | Rect { fill = Linear_gradient _; _ }
  | Rect { fill = Radial_gradient _; _ }
  | Rect { fill = No_paint; _ }
  | Circle _
  | Ellipse _
  | Line _
  | Path _
  | Polygon _
  | Polyline _
  | Text _
  | Group _
  | Clip _ ->
      None

(* [Bar.view] applies its hover lightening by index - [bar.ml] matches
   [Rect r when i = h.Hover.index] over the scene list - so datum [i] must be
   the [Rect] at index [i], and nothing but a data bar may sit in [0 .. N-1].
   That is a property of node *position*, which a "there are three rects"
   count cannot see, so the whole list is walked index by index against a
   fully-enumerated ordered expectation. The three data colours are distinct,
   so a reorder inside the data range reddens too. The tail arm asserts an
   absence and would go vacuous on its own; the head arm on the same fixture is
   its affirmative half. *)
let test_bar_scene_node_order_unchanged () =
  let scenes = themed_scene () in
  let expected_fills = List.map (fun d -> d.color) sample_data in
  Alcotest.(check bool)
    "the scene carries chrome after the data bars" true
    (List.length scenes > List.length expected_fills);
  List.iteri
    (fun i node ->
      let at = Printf.sprintf "node %d" i in
      match List.nth_opt expected_fills i with
      | Some expected -> (
          Alcotest.(check bool)
            (at ^ " is a data bar") true
            (Chart_test_helpers.is_rect node);
          match rect_solid_fill node with
          | Some c ->
              Alcotest.check Chart_test_helpers.color_testable
                (at ^ " carries datum " ^ string_of_int i ^ "'s colour")
                expected c
          | None -> Alcotest.fail (at ^ " has no solid fill"))
      | None ->
          Alcotest.(check bool)
            (at ^ " is not a data bar")
            false
            (Chart_test_helpers.is_rect node))
    scenes

(* The default-appearance guarantee for the two nodes this feature reshaped.
   [Axis.default_config] is the subject here, not an incidental base: the
   guarantee is that a caller who never mentions appearance gets what [Bar]
   drew before appearance existed. The four expected values are the literals
   that stood at [bar.ml:85-87] and [bar.ml:96] - the axis grey, width 1.0,
   size 12.0, and the solid black that the label inherited from [Scene.text]
   because the call passed no [~fill] at all. The label now passes [~fill]
   explicitly, so this is the case that says the explicit argument reproduces
   the inherited one. *)
let test_bar_default_x_axis_is_unchanged () =
  let default_x_config = { Axis.default_config with label = Some "Quarter" } in
  (* A different label, so the locator below cannot pick the Y axis label up by
     accident - it rejects an ambiguous match rather than taking the first. *)
  let default_y_config = { Axis.default_config with label = Some "Revenue" } in
  let scenes =
    Bar.scene ~data:sample_data
      ~label:(fun d -> d.label)
      ~value:(fun d -> d.value)
      ~color:(fun d -> d.color)
      ~width:chart_w ~height:chart_h ~padding:chart_padding
      ~x_axis:default_x_config ~y_axis:default_y_config ()
  in
  let _, _, _, _, (stroke : Nopal_draw.Paint.stroke) = x_axis_line scenes in
  Alcotest.check Chart_test_helpers.color_testable
    "X axis line keeps the axis grey"
    (Nopal_draw.Color.rgb ~r:0.2 ~g:0.2 ~b:0.2)
    (Chart_test_helpers.paint_color stroke.paint);
  Alcotest.(check (float 0.0)) "X axis line keeps width 1.0" 1.0 stroke.width;
  let _, label_size, label_fill = text_with_content "Quarter" scenes in
  Alcotest.(check (float 0.0)) "X axis label keeps size 12.0" 12.0 label_size;
  Alcotest.check Chart_test_helpers.color_testable
    "X axis label keeps solid black" Nopal_draw.Color.black
    (Chart_test_helpers.paint_color label_fill)

let () =
  Alcotest.run "Bar.scene"
    [
      ( "scene",
        [
          Alcotest.test_case "returns_nodes" `Quick test_bar_scene_returns_nodes;
          Alcotest.test_case "empty_data" `Quick test_bar_scene_empty_data;
          Alcotest.test_case "matches_view" `Quick test_bar_scene_matches_view;
          Alcotest.test_case "x_axis_honours_appearance" `Quick
            test_bar_x_axis_honours_appearance;
          Alcotest.test_case "node_order_unchanged" `Quick
            test_bar_scene_node_order_unchanged;
          Alcotest.test_case "default_x_axis_is_unchanged" `Quick
            test_bar_default_x_axis_is_unchanged;
        ] );
    ]
