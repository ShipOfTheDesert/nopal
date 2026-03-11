open Nopal_charts

let hit_testable =
  Alcotest.testable
    (fun fmt h ->
      Format.fprintf fmt "{ index = %d; series = %d }" h.Hit_map.index
        h.Hit_map.series)
    Hit_map.equal_hit

let hit_option = Alcotest.option hit_testable

let test_empty_hit_test () =
  let m = Hit_map.empty in
  Alcotest.(check hit_option)
    "empty map returns None" None
    (Hit_map.hit_test m ~x:5.0 ~y:5.0)

let test_rect_hit_inside () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Rect_region
            {
              x = 0.0;
              y = 0.0;
              w = 10.0;
              h = 10.0;
              hit = { index = 0; series = 0 };
            })
  in
  Alcotest.(check hit_option)
    "inside rect hits"
    (Some { Hit_map.index = 0; series = 0 })
    (Hit_map.hit_test m ~x:5.0 ~y:5.0)

let test_rect_hit_outside () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Rect_region
            {
              x = 0.0;
              y = 0.0;
              w = 10.0;
              h = 10.0;
              hit = { index = 0; series = 0 };
            })
  in
  Alcotest.(check hit_option)
    "outside rect misses" None
    (Hit_map.hit_test m ~x:15.0 ~y:15.0)

let test_rect_hit_edge () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Rect_region
            {
              x = 0.0;
              y = 0.0;
              w = 10.0;
              h = 10.0;
              hit = { index = 0; series = 0 };
            })
  in
  Alcotest.(check hit_option)
    "edge of rect hits"
    (Some { Hit_map.index = 0; series = 0 })
    (Hit_map.hit_test m ~x:0.0 ~y:0.0)

let test_circle_hit_inside () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Circle_region
            { cx = 10.0; cy = 10.0; r = 5.0; hit = { index = 1; series = 0 } })
  in
  Alcotest.(check hit_option)
    "inside circle hits"
    (Some { Hit_map.index = 1; series = 0 })
    (Hit_map.hit_test m ~x:10.0 ~y:10.0)

let test_circle_hit_outside () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Circle_region
            { cx = 10.0; cy = 10.0; r = 5.0; hit = { index = 1; series = 0 } })
  in
  Alcotest.(check hit_option)
    "outside circle misses" None
    (Hit_map.hit_test m ~x:20.0 ~y:20.0)

let test_circle_hit_edge () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Circle_region
            { cx = 10.0; cy = 10.0; r = 5.0; hit = { index = 1; series = 0 } })
  in
  Alcotest.(check hit_option)
    "edge of circle hits"
    (Some { Hit_map.index = 1; series = 0 })
    (Hit_map.hit_test m ~x:15.0 ~y:10.0)

let test_wedge_hit_inside () =
  (* Wedge centered at origin, from 0 to pi/2, outer_r=10, inner_r=0 *)
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Wedge_region
            {
              cx = 0.0;
              cy = 0.0;
              inner_r = 0.0;
              outer_r = 10.0;
              start_angle = 0.0;
              end_angle = Float.pi /. 2.0;
              hit = { index = 2; series = 0 };
            })
  in
  (* Point at angle ~pi/4, distance ~7.07 *)
  Alcotest.(check hit_option)
    "inside wedge hits"
    (Some { Hit_map.index = 2; series = 0 })
    (Hit_map.hit_test m ~x:5.0 ~y:5.0)

let test_wedge_hit_outside_radius () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Wedge_region
            {
              cx = 0.0;
              cy = 0.0;
              inner_r = 0.0;
              outer_r = 10.0;
              start_angle = 0.0;
              end_angle = Float.pi /. 2.0;
              hit = { index = 2; series = 0 };
            })
  in
  (* Point at angle ~pi/4 but distance ~14.14 > 10 *)
  Alcotest.(check hit_option)
    "outside radius misses" None
    (Hit_map.hit_test m ~x:10.0 ~y:10.0)

let test_wedge_hit_inside_inner_radius () =
  (* Donut wedge: inner_r=5, outer_r=10 *)
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Wedge_region
            {
              cx = 0.0;
              cy = 0.0;
              inner_r = 5.0;
              outer_r = 10.0;
              start_angle = 0.0;
              end_angle = Float.pi /. 2.0;
              hit = { index = 2; series = 0 };
            })
  in
  (* Point at angle ~pi/4, distance ~2.83 < 5 *)
  Alcotest.(check hit_option)
    "inside inner radius misses" None
    (Hit_map.hit_test m ~x:2.0 ~y:2.0)

let test_wedge_hit_outside_angle () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Wedge_region
            {
              cx = 0.0;
              cy = 0.0;
              inner_r = 0.0;
              outer_r = 10.0;
              start_angle = 0.0;
              end_angle = Float.pi /. 2.0;
              hit = { index = 2; series = 0 };
            })
  in
  (* Point at angle ~3pi/4 (in Q2 of standard math), distance ~7.07 *)
  Alcotest.(check hit_option)
    "outside angle range misses" None
    (Hit_map.hit_test m ~x:(-5.0) ~y:5.0)

let test_topmost_priority () =
  (* Two overlapping rects; last-added should win *)
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Rect_region
            {
              x = 0.0;
              y = 0.0;
              w = 20.0;
              h = 20.0;
              hit = { index = 0; series = 0 };
            })
    |> Hit_map.add
         (Hit_map.Rect_region
            {
              x = 5.0;
              y = 5.0;
              w = 10.0;
              h = 10.0;
              hit = { index = 1; series = 0 };
            })
  in
  Alcotest.(check hit_option)
    "topmost (last-added) wins"
    (Some { Hit_map.index = 1; series = 0 })
    (Hit_map.hit_test m ~x:7.0 ~y:7.0)

let test_multiple_rects_non_overlapping () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Rect_region
            {
              x = 0.0;
              y = 0.0;
              w = 10.0;
              h = 10.0;
              hit = { index = 0; series = 0 };
            })
    |> Hit_map.add
         (Hit_map.Rect_region
            {
              x = 20.0;
              y = 20.0;
              w = 10.0;
              h = 10.0;
              hit = { index = 1; series = 0 };
            })
  in
  Alcotest.(check hit_option)
    "first rect"
    (Some { Hit_map.index = 0; series = 0 })
    (Hit_map.hit_test m ~x:5.0 ~y:5.0);
  Alcotest.(check hit_option)
    "second rect"
    (Some { Hit_map.index = 1; series = 0 })
    (Hit_map.hit_test m ~x:25.0 ~y:25.0);
  Alcotest.(check hit_option)
    "gap between rects" None
    (Hit_map.hit_test m ~x:15.0 ~y:15.0)

let test_band_hit_inside () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Band_region
            { x = 10.0; w = 20.0; hit = { index = 3; series = 0 } })
  in
  (* Band ignores Y — any Y value within X range should hit *)
  Alcotest.(check hit_option)
    "inside band hits"
    (Some { Hit_map.index = 3; series = 0 })
    (Hit_map.hit_test m ~x:15.0 ~y:999.0)

let test_band_hit_outside () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Band_region
            { x = 10.0; w = 20.0; hit = { index = 3; series = 0 } })
  in
  Alcotest.(check hit_option)
    "outside band misses" None
    (Hit_map.hit_test m ~x:5.0 ~y:15.0)

let test_band_hit_edge () =
  let m =
    Hit_map.empty
    |> Hit_map.add
         (Hit_map.Band_region
            { x = 10.0; w = 20.0; hit = { index = 3; series = 0 } })
  in
  Alcotest.(check hit_option)
    "edge of band hits"
    (Some { Hit_map.index = 3; series = 0 })
    (Hit_map.hit_test m ~x:10.0 ~y:0.0);
  Alcotest.(check hit_option)
    "right edge of band hits"
    (Some { Hit_map.index = 3; series = 0 })
    (Hit_map.hit_test m ~x:30.0 ~y:0.0)

let test_equal_hit () =
  let a = { Hit_map.index = 0; series = 1 } in
  let b = { Hit_map.index = 0; series = 1 } in
  let c = { Hit_map.index = 1; series = 0 } in
  Alcotest.(check bool) "same hit equal" true (Hit_map.equal_hit a b);
  Alcotest.(check bool) "different hit not equal" false (Hit_map.equal_hit a c)

let () =
  Alcotest.run "Hit_map"
    [
      ( "hit_map",
        [
          Alcotest.test_case "empty hit test" `Quick test_empty_hit_test;
          Alcotest.test_case "rect hit inside" `Quick test_rect_hit_inside;
          Alcotest.test_case "rect hit outside" `Quick test_rect_hit_outside;
          Alcotest.test_case "rect hit edge" `Quick test_rect_hit_edge;
          Alcotest.test_case "circle hit inside" `Quick test_circle_hit_inside;
          Alcotest.test_case "circle hit outside" `Quick test_circle_hit_outside;
          Alcotest.test_case "circle hit edge" `Quick test_circle_hit_edge;
          Alcotest.test_case "wedge hit inside" `Quick test_wedge_hit_inside;
          Alcotest.test_case "wedge hit outside radius" `Quick
            test_wedge_hit_outside_radius;
          Alcotest.test_case "wedge hit inside inner radius" `Quick
            test_wedge_hit_inside_inner_radius;
          Alcotest.test_case "wedge hit outside angle" `Quick
            test_wedge_hit_outside_angle;
          Alcotest.test_case "band hit inside" `Quick test_band_hit_inside;
          Alcotest.test_case "band hit outside" `Quick test_band_hit_outside;
          Alcotest.test_case "band hit edge" `Quick test_band_hit_edge;
          Alcotest.test_case "topmost priority" `Quick test_topmost_priority;
          Alcotest.test_case "multiple rects non-overlapping" `Quick
            test_multiple_rects_non_overlapping;
          Alcotest.test_case "equal hit" `Quick test_equal_hit;
        ] );
    ]
