let default_radius = 4.0
let hover_scale = 1.5

let view ~data ~x ~y ?(radius = fun _ -> default_radius) ~color ~width ~height
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
      (* Compute X domain *)
      let x_values = List.map x data in
      let x_data_min = List.fold_left Float.min Float.infinity x_values in
      let x_data_max = List.fold_left Float.max Float.neg_infinity x_values in
      let x_lo, x_hi =
        Axis.compute_domain x_axis ~data_min:x_data_min ~data_max:x_data_max
      in
      let x_scale =
        Nopal_draw.Scale.create ~domain:(x_lo, x_hi)
          ~range:(chart_x, chart_x +. chart_width)
      in
      (* Compute Y domain *)
      let y_values = List.map y data in
      let y_data_min = List.fold_left Float.min Float.infinity y_values in
      let y_data_max = List.fold_left Float.max Float.neg_infinity y_values in
      let y_lo, y_hi =
        Axis.compute_domain y_axis ~data_min:y_data_min ~data_max:y_data_max
      in
      let y_scale =
        Nopal_draw.Scale.create ~domain:(y_lo, y_hi)
          ~range:(chart_y +. chart_height, chart_y)
      in
      (* Single-pass: build scene circles + hit map regions *)
      let scene_circles, hit_map =
        List.fold_left
          (fun (circles, hmap) (i, datum) ->
            let cx = Nopal_draw.Scale.apply x_scale (x datum) in
            let cy = Nopal_draw.Scale.apply y_scale (y datum) in
            let base_r = radius datum in
            let r =
              match hover with
              | Some h when h.Hover.index = i && h.Hover.series = 0 ->
                  base_r *. hover_scale
              | _ -> base_r
            in
            let c = color datum in
            let circle =
              Nopal_draw.Scene.circle ~fill:(Nopal_draw.Paint.solid c) ~cx ~cy
                ~r ()
            in
            let region =
              Hit_map.Circle_region
                { cx; cy; r = base_r; hit = { index = i; series = 0 } }
            in
            (circle :: circles, Hit_map.add region hmap))
          ([], Hit_map.empty)
          (List.mapi (fun i d -> (i, d)) data)
      in
      let point_scenes = List.rev scene_circles in
      (* Axes *)
      let x_ticks =
        Axis.compute_ticks x_axis ~data_min:x_data_min ~data_max:x_data_max
      in
      let x_axis_scene =
        Axis.render_x x_axis ~ticks:x_ticks ~scale:x_scale ~chart_x
          ~chart_y:(chart_y +. chart_height) ~chart_width
      in
      let y_ticks =
        Axis.compute_ticks y_axis ~data_min:y_data_min ~data_max:y_data_max
      in
      let y_axis_scene =
        Axis.render_y y_axis ~ticks:y_ticks ~scale:y_scale ~chart_x ~chart_y
          ~chart_height
      in
      let all_scene = point_scenes @ x_axis_scene @ y_axis_scene in
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
