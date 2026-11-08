open Nopal_element
open Nopal_style
open Nopal_ui

type model = { selected : string }
type msg = Selected of string

let init () = ({ selected = "medium" }, Nopal_mvu.Cmd.none)
let update _model (Selected value) = ({ selected = value }, Nopal_mvu.Cmd.none)

let layout_style ~direction ~gap =
  Style.default
  |> Style.with_layout (fun l ->
      { l with direction = Some direction; gap = Some gap })

let group_style = layout_style ~direction:Column_dir ~gap:8.0
let options_style = layout_style ~direction:Row_dir ~gap:24.0

let size_group model =
  let config =
    Radio_group.make ~label:"Size"
      ~options:
        [
          Radio_group.radio_option ~value:"small" "Small";
          Radio_group.radio_option ~value:"medium" "Medium";
          Radio_group.radio_option ~value:"large" "Large";
        ]
      ~selected:model.selected
    |> Radio_group.with_id "radio-row-size"
    |> Radio_group.with_visible_label true
    |> Radio_group.with_group_style group_style
    |> Radio_group.with_options_style options_style
  in
  Radio_group.view
    {
      config with
      on_select = Some (fun value -> Selected value);
      attrs = [ ("data-testid", "radio-row-group") ];
    }

let do_nothing_button ~testid label =
  Element.button ~attrs:[ ("data-testid", testid) ] (Element.text label)

let view model =
  Element.column
    [
      do_nothing_button ~testid:"radio-row-before" "Before the group";
      size_group model;
      do_nothing_button ~testid:"radio-row-after" "After the group";
    ]

let serialize_msg (Selected value) =
  Printf.sprintf "RadioRow:Selected:%s;" value
