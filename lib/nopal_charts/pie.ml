let two_pi = 2.0 *. Float.pi
let default_label_threshold = 15.0 (* degrees *)
let hover_offset = 10.0 (* pixels to offset hovered segment *)
let degrees_of_radians r = r *. 180.0 /. Float.pi

let scene ~data ~value ~label ~color ~width ~height ?(inner_radius = 0.0)
    ?(label_threshold = default_label_threshold) () =
  (* Filter out zero-value segments *)
  let segments =
    List.mapi (fun i d -> (i, d)) data
    |> List.filter (fun (_, d) -> value d > 0.0)
  in
  match segments with
  | [] -> []
  | _ ->
      let total =
        List.fold_left (fun acc (_, d) -> acc +. value d) 0.0 segments
      in
      let cx = width /. 2.0 in
      let cy = height /. 2.0 in
      let outer_r = Float.min cx cy *. 0.85 in
      let inner_r = inner_radius in
      (* Single pass: build scene paths.
         Angle is threaded through the fold accumulator rather than
         using a mutable ref. *)
      let scene_nodes, _final_angle =
        List.fold_left
          (fun (nodes, current_angle) (_orig_idx, datum) ->
            let v = value datum in
            let proportion = v /. total in
            let sweep = proportion *. two_pi in
            let start_a = current_angle in
            let end_a = start_a +. sweep in
            (* Build path using donut_arc *)
            let path_segs =
              Nopal_draw.Path.donut_arc ~cx ~cy ~inner_r ~outer_r
                ~start_angle:start_a ~end_angle:end_a
            in
            let c = color datum in
            let path_node =
              Nopal_draw.Scene.path ~fill:(Nopal_draw.Paint.solid c) path_segs
            in
            (* Label: placed at bisector angle, midway between inner and outer radius *)
            let sweep_degrees = degrees_of_radians sweep in
            let label_nodes =
              if sweep_degrees >= label_threshold then
                let bisector = (start_a +. end_a) /. 2.0 in
                let label_r = (inner_r +. outer_r) /. 2.0 in
                let lx = cx +. (label_r *. Float.cos bisector) in
                let ly = cy +. (label_r *. Float.sin bisector) in
                [
                  Nopal_draw.Scene.text ~x:lx ~y:ly ~font_size:12.0
                    ~fill:(Nopal_draw.Paint.solid Nopal_draw.Color.black)
                    ~anchor:Middle ~baseline:Middle_baseline (label datum);
                ]
              else []
            in
            (List.rev_append label_nodes (path_node :: nodes), end_a))
          ([], 0.0) segments
      in
      List.rev scene_nodes

let view ~data ~value ~label ~color ~width ~height ?(inner_radius = 0.0)
    ?(label_threshold = default_label_threshold) ?format_tooltip ?on_hover
    ?on_leave ?hover () =
  let all_scene =
    scene ~data ~value ~label ~color ~width ~height ~inner_radius
      ~label_threshold ()
  in
  match all_scene with
  | [] -> Nopal_element.Element.draw ~width ~height []
  | _ ->
      (* Recompute segments for hit map and hover offset *)
      let segments =
        List.mapi (fun i d -> (i, d)) data
        |> List.filter (fun (_, d) -> value d > 0.0)
      in
      let total =
        List.fold_left (fun acc (_, d) -> acc +. value d) 0.0 segments
      in
      let cx = width /. 2.0 in
      let cy = height /. 2.0 in
      let outer_r = Float.min cx cy *. 0.85 in
      let inner_r = inner_radius in
      (* Build scene with hover offset + hit map *)
      let scene_nodes, hit_map, _final_angle =
        List.fold_left
          (fun (nodes, hmap, current_angle) (orig_idx, datum) ->
            let v = value datum in
            let proportion = v /. total in
            let sweep = proportion *. two_pi in
            let start_a = current_angle in
            let end_a = start_a +. sweep in
            (* Compute offset for hovered segment *)
            let offset_x, offset_y =
              match hover with
              | Some h when h.Hover.index = orig_idx && h.Hover.series = 0 ->
                  let bisector = (start_a +. end_a) /. 2.0 in
                  ( hover_offset *. Float.cos bisector,
                    hover_offset *. Float.sin bisector )
              | _ -> (0.0, 0.0)
            in
            let seg_cx = cx +. offset_x in
            let seg_cy = cy +. offset_y in
            (* Build path using donut_arc *)
            let path_segs =
              Nopal_draw.Path.donut_arc ~cx:seg_cx ~cy:seg_cy ~inner_r ~outer_r
                ~start_angle:start_a ~end_angle:end_a
            in
            let c = color datum in
            let path_node =
              Nopal_draw.Scene.path ~fill:(Nopal_draw.Paint.solid c) path_segs
            in
            (* Label: placed at bisector angle, midway between inner and outer radius *)
            let sweep_degrees = degrees_of_radians sweep in
            let label_nodes =
              if sweep_degrees >= label_threshold then
                let bisector = (start_a +. end_a) /. 2.0 in
                let label_r = (inner_r +. outer_r) /. 2.0 in
                let lx = seg_cx +. (label_r *. Float.cos bisector) in
                let ly = seg_cy +. (label_r *. Float.sin bisector) in
                [
                  Nopal_draw.Scene.text ~x:lx ~y:ly ~font_size:12.0
                    ~fill:(Nopal_draw.Paint.solid Nopal_draw.Color.black)
                    ~anchor:Middle ~baseline:Middle_baseline (label datum);
                ]
              else []
            in
            (* Hit map: wedge region (using non-offset center for consistent hit testing) *)
            let region =
              Hit_map.Wedge_region
                {
                  cx;
                  cy;
                  inner_r;
                  outer_r;
                  start_angle = start_a;
                  end_angle = end_a;
                  hit = { index = orig_idx; series = 0 };
                }
            in
            ( List.rev_append label_nodes (path_node :: nodes),
              Hit_map.add region hmap,
              end_a ))
          ([], Hit_map.empty, 0.0) segments
      in
      let scene_nodes = List.rev scene_nodes in
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
          ~width ~height scene_nodes
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
