let min_bar_height = 2.0

let lighten (c : Nopal_draw.Color.t) =
  Nopal_draw.Color.lerp c Nopal_draw.Color.white 0.3

let view ~data ~label:_ ~value ~color ~width ~height
    ?(padding = Padding.default) ?(x_axis = Axis.default_config)
    ?(y_axis = Axis.default_config) ?format_tooltip ?on_hover ?on_leave ?hover
    () =
  match data with
  | [] -> Nopal_element.Element.draw ~width ~height []
  | _ -> (
      let n = List.length data in
      let chart_x = padding.left in
      let chart_y = padding.top in
      let chart_width = width -. padding.left -. padding.right in
      let chart_height = height -. padding.top -. padding.bottom in
      (* Compute Y domain *)
      let values = List.map value data in
      let data_min = List.fold_left Float.min Float.infinity values in
      let data_max = List.fold_left Float.max Float.neg_infinity values in
      (* Include 0 in domain so baseline is visible for mixed pos/neg *)
      let data_min = Float.min data_min 0.0 in
      let data_max = Float.max data_max 0.0 in
      let y_lo, y_hi = Axis.compute_domain y_axis ~data_min ~data_max in
      let y_scale =
        Nopal_draw.Scale.create ~domain:(y_lo, y_hi)
          ~range:(chart_y +. chart_height, chart_y)
      in
      (* X scale: bars are evenly spaced *)
      let bar_width = chart_width /. Float.of_int n in
      let bar_gap = bar_width *. 0.1 in
      let actual_bar_w = bar_width -. bar_gap in
      (* Baseline Y position (where value=0 maps to) *)
      let baseline_y = Nopal_draw.Scale.apply y_scale 0.0 in
      (* Single-pass: build scene rects + hit map regions *)
      let scene_rects, hit_map =
        List.fold_left
          (fun (rects, hmap) (i, datum) ->
            let v = value datum in
            let c = color datum in
            let fill_color =
              match hover with
              | Some h when h.Hover.index = i && h.Hover.series = 0 -> lighten c
              | _ -> c
            in
            let bar_x =
              chart_x +. (Float.of_int i *. bar_width) +. (bar_gap /. 2.0)
            in
            let raw_y = Nopal_draw.Scale.apply y_scale v in
            (* For positive values: bar goes from raw_y up to baseline_y *)
            (* For negative values: bar goes from baseline_y down to raw_y *)
            let rect_y, rect_h =
              if v >= 0.0 then
                let h = Float.abs (baseline_y -. raw_y) in
                let h = Float.max h min_bar_height in
                (baseline_y -. h, h)
              else
                let h = Float.abs (raw_y -. baseline_y) in
                let h = Float.max h min_bar_height in
                (baseline_y, h)
            in
            let rect =
              Nopal_draw.Scene.rect
                ~fill:(Nopal_draw.Paint.solid fill_color)
                ~x:bar_x ~y:rect_y ~w:actual_bar_w ~h:rect_h ()
            in
            let region =
              Hit_map.Rect_region
                {
                  x = bar_x;
                  y = rect_y;
                  w = actual_bar_w;
                  h = rect_h;
                  hit = { index = i; series = 0 };
                }
            in
            (rect :: rects, Hit_map.add region hmap))
          ([], Hit_map.empty)
          (List.mapi (fun i d -> (i, d)) data)
      in
      let bar_scenes = List.rev scene_rects in
      (* Axes *)
      let x_ticks =
        Axis.compute_ticks x_axis ~data_min:0.0 ~data_max:(Float.of_int (n - 1))
      in
      let x_scale =
        Nopal_draw.Scale.create
          ~domain:(0.0, Float.of_int (n - 1))
          ~range:(0.0, chart_width)
      in
      let x_axis_scene =
        Axis.render_x x_axis ~ticks:x_ticks ~scale:x_scale ~chart_x
          ~chart_y:(chart_y +. chart_height) ~chart_width
      in
      let y_ticks = Axis.compute_ticks y_axis ~data_min ~data_max in
      let y_axis_scene =
        Axis.render_y y_axis ~ticks:y_ticks ~scale:y_scale ~chart_x ~chart_y
          ~chart_height
      in
      let all_scene = bar_scenes @ x_axis_scene @ y_axis_scene in
      (* Build on_pointer_move handler *)
      let on_pointer_move =
        match on_hover with
        | None -> None
        | Some handler ->
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
                | None ->
                    handler
                      {
                        Hover.index = -1;
                        series = 0;
                        cursor_x = pe.x;
                        cursor_y = pe.y;
                      })
      in
      let draw_el =
        Nopal_element.Element.draw ?on_pointer_move ?on_pointer_leave:on_leave
          ~width ~height all_scene
      in
      (* Compose with tooltip if hovered *)
      match (hover, format_tooltip) with
      | Some h, Some fmt when h.Hover.index >= 0 && h.Hover.index < n ->
          let datum = List.nth data h.Hover.index in
          let tip = fmt datum in
          let tip_container =
            Tooltip.container ~x:h.cursor_x ~y:h.cursor_y ~chart_width:width
              ~chart_height:height tip
          in
          let outer_style =
            Nopal_style.Style.default
            |> Nopal_style.Style.with_layout (fun l ->
                { l with width = Fixed width; height = Fixed height })
          in
          Nopal_element.Element.box ~style:outer_style
            [ draw_el; tip_container ]
      | _ ->
          let outer_style =
            Nopal_style.Style.default
            |> Nopal_style.Style.with_layout (fun l ->
                { l with width = Fixed width; height = Fixed height })
          in
          Nopal_element.Element.box ~style:outer_style [ draw_el ])
