open Nopal_element
open Nopal_ui

type model = {
  default_value : string;
  placeholder_value : string;
  error_value : string;
  disabled_value : string;
  restyled_value : string;
}

type msg =
  | Default_changed of string
  | Default_submitted
  | Placeholder_changed of string
  | Error_changed of string
  | Restyled_changed of string
  | Restyled_label_clicked

let init () =
  ( {
      default_value = "";
      placeholder_value = "";
      error_value = "";
      disabled_value = "Cannot edit";
      restyled_value = "";
    },
    Nopal_mvu.Cmd.none )

(* The three things a downstream consumer forked this component for — the
   label's weight, the gap between the label and the box, and the error slot's
   colour — reached through the component's own setters instead. No [~attrs]
   styling and no [style:string]: both are forbidden outright. *)

let restyled_label_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_text
       (Nopal_style.Text.font_weight Nopal_style.Font.Semi_bold)

let restyled_wrapper_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l -> { l with gap = Some 28.0 })

(* #b3261e on the section's #ffffff background is 6.5:1, so the restyle does not
   trade the error slot's legibility for its colour. *)
let restyled_error_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_text
       (Nopal_style.Text.color (Nopal_style.Color.hex "#b3261e"))

(* Every field is written out rather than taken from [make] and amended, so what
   this demonstration asks of the component is stated here in full — including
   the four override fields, which is what a consumer holding a complete literal
   sees after this feature. *)
let restyled_config ~value =
  {
    TextInput.label = "Delivery note";
    value;
    placeholder = Some "Leave it with the neighbour";
    error = Some "A delivery note is required";
    disabled = false;
    id = None;
    on_change = Some (fun v -> Restyled_changed v);
    on_submit = None;
    on_blur = None;
    style = None;
    interaction = None;
    attrs = [ ("data-testid", "text-input-restyled-input") ];
    label_style = Some restyled_label_style;
    wrapper_style = Some restyled_wrapper_style;
    error_style = Some restyled_error_style;
    on_label_click = Some Restyled_label_clicked;
  }

let update model msg =
  match msg with
  | Default_changed v -> ({ model with default_value = v }, Nopal_mvu.Cmd.none)
  | Default_submitted -> (model, Nopal_mvu.Cmd.none)
  | Placeholder_changed v ->
      ({ model with placeholder_value = v }, Nopal_mvu.Cmd.none)
  | Error_changed v -> ({ model with error_value = v }, Nopal_mvu.Cmd.none)
  | Restyled_changed v -> ({ model with restyled_value = v }, Nopal_mvu.Cmd.none)
  (* Click-to-focus, the application's half and the whole of it: a view function
     cannot issue a command, so the component hands the label press out as a
     message and this one line answers it. *)
  | Restyled_label_clicked ->
      ( model,
        Nopal_mvu.Cmd.focus
          (TextInput.control_id (restyled_config ~value:model.restyled_value))
      )

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
  let restyled_input =
    Element.box
      ~attrs:[ ("data-testid", "text-input-restyled") ]
      [ TextInput.view (restyled_config ~value:model.restyled_value) ]
  in
  Element.column ~style:group_style
    ~attrs:[ ("data-testid", "text-input-section") ]
    [
      default_input;
      placeholder_input;
      error_input;
      disabled_input;
      restyled_input;
    ]
