type 'a series = {
  data : 'a list;
  y : 'a -> float;
  color : Nopal_draw.Color.t;
  label : string;
  smooth : bool;
  area_fill : bool;
  show_points : bool;
}

let series ?(smooth = false) ?(area_fill = false) ?(show_points = false) ~label
    ~color ~y data =
  { data; y; color; label; smooth; area_fill; show_points }

let view ~series ~x ~width ~height ?(padding = Padding.default)
    ?(x_axis = Axis.default_config) ?(y_axis = Axis.default_config)
    ?format_tooltip ?on_hover ?on_leave ?hover () =
  (* Flatten all data across series to check emptiness *)
  let all_data =
    List.concat_map
      (fun (s : _ series) -> List.map (fun d -> (s, d)) s.data)
      series
  in
  match all_data with
  | [] -> Nopal_element.Element.draw ~width ~height []
  | _ ->
      let chart_x = padding.Padding.left in
      let chart_y = padding.Padding.top in
      let chart_width = width -. padding.left -. padding.right in
      let chart_height = height -. padding.top -. padding.bottom in
      (* Compute global X/Y domains across all series *)
      let all_x = List.map (fun (_, d) -> x d) all_data in
      let all_y = List.map (fun (s, d) -> s.y d) all_data in
      let x_min = List.fold_left Float.min Float.infinity all_x in
      let x_max = List.fold_left Float.max Float.neg_infinity all_x in
      let data_y_min = List.fold_left Float.min Float.infinity all_y in
      let data_y_max = List.fold_left Float.max Float.neg_infinity all_y in
      let y_lo, y_hi =
        Axis.compute_domain y_axis ~data_min:data_y_min ~data_max:data_y_max
      in
      let x_lo, x_hi =
        Axis.compute_domain x_axis ~data_min:x_min ~data_max:x_max
      in
      let x_scale =
        Nopal_draw.Scale.create ~domain:(x_lo, x_hi)
          ~range:(chart_x, chart_x +. chart_width)
      in
      let y_scale =
        Nopal_draw.Scale.create ~domain:(y_lo, y_hi)
          ~range:(chart_y +. chart_height, chart_y)
      in
      (* Build scene nodes per series *)
      let scene_nodes =
        List.concat_map
          (fun (s : _ series) ->
            let points =
              List.map
                (fun d ->
                  let px = Nopal_draw.Scale.apply x_scale (x d) in
                  let py = Nopal_draw.Scale.apply y_scale (s.y d) in
                  (px, py))
                s.data
            in
            let line_nodes =
              if s.smooth then
                let segments = Nopal_draw.Path.smooth_curve points in
                let stroke =
                  Nopal_draw.Paint.stroke ~width:2.0
                    (Nopal_draw.Paint.solid s.color)
                in
                [ Nopal_draw.Scene.path ~stroke segments ]
              else
                let stroke =
                  Nopal_draw.Paint.stroke ~width:2.0
                    (Nopal_draw.Paint.solid s.color)
                in
                [ Nopal_draw.Scene.polyline ~stroke points ]
            in
            let area_nodes =
              if s.area_fill then
                let baseline_y = Nopal_draw.Scale.apply y_scale y_lo in
                match points with
                | [] -> []
                | (first_x, _) :: _ ->
                    let last_x, _ = List.nth points (List.length points - 1) in
                    let area_points =
                      points @ [ (last_x, baseline_y); (first_x, baseline_y) ]
                    in
                    let segments = Nopal_draw.Path.closed_area area_points in
                    let fill_color =
                      { s.color with Nopal_draw.Color.a = 0.3 }
                    in
                    [
                      Nopal_draw.Scene.path
                        ~fill:(Nopal_draw.Paint.solid fill_color)
                        segments;
                    ]
              else []
            in
            let point_nodes =
              if s.show_points then
                List.map
                  (fun (px, py) ->
                    Nopal_draw.Scene.circle
                      ~fill:(Nopal_draw.Paint.solid s.color)
                      ~cx:px ~cy:py ~r:3.0 ())
                  points
              else []
            in
            area_nodes @ line_nodes @ point_nodes)
          series
      in
      (* Build hit map: vertical bands, one per unique X index *)
      let unique_x_values =
        let xs =
          List.concat_map
            (fun (s : _ series) -> List.mapi (fun i d -> (i, x d)) s.data)
            series
        in
        (* Deduplicate by index *)
        let seen = Hashtbl.create 16 in
        List.filter_map
          (fun (i, xv) ->
            if Hashtbl.mem seen i then None
            else begin
              Hashtbl.add seen i true;
              Some (i, xv)
            end)
          xs
      in
      let n_x = List.length unique_x_values in
      let band_width =
        if n_x <= 1 then chart_width else chart_width /. Float.of_int n_x
      in
      let hit_map =
        List.fold_left
          (fun hmap (i, _xv) ->
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
            Hit_map.add region hmap)
          Hit_map.empty unique_x_values
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
      let all_scene = scene_nodes @ x_axis_scene @ y_axis_scene in
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
      let tooltip =
        match (hover, format_tooltip) with
        | Some h, Some fmt when h.Hover.index >= 0 ->
            (* Gather values from all series at the hovered index *)
            let entries =
              List.filter_map
                (fun (s : _ series) ->
                  let n_data = List.length s.data in
                  if h.Hover.index < n_data then
                    let datum = List.nth s.data h.Hover.index in
                    Some (s.label, s.y datum)
                  else None)
                series
            in
            let tip = fmt entries in
            Some
              (Tooltip.container ~x:h.cursor_x ~y:h.cursor_y ~chart_width:width
                 ~chart_height:height tip)
        | _ -> None
      in
      Chart_compose.compose ~draw_el ~width ~height ~tooltip
