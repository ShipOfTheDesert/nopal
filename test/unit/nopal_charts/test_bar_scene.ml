open Nopal_charts
open Nopal_scene

type datum = { label : string; value : float; color : Nopal_draw.Color.t }

let sample_data =
  [
    { label = "A"; value = 10.0; color = Nopal_draw.Color.categorical.(0) };
    { label = "B"; value = 20.0; color = Nopal_draw.Color.categorical.(1) };
    { label = "C"; value = 15.0; color = Nopal_draw.Color.categorical.(2) };
  ]

let test_bar_scene_returns_nodes () =
  let nodes =
    Bar.scene ~data:sample_data
      ~label:(fun d -> d.label)
      ~value:(fun d -> d.value)
      ~color:(fun d -> d.color)
      ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_bar_scene_empty_data () =
  let nodes =
    Bar.scene ~data:[]
      ~label:(fun d -> d.label)
      ~value:(fun d -> d.value)
      ~color:(fun d -> d.color)
      ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check int) "empty scene" 0 (List.length nodes)

let test_bar_scene_matches_view () =
  let scene_nodes =
    Bar.scene ~data:sample_data
      ~label:(fun d -> d.label)
      ~value:(fun d -> d.value)
      ~color:(fun d -> d.color)
      ~width:400.0 ~height:300.0 ()
  in
  let view_el =
    Bar.view ~data:sample_data
      ~label:(fun d -> d.label)
      ~value:(fun d -> d.value)
      ~color:(fun d -> d.color)
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
  Alcotest.run "Bar.scene"
    [
      ( "scene",
        [
          Alcotest.test_case "returns_nodes" `Quick test_bar_scene_returns_nodes;
          Alcotest.test_case "empty_data" `Quick test_bar_scene_empty_data;
          Alcotest.test_case "matches_view" `Quick test_bar_scene_matches_view;
        ] );
    ]
