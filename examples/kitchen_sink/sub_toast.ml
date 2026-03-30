open Nopal_element
open Nopal_style
open Nopal_ui

type model = { toasts : Toast.toast list; next_id : int }

type msg =
  | ShowInfo
  | ShowSuccess
  | ShowWarning
  | ShowError
  | Dismiss of string

let init () = ({ toasts = []; next_id = 1 }, Nopal_mvu.Cmd.none)

let show_toast variant message model =
  let id = "toast-" ^ string_of_int model.next_id in
  let toasts, cmd =
    Toast.add ~variant ~message ~id ~duration_ms:3000
      ~dismiss:(fun id -> Dismiss id)
      model.toasts
  in
  ({ toasts; next_id = model.next_id + 1 }, cmd)

let update model msg =
  match msg with
  | ShowInfo -> show_toast Info "This is an info notification" model
  | ShowSuccess -> show_toast Success "Operation succeeded!" model
  | ShowWarning -> show_toast Warning "Caution: check your input" model
  | ShowError -> show_toast Error "Something went wrong!" model
  | Dismiss id ->
      ({ model with toasts = Toast.dismiss id model.toasts }, Nopal_mvu.Cmd.none)

let button_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; direction = Some Row_dir })

let trigger_button_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 6.0 12.0 6.0 12.0)
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

let trigger_button_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#e5e3df") })
  in
  { Interaction.default with hover = Some hover }

let subscriptions _model = Nopal_mvu.Sub.none

let view _vp model =
  let config = Toast.make ~dismiss:(fun id -> Dismiss id) in
  Element.column
    ~style:
      (Style.default |> Style.with_layout (fun l -> { l with gap = Some 12.0 }))
    [
      Element.row ~style:button_row_style
        [
          Element.button ~style:trigger_button_style
            ~interaction:trigger_button_interaction ~on_click:ShowInfo
            ~attrs:[ ("data-testid", "toast-trigger-info") ]
            (Element.text "Show Info Toast");
          Element.button ~style:trigger_button_style
            ~interaction:trigger_button_interaction ~on_click:ShowSuccess
            ~attrs:[ ("data-testid", "toast-trigger-success") ]
            (Element.text "Show Success Toast");
          Element.button ~style:trigger_button_style
            ~interaction:trigger_button_interaction ~on_click:ShowWarning
            ~attrs:[ ("data-testid", "toast-trigger-warning") ]
            (Element.text "Show Warning Toast");
          Element.button ~style:trigger_button_style
            ~interaction:trigger_button_interaction ~on_click:ShowError
            ~attrs:[ ("data-testid", "toast-trigger-error") ]
            (Element.text "Show Error Toast");
        ];
      Toast.view config model.toasts;
    ]
