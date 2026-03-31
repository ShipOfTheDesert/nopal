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

let test_path_d_bezier () =
  let result =
    Nopal_svg.Svg_fmt.path_to_d
      [ Path.bezier_to ~cp1x:1.0 ~cp1y:2.0 ~cp2x:3.0 ~cp2y:4.0 ~x:5.0 ~y:6.0 ]
  in
  check_string "bezier" "C 1 2 3 4 5 6" result

let test_path_d_quad () =
  let result =
    Nopal_svg.Svg_fmt.path_to_d [ Path.quad_to ~cpx:1.0 ~cpy:2.0 ~x:3.0 ~y:4.0 ]
  in
  check_string "quad" "Q 1 2 3 4" result

let test_path_d_arc () =
  let pi = Float.pi in
  let result =
    Nopal_svg.Svg_fmt.path_to_d
      [
        Path.arc_to ~cx:50.0 ~cy:50.0 ~r:25.0 ~start_angle:0.0
          ~end_angle:(pi /. 2.0);
      ]
  in
  (* Arc_to is approximated as Bezier curves, so the output should contain
     C commands rather than A commands *)
  Alcotest.(check bool)
    "contains bezier approximation" true
    (Test_util.string_contains result ~sub:"C ")

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
          Alcotest.test_case "bezier" `Quick test_path_d_bezier;
          Alcotest.test_case "quad" `Quick test_path_d_quad;
          Alcotest.test_case "arc" `Quick test_path_d_arc;
        ] );
      ("blend", [ Alcotest.test_case "all modes" `Quick test_blend_modes ]);
      ("line_cap", [ Alcotest.test_case "mapping" `Quick test_line_cap_mapping ]);
      ( "line_join",
        [ Alcotest.test_case "mapping" `Quick test_line_join_mapping ] );
    ]
