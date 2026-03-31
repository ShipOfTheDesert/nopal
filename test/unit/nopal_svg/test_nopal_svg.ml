open Nopal_scene

let check_contains msg needle haystack =
  Alcotest.(check bool)
    msg true
    (Test_util.string_contains haystack ~sub:needle)

let check_starts_with msg prefix s =
  Alcotest.(check bool)
    msg true
    (String.length s >= String.length prefix
    && String.sub s 0 (String.length prefix) = prefix)

(* -- test_render_empty_scene -- *)
let test_render_empty_scene () =
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [] in
  check_starts_with "starts with <svg" "<svg" svg;
  check_contains "has xmlns" "xmlns=\"http://www.w3.org/2000/svg\"" svg;
  check_contains "has closing tag" "</svg>" svg

(* -- test_render_rect -- *)
let test_render_rect () =
  let node = Scene.rect ~x:10.0 ~y:20.0 ~w:100.0 ~h:50.0 () in
  let svg = Nopal_svg.render ~width:200.0 ~height:200.0 [ node ] in
  check_contains "has rect" "<rect" svg;
  check_contains "x attr" "x=\"10\"" svg;
  check_contains "y attr" "y=\"20\"" svg;
  check_contains "width attr" "width=\"100\"" svg;
  check_contains "height attr" "height=\"50\"" svg

(* -- test_render_rect_rounded -- *)
let test_render_rect_rounded () =
  let node = Scene.rect ~rx:5.0 ~ry:3.0 ~x:0.0 ~y:0.0 ~w:50.0 ~h:50.0 () in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "rx attr" "rx=\"5\"" svg;
  check_contains "ry attr" "ry=\"3\"" svg

(* -- test_render_circle -- *)
let test_render_circle () =
  let node = Scene.circle ~cx:50.0 ~cy:50.0 ~r:25.0 () in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "has circle" "<circle" svg;
  check_contains "cx attr" "cx=\"50\"" svg;
  check_contains "cy attr" "cy=\"50\"" svg;
  check_contains "r attr" "r=\"25\"" svg

(* -- test_render_ellipse -- *)
let test_render_ellipse () =
  let node = Scene.ellipse ~cx:50.0 ~cy:50.0 ~rx:30.0 ~ry:20.0 () in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "has ellipse" "<ellipse" svg;
  check_contains "rx attr" "rx=\"30\"" svg;
  check_contains "ry attr" "ry=\"20\"" svg

(* -- test_render_line -- *)
let test_render_line () =
  let node = Scene.line ~x1:0.0 ~y1:0.0 ~x2:100.0 ~y2:100.0 () in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "has line" "<line" svg;
  check_contains "x1 attr" "x1=\"0\"" svg;
  check_contains "y1 attr" "y1=\"0\"" svg;
  check_contains "x2 attr" "x2=\"100\"" svg;
  check_contains "y2 attr" "y2=\"100\"" svg

(* -- test_render_path -- *)
let test_render_path () =
  let segs =
    [ Path.move_to ~x:0.0 ~y:0.0; Path.line_to ~x:50.0 ~y:50.0; Path.close ]
  in
  let node = Scene.path segs in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "has path" "<path" svg;
  check_contains "d attr" "d=\"M 0 0 L 50 50 Z\"" svg

(* -- test_render_polygon -- *)
let test_render_polygon () =
  let node = Scene.polygon [ (0.0, 0.0); (50.0, 0.0); (25.0, 50.0) ] in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "has polygon" "<polygon" svg;
  check_contains "points attr" "points=\"0,0 50,0 25,50\"" svg

(* -- test_render_polyline -- *)
let test_render_polyline () =
  let node = Scene.polyline [ (0.0, 0.0); (50.0, 25.0); (100.0, 0.0) ] in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "has polyline" "<polyline" svg;
  check_contains "points attr" "points=\"0,0 50,25 100,0\"" svg;
  check_contains "fill none" "fill=\"none\"" svg

(* -- test_render_text -- *)
let test_render_text () =
  let node =
    Scene.text ~x:10.0 ~y:30.0 ~font_size:16.0
      ~font_family:Nopal_style.Font.Sans_serif ~anchor:Start
      ~baseline:Alphabetic "Hello"
  in
  let svg = Nopal_svg.render ~width:200.0 ~height:100.0 [ node ] in
  check_contains "has text" "<text" svg;
  check_contains "x attr" "x=\"10\"" svg;
  check_contains "y attr" "y=\"30\"" svg;
  check_contains "font-size" "font-size=\"16\"" svg;
  check_contains "text-anchor" "text-anchor=\"start\"" svg;
  check_contains "dominant-baseline" "dominant-baseline=\"alphabetic\"" svg;
  check_contains "content" ">Hello</text>" svg

(* -- test_render_group_opacity -- *)
let test_render_group_opacity () =
  let child = Scene.rect ~x:0.0 ~y:0.0 ~w:10.0 ~h:10.0 () in
  let node = Scene.group ~opacity:0.5 [ child ] in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "g with opacity" "opacity=\"0.5\"" svg

(* -- test_render_group_blend -- *)
let test_render_group_blend () =
  let child = Scene.rect ~x:0.0 ~y:0.0 ~w:10.0 ~h:10.0 () in
  let node = Scene.group ~blend:Multiply [ child ] in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "mix-blend-mode" "mix-blend-mode:multiply" svg

(* -- test_render_group_transforms -- *)
let test_render_group_transforms () =
  let child = Scene.rect ~x:0.0 ~y:0.0 ~w:10.0 ~h:10.0 () in
  let node =
    Scene.group ~transforms:[ Transform.translate ~dx:10.0 ~dy:20.0 ] [ child ]
  in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "transform attr" "transform=\"translate(10 20)\"" svg

(* -- test_render_group_nested -- *)
let test_render_group_nested () =
  let inner_child = Scene.circle ~cx:5.0 ~cy:5.0 ~r:3.0 () in
  let inner = Scene.group [ inner_child ] in
  let outer = Scene.group [ inner ] in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ outer ] in
  (* Should have nested <g> elements *)
  check_contains "nested g" "<g><g>" svg;
  check_contains "nested close" "</g></g>" svg

(* -- test_render_clip -- *)
let test_render_clip () =
  let shape = Scene.rect ~x:0.0 ~y:0.0 ~w:50.0 ~h:50.0 () in
  let child = Scene.circle ~cx:25.0 ~cy:25.0 ~r:30.0 () in
  let node = Scene.clip ~shape [ child ] in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "has clipPath def" "<clipPath" svg;
  check_contains "clip-path attr" "clip-path=\"url(#clip-" svg;
  check_contains "has defs" "<defs>" svg

(* -- test_render_linear_gradient -- *)
let test_render_linear_gradient () =
  let stops =
    [
      { Paint.offset = 0.0; color = Color.red };
      { Paint.offset = 1.0; color = Color.blue };
    ]
  in
  match Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:1.0 ~y1:0.0 ~stops with
  | Error e -> Alcotest.fail e
  | Ok grad ->
      let node = Scene.rect ~fill:grad ~x:0.0 ~y:0.0 ~w:100.0 ~h:100.0 () in
      let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
      check_contains "has linearGradient" "<linearGradient" svg;
      check_contains "has defs" "<defs>" svg;
      check_contains "url ref in fill" "url(#grad-" svg

(* -- test_render_radial_gradient -- *)
let test_render_radial_gradient () =
  let stops =
    [
      { Paint.offset = 0.0; color = Color.red };
      { Paint.offset = 1.0; color = Color.blue };
    ]
  in
  match Paint.radial_gradient ~cx:0.5 ~cy:0.5 ~r:0.5 ~stops with
  | Error e -> Alcotest.fail e
  | Ok grad ->
      let node = Scene.circle ~fill:grad ~cx:50.0 ~cy:50.0 ~r:50.0 () in
      let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
      check_contains "has radialGradient" "<radialGradient" svg;
      check_contains "has defs" "<defs>" svg

(* -- test_render_stroke_dash -- *)
let test_render_stroke_dash () =
  let s = Paint.stroke ~dash:[ 5.0; 3.0 ] (Paint.solid Color.black) in
  let node = Scene.rect ~stroke:s ~x:0.0 ~y:0.0 ~w:50.0 ~h:50.0 () in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ node ] in
  check_contains "stroke-dasharray" "stroke-dasharray=\"5 3\"" svg

(* -- test_render_multiple_nodes -- *)
let test_render_multiple_nodes () =
  let n1 = Scene.rect ~x:0.0 ~y:0.0 ~w:10.0 ~h:10.0 () in
  let n2 = Scene.circle ~cx:50.0 ~cy:50.0 ~r:5.0 () in
  let svg = Nopal_svg.render ~width:100.0 ~height:100.0 [ n1; n2 ] in
  check_contains "has rect" "<rect" svg;
  check_contains "has circle" "<circle" svg

(* -- test_svg_root_attributes -- *)
let test_svg_root_attributes () =
  let svg = Nopal_svg.render ~width:400.0 ~height:300.0 [] in
  check_starts_with "starts with <svg" "<svg" svg;
  check_contains "xmlns" "xmlns=\"http://www.w3.org/2000/svg\"" svg;
  check_contains "viewBox" "viewBox=\"0 0 400 300\"" svg

(* -- test_render_transform_all_variants -- *)
let test_render_transform_all_variants () =
  let pi = Float.pi in
  let child = Scene.rect ~x:0.0 ~y:0.0 ~w:10.0 ~h:10.0 () in
  (* Translate *)
  let g1 =
    Scene.group ~transforms:[ Transform.translate ~dx:5.0 ~dy:10.0 ] [ child ]
  in
  let svg1 = Nopal_svg.render ~width:100.0 ~height:100.0 [ g1 ] in
  check_contains "translate" "translate(5 10)" svg1;
  (* Scale *)
  let g2 =
    Scene.group ~transforms:[ Transform.scale ~sx:2.0 ~sy:3.0 ] [ child ]
  in
  let svg2 = Nopal_svg.render ~width:100.0 ~height:100.0 [ g2 ] in
  check_contains "scale" "scale(2 3)" svg2;
  (* Rotate *)
  let g3 = Scene.group ~transforms:[ Transform.rotate (pi /. 2.0) ] [ child ] in
  let svg3 = Nopal_svg.render ~width:100.0 ~height:100.0 [ g3 ] in
  check_contains "rotate" "rotate(90)" svg3;
  (* Rotate_around *)
  let g4 =
    Scene.group
      ~transforms:[ Transform.rotate_around ~angle:pi ~cx:50.0 ~cy:50.0 ]
      [ child ]
  in
  let svg4 = Nopal_svg.render ~width:100.0 ~height:100.0 [ g4 ] in
  check_contains "rotate around" "rotate(180 50 50)" svg4;
  (* Skew *)
  let g5 =
    Scene.group
      ~transforms:[ Transform.skew ~sx:(pi /. 4.0) ~sy:(pi /. 6.0) ]
      [ child ]
  in
  let svg5 = Nopal_svg.render ~width:100.0 ~height:100.0 [ g5 ] in
  check_contains "skewX" "skewX(45)" svg5;
  check_contains "skewY" "skewY(30)" svg5;
  (* Matrix *)
  let g6 =
    Scene.group
      ~transforms:
        [ Transform.matrix ~a:1.0 ~b:0.0 ~c:0.0 ~d:1.0 ~e:10.0 ~f:20.0 ]
      [ child ]
  in
  let svg6 = Nopal_svg.render ~width:100.0 ~height:100.0 [ g6 ] in
  check_contains "matrix" "matrix(1 0 0 1 10 20)" svg6

(* -- test_render_text_xml_escape -- *)
let test_render_text_xml_escape () =
  let node =
    Scene.text ~x:0.0 ~y:0.0 ~font_size:12.0
      ~font_family:Nopal_style.Font.Sans_serif ~anchor:Start
      ~baseline:Alphabetic "A & B < C > D \"E\" F'G"
  in
  let svg = Nopal_svg.render ~width:200.0 ~height:100.0 [ node ] in
  check_contains "ampersand escaped" "&amp;" svg;
  check_contains "lt escaped" "&lt;" svg;
  check_contains "gt escaped" "&gt;" svg;
  check_contains "quot escaped" "&quot;" svg;
  check_contains "apos escaped" "&#39;" svg

let () =
  Alcotest.run "Nopal_svg"
    [
      ( "empty",
        [ Alcotest.test_case "empty scene" `Quick test_render_empty_scene ] );
      ( "shapes",
        [
          Alcotest.test_case "rect" `Quick test_render_rect;
          Alcotest.test_case "rect rounded" `Quick test_render_rect_rounded;
          Alcotest.test_case "circle" `Quick test_render_circle;
          Alcotest.test_case "ellipse" `Quick test_render_ellipse;
          Alcotest.test_case "line" `Quick test_render_line;
          Alcotest.test_case "path" `Quick test_render_path;
          Alcotest.test_case "polygon" `Quick test_render_polygon;
          Alcotest.test_case "polyline" `Quick test_render_polyline;
        ] );
      ( "text",
        [
          Alcotest.test_case "text" `Quick test_render_text;
          Alcotest.test_case "xml escape" `Quick test_render_text_xml_escape;
        ] );
      ( "group",
        [
          Alcotest.test_case "opacity" `Quick test_render_group_opacity;
          Alcotest.test_case "blend" `Quick test_render_group_blend;
          Alcotest.test_case "transforms" `Quick test_render_group_transforms;
          Alcotest.test_case "nested" `Quick test_render_group_nested;
        ] );
      ("clip", [ Alcotest.test_case "clip" `Quick test_render_clip ]);
      ( "gradient",
        [
          Alcotest.test_case "linear" `Quick test_render_linear_gradient;
          Alcotest.test_case "radial" `Quick test_render_radial_gradient;
        ] );
      ("stroke", [ Alcotest.test_case "dash" `Quick test_render_stroke_dash ]);
      ( "multiple",
        [
          Alcotest.test_case "multiple nodes" `Quick test_render_multiple_nodes;
        ] );
      ( "root",
        [ Alcotest.test_case "svg attributes" `Quick test_svg_root_attributes ]
      );
      ( "transforms",
        [
          Alcotest.test_case "all variants" `Quick
            test_render_transform_all_variants;
        ] );
    ]
