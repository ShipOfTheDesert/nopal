open Nopal_element
open Nopal_style
open Nopal_ui

type model = { last_clicked : string option }
type msg = ButtonClicked of string

let init () = ({ last_clicked = None }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | ButtonClicked label ->
      ignore (model : model);
      ({ last_clicked = Some label }, Nopal_mvu.Cmd.none)

let variant_row_style =
  Style.default
  |> Style.with_layout (fun l -> { l with gap = 8.0; cross_align = Center })

let feedback_text =
  Text.default |> Text.font_size 0.9 |> Text.font_family System_ui

let view_variant_row variant =
  let name = Button.variant_to_string variant in
  let make_button label suffix config =
    let testid = "btn-" ^ name ^ suffix in
    let config = { config with Button.attrs = [ ("data-testid", testid) ] } in
    Button.view config (Element.text label)
  in
  let default_config =
    { (Button.default variant) with on_click = Some (ButtonClicked name) }
  in
  let disabled_config =
    {
      (Button.default variant) with
      disabled = true;
      on_click = Some (ButtonClicked (name ^ "-disabled"));
    }
  in
  let loading_config =
    {
      (Button.default variant) with
      loading = true;
      on_click = Some (ButtonClicked (name ^ "-loading"));
    }
  in
  Element.row ~style:variant_row_style
    [
      Element.styled_text ~text_style:feedback_text
        (String.capitalize_ascii name);
      make_button "Default" "" default_config;
      make_button "Disabled" "-disabled" disabled_config;
      make_button "Loading" "-loading" loading_config;
    ]

let section_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = 12.0 } |> Style.padding_all 20.0)

let section_title_text =
  Text.default
  |> Text.font_size 1.2
  |> Text.font_weight Font.Bold
  |> Text.font_family System_ui

let view _vp model =
  let feedback =
    match model.last_clicked with
    | None -> "No button clicked yet"
    | Some label -> "Last clicked: " ^ label
  in
  Element.column ~style:section_style
    ~attrs:[ ("data-testid", "ui-section") ]
    [
      Element.styled_text ~text_style:section_title_text "UI Components";
      view_variant_row Button.Primary;
      view_variant_row Button.Secondary;
      view_variant_row Button.Destructive;
      view_variant_row Button.Ghost;
      view_variant_row Button.Icon;
      Element.box
        ~attrs:[ ("data-testid", "ui-feedback") ]
        [ Element.styled_text ~text_style:feedback_text feedback ];
    ]
