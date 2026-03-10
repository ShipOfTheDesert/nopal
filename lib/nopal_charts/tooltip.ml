let tooltip_offset = 8.0

let tooltip_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      Nopal_style.Style.padding_all 6.0 { l with width = Hug; height = Hug })
  |> Nopal_style.Style.with_paint (fun p ->
      {
        p with
        background = Some (Nopal_style.Style.rgba 33 33 33 0.92);
        border = Some { Nopal_style.Style.default_border with radius = 4.0 };
      })

let text s =
  Nopal_element.Element.box ~style:tooltip_style
    [ Nopal_element.Element.text s ]

let container ~x ~y ~chart_width ~chart_height content =
  (* Estimate tooltip size for edge detection *)
  let tip_w = 120.0 in
  let tip_h = 40.0 in
  (* Determine if we need to flip *)
  let flip_x = x +. tooltip_offset +. tip_w > chart_width in
  let flip_y = y +. tooltip_offset +. tip_h > chart_height in
  let pad_left =
    if flip_x then Float.max 0.0 (x -. tooltip_offset -. tip_w)
    else x +. tooltip_offset
  in
  let pad_top =
    if flip_y then Float.max 0.0 (y -. tooltip_offset -. tip_h)
    else y +. tooltip_offset
  in
  let outer_style =
    Nopal_style.Style.default
    |> Nopal_style.Style.with_layout (fun l ->
        {
          l with
          width = Fixed chart_width;
          height = Fixed chart_height;
          padding_left = pad_left;
          padding_top = pad_top;
        })
    |> Nopal_style.Style.with_paint (fun p -> { p with overflow = Hidden })
  in
  Nopal_element.Element.box ~style:outer_style
    ~attrs:[ ("data-testid", "chart-tooltip") ]
    [ content ]
