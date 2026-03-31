open Nopal_charts
open Nopal_scene

let sample =
  [
    (1.0, 100.0, 110.0, 95.0, 105.0);
    (2.0, 105.0, 115.0, 100.0, 110.0);
    (3.0, 110.0, 120.0, 105.0, 108.0);
  ]

let test_trading_candlestick_scene_returns_nodes () =
  let nodes =
    Trading.Candlestick.scene ~data:sample
      ~x:(fun (x, _, _, _, _) -> x)
      ~open_:(fun (_, o, _, _, _) -> o)
      ~high:(fun (_, _, h, _, _) -> h)
      ~low:(fun (_, _, _, l, _) -> l)
      ~close:(fun (_, _, _, _, c) -> c)
      ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check bool) "non-empty scene" true (List.length nodes > 0)

let test_trading_candlestick_scene_empty_data () =
  let nodes =
    Trading.Candlestick.scene ~data:[]
      ~x:(fun (x, _, _, _, _) -> x)
      ~open_:(fun (_, o, _, _, _) -> o)
      ~high:(fun (_, _, h, _, _) -> h)
      ~low:(fun (_, _, _, l, _) -> l)
      ~close:(fun (_, _, _, _, c) -> c)
      ~width:400.0 ~height:300.0 ()
  in
  Alcotest.(check int) "empty scene" 0 (List.length nodes)

let test_trading_candlestick_scene_matches_view () =
  let scene_nodes =
    Trading.Candlestick.scene ~data:sample
      ~x:(fun (x, _, _, _, _) -> x)
      ~open_:(fun (_, o, _, _, _) -> o)
      ~high:(fun (_, _, h, _, _) -> h)
      ~low:(fun (_, _, _, l, _) -> l)
      ~close:(fun (_, _, _, _, c) -> c)
      ~width:400.0 ~height:300.0 ()
  in
  let view_el =
    Trading.Candlestick.view ~data:sample
      ~x:(fun (x, _, _, _, _) -> x)
      ~open_:(fun (_, o, _, _, _) -> o)
      ~high:(fun (_, _, h, _, _) -> h)
      ~low:(fun (_, _, _, l, _) -> l)
      ~close:(fun (_, _, _, _, c) -> c)
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
  Alcotest.run "Trading.Candlestick.scene"
    [
      ( "scene",
        [
          Alcotest.test_case "returns_nodes" `Quick
            test_trading_candlestick_scene_returns_nodes;
          Alcotest.test_case "empty_data" `Quick
            test_trading_candlestick_scene_empty_data;
          Alcotest.test_case "matches_view" `Quick
            test_trading_candlestick_scene_matches_view;
        ] );
    ]
