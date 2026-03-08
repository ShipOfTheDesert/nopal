open Nopal_element
open Nopal_style

type model = { count : int }
type msg = Increment | Decrement | Reset

let init () = ({ count = 0 }, Nopal_mvu.Cmd.none)

let update model msg =
  let model' =
    match msg with
    | Increment -> { count = model.count + 1 }
    | Decrement -> { count = max 0 (model.count - 1) }
    | Reset -> { count = 0 }
  in
  (model', Nopal_mvu.Cmd.none)

let column_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with cross_align = Center; gap = 8.0 } |> Style.padding_all 16.0)

let button_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with width = Fixed 64.0 } |> Style.padding 8.0 16.0 8.0 16.0)

let view model =
  Element.column ~style:column_style
    [
      Element.text (string_of_int model.count);
      Element.button ~style:button_style ~on_click:Increment (Element.text "+");
      Element.button ~style:button_style ~on_click:Decrement (Element.text "-");
      Element.button ~style:button_style ~on_click:Reset (Element.text "Reset");
    ]

let subscriptions _model = Nopal_mvu.Sub.none
