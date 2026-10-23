open Nopal_scene

let check_string = Alcotest.(check string)

let test_color_to_css_opaque () =
  let c = Color.rgb ~r:1.0 ~g:0.502 ~b:0.0 in
  check_string "opaque" "rgba(255,128,0,1)" (Nopal_svg.Svg_fmt.color_to_css c)

let test_color_to_css_transparent () =
  let c = Color.rgba ~r:0.0 ~g:0.0 ~b:0.0 ~a:0.5 in
  let result = Nopal_svg.Svg_fmt.color_to_css c in
  Alcotest.(check bool) "contains 0.5" true (String.length result > 0);
  check_string "transparent" "rgba(0,0,0,0.5)" result

let test_paint_solid_fill () =
  let ctx = Nopal_svg.Svg_fmt.create_ctx () in
  let c = Color.rgb ~r:1.0 ~g:0.0 ~b:0.0 in
  let result = Nopal_svg.Svg_fmt.paint_to_fill_attr ctx (Paint.solid c) in
  check_string "solid fill" "rgba(255,0,0,1)" result

let test_paint_no_paint_fill () =
  let ctx = Nopal_svg.Svg_fmt.create_ctx () in
  let result = Nopal_svg.Svg_fmt.paint_to_fill_attr ctx Paint.no_paint in
  check_string "no paint" "none" result

let test_paint_linear_gradient_produces_def () =
  let ctx = Nopal_svg.Svg_fmt.create_ctx () in
  let stops =
    [
      { Paint.offset = 0.0; color = Color.red };
      { Paint.offset = 1.0; color = Color.blue };
    ]
  in
  match Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:1.0 ~y1:0.0 ~stops with
  | Error e -> Alcotest.fail e
  | Ok grad ->
      let result = Nopal_svg.Svg_fmt.paint_to_fill_attr ctx grad in
      Alcotest.(check bool)
        "returns url ref" true
        (let prefix = "url(#grad-" in
         String.length result > String.length prefix
         && String.sub result 0 (String.length prefix) = prefix);
      let defs = Nopal_svg.Svg_fmt.defs_to_string ctx in
      Alcotest.(check bool)
        "has linearGradient def" true
        (Test_util.string_contains defs ~sub:"<linearGradient")

let test_paint_radial_gradient_produces_def () =
  let ctx = Nopal_svg.Svg_fmt.create_ctx () in
  let stops =
    [
      { Paint.offset = 0.0; color = Color.red };
      { Paint.offset = 1.0; color = Color.blue };
    ]
  in
  match Paint.radial_gradient ~cx:0.5 ~cy:0.5 ~r:0.5 ~stops with
  | Error e -> Alcotest.fail e
  | Ok grad ->
      let result = Nopal_svg.Svg_fmt.paint_to_fill_attr ctx grad in
      Alcotest.(check bool)
        "returns url ref" true
        (let prefix = "url(#grad-" in
         String.length result > String.length prefix
         && String.sub result 0 (String.length prefix) = prefix);
      let defs = Nopal_svg.Svg_fmt.defs_to_string ctx in
      Alcotest.(check bool)
        "has radialGradient def" true
        (Test_util.string_contains defs ~sub:"<radialGradient")

let test_gradient_stops_order () =
  let ctx = Nopal_svg.Svg_fmt.create_ctx () in
  let stops =
    [
      { Paint.offset = 0.0; color = Color.red };
      { Paint.offset = 0.5; color = Color.green };
      { Paint.offset = 1.0; color = Color.blue };
    ]
  in
  match Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:1.0 ~y1:0.0 ~stops with
  | Error e -> Alcotest.fail e
  | Ok grad ->
      let _result = Nopal_svg.Svg_fmt.paint_to_fill_attr ctx grad in
      let defs = Nopal_svg.Svg_fmt.defs_to_string ctx in
      (* Check that offset="0" appears before offset="0.5" which appears before
       offset="1" *)
      let find_offset defs needle =
        let found = ref (-1) in
        for i = 0 to String.length defs - String.length needle do
          if !found = -1 && String.sub defs i (String.length needle) = needle
          then found := i
        done;
        !found
      in
      let pos0 = find_offset defs "offset=\"0\"" in
      let pos05 = find_offset defs "offset=\"0.5\"" in
      let pos1 = find_offset defs "offset=\"1\"" in
      Alcotest.(check bool)
        "stops in order" true
        (pos0 >= 0 && pos05 > pos0 && pos1 > pos05)

let test_stroke_attrs_full () =
  let ctx = Nopal_svg.Svg_fmt.create_ctx () in
  let s =
    Paint.stroke ~width:2.0 ~dash:[ 5.0; 3.0 ] ~dash_offset:1.0
      ~line_cap:Round_cap ~line_join:Round_join (Paint.solid Color.red)
  in
  let result = Nopal_svg.Svg_fmt.stroke_to_attrs ctx s in
  let contains sub = Test_util.string_contains result ~sub in
  Alcotest.(check bool) "has stroke color" true (contains "stroke=\"");
  Alcotest.(check bool) "has stroke-width" true (contains "stroke-width=\"2\"");
  Alcotest.(check bool)
    "has stroke-dasharray" true
    (contains "stroke-dasharray=\"");
  Alcotest.(check bool)
    "has stroke-linecap" true
    (contains "stroke-linecap=\"round\"")

let test_stroke_attrs_minimal () =
  let ctx = Nopal_svg.Svg_fmt.create_ctx () in
  let s = Paint.stroke (Paint.solid Color.black) in
  let result = Nopal_svg.Svg_fmt.stroke_to_attrs ctx s in
  let contains sub = Test_util.string_contains result ~sub in
  Alcotest.(check bool) "has stroke" true (contains "stroke=\"");
  (* Minimal stroke should not have dasharray *)
  Alcotest.(check bool) "no dasharray" false (contains "stroke-dasharray")

let test_transform_translate () =
  let result =
    Nopal_svg.Svg_fmt.transform_to_attr (Transform.translate ~dx:10.0 ~dy:20.0)
  in
  check_string "translate" "translate(10 20)" result

let test_transform_rotate_radians_to_degrees () =
  let pi = Float.pi in
  let result =
    Nopal_svg.Svg_fmt.transform_to_attr (Transform.rotate (pi /. 2.0))
  in
  check_string "rotate" "rotate(90)" result

let test_transform_rotate_around () =
  let pi = Float.pi in
  let result =
    Nopal_svg.Svg_fmt.transform_to_attr
      (Transform.rotate_around ~angle:(pi /. 2.0) ~cx:50.0 ~cy:50.0)
  in
  check_string "rotate around" "rotate(90 50 50)" result

let test_transform_scale () =
  let result =
    Nopal_svg.Svg_fmt.transform_to_attr (Transform.scale ~sx:2.0 ~sy:3.0)
  in
  check_string "scale" "scale(2 3)" result

let test_transform_skew () =
  let pi = Float.pi in
  let result =
    Nopal_svg.Svg_fmt.transform_to_attr
      (Transform.skew ~sx:(pi /. 6.0) ~sy:(pi /. 4.0))
  in
  check_string "skew" "skewX(30) skewY(45)" result

let test_transform_matrix () =
  let result =
    Nopal_svg.Svg_fmt.transform_to_attr
      (Transform.matrix ~a:1.0 ~b:0.0 ~c:0.0 ~d:1.0 ~e:10.0 ~f:20.0)
  in
  check_string "matrix" "matrix(1 0 0 1 10 20)" result

let test_transforms_list_combined () =
  let result =
    Nopal_svg.Svg_fmt.transforms_to_attr
      [ Transform.translate ~dx:10.0 ~dy:20.0; Transform.scale ~sx:2.0 ~sy:2.0 ]
  in
  check_string "combined" "translate(10 20) scale(2 2)" result

let test_path_d_move_line_close () =
  let result =
    Nopal_svg.Svg_fmt.path_to_d
      [ Path.move_to ~x:0.0 ~y:0.0; Path.line_to ~x:10.0 ~y:10.0; Path.close ]
  in
  check_string "path" "M 0 0 L 10 10 Z" result

let test_path_d_close_without_subpath () =
  check_string "close alone" "Z" (Nopal_svg.Svg_fmt.path_to_d [ Path.close ])

let test_path_d_bezier () =
  let result =
    Nopal_svg.Svg_fmt.path_to_d
      [ Path.bezier_to ~cp1x:1.0 ~cp1y:2.0 ~cp2x:3.0 ~cp2y:4.0 ~x:5.0 ~y:6.0 ]
  in
  check_string "bezier" "M 1 2 C 1 2 3 4 5 6" result

let test_path_d_quad () =
  let result =
    Nopal_svg.Svg_fmt.path_to_d [ Path.quad_to ~cpx:1.0 ~cpy:2.0 ~x:3.0 ~y:4.0 ]
  in
  check_string "quad" "M 1 2 Q 1 2 3 4" result

let test_path_d_arc () =
  let pi = Float.pi in
  let result =
    Nopal_svg.Svg_fmt.path_to_d
      [
        Path.arc_to ~cx:50.0 ~cy:50.0 ~r:25.0 ~start_angle:0.0
          ~end_angle:(pi /. 2.0) ~direction:Path.Clockwise;
      ]
  in
  (* Arc_to is approximated as Bezier curves, so the output should contain
     C commands rather than A commands *)
  Alcotest.(check bool)
    "contains bezier approximation" true
    (Test_util.string_contains result ~sub:"C ")

type command =
  | Move of float * float
  | Line of float * float
  | Cubic of float * float
  | Close_path

let parse_float token =
  match float_of_string_opt token with
  | Some f -> f
  | None -> Alcotest.failf "not a number in d: %S" token

let rec parse_commands tokens =
  match tokens with
  | [] -> []
  | "M" :: x :: y :: rest ->
      Move (parse_float x, parse_float y) :: parse_commands rest
  | "L" :: x :: y :: rest ->
      Line (parse_float x, parse_float y) :: parse_commands rest
  | "C" :: _ :: _ :: _ :: _ :: x :: y :: rest ->
      Cubic (parse_float x, parse_float y) :: parse_commands rest
  | "Z" :: rest -> Close_path :: parse_commands rest
  | token :: _ -> Alcotest.failf "unexpected token in d: %S" token

let commands d = parse_commands (String.split_on_char ' ' d)
let point_tolerance = 1e-3
let angle_tolerance = 1e-3

let check_point label ~expected:(ex, ey) (x, y) =
  Alcotest.(check (float point_tolerance)) (label ^ " x") ex x;
  Alcotest.(check (float point_tolerance)) (label ^ " y") ey y

let point_on (row : Arc_cases.row) angle =
  (row.cx +. (row.r *. Float.cos angle), row.cy +. (row.r *. Float.sin angle))

(* The renderer draws from the start angle reduced into [0, 2π). For a row whose
   angle is too large to keep its fraction of a turn, that reduced angle is the
   only one the shared rule defines. *)
let oracle_start (row : Arc_cases.row) =
  match
    Nopal_draw.Arc.resolve row.direction ~cx:row.cx ~cy:row.cy ~r:row.r
      ~start_angle:row.start_angle ~end_angle:row.end_angle
  with
  | Nopal_draw.Arc.Sweep { start; _ } -> start
  | Nopal_draw.Arc.Invalid -> row.start_angle

(* Each curve spans at most a quarter turn, so the wrapped difference between
   consecutive endpoint angles is that curve's signed sweep. *)
let wrap_angle a =
  let two_pi = 2. *. Float.pi in
  let shifted = Float.rem (a +. Float.pi) two_pi in
  (if shifted < 0. then shifted +. two_pi else shifted) -. Float.pi

let swept_angle (row : Arc_cases.row) ~from points =
  let angle_of (x, y) = Float.atan2 (y -. row.cy) (x -. row.cx) in
  let _, total =
    List.fold_left
      (fun (previous, total) point ->
        let angle = angle_of point in
        (angle, total +. wrap_angle (angle -. previous)))
      (angle_of from, 0.)
      points
  in
  total

let arc_of_row (row : Arc_cases.row) =
  Path.arc_to ~cx:row.cx ~cy:row.cy ~r:row.r ~start_angle:row.start_angle
    ~end_angle:row.end_angle ~direction:row.direction

let curve_end = function
  | Cubic (x, y) -> (x, y)
  | Move _
  | Line _
  | Close_path ->
      Alcotest.fail "an arc's chain holds a command other than C"

let lead_point = function
  | Move (x, y)
  | Line (x, y)
  | Cubic (x, y) ->
      (x, y)
  | Close_path -> Alcotest.fail "an arc opens with Z"

let check_sweep_row (row : Arc_cases.row) sweep =
  let d =
    Nopal_svg.Svg_fmt.path_to_d [ Path.move_to ~x:0. ~y:0.; arc_of_row row ]
  in
  (* Control points are not read back below, so a NaN in one must be caught on
     the raw string. *)
  Alcotest.(check bool)
    "d holds no nan or inf" false
    (List.exists
       (fun token ->
         let lower = String.lowercase_ascii token in
         String.length lower >= 3
         && (String.equal lower "nan"
            || String.equal lower "-nan"
            || String.equal lower "inf"
            || String.equal lower "-inf"))
       (String.split_on_char ' ' d));
  match commands d with
  | Move _ :: lead :: chain -> (
      let start = lead_point lead in
      let ends = List.map curve_end chain in
      let finish = List.fold_left (fun _ point -> point) start ends in
      check_point "start" ~expected:(point_on row (oracle_start row)) start;
      check_point "end"
        ~expected:(point_on row (oracle_start row +. sweep))
        finish;
      (match Float.equal row.r 0. with
      (* Every point of a zero-radius arc is the centre, so its points carry no
         angle to recover. *)
      | true -> ()
      | false ->
          Alcotest.(check (float angle_tolerance))
            "swept angle" sweep
            (swept_angle row ~from:start ends));
      match lead with
      | Line _ -> ()
      | Move _
      | Cubic _
      | Close_path ->
          Alcotest.failf "an arc continuing a subpath must open with L: %S" d)
  | _ -> Alcotest.failf "unexpected d: %S" d

let check_invalid_row (row : Arc_cases.row) =
  let move = Path.move_to ~x:0. ~y:0. in
  let line = Path.line_to ~x:10. ~y:10. in
  check_string "invalid arc emits nothing"
    (Nopal_svg.Svg_fmt.path_to_d [ move; line ])
    (Nopal_svg.Svg_fmt.path_to_d [ move; arc_of_row row; line ])

let arc_table_case (row : Arc_cases.row) =
  Alcotest.test_case row.name `Quick (fun () ->
      match row.expected with
      | Arc_cases.Invalid -> check_invalid_row row
      | Arc_cases.Sweep sweep -> check_sweep_row row sweep)

let test_arc_continues_subpath () =
  let d =
    Nopal_svg.Svg_fmt.path_to_d
      (Nopal_draw.Path.donut_arc ~cx:50. ~cy:50. ~inner_r:20. ~outer_r:40.
         ~start_angle:0. ~end_angle:(1.2 *. Float.pi) ())
  in
  let is_move = function
    | Move _ -> true
    | Line _
    | Cubic _
    | Close_path ->
        false
  in
  let is_cubic = function
    | Cubic _ -> true
    | Move _
    | Line _
    | Close_path ->
        false
  in
  match commands d with
  | Move _ :: rest ->
      Alcotest.(check int)
        "moves after the first" 0
        (List.length (List.filter is_move rest));
      (* The donut holds two arcs of 1.2π, three curves each. *)
      Alcotest.(check int)
        "both arcs drawn" 6
        (List.length (List.filter is_cubic rest))
  | _ -> Alcotest.failf "the donut must open with M: %S" d

let test_arc_leading_move_when_no_subpath () =
  let d =
    Nopal_svg.Svg_fmt.path_to_d
      [
        Path.arc_to ~cx:50. ~cy:40. ~r:30. ~start_angle:0.
          ~end_angle:(Float.pi /. 2.) ~direction:Path.Clockwise;
      ]
  in
  match commands d with
  | Move (x, y) :: Cubic _ :: _ ->
      check_point "start" ~expected:(80., 40.) (x, y)
  | _ -> Alcotest.failf "a leading arc must open with M then C: %S" d

let test_arc_after_close_continues_with_line () =
  let d =
    Nopal_svg.Svg_fmt.path_to_d
      [
        Path.move_to ~x:0. ~y:0.;
        Path.line_to ~x:10. ~y:0.;
        Path.close;
        Path.arc_to ~cx:50. ~cy:40. ~r:30. ~start_angle:0.
          ~end_angle:(Float.pi /. 2.) ~direction:Path.Clockwise;
      ]
  in
  (* After Z canvas starts a new subpath at the closed one's start, so the arc
     reaches its start with a line, and SVG's current point after Z agrees. *)
  match List.rev (commands d) with
  | Cubic _ :: Line (x, y) :: Close_path :: _ ->
      check_point "arc start" ~expected:(80., 40.) (x, y)
  | _ -> Alcotest.failf "an arc after Z must continue with L: %S" d

let invalid_arc =
  Path.arc_to ~cx:0. ~cy:0. ~r:(-1.) ~start_angle:0. ~end_angle:1.
    ~direction:Path.Clockwise

let test_segment_after_invalid_arc_opens_with_move () =
  check_string "line" "M 5 5"
    (Nopal_svg.Svg_fmt.path_to_d [ invalid_arc; Path.line_to ~x:5. ~y:5. ]);
  check_string "bezier" "M 1 1 C 1 1 2 2 3 3"
    (Nopal_svg.Svg_fmt.path_to_d
       [
         invalid_arc;
         Path.bezier_to ~cp1x:1. ~cp1y:1. ~cp2x:2. ~cp2y:2. ~x:3. ~y:3.;
       ]);
  check_string "quad" "M 1 1 Q 1 1 3 3"
    (Nopal_svg.Svg_fmt.path_to_d
       [ invalid_arc; Path.quad_to ~cpx:1. ~cpy:1. ~x:3. ~y:3. ])

let test_blend_modes () =
  check_string "normal" "normal" (Nopal_svg.Svg_fmt.blend_to_css Normal);
  check_string "multiply" "multiply" (Nopal_svg.Svg_fmt.blend_to_css Multiply);
  check_string "screen" "screen" (Nopal_svg.Svg_fmt.blend_to_css Screen);
  check_string "overlay" "overlay" (Nopal_svg.Svg_fmt.blend_to_css Overlay);
  check_string "darken" "darken" (Nopal_svg.Svg_fmt.blend_to_css Darken);
  check_string "lighten" "lighten" (Nopal_svg.Svg_fmt.blend_to_css Lighten);
  check_string "color-dodge" "color-dodge"
    (Nopal_svg.Svg_fmt.blend_to_css Color_dodge);
  check_string "color-burn" "color-burn"
    (Nopal_svg.Svg_fmt.blend_to_css Color_burn);
  check_string "hard-light" "hard-light"
    (Nopal_svg.Svg_fmt.blend_to_css Hard_light);
  check_string "soft-light" "soft-light"
    (Nopal_svg.Svg_fmt.blend_to_css Soft_light);
  check_string "difference" "difference"
    (Nopal_svg.Svg_fmt.blend_to_css Difference);
  check_string "exclusion" "exclusion"
    (Nopal_svg.Svg_fmt.blend_to_css Exclusion)

let test_line_cap_mapping () =
  check_string "butt" "butt" (Nopal_svg.Svg_fmt.line_cap_to_string Butt);
  check_string "round" "round" (Nopal_svg.Svg_fmt.line_cap_to_string Round_cap);
  check_string "square" "square" (Nopal_svg.Svg_fmt.line_cap_to_string Square)

let test_line_join_mapping () =
  check_string "miter" "miter" (Nopal_svg.Svg_fmt.line_join_to_string Miter);
  check_string "round" "round"
    (Nopal_svg.Svg_fmt.line_join_to_string Round_join);
  check_string "bevel" "bevel" (Nopal_svg.Svg_fmt.line_join_to_string Bevel)

let () =
  Alcotest.run "Svg_fmt"
    [
      ( "color",
        [
          Alcotest.test_case "opaque" `Quick test_color_to_css_opaque;
          Alcotest.test_case "transparent" `Quick test_color_to_css_transparent;
        ] );
      ( "paint",
        [
          Alcotest.test_case "solid fill" `Quick test_paint_solid_fill;
          Alcotest.test_case "no paint" `Quick test_paint_no_paint_fill;
          Alcotest.test_case "linear gradient" `Quick
            test_paint_linear_gradient_produces_def;
          Alcotest.test_case "radial gradient" `Quick
            test_paint_radial_gradient_produces_def;
          Alcotest.test_case "gradient stops order" `Quick
            test_gradient_stops_order;
        ] );
      ( "stroke",
        [
          Alcotest.test_case "full" `Quick test_stroke_attrs_full;
          Alcotest.test_case "minimal" `Quick test_stroke_attrs_minimal;
        ] );
      ( "transform",
        [
          Alcotest.test_case "translate" `Quick test_transform_translate;
          Alcotest.test_case "rotate" `Quick
            test_transform_rotate_radians_to_degrees;
          Alcotest.test_case "rotate around" `Quick test_transform_rotate_around;
          Alcotest.test_case "scale" `Quick test_transform_scale;
          Alcotest.test_case "skew" `Quick test_transform_skew;
          Alcotest.test_case "matrix" `Quick test_transform_matrix;
          Alcotest.test_case "combined" `Quick test_transforms_list_combined;
        ] );
      ( "path",
        [
          Alcotest.test_case "move/line/close" `Quick
            test_path_d_move_line_close;
          Alcotest.test_case "close without subpath" `Quick
            test_path_d_close_without_subpath;
          Alcotest.test_case "bezier" `Quick test_path_d_bezier;
          Alcotest.test_case "quad" `Quick test_path_d_quad;
          Alcotest.test_case "arc" `Quick test_path_d_arc;
        ] );
      ("svg_fmt/arc_table", List.map arc_table_case Arc_cases.rows);
      ( "svg_fmt/arc_subpath",
        [
          Alcotest.test_case "arc continues subpath" `Quick
            test_arc_continues_subpath;
          Alcotest.test_case "arc after close continues with line" `Quick
            test_arc_after_close_continues_with_line;
          Alcotest.test_case "segment after invalid arc opens with move" `Quick
            test_segment_after_invalid_arc_opens_with_move;
          Alcotest.test_case "arc leading move when no subpath" `Quick
            test_arc_leading_move_when_no_subpath;
        ] );
      ("blend", [ Alcotest.test_case "all modes" `Quick test_blend_modes ]);
      ("line_cap", [ Alcotest.test_case "mapping" `Quick test_line_cap_mapping ]);
      ( "line_join",
        [ Alcotest.test_case "mapping" `Quick test_line_join_mapping ] );
    ]
