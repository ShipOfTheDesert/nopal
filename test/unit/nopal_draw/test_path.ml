open Nopal_draw

let test_move_to () =
  let s = Path.move_to ~x:10.0 ~y:20.0 in
  match s with
  | Path.Move_to { x; y } ->
      Alcotest.(check (float 0.001)) "x" 10.0 x;
      Alcotest.(check (float 0.001)) "y" 20.0 y
  | _ -> Alcotest.fail "expected Move_to"

let test_line_to () =
  let s = Path.line_to ~x:30.0 ~y:40.0 in
  match s with
  | Path.Line_to { x; y } ->
      Alcotest.(check (float 0.001)) "x" 30.0 x;
      Alcotest.(check (float 0.001)) "y" 40.0 y
  | _ -> Alcotest.fail "expected Line_to"

let test_bezier_to () =
  let s =
    Path.bezier_to ~cp1x:1.0 ~cp1y:2.0 ~cp2x:3.0 ~cp2y:4.0 ~x:5.0 ~y:6.0
  in
  match s with
  | Path.Bezier_to { cp1x; cp1y; cp2x; cp2y; x; y } ->
      Alcotest.(check (float 0.001)) "cp1x" 1.0 cp1x;
      Alcotest.(check (float 0.001)) "cp1y" 2.0 cp1y;
      Alcotest.(check (float 0.001)) "cp2x" 3.0 cp2x;
      Alcotest.(check (float 0.001)) "cp2y" 4.0 cp2y;
      Alcotest.(check (float 0.001)) "x" 5.0 x;
      Alcotest.(check (float 0.001)) "y" 6.0 y
  | _ -> Alcotest.fail "expected Bezier_to"

let test_quad_to () =
  let s = Path.quad_to ~cpx:1.0 ~cpy:2.0 ~x:3.0 ~y:4.0 in
  match s with
  | Path.Quad_to { cpx; cpy; x; y } ->
      Alcotest.(check (float 0.001)) "cpx" 1.0 cpx;
      Alcotest.(check (float 0.001)) "cpy" 2.0 cpy;
      Alcotest.(check (float 0.001)) "x" 3.0 x;
      Alcotest.(check (float 0.001)) "y" 4.0 y
  | _ -> Alcotest.fail "expected Quad_to"

let test_arc_to () =
  let s =
    Path.arc_to ~cx:50.0 ~cy:50.0 ~r:25.0 ~start_angle:0.0 ~end_angle:3.14159
  in
  match s with
  | Path.Arc_to { cx; cy; r; start_angle; end_angle } ->
      Alcotest.(check (float 0.001)) "cx" 50.0 cx;
      Alcotest.(check (float 0.001)) "cy" 50.0 cy;
      Alcotest.(check (float 0.001)) "r" 25.0 r;
      Alcotest.(check (float 0.001)) "start_angle" 0.0 start_angle;
      Alcotest.(check (float 0.001)) "end_angle" 3.14159 end_angle
  | _ -> Alcotest.fail "expected Arc_to"

let test_close () =
  let s = Path.close in
  match s with
  | Path.Close -> ()
  | _ -> Alcotest.fail "expected Close"

let test_smooth_curve_empty () =
  let segs = Path.smooth_curve [] in
  Alcotest.(check int) "empty" 0 (List.length segs)

let test_smooth_curve_single () =
  let segs = Path.smooth_curve [ (10.0, 20.0) ] in
  Alcotest.(check int) "length" 1 (List.length segs);
  match segs with
  | [ Path.Move_to { x; y } ] ->
      Alcotest.(check (float 0.001)) "x" 10.0 x;
      Alcotest.(check (float 0.001)) "y" 20.0 y
  | _ -> Alcotest.fail "expected single Move_to"

let test_smooth_curve_two () =
  let segs = Path.smooth_curve [ (0.0, 0.0); (10.0, 10.0) ] in
  Alcotest.(check int) "length" 2 (List.length segs);
  match segs with
  | [ Path.Move_to _; Path.Line_to { x; y } ] ->
      Alcotest.(check (float 0.001)) "x" 10.0 x;
      Alcotest.(check (float 0.001)) "y" 10.0 y
  | _ -> Alcotest.fail "expected Move_to + Line_to"

let test_smooth_curve_multiple () =
  let segs =
    Path.smooth_curve [ (0.0, 0.0); (10.0, 20.0); (20.0, 10.0); (30.0, 30.0) ]
  in
  (* Should be Move_to + 3 Bezier_to segments for Catmull-Rom *)
  Alcotest.(check int) "length" 4 (List.length segs);
  (match List.hd segs with
  | Path.Move_to _ -> ()
  | _ -> Alcotest.fail "first segment should be Move_to");
  List.iter
    (fun seg ->
      match seg with
      | Path.Move_to _
      | Path.Bezier_to _ ->
          ()
      | _ -> Alcotest.fail "remaining segments should be Bezier_to")
    (List.tl segs)

let test_straight_line () =
  let segs = Path.straight_line [ (0.0, 0.0); (10.0, 10.0); (20.0, 0.0) ] in
  Alcotest.(check int) "length" 3 (List.length segs);
  (match List.hd segs with
  | Path.Move_to _ -> ()
  | _ -> Alcotest.fail "first should be Move_to");
  List.iter
    (fun seg ->
      match seg with
      | Path.Line_to _ -> ()
      | _ -> Alcotest.fail "rest should be Line_to")
    (List.tl segs)

let test_closed_area () =
  let segs = Path.closed_area [ (0.0, 0.0); (10.0, 10.0); (20.0, 0.0) ] in
  (* Move_to + 2 Line_to + Close *)
  Alcotest.(check int) "length" 4 (List.length segs);
  (match List.hd segs with
  | Path.Move_to _ -> ()
  | _ -> Alcotest.fail "first should be Move_to");
  match List.rev segs |> List.hd with
  | Path.Close -> ()
  | _ -> Alcotest.fail "last should be Close"

let test_arc_segment () =
  let segs =
    Path.arc_segment ~cx:50.0 ~cy:50.0 ~r:25.0 ~start_angle:0.0
      ~end_angle:1.5708
  in
  (* Should have Move_to + Arc_to *)
  Alcotest.(check int) "length" 2 (List.length segs);
  (match List.hd segs with
  | Path.Move_to _ -> ()
  | _ -> Alcotest.fail "first should be Move_to");
  match List.nth segs 1 with
  | Path.Arc_to _ -> ()
  | _ -> Alcotest.fail "second should be Arc_to"

let test_donut_arc () =
  let segs =
    Path.donut_arc ~cx:50.0 ~cy:50.0 ~inner_r:10.0 ~outer_r:25.0
      ~start_angle:0.0 ~end_angle:1.5708
  in
  (* Should have: Move_to + Arc_to (outer) + Line_to + Arc_to (inner) + Close *)
  Alcotest.(check bool) "has segments" true (List.length segs >= 5);
  (match List.hd segs with
  | Path.Move_to _ -> ()
  | _ -> Alcotest.fail "first should be Move_to");
  match List.rev segs |> List.hd with
  | Path.Close -> ()
  | _ -> Alcotest.fail "last should be Close"

let () =
  Alcotest.run "Path"
    [
      ( "path",
        [
          Alcotest.test_case "move_to" `Quick test_move_to;
          Alcotest.test_case "line_to" `Quick test_line_to;
          Alcotest.test_case "bezier_to" `Quick test_bezier_to;
          Alcotest.test_case "quad_to" `Quick test_quad_to;
          Alcotest.test_case "arc_to" `Quick test_arc_to;
          Alcotest.test_case "close" `Quick test_close;
          Alcotest.test_case "smooth_curve empty" `Quick test_smooth_curve_empty;
          Alcotest.test_case "smooth_curve single" `Quick
            test_smooth_curve_single;
          Alcotest.test_case "smooth_curve two" `Quick test_smooth_curve_two;
          Alcotest.test_case "smooth_curve multiple" `Quick
            test_smooth_curve_multiple;
          Alcotest.test_case "straight_line" `Quick test_straight_line;
          Alcotest.test_case "closed_area" `Quick test_closed_area;
          Alcotest.test_case "arc_segment" `Quick test_arc_segment;
          Alcotest.test_case "donut_arc" `Quick test_donut_arc;
        ] );
    ]
