open Nopal_charts
open Nopal_scene

let sample = [ (1.0, 10.0); (2.0, 20.0); (3.0, 15.0); (4.0, 25.0) ]

let test_scatter_scene_returns_nodes () =
  let nodes =
    Scatter.scene ~data:sample ~x:fst ~y:snd
      ~color:(fun _ -> Nopal_draw.Color.categorical.(0))
      ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_scatter_scene_empty_data () =
  let nodes =
    Scatter.scene ~data:[] ~x:fst ~y:snd
      ~color:(fun _ -> Nopal_draw.Color.categorical.(0))
      ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check int) "empty scene" 0 (List.length nodes)

let test_scatter_scene_matches_view () =
  let scene_nodes =
    Scatter.scene ~data:sample ~x:fst ~y:snd
      ~color:(fun _ -> Nopal_draw.Color.categorical.(0))
      ~width:400.0 ~height:300.0 ()
  in
  let view_el =
    Scatter.view ~data:sample ~x:fst ~y:snd
      ~color:(fun _ -> Nopal_draw.Color.categorical.(0))
      ~width:400.0 ~height:300.0 ()
  in
  match Chart_test_helpers.extract_draw view_el with
  | Some (view_scene, _, _, _, _) ->
      Alcotest.(check int)
        "same length" (List.length scene_nodes) (List.length view_scene);
      List.iter2
        (fun a b -> Alcotest.(check bool) "nodes equal" true (Scene.equal a b))
        scene_nodes view_scene
  | None -> Alcotest.fail "expected Draw element from view"

let () =
  Alcotest.run "Scatter.scene"
    [
      ( "scene",
        [
          Alcotest.test_case "returns_nodes" `Quick
            test_scatter_scene_returns_nodes;
          Alcotest.test_case "empty_data" `Quick test_scatter_scene_empty_data;
          Alcotest.test_case "matches_view" `Quick
            test_scatter_scene_matches_view;
        ] );
    ]
