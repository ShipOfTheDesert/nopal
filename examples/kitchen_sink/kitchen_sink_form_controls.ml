open Nopal_element
open Nopal_style
open Nopal_ui

type model = { agree_checked : bool; color : string; size : string }

type msg =
  | Toggle_agree of bool
  | Select_color of string
  | Change_size of string

let init () =
  ({ agree_checked = false; color = "red"; size = "medium" }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Toggle_agree v -> ({ model with agree_checked = v }, Nopal_mvu.Cmd.none)
  | Select_color v -> ({ model with color = v }, Nopal_mvu.Cmd.none)
  | Change_size v -> ({ model with size = v }, Nopal_mvu.Cmd.none)

let group_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 16.0 })

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
    ]
