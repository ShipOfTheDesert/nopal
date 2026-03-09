open Nopal_element
open Nopal_style

type model = { count : int }
type msg = Increment | Decrement

let init () = ({ count = 0 }, Nopal_mvu.Cmd.none)

let update model msg =
  let model' =
    match msg with
    | Increment -> { count = model.count + 1 }
    | Decrement -> { count = model.count - 1 }
  in
  (model', Nopal_mvu.Cmd.none)

let row_style =
  Style.default
  |> Style.with_layout (fun l -> { l with cross_align = Center; gap = 8.0 })

let button_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 4.0 12.0 4.0 12.0)

let view model =
  Element.row ~style:row_style
    [
      Element.button ~style:button_style ~on_click:Decrement (Element.text "-");
      Element.text (string_of_int model.count);
      Element.button ~style:button_style ~on_click:Increment (Element.text "+");
    ]
