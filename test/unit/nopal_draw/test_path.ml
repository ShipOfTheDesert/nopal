open Nopal_draw

(* Path constructors (move_to, line_to, etc.) are tested in
   test/unit/nopal_scene/test_scene_path.ml. nopal_draw re-exports them,
   so we only test the higher-level algorithms here. *)

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
