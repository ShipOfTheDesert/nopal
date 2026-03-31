open Nopal_charts
open Nopal_scene

type cell = { r : int; c : int; v : float }

let sample_data =
  [
    { r = 0; c = 0; v = 1.0 };
    { r = 0; c = 1; v = 2.0 };
    { r = 0; c = 2; v = 3.0 };
    { r = 1; c = 0; v = 4.0 };
    { r = 1; c = 1; v = 5.0 };
    { r = 1; c = 2; v = 6.0 };
  ]

let seq_scale =
  Color_scale.sequential
    ~low:(Nopal_draw.Color.rgb ~r:1.0 ~g:1.0 ~b:1.0)
    ~high:(Nopal_draw.Color.rgb ~r:1.0 ~g:0.0 ~b:0.0)

let test_heat_map_scene_returns_nodes () =
  let nodes =
    Heat_map.scene ~data:sample_data
      ~row:(fun d -> d.r)
      ~col:(fun d -> d.c)
      ~value:(fun d -> d.v)
      ~row_count:2 ~col_count:3 ~scale:seq_scale ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_heat_map_scene_empty_data () =
  let nodes =
    Heat_map.scene ~data:[]
      ~row:(fun d -> d.r)
      ~col:(fun d -> d.c)
      ~value:(fun d -> d.v)
      ~row_count:0 ~col_count:0 ~scale:seq_scale ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check int) "empty scene" 0 (List.length nodes)

let test_heat_map_scene_matches_view () =
  let scene_nodes =
    Heat_map.scene ~data:sample_data
      ~row:(fun d -> d.r)
      ~col:(fun d -> d.c)
      ~value:(fun d -> d.v)
      ~row_count:2 ~col_count:3 ~scale:seq_scale ~width:400.0 ~height:300.0 ()
  in
  let view_el =
    Heat_map.view ~data:sample_data
      ~row:(fun d -> d.r)
      ~col:(fun d -> d.c)
      ~value:(fun d -> d.v)
      ~row_count:2 ~col_count:3 ~scale:seq_scale ~width:400.0 ~height:300.0 ()
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
  Alcotest.run "Heat_map.scene"
    [
      ( "scene",
        [
          Alcotest.test_case "returns_nodes" `Quick
            test_heat_map_scene_returns_nodes;
          Alcotest.test_case "empty_data" `Quick test_heat_map_scene_empty_data;
          Alcotest.test_case "matches_view" `Quick
            test_heat_map_scene_matches_view;
        ] );
    ]
