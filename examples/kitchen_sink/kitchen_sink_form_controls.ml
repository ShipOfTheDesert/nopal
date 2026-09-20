open Nopal_element
open Nopal_style
open Nopal_ui

type model = {
  agree_checked : bool;
  color : string;
  size : string;
  gift_wrap : bool;
  speed : string;
  window : string;
}

type msg =
  | Toggle_agree of bool
  | Select_color of string
  | Change_size of string
  | Toggle_gift_wrap of bool
  | Select_speed of string
  | Change_window of string

let init () =
  ( {
      agree_checked = false;
      color = "red";
      size = "medium";
      gift_wrap = false;
      speed = "express";
      window = "morning";
    },
    Nopal_mvu.Cmd.none )

let update model msg =
  match msg with
  | Toggle_agree v -> ({ model with agree_checked = v }, Nopal_mvu.Cmd.none)
  | Select_color v -> ({ model with color = v }, Nopal_mvu.Cmd.none)
  | Change_size v -> ({ model with size = v }, Nopal_mvu.Cmd.none)
  | Toggle_gift_wrap v -> ({ model with gift_wrap = v }, Nopal_mvu.Cmd.none)
  | Select_speed v -> ({ model with speed = v }, Nopal_mvu.Cmd.none)
  | Change_window v -> ({ model with window = v }, Nopal_mvu.Cmd.none)

let group_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 16.0 })

(* The three labelled controls beside the plain ones above, each restyled
   through its own setters rather than forked: the label's weight, the gap
   between the control and its label, and — on the radio group — the visible
   group label, which is opt-in because making one appear changes the rendered
   tree of every existing consumer. Every value is non-default, so a setter that
   compiled without reaching its node would show here. *)

let restyled_label_style =
  Style.default |> Style.with_text (Text.font_weight Font.Semi_bold)

let restyled_option_label_style =
  Style.default |> Style.with_text (Text.font_weight Font.Medium)

let restyled_checkbox_row_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 18.0 })

let restyled_select_wrapper_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 20.0 })

let restyled_group_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 14.0 })

let restyled_option_row_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 10.0 })

(* Each of the three is written out as a complete literal rather than amended
   from [make], so the demonstration states every field it asks for — including
   the override fields a consumer holding a complete literal now has to supply.
   The checkbox names its identifier explicitly; the select and the group take
   theirs from the slugified label, so both routes are shown. *)

let restyled_checkbox model =
  {
    Checkbox.label = "Gift wrap this order";
    checked = model.gift_wrap;
    disabled = false;
    on_toggle = Some (fun v -> Toggle_gift_wrap v);
    style = None;
    interaction = None;
    attrs = [ ("data-testid", "fc-checkbox-restyled") ];
    id = Some "gift-wrap";
    label_style = Some restyled_label_style;
    row_style = Some restyled_checkbox_row_style;
    on_label_click = None;
  }

let restyled_radio_group model =
  {
    Radio_group.label = "Shipping speed";
    options =
      [
        Radio_group.radio_option ~value:"express" "Express";
        Radio_group.radio_option ~value:"standard" "Standard";
      ];
    selected = model.speed;
    disabled = false;
    name = None;
    on_select = Some (fun v -> Select_speed v);
    style = None;
    interaction = None;
    attrs = [ ("data-testid", "fc-radio-group-restyled") ];
    id = None;
    visible_label = Some true;
    label_style = Some restyled_label_style;
    group_style = Some restyled_group_style;
    option_label_style = Some restyled_option_label_style;
    option_row_style = Some restyled_option_row_style;
    on_label_click = None;
  }

let restyled_select model =
  {
    Select_input.label = "Delivery window";
    options =
      [
        Element.select_option ~value:"morning" "Morning";
        Element.select_option ~value:"evening" "Evening";
      ];
    selected = model.window;
    placeholder = None;
    disabled = false;
    on_change = Some (fun v -> Change_window v);
    style = None;
    interaction = None;
    attrs = [ ("data-testid", "fc-select-restyled") ];
    id = None;
    label_style = Some restyled_label_style;
    wrapper_style = Some restyled_select_wrapper_style;
    on_label_click = None;
  }

let view _vp model =
  Element.column ~style:group_style
    ~attrs:[ ("data-testid", "form-controls-section") ]
    [
      (* Checkbox: togglable *)
      Checkbox.view
        {
          (Checkbox.make ~label:"I agree to the terms"
             ~checked:model.agree_checked)
          with
          on_toggle = Some (fun v -> Toggle_agree v);
          attrs = [ ("data-testid", "fc-checkbox") ];
        };
      (* Checkbox: checked and disabled *)
      Checkbox.view
        {
          (Checkbox.make ~label:"Already accepted" ~checked:true) with
          disabled = true;
          attrs = [ ("data-testid", "fc-checkbox-disabled") ];
        };
      (* Checkbox: unchecked *)
      Checkbox.view (Checkbox.make ~label:"Optional newsletter" ~checked:false);
      (* Radio group: with selection and one disabled option *)
      Radio_group.view
        {
          (Radio_group.make ~label:"Favorite color"
             ~options:
               [
                 Radio_group.radio_option ~value:"red" "Red";
                 Radio_group.radio_option ~value:"green" "Green";
                 Radio_group.radio_option ~value:"blue" ~disabled:true "Blue";
               ]
             ~selected:model.color)
          with
          on_select = Some (fun v -> Select_color v);
          attrs = [ ("data-testid", "fc-radio-group") ];
        };
      (* Radio group: entirely disabled *)
      Radio_group.view
        {
          (Radio_group.make ~label:"Disabled group"
             ~options:
               [
                 Radio_group.radio_option ~value:"x" "X";
                 Radio_group.radio_option ~value:"y" "Y";
               ]
             ~selected:"x")
          with
          disabled = true;
          attrs = [ ("data-testid", "fc-radio-group-disabled") ];
        };
      (* Select: with placeholder *)
      Select_input.view
        {
          (Select_input.make ~label:"T-shirt size"
             ~options:
               [
                 Element.select_option ~value:"small" "Small";
                 Element.select_option ~value:"medium" "Medium";
                 Element.select_option ~value:"large" "Large";
               ]
             ~selected:model.size)
          with
          placeholder = Some "Choose a size";
          on_change = Some (fun v -> Change_size v);
          attrs = [ ("data-testid", "fc-select") ];
        };
      (* Select: disabled *)
      Select_input.view
        {
          (Select_input.make ~label:"Locked size"
             ~options:
               [
                 Element.select_option ~value:"medium" "Medium";
                 Element.select_option ~value:"large" "Large";
               ]
             ~selected:"medium")
          with
          disabled = true;
          attrs = [ ("data-testid", "fc-select-disabled") ];
        };
      (* The same three components, restyled without leaving them. *)
      Checkbox.view (restyled_checkbox model);
      Radio_group.view (restyled_radio_group model);
      Select_input.view (restyled_select model);
    ]
