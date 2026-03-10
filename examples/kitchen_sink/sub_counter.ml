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
  |> Style.with_layout (fun l ->
      {
        l with
        width = Fixed 32.0;
        height = Fixed 32.0;
        main_align = Center;
        cross_align = Center;
      })
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#f0eeea");
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#d5d3cf";
              radius = 6.0;
            };
      })
  |> Style.with_text (fun t -> t |> Text.font_weight Font.Semi_bold)

let button_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#e5e3df") })
  in
  { Interaction.default with hover = Some hover }

let count_text =
  Text.default
  |> Text.font_size 1.1
  |> Text.font_weight Font.Bold
  |> Text.font_family System_ui

let view model =
  Element.row ~style:row_style
    [
      Element.button ~style:button_style ~interaction:button_interaction
        ~on_click:Decrement (Element.text "-");
      Element.styled_text ~text_style:count_text (string_of_int model.count);
      Element.button ~style:button_style ~interaction:button_interaction
        ~on_click:Increment (Element.text "+");
    ]
