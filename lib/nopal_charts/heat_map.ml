let highlight_amount = 0.3

let lighten (c : Nopal_draw.Color.t) =
  Nopal_draw.Color.lerp c Nopal_draw.Color.white highlight_amount

let view ~data ~row ~col ~value ~row_count ~col_count ?(row_labels = [])
    ?(col_labels = []) ~scale ~width ~height ?(padding = Padding.default)
    ?format_tooltip ?on_hover ?on_leave ?hover () =
  match (row_count, col_count) with
  | 0, _
  | _, 0 ->
      Nopal_element.Element.draw ~width ~height []
  | _ ->
      let chart_x = padding.left in
      let chart_y = padding.top in
      let chart_width = width -. padding.left -. padding.right in
      let chart_height = height -. padding.top -. padding.bottom in
      let cell_w = chart_width /. Float.of_int col_count in
      let cell_h = chart_height /. Float.of_int row_count in
      (* Compute min/max values across all data *)
      let vmin, vmax =
        List.fold_left
          (fun (lo, hi) datum ->
            let v = value datum in
            (Float.min lo v, Float.max hi v))
          (Float.infinity, Float.neg_infinity)
          data
      in
      (* Build a lookup table: (row, col) -> datum for tooltip *)
      let datum_by_idx = Hashtbl.create 64 in
      (* Single-pass: build scene rects + hit map *)
      let cell_scenes, hit_map =
        List.fold_left
          (fun (scenes, hmap) datum ->
            let r = row datum in
            let c = col datum in
            let v = value datum in
            let base_color = Color_scale.apply scale ~min:vmin ~max:vmax v in
            let idx = (r * col_count) + c in
            Hashtbl.replace datum_by_idx idx datum;
            let fill_color =
              match hover with
              | Some h when h.Hover.index = idx && h.Hover.series = 0 ->
                  lighten base_color
              | _ -> base_color
            in
            let cx = chart_x +. (Float.of_int c *. cell_w) in
            let cy = chart_y +. (Float.of_int r *. cell_h) in
            let rect =
              Nopal_draw.Scene.rect
                ~fill:(Nopal_draw.Paint.solid fill_color)
                ~x:cx ~y:cy ~w:cell_w ~h:cell_h ()
            in
            let region =
              Hit_map.Rect_region
                {
                  x = cx;
                  y = cy;
                  w = cell_w;
                  h = cell_h;
                  hit = { index = idx; series = 0 };
                }
            in
            (rect :: scenes, Hit_map.add region hmap))
          ([], Hit_map.empty) data
      in
      let cell_scenes = List.rev cell_scenes in
      (* Row labels *)
      let row_label_scenes =
        List.mapi
          (fun i lbl ->
            let y_pos =
              chart_y +. (Float.of_int i *. cell_h) +. (cell_h /. 2.0)
            in
            Nopal_draw.Scene.text ~font_size:11.0 ~anchor:End_anchor
              ~baseline:Middle_baseline ~x:(chart_x -. 4.0) ~y:y_pos lbl)
          row_labels
      in
      (* Column labels *)
      let col_label_scenes =
        List.mapi
          (fun i lbl ->
            let x_pos =
              chart_x +. (Float.of_int i *. cell_w) +. (cell_w /. 2.0)
            in
            Nopal_draw.Scene.text ~font_size:11.0 ~anchor:Middle ~baseline:Top
              ~x:x_pos
              ~y:(chart_y +. chart_height +. 4.0)
              lbl)
          col_labels
      in
      let all_scene = cell_scenes @ row_label_scenes @ col_label_scenes in
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
      let total_cells = row_count * col_count in
      let tooltip =
        match (hover, format_tooltip) with
        | Some h, Some fmt when h.Hover.index < total_cells -> (
            let idx = h.Hover.index in
            match Hashtbl.find_opt datum_by_idx idx with
            | Some datum ->
                let tip = fmt datum in
                Some
                  (Tooltip.container ~x:h.cursor_x ~y:h.cursor_y
                     ~chart_width:width ~chart_height:height tip)
            | None -> None)
        | _ -> None
      in
      Chart_compose.compose ~draw_el ~width ~height ~tooltip
