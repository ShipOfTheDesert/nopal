open Nopal_element
open Nopal_style
open Nopal_ui

type model = { selected : string }
type msg = Selected of string

let init () = ({ selected = "express" }, Nopal_mvu.Cmd.none)
let update _model (Selected value) = ({ selected = value }, Nopal_mvu.Cmd.none)
let hairline_color = Style.hex "#C9C3B8"
let ring_color = Style.rgba 2 64 58 0.5

(* Every paint field is written out, so no style inherits a look it did not ask
   for. *)
let paint ?border ?shadow () =
  { Style.background = None; border; opacity = 1.0; shadow; overflow = Visible }

let group_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with direction = Some Column_dir; gap = Some 8.0 })

let options_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with direction = Some Row_dir; gap = Some 12.0 })

let option_row_style =
  {
    Style.layout = Style.padding_all 8.0 Style.default_layout;
    paint =
      paint
        ~border:
          {
            Style.width = 1.0;
            style = Solid;
            color = hairline_color;
            radius = 6.0;
            corners = None;
          }
        ();
    text = Style.default_text;
  }

(* Zero offset and zero blur make the shadow read as a ring; the spread alone
   gives it its width. *)
let option_row_interaction =
  {
    Interaction.hover = None;
    pressed = None;
    focused = None;
    focused_within =
      Some
        {
          Style.layout = Style.default_layout;
          paint =
            paint
              ~shadow:
                {
                  x = 0.0;
                  y = 0.0;
                  blur = 0.0;
                  spread = 2.0;
                  color = ring_color;
                }
              ();
          text = Style.default_text;
        };
  }

let shipping_group model =
  let config =
    Radio_group.make ~label:"Shipping"
      ~options:
        [
          Radio_group.radio_option ~value:"standard" "Standard";
          Radio_group.radio_option ~value:"express" "Express";
          Radio_group.radio_option ~value:"overnight" "Overnight";
        ]
      ~selected:model.selected
    |> Radio_group.with_id "hidden-radio-shipping"
    |> Radio_group.with_visible_label true
    |> Radio_group.with_group_style group_style
    |> Radio_group.with_options_style options_style
    |> Radio_group.with_option_row_style option_row_style
    |> Radio_group.with_option_row_interaction option_row_interaction
    |> Radio_group.with_hidden_inputs
  in
  Radio_group.view
    { config with on_select = Some (fun value -> Selected value) }

let do_nothing_button ~testid label =
  Element.button ~attrs:[ ("data-testid", testid) ] (Element.text label)

let view model =
  Element.column
    [
      do_nothing_button ~testid:"hidden-radio-before" "Before the group";
      shipping_group model;
      do_nothing_button ~testid:"hidden-radio-after" "After the group";
    ]

let serialize_msg (Selected value) =
  Printf.sprintf "HiddenRadio:Selected:%s;" value
