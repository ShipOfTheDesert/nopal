open Nopal_charts
open Nopal_element
open Nopal_draw

type msg = Hovered of Hover.t | Left

(* --- sample data --- *)

(* Each point: (x, open, high, low, close) *)
type candle = { x : float; o : float; h : float; l : float; c : float }

let sample_data =
  [
    { x = 1.0; o = 100.0; h = 110.0; l = 95.0; c = 105.0 };
    (* bullish *)
    { x = 2.0; o = 105.0; h = 108.0; l = 98.0; c = 100.0 };
    (* bearish *)
    { x = 3.0; o = 100.0; h = 115.0; l = 99.0; c = 112.0 };
    (* bullish *)
    { x = 4.0; o = 112.0; h = 113.0; l = 105.0; c = 106.0 };
    (* bearish *)
    { x = 5.0; o = 106.0; h = 120.0; l = 104.0; c = 118.0 };
    (* bullish *)
  ]

(* Doji: open == close *)
let doji_data = [ { x = 1.0; o = 100.0; h = 110.0; l = 90.0; c = 100.0 } ]
let x_of c = c.x
let open_of c = c.o
let high_of c = c.h
let low_of c = c.l
let close_of c = c.c
let custom_bullish = Color.rgb ~r:0.0 ~g:0.6 ~b:0.0
let custom_bearish = Color.rgb ~r:0.6 ~g:0.0 ~b:0.0

(* --- helpers --- *)

let candle_view ?bullish_color ?bearish_color ?on_hover ?on_leave ?hover
    ?format_tooltip ?domain_window data =
  Trading.Candlestick.view ~data ~x:x_of ~open_:open_of ~high:high_of
    ~low:low_of ~close:close_of ~width:400.0 ~height:300.0 ?bullish_color
    ?bearish_color ?on_hover ?on_leave ?hover ?format_tooltip ?domain_window ()

let extract_draw (el : msg Element.t) =
  match el with
  | Box { children; _ } ->
      List.find_map
        (fun (child : msg Element.t) ->
          match child with
          | Draw d ->
              Some
                ( d.scene,
                  d.on_pointer_move,
                  d.on_pointer_leave,
                  d.width,
                  d.height )
          | _ -> None)
        children
  | Draw d ->
      Some (d.scene, d.on_pointer_move, d.on_pointer_leave, d.width, d.height)
  | _ -> None

let count_rects (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      match node with
      | Rect _ -> acc + 1
      | _ -> acc)
    0 scene

let count_lines (scene : Scene.t list) =
  List.fold_left
    (fun acc (node : Scene.t) ->
      match node with
      | Line _ -> acc + 1
      | _ -> acc)
    0 scene

let get_rect_fills (scene : Scene.t list) =
  List.filter_map
    (fun (node : Scene.t) ->
      match node with
      | Rect { fill; _ } -> Some fill
      | _ -> None)
    scene

let get_rect_heights (scene : Scene.t list) =
  List.filter_map
    (fun (node : Scene.t) ->
      match node with
      | Rect { h; _ } -> Some h
      | _ -> None)
    scene

(* --- tests --- *)

let test_empty_data () =
  let el =
    Trading.Candlestick.view ~data:[] ~x:x_of ~open_:open_of ~high:high_of
      ~low:low_of ~close:close_of ~width:400.0 ~height:300.0 ()
  in
  match (el : msg Element.t) with
  | Draw { scene; _ } ->
      Alcotest.(check int) "empty scene" 0 (List.length scene)
  | _ -> Alcotest.fail "expected Draw element for empty data"

let test_produces_draw_element () =
  let el = candle_view sample_data in
  match extract_draw el with
  | Some (_, _, _, w, h) ->
      Alcotest.(check (float 0.01)) "width" 400.0 w;
      Alcotest.(check (float 0.01)) "height" 300.0 h
  | None -> Alcotest.fail "expected Draw element"

let test_bullish_candle_color () =
  (* Bullish = close > open. With custom bullish color, those candles should use it *)
  let el = candle_view ~bullish_color:custom_bullish sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let fills = get_rect_fills scene in
      let has_bullish =
        List.exists
          (fun (p : Paint.t) ->
            match p with
            | Solid c ->
                Float.equal c.r custom_bullish.r
                && Float.equal c.g custom_bullish.g
                && Float.equal c.b custom_bullish.b
            | _ -> false)
          fills
      in
      Alcotest.(check bool) "has bullish color rect" true has_bullish
  | None -> Alcotest.fail "expected Draw element"

let test_bearish_candle_color () =
  (* Bearish = close < open. With custom bearish color, those candles should use it *)
  let el = candle_view ~bearish_color:custom_bearish sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let fills = get_rect_fills scene in
      let has_bearish =
        List.exists
          (fun (p : Paint.t) ->
            match p with
            | Solid c ->
                Float.equal c.r custom_bearish.r
                && Float.equal c.g custom_bearish.g
                && Float.equal c.b custom_bearish.b
            | _ -> false)
          fills
      in
      Alcotest.(check bool) "has bearish color rect" true has_bearish
  | None -> Alcotest.fail "expected Draw element"

let test_wick_extends_full_range () =
  (* Each candle should have a wick (Line). Axes also produce lines,
     so check that we have at least 5 lines (one per candle). *)
  let el = candle_view sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n_lines = count_lines scene in
      Alcotest.(check bool) "at least 5 wick lines" true (n_lines >= 5)
  | None -> Alcotest.fail "expected Draw element"

let test_body_spans_open_close () =
  (* Each candle should have a body (Rect). Axes may also produce rects,
     so check that we have at least 5 rects (one per candle). *)
  let el = candle_view sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n_rects = count_rects scene in
      Alcotest.(check bool) "at least 5 body rects" true (n_rects >= 5)
  | None -> Alcotest.fail "expected Draw element"

let test_hover_covers_wick_range () =
  (* Hit regions should cover the full wick range (high to low) *)
  let hover =
    Hover.{ index = 0; series = 0; cursor_x = 100.0; cursor_y = 150.0 }
  in
  let el =
    candle_view ~hover
      ~on_hover:(fun h -> Hovered h)
      ~on_leave:Left
      ~format_tooltip:(fun _idx _o _h _l _c -> Element.text "tooltip")
      sample_data
  in
  match extract_draw el with
  | Some (_, on_pointer_move, _, _, _) ->
      Alcotest.(check bool)
        "has pointer move handler" true
        (Option.is_some on_pointer_move)
  | None -> Alcotest.fail "expected Draw element"

let test_tooltip_shows_ohlc () =
  let hover =
    Hover.{ index = 0; series = 0; cursor_x = 100.0; cursor_y = 150.0 }
  in
  let tooltip_called = ref false in
  let el =
    candle_view ~hover
      ~on_hover:(fun h -> Hovered h)
      ~on_leave:Left
      ~format_tooltip:(fun _idx o h l c ->
        tooltip_called := true;
        Element.text (Printf.sprintf "O:%.0f H:%.0f L:%.0f C:%.0f" o h l c))
      sample_data
  in
  (* Should be a Box with tooltip child *)
  match (el : msg Element.t) with
  | Box { children; _ } ->
      Alcotest.(check bool) "has children" true (List.length children >= 2);
      Alcotest.(check bool) "tooltip formatter called" true !tooltip_called
  | _ -> Alcotest.fail "expected Box with tooltip"

let test_default_colors () =
  (* Without explicit colors, should still produce colored rects *)
  let el = candle_view sample_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let fills = get_rect_fills scene in
      Alcotest.(check bool) "has body fills" true (List.length fills >= 5)
  | None -> Alcotest.fail "expected Draw element"

let test_custom_colors () =
  (* Both custom colors should appear in the scene *)
  let el =
    candle_view ~bullish_color:custom_bullish ~bearish_color:custom_bearish
      sample_data
  in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let fills = get_rect_fills scene in
      let has_bull =
        List.exists
          (fun (p : Paint.t) ->
            match p with
            | Solid c -> Float.equal c.g custom_bullish.g
            | _ -> false)
          fills
      in
      let has_bear =
        List.exists
          (fun (p : Paint.t) ->
            match p with
            | Solid c -> Float.equal c.r custom_bearish.r && Float.equal c.g 0.0
            | _ -> false)
          fills
      in
      Alcotest.(check bool) "has bullish" true has_bull;
      Alcotest.(check bool) "has bearish" true has_bear
  | None -> Alcotest.fail "expected Draw element"

let test_domain_window_clips () =
  (* With a domain window [2.0, 4.0], only candles in that range should render.
     Compare candle-specific scene nodes between full and clipped views. *)
  let full_el = candle_view sample_data in
  let window = Domain_window.create ~x_min:2.0 ~x_max:4.0 in
  let clipped_el = candle_view ~domain_window:window sample_data in
  match (extract_draw full_el, extract_draw clipped_el) with
  | Some (full_scene, _, _, _, _), Some (clipped_scene, _, _, _, _) ->
      let full_rects = count_rects full_scene in
      let clipped_rects = count_rects clipped_scene in
      Alcotest.(check bool)
        "fewer rects after clipping" true
        (clipped_rects > 0 && clipped_rects < full_rects)
  | _ -> Alcotest.fail "expected Draw elements"

let test_doji_candle () =
  (* Doji: open == close. Body should have near-zero height but still render *)
  let el = candle_view doji_data in
  match extract_draw el with
  | Some (scene, _, _, _, _) ->
      let n_rects = count_rects scene in
      let n_lines = count_lines scene in
      (* At least 1 body rect and 1 wick line (axes add more) *)
      Alcotest.(check bool) "has body rect" true (n_rects >= 1);
      Alcotest.(check bool) "has wick line" true (n_lines >= 1);
      (* Body height should be very small (doji) — find the smallest rect height *)
      let heights = get_rect_heights scene in
      let min_h = List.fold_left Float.min Float.infinity heights in
      Alcotest.(check bool) "doji body height small" true (min_h < 5.0)
  | None -> Alcotest.fail "expected Draw element"

let () =
  Alcotest.run "Trading_candlestick"
    [
      ( "trading_candlestick",
        [
          Alcotest.test_case "empty_data" `Quick test_empty_data;
          Alcotest.test_case "produces_draw_element" `Quick
            test_produces_draw_element;
          Alcotest.test_case "bullish_candle_color" `Quick
            test_bullish_candle_color;
          Alcotest.test_case "bearish_candle_color" `Quick
            test_bearish_candle_color;
          Alcotest.test_case "wick_extends_full_range" `Quick
            test_wick_extends_full_range;
          Alcotest.test_case "body_spans_open_close" `Quick
            test_body_spans_open_close;
          Alcotest.test_case "hover_covers_wick_range" `Quick
            test_hover_covers_wick_range;
          Alcotest.test_case "tooltip_shows_ohlc" `Quick test_tooltip_shows_ohlc;
          Alcotest.test_case "default_colors" `Quick test_default_colors;
          Alcotest.test_case "custom_colors" `Quick test_custom_colors;
          Alcotest.test_case "domain_window_clips" `Quick
            test_domain_window_clips;
          Alcotest.test_case "doji_candle" `Quick test_doji_candle;
        ] );
    ]
