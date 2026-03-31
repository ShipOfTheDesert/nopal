open Nopal_charts
open Nopal_scene

let sample = [ (1.0, -0.05); (2.0, -0.12); (3.0, -0.08); (4.0, -0.15) ]

let test_trading_drawdown_scene_returns_nodes () =
  let nodes =
    Trading.Drawdown.scene ~data:sample ~x:fst ~y:snd ~width:400.0 ~height:300.0
      ()
  in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_trading_drawdown_scene_empty_data () =
  let nodes =
    Trading.Drawdown.scene ~data:[] ~x:fst ~y:snd ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check int) "empty scene" 0 (List.length nodes)

let test_trading_drawdown_scene_matches_view () =
  let scene_nodes =
    Trading.Drawdown.scene ~data:sample ~x:fst ~y:snd ~width:400.0 ~height:300.0
      ()
  in
  let view_el =
    Trading.Drawdown.view ~data:sample ~x:fst ~y:snd ~width:400.0 ~height:300.0
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
  Alcotest.run "Trading.Drawdown.scene"
    [
      ( "scene",
        [
          Alcotest.test_case "returns_nodes" `Quick
            test_trading_drawdown_scene_returns_nodes;
          Alcotest.test_case "empty_data" `Quick
            test_trading_drawdown_scene_empty_data;
          Alcotest.test_case "matches_view" `Quick
            test_trading_drawdown_scene_matches_view;
        ] );
    ]
