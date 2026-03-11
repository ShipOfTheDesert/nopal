let default_bullish = Nopal_draw.Color.rgb ~r:0.16 ~g:0.68 ~b:0.34
let default_bearish = Nopal_draw.Color.rgb ~r:0.84 ~g:0.18 ~b:0.18

let view ~data ~x ~open_ ~high ~low ~close ~width ~height
    ?(padding = Padding.default) ?bullish_color ?bearish_color
    ?(x_axis = Axis.default_config) ?y_axis ?format_tooltip ?on_hover ?on_leave
    ?hover ?domain_window () =
  (* Apply domain window clipping if provided *)
  let visible_data =
    match domain_window with
    | Some window -> Viewport.clip ~x ~data ~window ~buffer:0
    | None -> data
  in
  match visible_data with
  | [] -> Nopal_element.Element.draw ~width ~height []
  | _ ->
      let bull_color =
        match bullish_color with
        | Some c -> c
        | None -> default_bullish
      in
      let bear_color =
        match bearish_color with
        | Some c -> c
        | None -> default_bearish
      in
      let chart_x = padding.Padding.left in
      let chart_y = padding.Padding.top in
      let chart_width = width -. padding.left -. padding.right in
      let chart_height = height -. padding.top -. padding.bottom in
      (* Compute X domain *)
      let all_x = List.map (fun d -> x d) visible_data in
      let x_min = List.fold_left Float.min Float.infinity all_x in
      let x_max = List.fold_left Float.max Float.neg_infinity all_x in
      (* Compute Y domain from high/low *)
      let all_highs = List.map (fun d -> high d) visible_data in
      let all_lows = List.map (fun d -> low d) visible_data in
      let data_y_min = List.fold_left Float.min Float.infinity all_lows in
      let data_y_max = List.fold_left Float.max Float.neg_infinity all_highs in
      let y_axis_cfg =
        match y_axis with
        | Some cfg -> cfg
        | None -> Axis.default_config
      in
      let y_lo, y_hi =
        Axis.compute_domain y_axis_cfg ~data_min:data_y_min ~data_max:data_y_max
      in
      let x_lo, x_hi =
        match domain_window with
        | Some window -> (window.x_min, window.x_max)
        | None -> Axis.compute_domain x_axis ~data_min:x_min ~data_max:x_max
      in
      let x_scale =
        Nopal_draw.Scale.create ~domain:(x_lo, x_hi)
          ~range:(chart_x, chart_x +. chart_width)
      in
      let y_scale =
        Nopal_draw.Scale.create ~domain:(y_lo, y_hi)
          ~range:(chart_y +. chart_height, chart_y)
      in
      (* Candle width: divide chart width by number of candles, use 80% for body *)
      let n = List.length visible_data in
      let candle_slot = chart_width /. Float.of_int n in
      let candle_w = candle_slot *. 0.8 in
      (* Build scene: one wick line + one body rect per candle *)
      let candle_scenes, hit_map =
        List.fold_left
          (fun (scenes, hmap) (i, d) ->
            let px = Nopal_draw.Scale.apply x_scale (x d) in
            let high_y = Nopal_draw.Scale.apply y_scale (high d) in
            let low_y = Nopal_draw.Scale.apply y_scale (low d) in
            let open_y = Nopal_draw.Scale.apply y_scale (open_ d) in
            let close_y = Nopal_draw.Scale.apply y_scale (close d) in
            let is_bullish = close d > open_ d in
            let color = if is_bullish then bull_color else bear_color in
            (* Wick: line from high to low *)
            let wick =
              Nopal_draw.Scene.line
                ~stroke:
                  (Nopal_draw.Paint.stroke ~width:1.0
                     (Nopal_draw.Paint.solid color))
                ~x1:px ~y1:high_y ~x2:px ~y2:low_y ()
            in
            (* Body: rect from open to close *)
            let body_top = Float.min open_y close_y in
            let body_h =
              let raw = Float.abs (close_y -. open_y) in
              if raw < 1.0 then 1.0 else raw
            in
            let body =
              Nopal_draw.Scene.rect
                ~fill:(Nopal_draw.Paint.solid color)
                ~x:(px -. (candle_w /. 2.0))
                ~y:body_top ~w:candle_w ~h:body_h ()
            in
            (* Hit region: covers full wick range *)
            let region =
              Hit_map.Rect_region
                {
                  x = px -. (candle_w /. 2.0);
                  y = high_y;
                  w = candle_w;
                  h = low_y -. high_y;
                  hit = { index = i; series = 0 };
                }
            in
            (wick :: body :: scenes, Hit_map.add region hmap))
          ([], Hit_map.empty)
          (List.mapi (fun i d -> (i, d)) visible_data)
      in
      let candle_scenes = List.rev candle_scenes in
      (* Axes *)
      let x_ticks = Axis.compute_ticks x_axis ~data_min:x_min ~data_max:x_max in
      let x_axis_scene =
        Axis.render_x x_axis ~ticks:x_ticks ~scale:x_scale ~chart_x
          ~chart_y:(chart_y +. chart_height) ~chart_width
      in
      let y_ticks =
        Axis.compute_ticks y_axis_cfg ~data_min:data_y_min ~data_max:data_y_max
      in
      let y_axis_scene =
        Axis.render_y y_axis_cfg ~ticks:y_ticks ~scale:y_scale ~chart_x ~chart_y
          ~chart_height
      in
      let all_scene = candle_scenes @ x_axis_scene @ y_axis_scene in
      (* Build on_pointer_move handler *)
      let on_pointer_move =
        match (on_hover, on_leave) with
        | Some handler, Some leave_msg ->
            Some
              (fun (pe : Nopal_element.Element.pointer_event) ->
                match Hit_map.hit_test hit_map ~x:pe.x ~y:pe.y with
                | Some hit ->
                    handler
                      {
                        Hover.index = hit.index;
                        series = hit.series;
                        cursor_x = pe.x;
                        cursor_y = pe.y;
                      }
                | None -> leave_msg)
        | _ -> None
      in
      let draw_el =
        Nopal_element.Element.draw ?on_pointer_move ?on_pointer_leave:on_leave
          ~width ~height all_scene
      in
      (* Compose with tooltip if hovered *)
      let visible_arr = Array.of_list visible_data in
      let tooltip =
        match (hover, format_tooltip) with
        | Some h, Some fmt
          when h.Hover.index >= 0 && h.Hover.index < Array.length visible_arr ->
            let datum = visible_arr.(h.Hover.index) in
            let tip =
              fmt h.Hover.index (open_ datum) (high datum) (low datum)
                (close datum)
            in
            Some
              (Tooltip.container ~x:h.cursor_x ~y:h.cursor_y ~chart_width:width
                 ~chart_height:height tip)
        | _ -> None
      in
      Chart_compose.compose ~draw_el ~width ~height ~tooltip
