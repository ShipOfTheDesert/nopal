open Nopal_charts
open Nopal_scene

let sample_data = [ (0.0, 10.0); (1.0, 20.0); (2.0, 15.0) ]

let mk_series ?(smooth = false) ?(area_fill = false) ?(show_points = false)
    ~label ~color data =
  Line.series ~smooth ~area_fill ~show_points ~label ~color
    ~y:(fun (_, v) -> v)
    data

let series_a =
  mk_series ~label:"A" ~color:Nopal_draw.Color.categorical.(0) sample_data

let series_b =
  mk_series ~label:"B"
    ~color:Nopal_draw.Color.categorical.(1)
    [ (0.0, 5.0); (1.0, 25.0); (2.0, 10.0) ]

let test_line_scene_returns_nodes () =
  let nodes =
    Line.scene ~series:[ series_a ] ~x:fst ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_line_scene_empty_data () =
  let empty_s = mk_series ~label:"empty" ~color:Color.categorical.(0) [] in
  let nodes =
    Line.scene ~series:[ empty_s ] ~x:fst ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check int) "empty scene" 0 (List.length nodes)

let test_line_scene_matches_view () =
  let scene_nodes =
    Line.scene ~series:[ series_a; series_b ] ~x:fst ~width:400.0 ~height:300.0
      ()
  in
  let view_el =
    Line.view ~series:[ series_a; series_b ] ~x:fst ~width:400.0 ~height:300.0
      ()
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
  Alcotest.run "Line.scene"
    [
      ( "scene",
        [
          Alcotest.test_case "returns_nodes" `Quick
            test_line_scene_returns_nodes;
          Alcotest.test_case "empty_data" `Quick test_line_scene_empty_data;
          Alcotest.test_case "matches_view" `Quick test_line_scene_matches_view;
        ] );
    ]
