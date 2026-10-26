open Nopal_element
open Nopal_style

(* Text fields are all options, so starting from the default style inherits no
   opinion about anything but the size and weight named here. *)
let scale_style level =
  let size =
    match level with
    | Element.H1 -> 2.0
    | Element.H2 -> 1.6
    | Element.H3 -> 1.3
    | Element.H4 -> 1.15
    | Element.H5 -> 1.0
    | Element.H6 -> 0.875
  in
  Style.default
  |> Style.with_text (fun t ->
      t |> Text.font_size size |> Text.font_weight Font.Semi_bold)

let chain_heading level text =
  Element.heading ~style:(scale_style level) level (Element.text text)

let styled_style =
  Style.default |> Style.with_text (fun t -> t |> Text.font_size 1.5)

let styled_interaction =
  {
    Interaction.hover =
      Some
        (Style.default
        |> Style.with_text (fun t -> t |> Text.text_decoration Text.Underline));
    pressed = None;
    focused = None;
  }

let view () =
  Element.column
    [
      chain_heading Element.H3 "Heading level three";
      chain_heading Element.H4 "Heading level four";
      chain_heading Element.H5 "Heading level five";
      chain_heading Element.H6 "Heading level six";
      Element.row
        ~attrs:[ ("data-testid", "headings-unstyled-pair") ]
        [
          Element.heading
            ~attrs:[ ("data-testid", "headings-unstyled") ]
            Element.H3
            (Element.text "An unstyled heading");
          Element.box
            ~attrs:[ ("data-testid", "headings-plain-text") ]
            [ Element.text "Plain text beside it" ];
        ];
      Element.heading ~style:styled_style ~interaction:styled_interaction
        ~attrs:[ ("data-testid", "headings-styled") ]
        Element.H3
        (Element.text "A styled heading");
    ]
