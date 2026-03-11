module E = Nopal_element.Element
open Nopal_charts

type msg =
  | Render_candlestick_1k
  | Render_heat_map_50x50
  | Render_line_100k_clipped
  | Render_lttb_100k
  | Clear

type model = { chart_element : msg E.t }

(* Generate OHLC data: n candles with synthetic price action *)
let gen_ohlc n =
  let rec go acc i price =
    match i with
    | _ when i >= n -> List.rev acc
    | _ ->
        let open_ = price in
        let delta = Random.float 10.0 -. 5.0 in
        let close = price +. delta in
        let high = Float.max open_ close +. Random.float 3.0 in
        let low = Float.min open_ close -. Random.float 3.0 in
        let x = Float.of_int i in
        go ((x, open_, high, low, close) :: acc) (i + 1) close
  in
  go [] 0 100.0

(* Generate heat map grid: rows x cols as flat list of (row, col, value) *)
let gen_heat_map rows cols =
  let acc = ref [] in
  for r = rows - 1 downto 0 do
    for c = cols - 1 downto 0 do
      acc := (r, c, Random.float 100.0) :: !acc
    done
  done;
  !acc

(* Generate line data: n points *)
let gen_line_data n =
  List.init n (fun i ->
      let x = Float.of_int i in
      let y = 50.0 +. (30.0 *. sin (x *. 0.05)) +. (10.0 *. sin (x *. 0.13)) in
      (x, y))

let init () = ({ chart_element = E.empty }, Nopal_mvu.Cmd.none)

let update _model msg =
  match msg with
  | Render_candlestick_1k ->
      let data = gen_ohlc 1000 in
      let el =
        Trading.Candlestick.view ~data
          ~x:(fun (x, _, _, _, _) -> x)
          ~open_:(fun (_, o, _, _, _) -> o)
          ~high:(fun (_, _, h, _, _) -> h)
          ~low:(fun (_, _, _, l, _) -> l)
          ~close:(fun (_, _, _, _, c) -> c)
          ~width:800.0 ~height:400.0 ()
      in
      ({ chart_element = el }, Nopal_mvu.Cmd.none)
  | Render_heat_map_50x50 ->
      let data = gen_heat_map 50 50 in
      let row_labels = List.init 50 (fun i -> string_of_int i) in
      let col_labels = List.init 50 (fun i -> string_of_int i) in
      let scale =
        Color_scale.sequential
          ~low:(Nopal_draw.Color.rgba ~r:1.0 ~g:1.0 ~b:0.9 ~a:1.0)
          ~high:(Nopal_draw.Color.rgba ~r:0.0 ~g:0.4 ~b:0.0 ~a:1.0)
      in
      let el =
        Heat_map.view ~data
          ~row:(fun (r, _, _) -> r)
          ~col:(fun (_, c, _) -> c)
          ~value:(fun (_, _, v) -> v)
          ~row_count:50 ~col_count:50 ~row_labels ~col_labels ~scale
          ~width:800.0 ~height:800.0 ()
      in
      ({ chart_element = el }, Nopal_mvu.Cmd.none)
  | Render_line_100k_clipped ->
      let data = gen_line_data 100_000 in
      let domain_window = Domain_window.create ~x_min:50000.0 ~x_max:50500.0 in
      let el =
        Line.view
          ~series:
            [
              Line.series ~label:"bench" ~color:Nopal_draw.Color.blue
                ~y:(fun (_, y) -> y)
                data;
            ]
          ~x:(fun (x, _) -> x)
          ~width:800.0 ~height:400.0 ~domain_window ()
      in
      ({ chart_element = el }, Nopal_mvu.Cmd.none)
  | Render_lttb_100k ->
      (* Pure computation benchmark — generate 100k, downsample to 1k *)
      let data =
        Array.init 100_000 (fun i ->
            let x = Float.of_int i in
            let y = 50.0 +. (30.0 *. sin (x *. 0.05)) in
            (x, y))
      in
      let _downsampled =
        Downsample.lttb
          ~x:(fun (x, _) -> x)
          ~y:(fun (_, y) -> y)
          ~data ~target:1000
      in
      (* Render a small text to signal completion *)
      let el = E.text "lttb done" in
      ({ chart_element = el }, Nopal_mvu.Cmd.none)
  | Clear -> ({ chart_element = E.empty }, Nopal_mvu.Cmd.none)

let view _vp model =
  E.column
    ~attrs:[ ("id", "chart-bench") ]
    [
      E.box
        ~attrs:[ ("id", "controls") ]
        [
          E.button
            ~attrs:[ ("id", "candlestick-1k") ]
            ~on_click:Render_candlestick_1k (E.text "Candlestick 1k");
          E.button
            ~attrs:[ ("id", "heatmap-50x50") ]
            ~on_click:Render_heat_map_50x50 (E.text "Heat map 50x50");
          E.button
            ~attrs:[ ("id", "line-100k") ]
            ~on_click:Render_line_100k_clipped
            (E.text "Line 100k clipped");
          E.button
            ~attrs:[ ("id", "lttb-100k") ]
            ~on_click:Render_lttb_100k (E.text "LTTB 100k");
          E.button ~attrs:[ ("id", "clear") ] ~on_click:Clear (E.text "Clear");
        ];
      E.box ~attrs:[ ("id", "chart-output") ] [ model.chart_element ];
    ]

let subscriptions _model = Nopal_mvu.Sub.none
