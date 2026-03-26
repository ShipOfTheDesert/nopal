open Nopal_element
open Nopal_ui

type model = {
  default_value : string;
  placeholder_value : string;
  error_value : string;
  disabled_value : string;
}

type msg =
  | Default_changed of string
  | Default_submitted
  | Placeholder_changed of string
  | Error_changed of string

let init () =
  ( {
      default_value = "";
      placeholder_value = "";
      error_value = "";
      disabled_value = "Cannot edit";
    },
    Nopal_mvu.Cmd.none )

let update model msg =
  match msg with
  | Default_changed v -> ({ model with default_value = v }, Nopal_mvu.Cmd.none)
  | Default_submitted -> (model, Nopal_mvu.Cmd.none)
  | Placeholder_changed v ->
      ({ model with placeholder_value = v }, Nopal_mvu.Cmd.none)
  | Error_changed v -> ({ model with error_value = v }, Nopal_mvu.Cmd.none)

let group_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l -> { l with gap = Some 12.0 })

let view _vp model =
  let default_input =
    TextInput.view
      {
        (TextInput.make ~label:"Default" ~value:model.default_value) with
        on_change = Some (fun v -> Default_changed v);
        on_submit = Some Default_submitted;
        attrs = [ ("data-testid", "text-input-default") ];
      }
  in
  let placeholder_input =
    TextInput.view
      {
        (TextInput.make ~label:"With Placeholder" ~value:model.placeholder_value)
        with
        placeholder = Some "Enter text here...";
        on_change = Some (fun v -> Placeholder_changed v);
        attrs = [ ("data-testid", "text-input-placeholder") ];
      }
  in
  let error_input =
    TextInput.view
      {
        (TextInput.make ~label:"With Error" ~value:model.error_value) with
        error = Some "This field is required";
        on_change = Some (fun v -> Error_changed v);
        attrs = [ ("data-testid", "text-input-error") ];
      }
  in
  let disabled_input =
    TextInput.view
      {
        (TextInput.make ~label:"Disabled" ~value:model.disabled_value) with
        disabled = true;
        attrs = [ ("data-testid", "text-input-disabled") ];
      }
  in
  Element.column ~style:group_style
    ~attrs:[ ("data-testid", "text-input-section") ]
    [ default_input; placeholder_input; error_input; disabled_input ]
