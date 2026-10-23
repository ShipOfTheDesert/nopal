open Nopal_draw

(* nopal_draw re-exports the nopal_scene path constructors and shadows only
   arc_to, so the arc direction cases below are the only constructor tests
   here; the rest cover the higher-level algorithms. *)

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
  | Line_to _
  | Bezier_to _
  | Quad_to _
  | Arc_to _
  | Close ->
      Alcotest.fail "first segment should be Move_to");
  List.iter
    (fun seg ->
      match seg with
      | Path.Move_to _
      | Path.Bezier_to _ ->
          ()
      | Line_to _
      | Quad_to _
      | Arc_to _
      | Close ->
          Alcotest.fail "remaining segments should be Bezier_to")
    (List.tl segs)

let test_straight_line () =
  let segs = Path.straight_line [ (0.0, 0.0); (10.0, 10.0); (20.0, 0.0) ] in
  Alcotest.(check int) "length" 3 (List.length segs);
  (match List.hd segs with
  | Path.Move_to _ -> ()
  | Line_to _
  | Bezier_to _
  | Quad_to _
  | Arc_to _
  | Close ->
      Alcotest.fail "first should be Move_to");
  List.iter
    (fun seg ->
      match seg with
      | Path.Line_to _ -> ()
      | Move_to _
      | Bezier_to _
      | Quad_to _
      | Arc_to _
      | Close ->
          Alcotest.fail "rest should be Line_to")
    (List.tl segs)

let test_closed_area () =
  let segs = Path.closed_area [ (0.0, 0.0); (10.0, 10.0); (20.0, 0.0) ] in
  (* Move_to + 2 Line_to + Close *)
  Alcotest.(check int) "length" 4 (List.length segs);
  (match List.hd segs with
  | Path.Move_to _ -> ()
  | Line_to _
  | Bezier_to _
  | Quad_to _
  | Arc_to _
  | Close ->
      Alcotest.fail "first should be Move_to");
  match List.rev segs |> List.hd with
  | Path.Close -> ()
  | Move_to _
  | Line_to _
  | Bezier_to _
  | Quad_to _
  | Arc_to _ ->
      Alcotest.fail "last should be Close"

let test_arc_segment () =
  let segs =
    Path.arc_segment ~cx:50.0 ~cy:50.0 ~r:25.0 ~start_angle:0.0
      ~end_angle:1.5708 ()
  in
  (* Should have Move_to + Arc_to *)
  Alcotest.(check int) "length" 2 (List.length segs);
  (match List.hd segs with
  | Path.Move_to _ -> ()
  | Line_to _
  | Bezier_to _
  | Quad_to _
  | Arc_to _
  | Close ->
      Alcotest.fail "first should be Move_to");
  match List.nth segs 1 with
  | Path.Arc_to _ -> ()
  | Move_to _
  | Line_to _
  | Bezier_to _
  | Quad_to _
  | Close ->
      Alcotest.fail "second should be Arc_to"

let test_donut_arc () =
  let segs =
    Path.donut_arc ~cx:50.0 ~cy:50.0 ~inner_r:10.0 ~outer_r:25.0
      ~start_angle:0.0 ~end_angle:1.5708 ()
  in
  (* Should have: Move_to + Arc_to (outer) + Line_to + Arc_to (inner) + Close *)
  Alcotest.(check bool) "has segments" true (List.length segs >= 5);
  (match List.hd segs with
  | Path.Move_to _ -> ()
  | Line_to _
  | Bezier_to _
  | Quad_to _
  | Arc_to _
  | Close ->
      Alcotest.fail "first should be Move_to");
  match List.rev segs |> List.hd with
  | Path.Close -> ()
  | Move_to _
  | Line_to _
  | Bezier_to _
  | Quad_to _
  | Arc_to _ ->
      Alcotest.fail "last should be Close"

let direction = Alcotest.testable Path.pp_direction Path.equal_direction

let arc_directions segs =
  List.filter_map
    (fun (seg : Path.segment) ->
      match seg with
      | Arc_to { direction; _ } -> Some direction
      | Move_to _
      | Line_to _
      | Bezier_to _
      | Quad_to _
      | Close ->
          None)
    segs

let test_default_direction_is_clockwise () =
  let check = Alcotest.(check (list direction)) in
  check "arc_to" [ Clockwise ]
    (arc_directions
       [
         Path.arc_to ~cx:50.0 ~cy:50.0 ~r:25.0 ~start_angle:0.0 ~end_angle:1.0
           ();
       ]);
  check "arc_segment" [ Clockwise ]
    (arc_directions
       (Path.arc_segment ~cx:50.0 ~cy:50.0 ~r:25.0 ~start_angle:0.0
          ~end_angle:1.0 ()));
  match
    arc_directions
      (Path.donut_arc ~cx:50.0 ~cy:50.0 ~inner_r:10.0 ~outer_r:25.0
         ~start_angle:0.0 ~end_angle:1.0 ())
  with
  | [ outer; inner ] ->
      Alcotest.check direction "donut_arc outer" Clockwise outer;
      Alcotest.check direction "donut_arc inner" Anticlockwise inner
  | other ->
      Alcotest.failf "donut_arc: expected two arcs, got %d" (List.length other)

let test_explicit_anticlockwise_changes_segment () =
  let default =
    Path.arc_to ~cx:50.0 ~cy:40.0 ~r:25.0 ~start_angle:0.5 ~end_angle:2.0 ()
  in
  let explicit =
    Path.arc_to ~direction:Anticlockwise ~cx:50.0 ~cy:40.0 ~r:25.0
      ~start_angle:0.5 ~end_angle:2.0 ()
  in
  let expected =
    Path.Arc_to
      {
        cx = 50.0;
        cy = 40.0;
        r = 25.0;
        start_angle = 0.5;
        end_angle = 2.0;
        direction = Anticlockwise;
      }
  in
  Alcotest.(check bool)
    "differs from default" false
    (Path.equal_segment default explicit);
  Alcotest.(check bool)
    "only the direction changed" true
    (Path.equal_segment expected explicit);
  let default_segs =
    Path.arc_segment ~cx:50.0 ~cy:40.0 ~r:25.0 ~start_angle:0.5 ~end_angle:2.0
      ()
  in
  let explicit_segs =
    Path.arc_segment ~direction:Anticlockwise ~cx:50.0 ~cy:40.0 ~r:25.0
      ~start_angle:0.5 ~end_angle:2.0 ()
  in
  match (default_segs, explicit_segs) with
  | [ default_move; default_arc ], [ explicit_move; explicit_arc ] ->
      Alcotest.(check bool)
        "arc_segment move unchanged" true
        (Path.equal_segment default_move explicit_move);
      Alcotest.(check bool)
        "arc_segment arc differs" false
        (Path.equal_segment default_arc explicit_arc);
      Alcotest.(check bool)
        "arc_segment arc differs only in direction" true
        (Path.equal_segment expected explicit_arc)
  | _ -> Alcotest.fail "arc_segment: expected Move_to + Arc_to"

let test_donut_inner_edge_reverses () =
  List.iter
    (fun (outer_direction : Path.direction) ->
      let opposite : Path.direction =
        match outer_direction with
        | Clockwise -> Anticlockwise
        | Anticlockwise -> Clockwise
      in
      let segs =
        Path.donut_arc ~direction:outer_direction ~cx:50.0 ~cy:50.0
          ~inner_r:10.0 ~outer_r:25.0 ~start_angle:0.3 ~end_angle:1.2 ()
      in
      match segs with
      | [ Move_to _; Arc_to outer; Line_to _; Arc_to inner; Close ] ->
          Alcotest.check direction "outer direction" outer_direction
            outer.direction;
          Alcotest.check direction "inner direction" opposite inner.direction;
          Alcotest.(check (float 1e-12)) "outer start" 0.3 outer.start_angle;
          Alcotest.(check (float 1e-12)) "outer end" 1.2 outer.end_angle;
          Alcotest.(check (float 1e-12)) "inner start" 1.2 inner.start_angle;
          Alcotest.(check (float 1e-12)) "inner end" 0.3 inner.end_angle
      | _ -> Alcotest.fail "expected Move_to, Arc_to, Line_to, Arc_to, Close")
    [ Clockwise; Anticlockwise ]

let test_equal_segment_compares_direction () =
  let arc direction =
    Path.arc_to ~direction ~cx:50.0 ~cy:50.0 ~r:25.0 ~start_angle:0.0
      ~end_angle:1.0 ()
  in
  Alcotest.(check bool)
    "clockwise equals itself" true
    (Path.equal_segment (arc Clockwise) (arc Clockwise));
  Alcotest.(check bool)
    "anticlockwise equals itself" true
    (Path.equal_segment (arc Anticlockwise) (arc Anticlockwise));
  Alcotest.(check bool)
    "clockwise differs from anticlockwise" false
    (Path.equal_segment (arc Clockwise) (arc Anticlockwise));
  Alcotest.(check bool)
    "anticlockwise differs from clockwise" false
    (Path.equal_segment (arc Anticlockwise) (arc Clockwise))

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
          Alcotest.test_case "default_direction_is_clockwise" `Quick
            test_default_direction_is_clockwise;
          Alcotest.test_case "explicit_anticlockwise_changes_segment" `Quick
            test_explicit_anticlockwise_changes_segment;
          Alcotest.test_case "donut_inner_edge_reverses" `Quick
            test_donut_inner_edge_reverses;
          Alcotest.test_case "equal_segment_compares_direction" `Quick
            test_equal_segment_compares_direction;
        ] );
    ]
