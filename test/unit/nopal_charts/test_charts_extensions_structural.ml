open Nopal_charts
open Nopal_draw
open Nopal_test.Test_renderer

type msg = Hovered of Hover.t | Left

(* --- Heat map helpers --- *)

type heat_cell = { r : int; c : int; v : float }

let heat_map_data =
  [
    { r = 0; c = 0; v = 1.0 };
    { r = 0; c = 1; v = 2.0 };
    { r = 0; c = 2; v = 3.0 };
    { r = 1; c = 0; v = 4.0 };
    { r = 1; c = 1; v = 5.0 };
    { r = 1; c = 2; v = 6.0 };
  ]

let heat_map_element ?hover () =
  Heat_map.view ~data:heat_map_data
    ~row:(fun d -> d.r)
    ~col:(fun d -> d.c)
    ~value:(fun d -> d.v)
    ~row_count:2 ~col_count:3 ~row_labels:[ "R0"; "R1" ]
    ~col_labels:[ "C0"; "C1"; "C2" ]
    ~scale:(Color_scale.sequential ~low:Color.white ~high:Color.black)
    ~width:400.0 ~height:300.0
    ~on_hover:(fun h -> Hovered h)
    ~on_leave:Left ?hover ()

(* --- Candlestick helpers --- *)

type ohlc = { t : float; o : float; h : float; l : float; c : float }

let candle_data =
  [
    { t = 0.0; o = 10.0; h = 15.0; l = 8.0; c = 13.0 };
    { t = 1.0; o = 13.0; h = 14.0; l = 9.0; c = 10.0 };
    { t = 2.0; o = 10.0; h = 12.0; l = 10.0; c = 12.0 };
  ]

let candlestick_element () =
  Trading.Candlestick.view ~data:candle_data
    ~x:(fun d -> d.t)
    ~open_:(fun d -> d.o)
    ~high:(fun d -> d.h)
    ~low:(fun d -> d.l)
    ~close:(fun d -> d.c)
    ~width:400.0 ~height:300.0
    ~on_hover:(fun h -> Hovered h)
    ~on_leave:Left ()

(* --- Drawdown helpers --- *)

let drawdown_data =
  [ (0.0, 0.0); (1.0, -0.05); (2.0, -0.10); (3.0, -0.03); (4.0, -0.15) ]

let drawdown_element () =
  Trading.Drawdown.view ~data:drawdown_data ~x:fst ~y:snd ~width:400.0
    ~height:300.0
    ~on_hover:(fun h -> Hovered h)
    ~on_leave:Left ()

(* --- Chart pane helpers --- *)

let chart_pane_element () =
  let p1 =
    Chart_pane.pane ~height_ratio:0.6 (fun _dw ~width:_ ~height:_ ->
        Nopal_element.Element.text "pane1")
  in
  let p2 =
    Chart_pane.pane ~height_ratio:0.4 (fun _dw ~width:_ ~height:_ ->
        Nopal_element.Element.text "pane2")
  in
  let dw = Domain_window.create ~x_min:0.0 ~x_max:10.0 in
  Chart_pane.view ~panes:[ p1; p2 ] ~domain_window:dw ~width:400.0 ~height:300.0
    ()

(* --- Tests --- *)

let test_heat_map_render_structure () =
  let el = heat_map_element () in
  let r = render el in
  let t = tree r in
  let canvas = find (By_tag "canvas") t in
  Alcotest.(check bool) "heat map canvas found" true (Option.is_some canvas);
  match canvas with
  | Some c -> (
      let scene_nodes = attr "scene-nodes" c in
      match scene_nodes with
      | Some n ->
          (* 6 cells + 2 row labels + 3 col labels = 11 scene nodes *)
          Alcotest.(check bool)
            "heat map has scene nodes" true
            (int_of_string n > 0)
      | None -> Alcotest.fail "missing scene-nodes attr on heat map canvas")
  | None -> Alcotest.fail "unreachable"

let test_candlestick_render_structure () =
  let el = candlestick_element () in
  let r = render el in
  let t = tree r in
  let canvas = find (By_tag "canvas") t in
  Alcotest.(check bool) "candlestick canvas found" true (Option.is_some canvas);
  match canvas with
  | Some c -> (
      let scene_nodes = attr "scene-nodes" c in
      match scene_nodes with
      | Some n ->
          (* 3 candles × 2 (wick + body) + axis nodes *)
          Alcotest.(check bool)
            "candlestick has scene nodes" true
            (int_of_string n >= 6)
      | None -> Alcotest.fail "missing scene-nodes attr on candlestick canvas")
  | None -> Alcotest.fail "unreachable"

let test_drawdown_render_structure () =
  let el = drawdown_element () in
  let r = render el in
  let t = tree r in
  let canvas = find (By_tag "canvas") t in
  Alcotest.(check bool) "drawdown canvas found" true (Option.is_some canvas);
  match canvas with
  | Some c -> (
      let scene_nodes = attr "scene-nodes" c in
      match scene_nodes with
      | Some n ->
          (* area path + axis nodes *)
          Alcotest.(check bool)
            "drawdown has scene nodes" true
            (int_of_string n > 0)
      | None -> Alcotest.fail "missing scene-nodes attr on drawdown canvas")
  | None -> Alcotest.fail "unreachable"

let test_chart_pane_structure () =
  let el = chart_pane_element () in
  let r = render el in
  let t = tree r in
  (* Chart pane produces a column with box children *)
  let column = find (By_tag "column") t in
  Alcotest.(check bool) "chart pane column found" true (Option.is_some column);
  (* Should contain text from both panes *)
  let tc = text_content t in
  Alcotest.(check bool) "pane1 text present" true (String.length tc > 0);
  let has_pane1 = Option.is_some (find (By_text "pane1") t) in
  let has_pane2 = Option.is_some (find (By_text "pane2") t) in
  Alcotest.(check bool) "pane1 found" true has_pane1;
  Alcotest.(check bool) "pane2 found" true has_pane2

let test_heat_map_hover_simulation () =
  let el = heat_map_element () in
  let r = render el in
  let result = pointer_move (By_tag "canvas") ~x:100.0 ~y:100.0 r in
  match result with
  | Ok () -> (
      let msgs = messages r in
      Alcotest.(check bool) "at least one message" true (List.length msgs >= 1);
      match msgs with
      | Hovered h :: _ ->
          (* index should be a valid cell index (0..5) *)
          Alcotest.(check bool)
            "hover index valid" true
            (h.index >= 0 && h.index < 6)
      | _ -> Alcotest.fail "expected Hovered message from heat map")
  | Error (Not_found _) -> Alcotest.fail "canvas not found for pointer_move"
  | Error (No_handler _) -> Alcotest.fail "no pointer_move handler on canvas"

let () =
  Alcotest.run "Charts_extensions_structural"
    [
      ( "structural",
        [
          Alcotest.test_case "heat_map_render_structure" `Quick
            test_heat_map_render_structure;
          Alcotest.test_case "candlestick_render_structure" `Quick
            test_candlestick_render_structure;
          Alcotest.test_case "drawdown_render_structure" `Quick
            test_drawdown_render_structure;
          Alcotest.test_case "chart_pane_structure" `Quick
            test_chart_pane_structure;
          Alcotest.test_case "heat_map_hover_simulation" `Quick
            test_heat_map_hover_simulation;
        ] );
    ]
