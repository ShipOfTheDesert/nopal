let outer_style width height =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with width = Some (Fixed width); height = Some (Fixed height) })

let compose ~draw_el ~width ~height ~tooltip =
  let style = outer_style width height in
  match tooltip with
  | Some tip_el -> Nopal_element.Element.box ~style [ draw_el; tip_el ]
  | None -> Nopal_element.Element.box ~style [ draw_el ]
