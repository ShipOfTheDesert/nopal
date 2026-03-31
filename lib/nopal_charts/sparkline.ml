let scene ~data ~width ~height ?(color = Nopal_draw.Color.categorical.(0))
    ?(stroke_width = 1.5) () =
  match data with
  | [] -> []
  | [ _ ] -> []
  | _ ->
      let n = List.length data in
      let data_min = List.fold_left Float.min Float.infinity data in
      let data_max = List.fold_left Float.max Float.neg_infinity data in
      let y_scale =
        if Float.equal data_min data_max then
          Nopal_draw.Scale.create
            ~domain:(data_min, data_max +. 1.0)
            ~range:(height, 0.0)
        else
          Nopal_draw.Scale.create ~domain:(data_min, data_max)
            ~range:(height, 0.0)
      in
      let x_step = width /. Float.of_int (n - 1) in
      let points =
        List.mapi
          (fun i v ->
            let x = Float.of_int i *. x_step in
            let y = Nopal_draw.Scale.apply y_scale v in
            (x, y))
          data
      in
      let stroke =
        Nopal_draw.Paint.stroke ~width:stroke_width
          (Nopal_draw.Paint.solid color)
      in
      let line = Nopal_draw.Scene.polyline ~stroke points in
      [ line ]

let view ~data ~width ~height ?(color = Nopal_draw.Color.categorical.(0))
    ?(stroke_width = 1.5) () =
  match scene ~data ~width ~height ~color ~stroke_width () with
  | [] -> Nopal_element.Element.draw ~width ~height []
  | nodes -> Nopal_element.Element.draw ~width ~height nodes
