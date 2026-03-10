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

(* Colors *)
let bg_page = Style.hex "#faf9f7"
let bg_card = Style.hex "#ffffff"
let border_color = Style.hex "#e5e3df"
let accent = Style.hex "#4a90d9"
let accent_hover = Style.hex "#3a7bc8"
let accent_pressed = Style.hex "#2e6db5"
let muted_hover = Style.hex "#666666"

let page_style =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        width = Fill;
        height = Fill;
        main_align = Center;
        cross_align = Center;
      })
  |> Style.with_paint (fun p -> { p with background = Some bg_page })

let card_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with cross_align = Center; gap = 24.0 } |> Style.padding_all 40.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some bg_card;
        border =
          Some
            { width = 1.0; style = Solid; color = border_color; radius = 12.0 };
        shadow =
          Some { x = 0.0; y = 2.0; blur = 12.0; color = Style.rgba 0 0 0 0.06 };
      })

let title_text =
  Text.default
  |> Text.font_size 0.85
  |> Text.font_weight Font.Medium
  |> Text.letter_spacing (Ls_em 0.06)
  |> Text.text_transform Uppercase

let count_text =
  Text.default
  |> Text.font_size 3.5
  |> Text.font_weight Font.Bold
  |> Text.font_family System_ui

let row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with direction = Row_dir; gap = 8.0; cross_align = Center })

let button_base =
  Style.default
  |> Style.with_layout (fun l ->
      {
        l with
        width = Fixed 48.0;
        height = Fixed 48.0;
        main_align = Center;
        cross_align = Center;
      })
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some accent;
        border =
          Some
            {
              width = 0.0;
              style = Solid;
              color = Style.transparent;
              radius = 10.0;
            };
      })
  |> Style.with_text (fun t ->
      t |> Text.font_size 1.2 |> Text.font_weight Font.Semi_bold)

let button_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p -> { p with background = Some accent_hover })
  in
  let pressed =
    Style.default
    |> Style.with_paint (fun p -> { p with background = Some accent_pressed })
  in
  { Interaction.default with hover = Some hover; pressed = Some pressed }

let reset_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 8.0 20.0 8.0 20.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#f5f4f1");
        border =
          Some
            { width = 1.0; style = Solid; color = border_color; radius = 8.0 };
      })
  |> Style.with_text (fun t ->
      t |> Text.font_size 0.85 |> Text.font_weight Font.Medium)

let reset_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        {
          p with
          background = Some (Style.hex "#eeedea");
          border =
            Some
              { width = 1.0; style = Solid; color = muted_hover; radius = 8.0 };
        })
  in
  { Interaction.default with hover = Some hover }

let view model =
  Element.column ~style:page_style
    [
      Element.column ~style:card_style
        [
          Element.styled_text ~text_style:title_text "Counter";
          Element.styled_text ~text_style:count_text (string_of_int model.count);
          Element.row ~style:row_style
            [
              Element.button ~style:button_base ~interaction:button_interaction
                ~on_click:Increment (Element.text "+");
              Element.button ~style:button_base ~interaction:button_interaction
                ~on_click:Decrement (Element.text "-");
            ];
          Element.button ~style:reset_style ~interaction:reset_interaction
            ~on_click:Reset
            (Element.styled_text
               ~text_style:(Text.default |> Text.font_weight Font.Medium)
               "Reset");
        ];
    ]

let subscriptions _model = Nopal_mvu.Sub.none
