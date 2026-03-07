open Nopal_element

type model = { count : int }
type msg = Increment | Decrement | Reset

let init () = ({ count = 0 }, Nopal_mvu.Cmd.none)

let update model msg =
  let model' =
    match msg with
    | Increment -> { count = model.count + 1 }
    | Decrement -> { count = model.count - 1 }
    | Reset -> { count = 0 }
  in
  (model', Nopal_mvu.Cmd.none)

let view model =
  Element.column
    [
      Element.text (string_of_int model.count);
      Element.button ~on_click:Increment (Element.text "+");
      Element.button ~on_click:Decrement (Element.text "-");
      Element.button ~on_click:Reset (Element.text "Reset");
    ]

let subscriptions _model = Nopal_mvu.Sub.none
