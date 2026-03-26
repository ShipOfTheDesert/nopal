type direction = Horizontal | Vertical
type entry = { label : string; color : Nopal_draw.Color.t }

let entry ~label ~color = { label; color }

let swatch_style color =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with width = Some (Fixed 12.0); height = Some (Fixed 12.0) })
  |> Nopal_style.Style.with_paint (fun p ->
      {
        p with
        background =
          Some
            (Rgba
               {
                 r = Float.to_int (color.Nopal_draw.Color.r *. 255.0);
                 g = Float.to_int (color.Nopal_draw.Color.g *. 255.0);
                 b = Float.to_int (color.Nopal_draw.Color.b *. 255.0);
                 a = color.Nopal_draw.Color.a;
               });
      })

let entry_element entry =
  let swatch = Nopal_element.Element.box ~style:(swatch_style entry.color) [] in
  let label = Nopal_element.Element.text entry.label in
  Nopal_element.Element.row [ swatch; label ]

let view ~entries ?(direction = Horizontal) ?style () =
  match entries with
  | [] -> Nopal_element.Element.empty
  | entries ->
      let children = List.map entry_element entries in
      let container =
        match direction with
        | Horizontal -> Nopal_element.Element.row ?style children
        | Vertical -> Nopal_element.Element.column ?style children
      in
      container
