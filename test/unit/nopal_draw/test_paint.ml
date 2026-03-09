open Nopal_draw

let color_red = Color.rgba ~r:1.0 ~g:0.0 ~b:0.0 ~a:1.0
let color_blue = Color.rgba ~r:0.0 ~g:0.0 ~b:1.0 ~a:1.0
let color_green = Color.rgba ~r:0.0 ~g:1.0 ~b:0.0 ~a:1.0

let test_solid_construction () =
  let p = Paint.solid color_red in
  Alcotest.(check bool)
    "is solid red" true
    (match p with
    | Paint.Solid c -> Color.equal c color_red
    | _ -> false)

let test_no_paint () =
  let p = Paint.no_paint in
  Alcotest.(check bool)
    "is No_paint" true
    (match p with
    | Paint.No_paint -> true
    | _ -> false)

let test_linear_gradient_valid () =
  let stops =
    [
      { Paint.offset = 0.0; color = color_red };
      { Paint.offset = 1.0; color = color_blue };
    ]
  in
  match Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:100.0 ~y1:0.0 ~stops with
  | Ok (Paint.Linear_gradient g) ->
      Alcotest.(check (float 0.001)) "x1" 100.0 g.x1;
      Alcotest.(check int) "stop count" 2 (List.length g.stops)
  | Ok _ -> Alcotest.fail "expected Linear_gradient"
  | Error e -> Alcotest.fail e

let test_linear_gradient_empty_stops () =
  match Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:1.0 ~y1:0.0 ~stops:[] with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "expected error for empty stops"

let test_linear_gradient_sorts_stops () =
  let stops =
    [
      { Paint.offset = 0.8; color = color_blue };
      { Paint.offset = 0.2; color = color_red };
      { Paint.offset = 0.5; color = color_green };
    ]
  in
  match Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:1.0 ~y1:0.0 ~stops with
  | Ok (Paint.Linear_gradient g) ->
      let offsets =
        List.map (fun (s : Paint.gradient_stop) -> s.offset) g.stops
      in
      Alcotest.(check (list (float 0.001))) "sorted" [ 0.2; 0.5; 0.8 ] offsets
  | Ok _ -> Alcotest.fail "expected Linear_gradient"
  | Error e -> Alcotest.fail e

let test_linear_gradient_offset_range () =
  let stops =
    [
      { Paint.offset = -0.5; color = color_red };
      { Paint.offset = 1.5; color = color_blue };
    ]
  in
  match Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:1.0 ~y1:0.0 ~stops with
  | Ok (Paint.Linear_gradient g) ->
      let offsets =
        List.map (fun (s : Paint.gradient_stop) -> s.offset) g.stops
      in
      Alcotest.(check (list (float 0.001))) "clamped" [ 0.0; 1.0 ] offsets
  | Ok _ -> Alcotest.fail "expected Linear_gradient"
  | Error e -> Alcotest.fail e

let test_radial_gradient_valid () =
  let stops =
    [
      { Paint.offset = 0.0; color = color_red };
      { Paint.offset = 1.0; color = color_blue };
    ]
  in
  match Paint.radial_gradient ~cx:50.0 ~cy:50.0 ~r:25.0 ~stops with
  | Ok (Paint.Radial_gradient g) ->
      Alcotest.(check (float 0.001)) "cx" 50.0 g.cx;
      Alcotest.(check (float 0.001)) "r" 25.0 g.r;
      Alcotest.(check int) "stop count" 2 (List.length g.stops)
  | Ok _ -> Alcotest.fail "expected Radial_gradient"
  | Error e -> Alcotest.fail e

let test_radial_gradient_empty_stops () =
  match Paint.radial_gradient ~cx:0.0 ~cy:0.0 ~r:1.0 ~stops:[] with
  | Error _ -> ()
  | Ok _ -> Alcotest.fail "expected error for empty stops"

let test_stroke_defaults () =
  let s = Paint.stroke (Paint.solid color_red) in
  Alcotest.(check (float 0.001)) "default width" 1.0 s.width;
  Alcotest.(check (list (float 0.001))) "no dash" [] s.dash;
  Alcotest.(check (float 0.001)) "dash_offset" 0.0 s.dash_offset;
  Alcotest.(check bool)
    "butt cap" true
    (match s.line_cap with
    | Paint.Butt -> true
    | _ -> false);
  Alcotest.(check bool)
    "miter join" true
    (match s.line_join with
    | Paint.Miter -> true
    | _ -> false)

let test_stroke_custom () =
  let s =
    Paint.stroke ~width:3.0 ~dash:[ 5.0; 3.0 ] ~dash_offset:1.0
      ~line_cap:Paint.Round_cap ~line_join:Paint.Bevel (Paint.solid color_blue)
  in
  Alcotest.(check (float 0.001)) "width" 3.0 s.width;
  Alcotest.(check (list (float 0.001))) "dash" [ 5.0; 3.0 ] s.dash;
  Alcotest.(check (float 0.001)) "dash_offset" 1.0 s.dash_offset;
  Alcotest.(check bool)
    "round cap" true
    (match s.line_cap with
    | Paint.Round_cap -> true
    | _ -> false);
  Alcotest.(check bool)
    "bevel join" true
    (match s.line_join with
    | Paint.Bevel -> true
    | _ -> false)

let test_equal_solid () =
  let a = Paint.solid color_red in
  let b = Paint.solid color_red in
  let c = Paint.solid color_blue in
  Alcotest.(check bool) "same" true (Paint.equal a b);
  Alcotest.(check bool) "different" false (Paint.equal a c)

let test_equal_gradient () =
  let stops =
    [
      { Paint.offset = 0.0; color = color_red };
      { Paint.offset = 1.0; color = color_blue };
    ]
  in
  let mk () =
    match Paint.linear_gradient ~x0:0.0 ~y0:0.0 ~x1:1.0 ~y1:0.0 ~stops with
    | Ok p -> p
    | Error e -> Alcotest.fail e
  in
  Alcotest.(check bool) "same gradient" true (Paint.equal (mk ()) (mk ()));
  Alcotest.(check bool)
    "different from solid" false
    (Paint.equal (mk ()) (Paint.solid color_red))

let () =
  Alcotest.run "Paint"
    [
      ( "paint",
        [
          Alcotest.test_case "solid construction" `Quick test_solid_construction;
          Alcotest.test_case "no paint" `Quick test_no_paint;
          Alcotest.test_case "linear gradient valid" `Quick
            test_linear_gradient_valid;
          Alcotest.test_case "linear gradient empty stops" `Quick
            test_linear_gradient_empty_stops;
          Alcotest.test_case "linear gradient sorts stops" `Quick
            test_linear_gradient_sorts_stops;
          Alcotest.test_case "linear gradient offset range" `Quick
            test_linear_gradient_offset_range;
          Alcotest.test_case "radial gradient valid" `Quick
            test_radial_gradient_valid;
          Alcotest.test_case "radial gradient empty stops" `Quick
            test_radial_gradient_empty_stops;
          Alcotest.test_case "stroke defaults" `Quick test_stroke_defaults;
          Alcotest.test_case "stroke custom" `Quick test_stroke_custom;
          Alcotest.test_case "equal solid" `Quick test_equal_solid;
          Alcotest.test_case "equal gradient" `Quick test_equal_gradient;
        ] );
    ]
