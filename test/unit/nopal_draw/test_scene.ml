open Nopal_draw

let color_red = Color.rgba ~r:1.0 ~g:0.0 ~b:0.0 ~a:1.0
let color_black = Color.rgba ~r:0.0 ~g:0.0 ~b:0.0 ~a:1.0

let test_rect_defaults () =
  let r = Scene.rect ~x:10.0 ~y:20.0 ~w:100.0 ~h:50.0 () in
  match r with
  | Scene.Rect { x; y; w; h; rx; ry; fill; stroke } ->
      Alcotest.(check (float 0.001)) "x" 10.0 x;
      Alcotest.(check (float 0.001)) "y" 20.0 y;
      Alcotest.(check (float 0.001)) "w" 100.0 w;
      Alcotest.(check (float 0.001)) "h" 50.0 h;
      Alcotest.(check (float 0.001)) "rx" 0.0 rx;
      Alcotest.(check (float 0.001)) "ry" 0.0 ry;
      Alcotest.(check bool)
        "fill is No_paint" true
        (Paint.equal fill Paint.no_paint);
      Alcotest.(check bool)
        "stroke is None" true
        (match stroke with
        | None -> true
        | Some _ -> false)
  | _ -> Alcotest.fail "expected Rect"

let test_rect_rounded () =
  let r = Scene.rect ~rx:5.0 ~ry:10.0 ~x:0.0 ~y:0.0 ~w:50.0 ~h:50.0 () in
  match r with
  | Scene.Rect { rx; ry; _ } ->
      Alcotest.(check (float 0.001)) "rx" 5.0 rx;
      Alcotest.(check (float 0.001)) "ry" 10.0 ry
  | _ -> Alcotest.fail "expected Rect"

let test_circle () =
  let c = Scene.circle ~cx:50.0 ~cy:50.0 ~r:25.0 () in
  match c with
  | Scene.Circle { cx; cy; r; _ } ->
      Alcotest.(check (float 0.001)) "cx" 50.0 cx;
      Alcotest.(check (float 0.001)) "cy" 50.0 cy;
      Alcotest.(check (float 0.001)) "r" 25.0 r
  | _ -> Alcotest.fail "expected Circle"

let test_ellipse () =
  let e = Scene.ellipse ~cx:50.0 ~cy:50.0 ~rx:30.0 ~ry:20.0 () in
  match e with
  | Scene.Ellipse { cx; cy; rx; ry; _ } ->
      Alcotest.(check (float 0.001)) "cx" 50.0 cx;
      Alcotest.(check (float 0.001)) "cy" 50.0 cy;
      Alcotest.(check (float 0.001)) "rx" 30.0 rx;
      Alcotest.(check (float 0.001)) "ry" 20.0 ry
  | _ -> Alcotest.fail "expected Ellipse"

let test_line_default_stroke () =
  let l = Scene.line ~x1:0.0 ~y1:0.0 ~x2:100.0 ~y2:100.0 () in
  match l with
  | Scene.Line { x1; y1; x2; y2; stroke } ->
      Alcotest.(check (float 0.001)) "x1" 0.0 x1;
      Alcotest.(check (float 0.001)) "y1" 0.0 y1;
      Alcotest.(check (float 0.001)) "x2" 100.0 x2;
      Alcotest.(check (float 0.001)) "y2" 100.0 y2;
      Alcotest.(check (float 0.001)) "stroke width" 1.0 stroke.width
  | _ -> Alcotest.fail "expected Line"

let test_path () =
  let segments =
    [ Path.move_to ~x:0.0 ~y:0.0; Path.line_to ~x:100.0 ~y:100.0; Path.close ]
  in
  let p = Scene.path segments in
  match p with
  | Scene.Path { segments = segs; _ } ->
      Alcotest.(check int) "segment count" 3 (List.length segs)
  | _ -> Alcotest.fail "expected Path"

let test_polygon () =
  let pts = [ (0.0, 0.0); (100.0, 0.0); (50.0, 100.0) ] in
  let p = Scene.polygon pts in
  match p with
  | Scene.Polygon { points; _ } ->
      Alcotest.(check int) "point count" 3 (List.length points)
  | _ -> Alcotest.fail "expected Polygon"

let test_polyline () =
  let pts = [ (0.0, 0.0); (50.0, 50.0); (100.0, 0.0) ] in
  let p = Scene.polyline pts in
  match p with
  | Scene.Polyline { points; stroke } ->
      Alcotest.(check int) "point count" 3 (List.length points);
      Alcotest.(check (float 0.001)) "default stroke width" 1.0 stroke.width
  | _ -> Alcotest.fail "expected Polyline"

let test_text_defaults () =
  let t = Scene.text ~x:10.0 ~y:20.0 "Hello" in
  match t with
  | Scene.Text
      {
        x;
        y;
        content;
        font_size;
        font_family;
        font_weight;
        fill;
        anchor;
        baseline;
      } ->
      Alcotest.(check (float 0.001)) "x" 10.0 x;
      Alcotest.(check (float 0.001)) "y" 20.0 y;
      Alcotest.(check string) "content" "Hello" content;
      Alcotest.(check (float 0.001)) "font_size" 16.0 font_size;
      Alcotest.(check bool)
        "font_family" true
        (Nopal_style.Font.equal_family font_family Nopal_style.Font.Sans_serif);
      Alcotest.(check bool)
        "font_weight" true
        (Nopal_style.Font.equal_weight font_weight Nopal_style.Font.Normal);
      Alcotest.(check bool)
        "fill is solid black" true
        (Paint.equal fill (Paint.solid color_black));
      Alcotest.(check bool)
        "anchor" true
        (match anchor with
        | Scene.Start -> true
        | _ -> false);
      Alcotest.(check bool)
        "baseline" true
        (match baseline with
        | Scene.Alphabetic -> true
        | _ -> false)
  | _ -> Alcotest.fail "expected Text"

let test_text_custom () =
  let t =
    Scene.text ~x:0.0 ~y:0.0 ~font_size:24.0
      ~font_family:Nopal_style.Font.Monospace ~font_weight:Nopal_style.Font.Bold
      ~fill:(Paint.solid color_red) ~anchor:Scene.Middle ~baseline:Scene.Top
      "Custom"
  in
  match t with
  | Scene.Text
      { font_size; font_family; font_weight; fill; anchor; baseline; _ } ->
      Alcotest.(check (float 0.001)) "font_size" 24.0 font_size;
      Alcotest.(check bool)
        "monospace" true
        (Nopal_style.Font.equal_family font_family Nopal_style.Font.Monospace);
      Alcotest.(check bool)
        "bold" true
        (Nopal_style.Font.equal_weight font_weight Nopal_style.Font.Bold);
      Alcotest.(check bool)
        "fill red" true
        (Paint.equal fill (Paint.solid color_red));
      Alcotest.(check bool)
        "anchor middle" true
        (match anchor with
        | Scene.Middle -> true
        | _ -> false);
      Alcotest.(check bool)
        "baseline top" true
        (match baseline with
        | Scene.Top -> true
        | _ -> false)
  | _ -> Alcotest.fail "expected Text"

let test_group_defaults () =
  let g = Scene.group [ Scene.circle ~cx:0.0 ~cy:0.0 ~r:10.0 () ] in
  match g with
  | Scene.Group { opacity; blend; transforms; children } ->
      Alcotest.(check (float 0.001)) "opacity" 1.0 opacity;
      Alcotest.(check bool)
        "blend normal" true
        (match blend with
        | Scene.Normal -> true
        | _ -> false);
      Alcotest.(check int) "no transforms" 0 (List.length transforms);
      Alcotest.(check int) "1 child" 1 (List.length children)
  | _ -> Alcotest.fail "expected Group"

let test_group_custom () =
  let g =
    Scene.group ~opacity:0.5 ~blend:Scene.Multiply
      ~transforms:[ Transform.translate ~dx:10.0 ~dy:20.0 ]
      [ Scene.circle ~cx:0.0 ~cy:0.0 ~r:5.0 () ]
  in
  match g with
  | Scene.Group { opacity; blend; transforms; children } ->
      Alcotest.(check (float 0.001)) "opacity" 0.5 opacity;
      Alcotest.(check bool)
        "blend multiply" true
        (match blend with
        | Scene.Multiply -> true
        | _ -> false);
      Alcotest.(check int) "1 transform" 1 (List.length transforms);
      Alcotest.(check int) "1 child" 1 (List.length children)
  | _ -> Alcotest.fail "expected Group"

let test_clip () =
  let shape = Scene.rect ~x:0.0 ~y:0.0 ~w:100.0 ~h:100.0 () in
  let child = Scene.circle ~cx:50.0 ~cy:50.0 ~r:25.0 () in
  let c = Scene.clip ~shape [ child ] in
  match c with
  | Scene.Clip { shape = s; children } ->
      Alcotest.(check bool)
        "shape is rect" true
        (match s with
        | Scene.Rect _ -> true
        | _ -> false);
      Alcotest.(check int) "1 child" 1 (List.length children)
  | _ -> Alcotest.fail "expected Clip"

let test_equal_rect () =
  let a =
    Scene.rect ~x:10.0 ~y:20.0 ~w:100.0 ~h:50.0 ~fill:(Paint.solid color_red) ()
  in
  let b =
    Scene.rect ~x:10.0 ~y:20.0 ~w:100.0 ~h:50.0 ~fill:(Paint.solid color_red) ()
  in
  let c =
    Scene.rect ~x:10.0 ~y:20.0 ~w:200.0 ~h:50.0 ~fill:(Paint.solid color_red) ()
  in
  Alcotest.(check bool) "same" true (Scene.equal a b);
  Alcotest.(check bool) "different" false (Scene.equal a c)

let () =
  Alcotest.run "Scene"
    [
      ( "scene",
        [
          Alcotest.test_case "rect defaults" `Quick test_rect_defaults;
          Alcotest.test_case "rect rounded" `Quick test_rect_rounded;
          Alcotest.test_case "circle" `Quick test_circle;
          Alcotest.test_case "ellipse" `Quick test_ellipse;
          Alcotest.test_case "line default stroke" `Quick
            test_line_default_stroke;
          Alcotest.test_case "path" `Quick test_path;
          Alcotest.test_case "polygon" `Quick test_polygon;
          Alcotest.test_case "polyline" `Quick test_polyline;
          Alcotest.test_case "text defaults" `Quick test_text_defaults;
          Alcotest.test_case "text custom" `Quick test_text_custom;
          Alcotest.test_case "group defaults" `Quick test_group_defaults;
          Alcotest.test_case "group custom" `Quick test_group_custom;
          Alcotest.test_case "clip" `Quick test_clip;
          Alcotest.test_case "equal rect" `Quick test_equal_rect;
        ] );
    ]
