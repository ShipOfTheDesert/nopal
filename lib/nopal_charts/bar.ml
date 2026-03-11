let min_bar_height = 2.0
let category_label_offset = 16.0

let lighten (c : Nopal_draw.Color.t) =
  Nopal_draw.Color.lerp c Nopal_draw.Color.white 0.3

let view ~data ~label ~value ~color ?x ~width ~height
    ?(padding = Padding.default) ?(x_axis = Axis.default_config)
    ?(y_axis = Axis.default_config) ?format_tooltip ?on_hover ?on_leave ?hover
    ?domain_window () =
  (* Apply domain window clipping if provided *)
  let data =
    match (domain_window, x) with
    | Some window, Some x_fn -> Viewport.clip ~x:x_fn ~data ~window ~buffer:0
    | _ -> data
  in
  match data with
  | [] -> Nopal_element.Element.draw ~width ~height []
  | _ ->
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
      (* Single-pass: build scene rects + hit map regions + category labels *)
      let scene_rects, hit_map, category_labels =
        List.fold_left
          (fun (rects, hmap, labels) (i, datum) ->
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
            (* Category label centered under bar *)
            let label_x = bar_x +. (actual_bar_w /. 2.0) in
            let label_y = chart_y +. chart_height +. category_label_offset in
            let lbl =
              Nopal_draw.Scene.text ~font_size:11.0 ~anchor:Middle ~baseline:Top
                ~x:label_x ~y:label_y (label datum)
            in
            (rect :: rects, Hit_map.add region hmap, lbl :: labels))
          ([], Hit_map.empty, [])
          (List.mapi (fun i d -> (i, d)) data)
      in
      let bar_scenes = List.rev scene_rects in
      let category_label_scenes = List.rev category_labels in
      (* X axis line only (labels rendered per-bar above) *)
      let x_axis_line =
        let ax_y = chart_y +. chart_height in
        [
          Nopal_draw.Scene.line
            ~stroke:
              (Nopal_draw.Paint.stroke ~width:1.0
                 (Nopal_draw.Paint.solid
                    (Nopal_draw.Color.rgb ~r:0.2 ~g:0.2 ~b:0.2)))
            ~x1:chart_x ~y1:ax_y ~x2:(chart_x +. chart_width) ~y2:ax_y ();
        ]
      in
      (* X axis label if configured *)
      let x_label_scene =
        match x_axis.label with
        | Some lbl ->
            let center_x = chart_x +. (chart_width /. 2.0) in
            [
              Nopal_draw.Scene.text ~font_size:12.0 ~anchor:Middle ~baseline:Top
                ~x:center_x
                ~y:(chart_y +. chart_height +. category_label_offset +. 16.0)
                lbl;
            ]
        | None -> []
      in
      (* Y axis *)
      let y_ticks = Axis.compute_ticks y_axis ~data_min ~data_max in
      let y_axis_scene =
        Axis.render_y y_axis ~ticks:y_ticks ~scale:y_scale ~chart_x ~chart_y
          ~chart_height
      in
      let all_scene =
        bar_scenes @ category_label_scenes @ x_axis_line @ x_label_scene
        @ y_axis_scene
      in
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
      (* Build tooltip scene if hovered *)
      let tooltip_scene =
        match (hover, format_tooltip) with
        | Some h, Some fmt when h.Hover.index < n ->
            let datum = List.nth data h.Hover.index in
            let tip = fmt datum in
            Tooltip.scene ~x:h.cursor_x ~y:h.cursor_y ~chart_width:width
              ~chart_height:height tip
        | _ -> []
      in
      Chart_compose.compose ~scene:all_scene ~tooltip_scene ~width ~height
        ?on_pointer_move ?on_pointer_leave:on_leave ()
