open Nopal_charts
open Nopal_scene

let sample = [ 10.0; 20.0; 15.0; 25.0; 18.0 ]

let test_sparkline_scene_returns_nodes () =
  let nodes = Sparkline.scene ~data:sample ~width:100.0 ~height:30.0 () in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_sparkline_scene_empty_data () =
  let nodes = Sparkline.scene ~data:[] ~width:100.0 ~height:30.0 () in
  Alcotest.(check int) "empty scene" 0 (List.length nodes)

let test_sparkline_scene_matches_view () =
  let scene_nodes = Sparkline.scene ~data:sample ~width:100.0 ~height:30.0 () in
  let view_el = Sparkline.view ~data:sample ~width:100.0 ~height:30.0 () in
  match Chart_test_helpers.extract_draw view_el with
  | Some (view_scene, _, _, _, _) ->
      Alcotest.(check int)
        "same length" (List.length scene_nodes) (List.length view_scene);
      List.iter2
        (fun a b -> Alcotest.(check bool) "nodes equal" true (Scene.equal a b))
        scene_nodes view_scene
  | None -> Alcotest.fail "expected Draw element from view"

let () =
  Alcotest.run "Sparkline.scene"
    [
      ( "scene",
        [
          Alcotest.test_case "returns_nodes" `Quick
            test_sparkline_scene_returns_nodes;
          Alcotest.test_case "empty_data" `Quick test_sparkline_scene_empty_data;
          Alcotest.test_case "matches_view" `Quick
            test_sparkline_scene_matches_view;
        ] );
    ]
