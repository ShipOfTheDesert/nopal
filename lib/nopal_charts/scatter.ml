let default_radius = 4.0
let hover_scale = 1.5

let scene ~data ~x ~y ?(radius = fun _ -> default_radius) ~color ~width ~height
    ?(padding = Padding.default) ?(x_axis = Axis.default_config)
    ?(y_axis = Axis.default_config) ?domain_window () =
  (* Apply domain window clipping if provided *)
  let data =
    match domain_window with
    | Some window -> Viewport.clip ~x ~data ~window ~buffer:0
    | None -> data
  in
  match data with
  | [] -> []
  | _ ->
      let chart_x = padding.left in
      let chart_y = padding.top in
      let chart_width = width -. padding.left -. padding.right in
      let chart_height = height -. padding.top -. padding.bottom in
      (* Compute X domain *)
      let x_values = List.map x data in
      let x_data_min = List.fold_left Float.min Float.infinity x_values in
      let x_data_max = List.fold_left Float.max Float.neg_infinity x_values in
      let x_lo, x_hi =
        match domain_window with
        | Some window -> (window.x_min, window.x_max)
        | None ->
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
      (* Build scene circles *)
      let scene_circles =
        List.map
          (fun datum ->
            let cx = Nopal_draw.Scale.apply x_scale (x datum) in
            let cy = Nopal_draw.Scale.apply y_scale (y datum) in
            let r = radius datum in
            let c = color datum in
            Nopal_draw.Scene.circle ~fill:(Nopal_draw.Paint.solid c) ~cx ~cy ~r
              ())
          data
      in
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
      (* Invariant: data circles occupy indices 0..N-1 so that view can
         apply hover effects by index. Axis/decoration nodes follow. *)
      scene_circles @ x_axis_scene @ y_axis_scene

let view ~data ~x ~y ?(radius = fun _ -> default_radius) ~color ~width ~height
    ?(padding = Padding.default) ?(x_axis = Axis.default_config)
    ?(y_axis = Axis.default_config) ?format_tooltip ?on_hover ?on_leave ?hover
    ?domain_window () =
  let all_scene =
    scene ~data ~x ~y ~radius ~color ~width ~height ~padding ~x_axis ~y_axis
      ?domain_window ()
  in
  match all_scene with
  | [] -> Nopal_element.Element.draw ~width ~height []
  | _ ->
      (* Recompute clipped data and scales for hit map *)
      let data =
        match domain_window with
        | Some window -> Viewport.clip ~x ~data ~window ~buffer:0
        | None -> data
      in
      let chart_x = padding.left in
      let chart_y = padding.top in
      let chart_width = width -. padding.left -. padding.right in
      let chart_height = height -. padding.top -. padding.bottom in
      let x_values = List.map x data in
      let x_data_min = List.fold_left Float.min Float.infinity x_values in
      let x_data_max = List.fold_left Float.max Float.neg_infinity x_values in
      let x_lo, x_hi =
        match domain_window with
        | Some window -> (window.x_min, window.x_max)
        | None ->
            Axis.compute_domain x_axis ~data_min:x_data_min ~data_max:x_data_max
      in
      let x_scale =
        Nopal_draw.Scale.create ~domain:(x_lo, x_hi)
          ~range:(chart_x, chart_x +. chart_width)
      in
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
      (* Build hit map with hover scaling *)
      let hit_map =
        List.fold_left
          (fun hmap (i, datum) ->
            let cx = Nopal_draw.Scale.apply x_scale (x datum) in
            let cy = Nopal_draw.Scale.apply y_scale (y datum) in
            let base_r = radius datum in
            let region =
              Hit_map.Circle_region
                { cx; cy; r = base_r; hit = { index = i; series = 0 } }
            in
            Hit_map.add region hmap)
          Hit_map.empty
          (List.mapi (fun i d -> (i, d)) data)
      in
      (* Apply hover scaling to scene circles *)
      let all_scene =
        match hover with
        | Some h ->
            List.mapi
              (fun i node ->
                if i = h.Hover.index && h.Hover.series = 0 then
                  match List.nth_opt data i with
                  | None -> node
                  | Some datum ->
                      let cx = Nopal_draw.Scale.apply x_scale (x datum) in
                      let cy = Nopal_draw.Scale.apply y_scale (y datum) in
                      let r = radius datum *. hover_scale in
                      let c = color datum in
                      Nopal_draw.Scene.circle ~fill:(Nopal_draw.Paint.solid c)
                        ~cx ~cy ~r ()
                else node)
              all_scene
        | None -> all_scene
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
      let draw_el =
        Nopal_element.Element.draw ?on_pointer_move ?on_pointer_leave:on_leave
          ~width ~height all_scene
      in
      (* Compose with tooltip if hovered *)
      let tooltip =
        match (hover, format_tooltip) with
        | Some h, Some fmt -> (
            match List.nth_opt data h.Hover.index with
            | Some datum ->
                let tip = fmt datum in
                Some
                  (Tooltip.container ~x:h.cursor_x ~y:h.cursor_y
                     ~chart_width:width ~chart_height:height tip)
            | None -> None)
        | _ -> None
      in
      Chart_compose.compose ~draw_el ~width ~height ~tooltip
