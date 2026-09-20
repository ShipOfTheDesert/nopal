module E = Nopal_element.Element

let of_text_style ~text_style text =
  match text_style with
  | Some t -> E.styled_text ~text_style:t text
  | None -> E.text text

let of_style ~style text =
  of_text_style
    ~text_style:(Option.map (fun s -> s.Nopal_style.Style.text) style)
    text
