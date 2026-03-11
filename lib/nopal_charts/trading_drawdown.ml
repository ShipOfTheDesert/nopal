let default_fill_color = Nopal_draw.Color.rgba ~r:0.9 ~g:0.2 ~b:0.2 ~a:0.5

let view ~data ~x ~y ~width ~height ?(padding = Padding.default) ?fill_color
    ?(x_axis = Axis.default_config) ?y_axis ?format_tooltip ?on_hover ?on_leave
    ?hover ?domain_window () =
  (* Apply domain window clipping if provided *)
  let visible_data =
    match domain_window with
    | Some window -> Viewport.clip ~x ~data ~window ~buffer:1
    | None -> data
  in
  match visible_data with
  | [] -> Nopal_element.Element.draw ~width ~height []
  | _ ->
      let chart_x = padding.Padding.left in
      let chart_y = padding.Padding.top in
      let chart_width = width -. padding.left -. padding.right in
      let chart_height = height -. padding.top -. padding.bottom in
      (* Compute X domain *)
      let all_x = List.map (fun d -> x d) visible_data in
      let x_min = List.fold_left Float.min Float.infinity all_x in
      let x_max = List.fold_left Float.max Float.neg_infinity all_x in
      (* Compute Y domain: [min_drawdown, 0.0] *)
      let all_y = List.map (fun d -> y d) visible_data in
      let data_y_min = List.fold_left Float.min Float.infinity all_y in
      let data_y_max = 0.0 in
      (* Override y_axis to force max at 0.0 *)
      let y_axis =
        match y_axis with
        | Some cfg -> { cfg with Axis.max = Some 0.0 }
        | None -> { Axis.default_config with Axis.max = Some 0.0 }
      in
      let y_lo, y_hi =
        Axis.compute_domain y_axis ~data_min:data_y_min ~data_max:data_y_max
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
      (* Build area path: top line forward (drawdown values), baseline (0%) backward *)
      let fill =
        match fill_color with
        | Some c -> c
        | None -> default_fill_color
      in
      let points =
        List.map
          (fun d ->
            let px = Nopal_draw.Scale.apply x_scale (x d) in
            let py = Nopal_draw.Scale.apply y_scale (y d) in
            (px, py))
          visible_data
      in
      let baseline_y = Nopal_draw.Scale.apply y_scale 0.0 in
      let area_scene =
        match points with
        | [] -> []
        | (first_x, _) :: _ ->
            let last_x, _ = List.nth points (List.length points - 1) in
            let area_points =
              points @ [ (last_x, baseline_y); (first_x, baseline_y) ]
            in
            let segments = Nopal_draw.Path.closed_area area_points in
            [
              Nopal_draw.Scene.path ~fill:(Nopal_draw.Paint.solid fill) segments;
            ]
      in
      (* Build hit map: vertical bands, one per data point *)
      let n_points = List.length visible_data in
      let band_width =
        if n_points <= 1 then chart_width
        else chart_width /. Float.of_int n_points
      in
      let hit_map =
        List.fold_left
          (fun (hmap, i) _d ->
            let band_x = chart_x +. (Float.of_int i *. band_width) in
            let region =
              Hit_map.Rect_region
                {
                  x = band_x;
                  y = chart_y;
                  w = band_width;
                  h = chart_height;
                  hit = { index = i; series = 0 };
                }
            in
            (Hit_map.add region hmap, i + 1))
          (Hit_map.empty, 0) visible_data
        |> fst
      in
      (* Axes *)
      let x_ticks = Axis.compute_ticks x_axis ~data_min:x_min ~data_max:x_max in
      let x_axis_scene =
        Axis.render_x x_axis ~ticks:x_ticks ~scale:x_scale ~chart_x
          ~chart_y:(chart_y +. chart_height) ~chart_width
      in
      let y_ticks =
        Axis.compute_ticks y_axis ~data_min:data_y_min ~data_max:data_y_max
      in
      let y_axis_scene =
        Axis.render_y y_axis ~ticks:y_ticks ~scale:y_scale ~chart_x ~chart_y
          ~chart_height
      in
      let all_scene = area_scene @ x_axis_scene @ y_axis_scene in
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
        | Some h, Some fmt when h.Hover.index >= 0 && h.Hover.index < n_points
          ->
            let datum = List.nth visible_data h.Hover.index in
            let value = y datum in
            let tip = fmt h.Hover.index value in
            Tooltip.scene ~x:h.cursor_x ~y:h.cursor_y ~chart_width:width
              ~chart_height:height tip
        | _ -> []
      in
      Chart_compose.compose ~scene:all_scene ~tooltip_scene ~width ~height
        ?on_pointer_move ?on_pointer_leave:on_leave ()
