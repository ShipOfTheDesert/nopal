open Nopal_charts
open Nopal_scene

let sample =
  [
    ("Apple", 30.0, Nopal_draw.Color.categorical.(0));
    ("Banana", 50.0, Nopal_draw.Color.categorical.(1));
    ("Cherry", 20.0, Nopal_draw.Color.categorical.(2));
  ]

let test_pie_scene_returns_nodes () =
  let nodes =
    Pie.scene ~data:sample
      ~value:(fun (_, v, _) -> v)
      ~label:(fun (l, _, _) -> l)
      ~color:(fun (_, _, c) -> c)
      ~width:400.0 ~height:400.0 ()
  in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_pie_scene_empty_data () =
  let nodes =
    Pie.scene ~data:[]
      ~value:(fun (_, v, _) -> v)
      ~label:(fun (l, _, _) -> l)
      ~color:(fun (_, _, c) -> c)
      ~width:400.0 ~height:400.0 ()
  in
  Alcotest.(check int) "empty scene" 0 (List.length nodes)

let test_pie_scene_matches_view () =
  let scene_nodes =
    Pie.scene ~data:sample
      ~value:(fun (_, v, _) -> v)
      ~label:(fun (l, _, _) -> l)
      ~color:(fun (_, _, c) -> c)
      ~width:400.0 ~height:400.0 ()
  in
  let view_el =
    Pie.view ~data:sample
      ~value:(fun (_, v, _) -> v)
      ~label:(fun (l, _, _) -> l)
      ~color:(fun (_, _, c) -> c)
      ~width:400.0 ~height:400.0 ()
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
  Alcotest.run "Pie.scene"
    [
      ( "scene",
        [
          Alcotest.test_case "returns_nodes" `Quick test_pie_scene_returns_nodes;
          Alcotest.test_case "empty_data" `Quick test_pie_scene_empty_data;
          Alcotest.test_case "matches_view" `Quick test_pie_scene_matches_view;
        ] );
    ]
