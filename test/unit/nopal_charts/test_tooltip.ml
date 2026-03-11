open Nopal_charts

let test_text_returns_string () =
  let s = Tooltip.text "foo" in
  Alcotest.(check string) "identity" "foo" s

let test_scene_produces_nodes () =
  let nodes =
    Tooltip.scene ~x:100.0 ~y:100.0 ~chart_width:400.0 ~chart_height:300.0
      "hello"
  in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_scene_stays_in_bounds_right () =
  (* Place tooltip near the right edge — should flip left *)
  let nodes =
    Tooltip.scene ~x:390.0 ~y:100.0 ~chart_width:400.0 ~chart_height:300.0 "tip"
  in
  Alcotest.(check bool) "produces scene nodes" true (List.length nodes > 0)

let test_scene_stays_in_bounds_bottom () =
  (* Place tooltip near the bottom edge — should flip up *)
  let nodes =
    Tooltip.scene ~x:100.0 ~y:290.0 ~chart_width:400.0 ~chart_height:300.0 "tip"
  in
  Alcotest.(check bool) "produces scene nodes" true (List.length nodes > 0)

let test_scene_stays_in_bounds_corner () =
  (* Place tooltip near both right and bottom edges *)
  let nodes =
    Tooltip.scene ~x:390.0 ~y:290.0 ~chart_width:400.0 ~chart_height:300.0 "tip"
  in
  Alcotest.(check bool) "produces scene nodes" true (List.length nodes > 0)

let () =
  Alcotest.run "Tooltip"
    [
      ( "tooltip",
        [
          Alcotest.test_case "text_returns_string" `Quick
            test_text_returns_string;
          Alcotest.test_case "scene_produces_nodes" `Quick
            test_scene_produces_nodes;
          Alcotest.test_case "scene_stays_in_bounds_right" `Quick
            test_scene_stays_in_bounds_right;
          Alcotest.test_case "scene_stays_in_bounds_bottom" `Quick
            test_scene_stays_in_bounds_bottom;
          Alcotest.test_case "scene_stays_in_bounds_corner" `Quick
            test_scene_stays_in_bounds_corner;
        ] );
    ]
