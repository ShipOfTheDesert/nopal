open Nopal_charts

let test_default_config () =
  let cfg = Axis.default_config in
  Alcotest.(check (option string)) "no label" None cfg.label;
  Alcotest.(check (option (float 0.001))) "no explicit min" None cfg.min;
  Alcotest.(check (option (float 0.001))) "no explicit max" None cfg.max;
  Alcotest.(check int) "tick_count = 5" 5 cfg.tick_count;
  Alcotest.(check string) "default format" "0." (cfg.format_tick 0.)

let test_compute_ticks_count () =
  let cfg = { Axis.default_config with tick_count = 4 } in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let n = List.length ticks in
  Alcotest.(check bool) "reasonable tick count" true (n >= 2 && n <= 10)

let test_compute_ticks_range () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let values = List.map (fun (t : Axis.tick) -> t.value) ticks in
  let min_v = List.fold_left Float.min Float.infinity values in
  let max_v = List.fold_left Float.max Float.neg_infinity values in
  Alcotest.(check bool) "min tick >= 0" true (min_v >= 0.0);
  Alcotest.(check bool) "max tick <= 100" true (max_v <= 100.0)

let test_compute_ticks_explicit_min_max () =
  let cfg = { Axis.default_config with min = Some 10.0; max = Some 50.0 } in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let values = List.map (fun (t : Axis.tick) -> t.value) ticks in
  let min_v = List.fold_left Float.min Float.infinity values in
  let max_v = List.fold_left Float.max Float.neg_infinity values in
  Alcotest.(check bool) "min tick >= 10" true (min_v >= 10.0);
  Alcotest.(check bool) "max tick <= 50" true (max_v <= 50.0)

let test_compute_ticks_format () =
  let fmt v = Printf.sprintf "%.1f%%" v in
  let cfg = { Axis.default_config with format_tick = fmt } in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  List.iter
    (fun (t : Axis.tick) ->
      Alcotest.(check bool)
        "label ends with %" true
        (String.length t.label > 0 && t.label.[String.length t.label - 1] = '%'))
    ticks

let test_compute_domain_auto () =
  let cfg = Axis.default_config in
  let lo, hi = Axis.compute_domain cfg ~data_min:3.0 ~data_max:97.0 in
  Alcotest.(check bool) "lo <= data_min" true (lo <= 3.0);
  Alcotest.(check bool) "hi >= data_max" true (hi >= 97.0)

let test_compute_domain_explicit () =
  let cfg = { Axis.default_config with min = Some 10.0; max = Some 90.0 } in
  let lo, hi = Axis.compute_domain cfg ~data_min:0.0 ~data_max:100.0 in
  Alcotest.(check (float 0.001)) "lo = 10" 10.0 lo;
  Alcotest.(check (float 0.001)) "hi = 90" 90.0 hi

let test_compute_domain_partial () =
  let cfg_min = { Axis.default_config with min = Some 5.0 } in
  let lo, hi = Axis.compute_domain cfg_min ~data_min:10.0 ~data_max:50.0 in
  Alcotest.(check (float 0.001)) "lo = 5" 5.0 lo;
  Alcotest.(check bool) "hi >= 50" true (hi >= 50.0);
  let cfg_max = { Axis.default_config with max = Some 80.0 } in
  let lo2, hi2 = Axis.compute_domain cfg_max ~data_min:10.0 ~data_max:50.0 in
  Alcotest.(check bool) "lo2 <= 10" true (lo2 <= 10.0);
  Alcotest.(check (float 0.001)) "hi2 = 80" 80.0 hi2

let test_render_x_produces_scenes () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 400.0)
  in
  let scenes =
    Axis.render_x cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:300.0
      ~chart_width:400.0
  in
  Alcotest.(check bool) "non-empty scenes" true (List.length scenes > 0)

let test_render_y_produces_scenes () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(300.0, 0.0)
  in
  let scenes =
    Axis.render_y cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:0.0
      ~chart_height:300.0
  in
  Alcotest.(check bool) "non-empty scenes" true (List.length scenes > 0)

let rec has_text_with_content content scene =
  match (scene : Nopal_draw.Scene.t) with
  | Text { content = c; _ } -> String.equal c content
  | Group { children; _ } ->
      List.exists (has_text_with_content content) children
  | Rect _
  | Circle _
  | Ellipse _
  | Line _
  | Path _
  | Polygon _
  | Polyline _
  | Clip _ ->
      false

let test_render_x_tick_labels () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 400.0)
  in
  let scenes =
    Axis.render_x cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:300.0
      ~chart_width:400.0
  in
  List.iter
    (fun (t : Axis.tick) ->
      Alcotest.(check bool)
        ("x axis has label " ^ t.label)
        true
        (List.exists (has_text_with_content t.label) scenes))
    ticks

let test_render_y_tick_labels () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(300.0, 0.0)
  in
  let scenes =
    Axis.render_y cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:0.0
      ~chart_height:300.0
  in
  List.iter
    (fun (t : Axis.tick) ->
      Alcotest.(check bool)
        ("y axis has label " ^ t.label)
        true
        (List.exists (has_text_with_content t.label) scenes))
    ticks

let test_large_axis_range () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.001 ~data_max:1000000.0 in
  let n = List.length ticks in
  (* Should produce a reasonable number of ticks without crashing *)
  Alcotest.(check bool) "reasonable tick count" true (n >= 2 && n <= 20);
  let values = List.map (fun (t : Axis.tick) -> t.value) ticks in
  let min_v = List.fold_left Float.min Float.infinity values in
  let max_v = List.fold_left Float.max Float.neg_infinity values in
  Alcotest.(check bool) "min tick covers lower bound" true (min_v <= 0.001);
  Alcotest.(check bool) "max tick covers upper bound" true (max_v >= 1000000.0)

let test_render_x_axis_label () =
  let cfg = { Axis.default_config with label = Some "Time (s)" } in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 400.0)
  in
  let scenes =
    Axis.render_x cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:300.0
      ~chart_width:400.0
  in
  Alcotest.(check bool)
    "x axis contains label text" true
    (List.exists (has_text_with_content "Time (s)") scenes)

let test_render_y_axis_label () =
  let cfg = { Axis.default_config with label = Some "Value" } in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(300.0, 0.0)
  in
  let scenes =
    Axis.render_y cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:0.0
      ~chart_height:300.0
  in
  Alcotest.(check bool)
    "y axis contains label text" true
    (List.exists (has_text_with_content "Value") scenes)

let test_render_x_no_label_when_none () =
  let cfg = Axis.default_config in
  let ticks = Axis.compute_ticks cfg ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 400.0)
  in
  let scenes =
    Axis.render_x cfg ~ticks ~scale ~chart_x:50.0 ~chart_y:300.0
      ~chart_width:400.0
  in
  (* Count text nodes — should only be tick labels, no axis label *)
  let text_count =
    List.fold_left
      (fun acc (node : Nopal_draw.Scene.t) ->
        match node with
        | Text _ -> acc + 1
        | Rect _
        | Circle _
        | Ellipse _
        | Line _
        | Path _
        | Polygon _
        | Polyline _
        | Group _
        | Clip _ ->
            acc)
      0 scenes
  in
  Alcotest.(check int)
    "text count equals tick count" (List.length ticks) text_count

(* Every field is stated explicitly rather than derived from
   [default_appearance], so this case cannot pass by agreeing with the value it
   is meant to police. *)
let themed_appearance =
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

let test_default_appearance_matches_today () =
  let a = Axis.default_appearance in
  let axis_grey = Nopal_draw.Color.rgb ~r:0.2 ~g:0.2 ~b:0.2 in
  Alcotest.check Chart_test_helpers.color_testable "line_color is the axis grey"
    axis_grey a.line_color;
  Alcotest.(check (float 0.0)) "line_width = 1.0" 1.0 a.line_width;
  Alcotest.check Chart_test_helpers.color_testable "tick_color is the axis grey"
    axis_grey a.tick_color;
  Alcotest.(check (float 0.0)) "tick_length = 6.0" 6.0 a.tick_length;
  Alcotest.check Chart_test_helpers.color_testable "tick_label_color is black"
    Nopal_draw.Color.black a.tick_label_color;
  Alcotest.(check (float 0.0)) "tick_label_size = 11.0" 11.0 a.tick_label_size;
  Alcotest.check Chart_test_helpers.color_testable "axis_label_color is black"
    Nopal_draw.Color.black a.axis_label_color;
  Alcotest.(check (float 0.0)) "axis_label_size = 12.0" 12.0 a.axis_label_size

let test_default_config_carries_default_appearance () =
  Alcotest.(check bool)
    "default_config.appearance is default_appearance" true
    (Axis.equal_appearance Axis.default_appearance
       Axis.default_config.appearance)

let test_equal_appearance_float_fields () =
  Alcotest.(check bool)
    "identical values are equal" true
    (Axis.equal_appearance themed_appearance themed_appearance);
  let differs label (b : Axis.appearance) =
    Alcotest.(check bool)
      label false
      (Axis.equal_appearance themed_appearance b)
  in
  differs "line_width differs" { themed_appearance with line_width = 3.5 };
  differs "tick_length differs" { themed_appearance with tick_length = 9.5 };
  differs "tick_label_size differs"
    { themed_appearance with tick_label_size = 17.5 };
  differs "axis_label_size differs"
    { themed_appearance with axis_label_size = 23.5 }

let test_equal_appearance_color_fields () =
  let other = Nopal_draw.Color.rgb ~r:0.05 ~g:0.05 ~b:0.05 in
  let differs label (b : Axis.appearance) =
    Alcotest.(check bool)
      label false
      (Axis.equal_appearance themed_appearance b)
  in
  differs "line_color differs" { themed_appearance with line_color = other };
  differs "tick_color differs" { themed_appearance with tick_color = other };
  differs "tick_label_color differs"
    { themed_appearance with tick_label_color = other };
  differs "axis_label_color differs"
    { themed_appearance with axis_label_color = other }

(* Both renderers emit the axis line first and one tick mark per tick after it;
   nothing else either of them emits is a [Line]. *)
let axis_line_and_ticks scenes =
  match Chart_test_helpers.lines_of scenes with
  | axis :: ticks -> (axis, ticks)
  | [] -> Alcotest.fail "expected an axis line node"

let stroke_color (s : Nopal_draw.Paint.stroke) =
  Chart_test_helpers.paint_color s.paint

(* Written out in full rather than as [{ Axis.default_config with appearance }]
   so that no field feeding the renderers is inherited unseen. *)
let themed_config : Axis.config =
  {
    label = Some "Themed";
    min = None;
    max = None;
    tick_count = 5;
    format_tick = string_of_float;
    appearance = themed_appearance;
  }

let themed_x_scenes () =
  let ticks = Axis.compute_ticks themed_config ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(0.0, 400.0)
  in
  Axis.render_x themed_config ~ticks ~scale ~chart_x:50.0 ~chart_y:300.0
    ~chart_width:400.0

let themed_y_scenes () =
  let ticks = Axis.compute_ticks themed_config ~data_min:0.0 ~data_max:100.0 in
  let scale =
    Nopal_draw.Scale.create ~domain:(0.0, 100.0) ~range:(300.0, 0.0)
  in
  Axis.render_y themed_config ~ticks ~scale ~chart_x:50.0 ~chart_y:0.0
    ~chart_height:300.0

(* [line_color] and [tick_color] split one pre-existing constant and their
   defaults are identical, so "some node has the new colour" would pass under a
   swap. Each colour is asserted to reach its own node and to be absent from the
   other's. *)
let test_line_color_reaches_axis_line_only () =
  let assert_split label scenes =
    let (_, _, _, _, axis_stroke), tick_lines = axis_line_and_ticks scenes in
    Alcotest.(check bool)
      (label ^ ": tick marks are present")
      true
      (match tick_lines with
      | [] -> false
      | _ :: _ -> true);
    Alcotest.check Chart_test_helpers.color_testable
      (label ^ ": axis line carries line_color")
      themed_appearance.line_color (stroke_color axis_stroke);
    Alcotest.(check bool)
      (label ^ ": no tick mark carries line_color")
      false
      (List.exists
         (fun (_, _, _, _, s) ->
           Nopal_draw.Color.equal (stroke_color s) themed_appearance.line_color)
         tick_lines)
  in
  assert_split "x" (themed_x_scenes ());
  assert_split "y" (themed_y_scenes ())

let test_tick_color_reaches_tick_marks_only () =
  let assert_split label scenes =
    let (_, _, _, _, axis_stroke), tick_lines = axis_line_and_ticks scenes in
    Alcotest.(check bool)
      (label ^ ": tick marks are present")
      true
      (match tick_lines with
      | [] -> false
      | _ :: _ -> true);
    List.iter
      (fun (_, _, _, _, s) ->
        Alcotest.check Chart_test_helpers.color_testable
          (label ^ ": tick mark carries tick_color")
          themed_appearance.tick_color (stroke_color s))
      tick_lines;
    Alcotest.(check bool)
      (label ^ ": axis line does not carry tick_color")
      false
      (Nopal_draw.Color.equal (stroke_color axis_stroke)
         themed_appearance.tick_color)
  in
  assert_split "x" (themed_x_scenes ());
  assert_split "y" (themed_y_scenes ())

(* There is no separate tick width: [line_width] is the width of both strokes.
   3.0 is [themed_appearance.line_width], stated as a literal so the expectation
   is not recomputed from the value under test. *)
let test_line_width_reaches_both_strokes () =
  let assert_widths label scenes =
    let (_, _, _, _, axis_stroke), tick_lines = axis_line_and_ticks scenes in
    Alcotest.(check bool)
      (label ^ ": tick marks are present")
      true
      (match tick_lines with
      | [] -> false
      | _ :: _ -> true);
    Alcotest.(check (float 0.0))
      (label ^ ": axis line width is line_width")
      3.0 axis_stroke.width;
    List.iter
      (fun (_, _, _, _, (s : Nopal_draw.Paint.stroke)) ->
        Alcotest.(check (float 0.0))
          (label ^ ": tick mark width is line_width")
          3.0 s.width)
      tick_lines
  in
  assert_widths "x" (themed_x_scenes ());
  assert_widths "y" (themed_y_scenes ())

(* [themed_appearance.tick_length] is 9.0, the X axis sits at [chart_y = 300.0]
   and the Y axis at [chart_x = 50.0]. The far coordinates are therefore 309.0
   and 41.0, written as literals rather than as [chart_y +. tick_length], which
   would restate the implementation's own expression and pass for any length. *)
let test_tick_length_changes_tick_geometry () =
  let _axis_line, x_ticks = axis_line_and_ticks (themed_x_scenes ()) in
  Alcotest.(check bool)
    "x: tick marks are present" true
    (match x_ticks with
    | [] -> false
    | _ :: _ -> true);
  List.iter
    (fun (_, y1, _, y2, _) ->
      Alcotest.(check (float 0.0)) "x tick starts on the axis" 300.0 y1;
      Alcotest.(check (float 0.0)) "x tick ends 9.0 below the axis" 309.0 y2)
    x_ticks;
  let _axis_line, y_ticks = axis_line_and_ticks (themed_y_scenes ()) in
  Alcotest.(check bool)
    "y: tick marks are present" true
    (match y_ticks with
    | [] -> false
    | _ :: _ -> true);
  List.iter
    (fun (x1, _, x2, _, _) ->
      Alcotest.(check (float 0.0)) "y tick starts 9.0 left of the axis" 41.0 x1;
      Alcotest.(check (float 0.0)) "y tick ends on the axis" 50.0 x2)
    y_ticks

(* The axis label and the tick labels are told apart by content, not by
   position: [themed_config] labels the axis "Themed" and its [format_tick] is
   [string_of_float], so no tick label can collide with it. Returns
   (tick labels, axis labels). *)
let tick_and_axis_labels scenes =
  List.partition
    (fun (content, _, _) -> not (String.equal content "Themed"))
    (Chart_test_helpers.texts_of scenes)

(* [tick_label_size] (17.0) and [axis_label_size] (23.0) sit a few lines apart
   in each renderer and are trivially crossed, as are the two colours. Every
   assertion is therefore paired with the arm saying the other label kind does
   not carry this value. The sizes are literals rather than
   [themed_appearance.tick_label_size], which would restate the value under test
   and pass for any routing. *)
let test_tick_label_color_and_size () =
  let assert_tick_labels label scenes =
    let tick_labels, axis_labels = tick_and_axis_labels scenes in
    Alcotest.(check bool)
      (label ^ ": tick labels are present")
      true
      (match tick_labels with
      | [] -> false
      | _ :: _ -> true);
    Alcotest.(check int)
      (label ^ ": exactly one axis label")
      1 (List.length axis_labels);
    List.iter
      (fun (content, font_size, fill) ->
        Alcotest.check Chart_test_helpers.color_testable
          (label ^ ": tick label " ^ content ^ " carries tick_label_color")
          themed_appearance.tick_label_color
          (Chart_test_helpers.paint_color fill);
        Alcotest.(check (float 0.0))
          (label ^ ": tick label " ^ content ^ " carries tick_label_size")
          17.0 font_size)
      tick_labels;
    List.iter
      (fun (_, font_size, fill) ->
        Alcotest.(check bool)
          (label ^ ": the axis label does not carry tick_label_color")
          false
          (Nopal_draw.Color.equal
             (Chart_test_helpers.paint_color fill)
             themed_appearance.tick_label_color);
        Alcotest.(check bool)
          (label ^ ": the axis label does not carry tick_label_size")
          false
          (Float.equal font_size 17.0))
      axis_labels
  in
  assert_tick_labels "x" (themed_x_scenes ());
  assert_tick_labels "y" (themed_y_scenes ())

let test_axis_label_color_and_size () =
  let assert_axis_label label scenes =
    let tick_labels, axis_labels = tick_and_axis_labels scenes in
    Alcotest.(check bool)
      (label ^ ": tick labels are present")
      true
      (match tick_labels with
      | [] -> false
      | _ :: _ -> true);
    (match axis_labels with
    | [ (content, font_size, fill) ] ->
        Alcotest.(check string)
          (label ^ ": the axis label is the configured text")
          "Themed" content;
        Alcotest.check Chart_test_helpers.color_testable
          (label ^ ": axis label carries axis_label_color")
          themed_appearance.axis_label_color
          (Chart_test_helpers.paint_color fill);
        Alcotest.(check (float 0.0))
          (label ^ ": axis label carries axis_label_size")
          23.0 font_size
    | []
    | _ :: _ :: _ ->
        Alcotest.fail "expected exactly one axis label node");
    List.iter
      (fun (content, font_size, fill) ->
        Alcotest.(check bool)
          (label ^ ": tick label " ^ content
         ^ " does not carry axis_label_color")
          false
          (Nopal_draw.Color.equal
             (Chart_test_helpers.paint_color fill)
             themed_appearance.axis_label_color);
        Alcotest.(check bool)
          (label ^ ": tick label " ^ content ^ " does not carry axis_label_size")
          false
          (Float.equal font_size 23.0))
      tick_labels
  in
  assert_axis_label "x" (themed_x_scenes ());
  assert_axis_label "y" (themed_y_scenes ())

let () =
  Alcotest.run "Axis"
    [
      ( "config",
        [
          Alcotest.test_case "default_config" `Quick test_default_config;
          Alcotest.test_case "default_config_carries_default_appearance" `Quick
            test_default_config_carries_default_appearance;
        ] );
      ( "appearance",
        [
          Alcotest.test_case "default_appearance_matches_today" `Quick
            test_default_appearance_matches_today;
          Alcotest.test_case "equal_appearance_float_fields" `Quick
            test_equal_appearance_float_fields;
          Alcotest.test_case "equal_appearance_color_fields" `Quick
            test_equal_appearance_color_fields;
        ] );
      ( "compute_ticks",
        [
          Alcotest.test_case "count" `Quick test_compute_ticks_count;
          Alcotest.test_case "range" `Quick test_compute_ticks_range;
          Alcotest.test_case "explicit_min_max" `Quick
            test_compute_ticks_explicit_min_max;
          Alcotest.test_case "format" `Quick test_compute_ticks_format;
          Alcotest.test_case "large_axis_range" `Quick test_large_axis_range;
        ] );
      ( "compute_domain",
        [
          Alcotest.test_case "auto" `Quick test_compute_domain_auto;
          Alcotest.test_case "explicit" `Quick test_compute_domain_explicit;
          Alcotest.test_case "partial" `Quick test_compute_domain_partial;
        ] );
      ( "render",
        [
          Alcotest.test_case "x_produces_scenes" `Quick
            test_render_x_produces_scenes;
          Alcotest.test_case "y_produces_scenes" `Quick
            test_render_y_produces_scenes;
          Alcotest.test_case "x_tick_labels" `Quick test_render_x_tick_labels;
          Alcotest.test_case "y_tick_labels" `Quick test_render_y_tick_labels;
          Alcotest.test_case "x_axis_label" `Quick test_render_x_axis_label;
          Alcotest.test_case "y_axis_label" `Quick test_render_y_axis_label;
          Alcotest.test_case "x_no_label_when_none" `Quick
            test_render_x_no_label_when_none;
          Alcotest.test_case "line_color_reaches_axis_line_only" `Quick
            test_line_color_reaches_axis_line_only;
          Alcotest.test_case "tick_color_reaches_tick_marks_only" `Quick
            test_tick_color_reaches_tick_marks_only;
          Alcotest.test_case "line_width_reaches_both_strokes" `Quick
            test_line_width_reaches_both_strokes;
          Alcotest.test_case "tick_length_changes_tick_geometry" `Quick
            test_tick_length_changes_tick_geometry;
          Alcotest.test_case "tick_label_color_and_size" `Quick
            test_tick_label_color_and_size;
          Alcotest.test_case "axis_label_color_and_size" `Quick
            test_axis_label_color_and_size;
        ] );
    ]
