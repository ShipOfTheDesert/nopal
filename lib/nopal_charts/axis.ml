type tick = { value : float; label : string }

type config = {
  label : string option;
  min : float option;
  max : float option;
  tick_count : int;
  format_tick : float -> string;
}

let default_config =
  {
    label = None;
    min = None;
    max = None;
    tick_count = 5;
    format_tick = string_of_float;
  }

(** Compute a "nice" number for tick spacing. Rounds to 1, 2, or 5 * 10^n. *)
let nice_number v round =
  let exp = Float.floor (Float.log10 v) in
  let frac = v /. (10.0 ** exp) in
  let nice_frac =
    match round with
    | true -> (
        match () with
        | () when frac < 1.5 -> 1.0
        | () when frac < 3.0 -> 2.0
        | () when frac < 7.0 -> 5.0
        | () -> 10.0)
    | false -> (
        match () with
        | () when frac <= 1.0 -> 1.0
        | () when frac <= 2.0 -> 2.0
        | () when frac <= 5.0 -> 5.0
        | () -> 10.0)
  in
  nice_frac *. (10.0 ** exp)

let compute_domain config ~data_min ~data_max =
  let range = data_max -. data_min in
  let range = if Float.equal range 0.0 then 1.0 else range in
  let tick_spacing =
    nice_number (range /. Float.of_int config.tick_count) true
  in
  let nice_min = Float.floor (data_min /. tick_spacing) *. tick_spacing in
  let nice_max = Float.ceil (data_max /. tick_spacing) *. tick_spacing in
  let lo =
    match config.min with
    | Some m -> m
    | None -> nice_min
  in
  let hi =
    match config.max with
    | Some m -> m
    | None -> nice_max
  in
  (lo, hi)

let compute_ticks config ~data_min ~data_max =
  let lo, hi = compute_domain config ~data_min ~data_max in
  let range = hi -. lo in
  let range = if Float.equal range 0.0 then 1.0 else range in
  let tick_spacing =
    nice_number (range /. Float.of_int config.tick_count) true
  in
  let first_tick = Float.ceil (lo /. tick_spacing) *. tick_spacing in
  let rec collect v acc =
    if v > hi +. (tick_spacing *. 0.001) then List.rev acc
    else
      let t = { value = v; label = config.format_tick v } in
      collect (v +. tick_spacing) (t :: acc)
  in
  collect first_tick []

let tick_size = 6.0
let label_offset = 16.0

let axis_stroke =
  Nopal_draw.Paint.stroke ~width:1.0
    (Nopal_draw.Paint.solid (Nopal_draw.Color.rgb ~r:0.2 ~g:0.2 ~b:0.2))

let axis_label_offset = 32.0

let render_x config ~ticks ~scale ~chart_x ~chart_y ~chart_width =
  let axis_line =
    Nopal_draw.Scene.line ~stroke:axis_stroke ~x1:chart_x ~y1:chart_y
      ~x2:(chart_x +. chart_width) ~y2:chart_y ()
  in
  let tick_scenes =
    List.concat_map
      (fun (t : tick) ->
        let x = chart_x +. Nopal_draw.Scale.apply scale t.value in
        let tick_line =
          Nopal_draw.Scene.line ~stroke:axis_stroke ~x1:x ~y1:chart_y ~x2:x
            ~y2:(chart_y +. tick_size) ()
        in
        let tick_label =
          Nopal_draw.Scene.text ~font_size:11.0 ~anchor:Middle ~baseline:Top ~x
            ~y:(chart_y +. label_offset) t.label
        in
        [ tick_line; tick_label ])
      ticks
  in
  let label_scene =
    match config.label with
    | Some lbl ->
        let center_x = chart_x +. (chart_width /. 2.0) in
        [
          Nopal_draw.Scene.text ~font_size:12.0 ~anchor:Middle ~baseline:Top
            ~x:center_x
            ~y:(chart_y +. axis_label_offset)
            lbl;
        ]
    | None -> []
  in
  (axis_line :: tick_scenes) @ label_scene

let render_y config ~ticks ~scale ~chart_x ~chart_y ~chart_height =
  let axis_line =
    Nopal_draw.Scene.line ~stroke:axis_stroke ~x1:chart_x ~y1:chart_y
      ~x2:chart_x ~y2:(chart_y +. chart_height) ()
  in
  let tick_scenes =
    List.concat_map
      (fun (t : tick) ->
        let y = Nopal_draw.Scale.apply scale t.value in
        let tick_line =
          Nopal_draw.Scene.line ~stroke:axis_stroke ~x1:(chart_x -. tick_size)
            ~y1:y ~x2:chart_x ~y2:y ()
        in
        let tick_label =
          Nopal_draw.Scene.text ~font_size:11.0 ~anchor:End_anchor
            ~baseline:Middle_baseline ~x:(chart_x -. label_offset) ~y t.label
        in
        [ tick_line; tick_label ])
      ticks
  in
  let label_scene =
    match config.label with
    | Some lbl ->
        let center_y = chart_y +. (chart_height /. 2.0) in
        [
          Nopal_draw.Scene.text ~font_size:12.0 ~anchor:End_anchor
            ~baseline:Middle_baseline
            ~x:(chart_x -. axis_label_offset)
            ~y:center_y lbl;
        ]
    | None -> []
  in
  (axis_line :: tick_scenes) @ label_scene
