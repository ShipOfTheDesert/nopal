open Nopal_scene

let test_move_to () =
  match Path.move_to ~x:10.0 ~y:20.0 with
  | Path.Move_to { x; y } ->
      Alcotest.(check (float 0.001)) "x" 10.0 x;
      Alcotest.(check (float 0.001)) "y" 20.0 y
  | _ -> Alcotest.fail "expected Move_to"

let test_line_to () =
  match Path.line_to ~x:5.0 ~y:6.0 with
  | Path.Line_to { x; y } ->
      Alcotest.(check (float 0.001)) "x" 5.0 x;
      Alcotest.(check (float 0.001)) "y" 6.0 y
  | _ -> Alcotest.fail "expected Line_to"

let test_bezier_to () =
  match Path.bezier_to ~cp1x:1.0 ~cp1y:2.0 ~cp2x:3.0 ~cp2y:4.0 ~x:5.0 ~y:6.0 with
  | Path.Bezier_to { cp1x; cp1y; cp2x; cp2y; x; y } ->
      Alcotest.(check (float 0.001)) "cp1x" 1.0 cp1x;
      Alcotest.(check (float 0.001)) "cp1y" 2.0 cp1y;
      Alcotest.(check (float 0.001)) "cp2x" 3.0 cp2x;
      Alcotest.(check (float 0.001)) "cp2y" 4.0 cp2y;
      Alcotest.(check (float 0.001)) "x" 5.0 x;
      Alcotest.(check (float 0.001)) "y" 6.0 y
  | _ -> Alcotest.fail "expected Bezier_to"

let test_quad_to () =
  match Path.quad_to ~cpx:1.0 ~cpy:2.0 ~x:3.0 ~y:4.0 with
  | Path.Quad_to { cpx; cpy; x; y } ->
      Alcotest.(check (float 0.001)) "cpx" 1.0 cpx;
      Alcotest.(check (float 0.001)) "cpy" 2.0 cpy;
      Alcotest.(check (float 0.001)) "x" 3.0 x;
      Alcotest.(check (float 0.001)) "y" 4.0 y
  | _ -> Alcotest.fail "expected Quad_to"

let test_arc_to () =
  match
    Path.arc_to ~cx:50.0 ~cy:50.0 ~r:25.0 ~start_angle:0.0 ~end_angle:3.14159
  with
  | Path.Arc_to { cx; cy; r; start_angle; end_angle } ->
      Alcotest.(check (float 0.001)) "cx" 50.0 cx;
      Alcotest.(check (float 0.001)) "cy" 50.0 cy;
      Alcotest.(check (float 0.001)) "r" 25.0 r;
      Alcotest.(check (float 0.001)) "start_angle" 0.0 start_angle;
      Alcotest.(check (float 0.001)) "end_angle" 3.14159 end_angle
  | _ -> Alcotest.fail "expected Arc_to"

let test_close () =
  match Path.close with
  | Path.Close -> ()
  | _ -> Alcotest.fail "expected Close"

let test_equal_segment () =
  let a = Path.move_to ~x:1.0 ~y:2.0 in
  let b = Path.move_to ~x:1.0 ~y:2.0 in
  let c = Path.line_to ~x:1.0 ~y:2.0 in
  Alcotest.(check bool) "same" true (Path.equal_segment a b);
  Alcotest.(check bool) "diff variant" false (Path.equal_segment a c)

let () =
  Alcotest.run "Nopal_scene.Path"
    [
      ( "path",
        [
          Alcotest.test_case "move_to" `Quick test_move_to;
          Alcotest.test_case "line_to" `Quick test_line_to;
          Alcotest.test_case "bezier_to" `Quick test_bezier_to;
          Alcotest.test_case "quad_to" `Quick test_quad_to;
          Alcotest.test_case "arc_to" `Quick test_arc_to;
          Alcotest.test_case "close" `Quick test_close;
          Alcotest.test_case "equal_segment" `Quick test_equal_segment;
        ] );
    ]
