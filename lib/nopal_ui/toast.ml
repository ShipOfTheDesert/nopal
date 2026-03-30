type variant = Info | Success | Warning | Error
type toast = { id : string; variant : variant; message : string }

type 'msg config = {
  dismiss : string -> 'msg;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
}

let make ~dismiss = { dismiss; style = None; interaction = None; attrs = [] }

let add ~variant ~message ~id ?duration_ms ~dismiss toasts =
  let toast = { id; variant; message } in
  let cmd =
    match duration_ms with
    | Some ms -> Nopal_mvu.Cmd.after ms (dismiss id)
    | None -> Nopal_mvu.Cmd.none
  in
  (List.rev (toast :: List.rev toasts), cmd)

let dismiss id toasts =
  List.filter (fun (t : toast) -> not (String.equal t.id id)) toasts

module S = Nopal_style.Style
module I = Nopal_style.Interaction
module E = Nopal_element.Element

let variant_to_string = function
  | Info -> "info"
  | Success -> "success"
  | Warning -> "warning"
  | Error -> "error"

let base_style =
  S.default
  |> S.with_layout (fun l -> l |> S.padding 8.0 16.0 8.0 16.0)
  |> S.with_paint (fun p ->
      {
        p with
        border =
          Some
            {
              width = 0.0;
              style = No_border;
              color = Transparent;
              radius = 6.0;
            };
      })

let default_style_for variant =
  match variant with
  | Info ->
      base_style
      |> S.with_paint (fun p -> { p with background = Some (S.hex "#d0e8ff") })
  | Success ->
      base_style
      |> S.with_paint (fun p -> { p with background = Some (S.hex "#d4edda") })
  | Warning ->
      base_style
      |> S.with_paint (fun p -> { p with background = Some (S.hex "#fff3cd") })
  | Error ->
      base_style
      |> S.with_paint (fun p -> { p with background = Some (S.hex "#f8d7da") })

let default_interaction_for variant =
  match variant with
  | Info ->
      {
        I.default with
        hover =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#b8d8ff") }));
        pressed =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#a0c8ff") }));
      }
  | Success ->
      {
        I.default with
        hover =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#b8dbbc") }));
        pressed =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#9cca9e") }));
      }
  | Warning ->
      {
        I.default with
        hover =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#ffe8a0") }));
        pressed =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#ffdd73") }));
      }
  | Error ->
      {
        I.default with
        hover =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#f0b8be") }));
        pressed =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#e89aa0") }));
      }

let aria_live_for = function
  | Info
  | Success ->
      "polite"
  | Warning
  | Error ->
      "assertive"

let view config toasts =
  let style =
    match config.style with
    | Some s -> s
    | None -> S.default |> S.with_layout (fun l -> { l with gap = Some 8.0 })
  in
  let toast_elements =
    List.map
      (fun (t : toast) ->
        let toast_style = default_style_for t.variant in
        let interaction =
          match config.interaction with
          | Some i -> i
          | None -> default_interaction_for t.variant
        in
        let attrs =
          [
            ("data-testid", "toast-" ^ t.id);
            ("data-variant", variant_to_string t.variant);
            ("aria-live", aria_live_for t.variant);
            ("aria-label", "Dismiss: " ^ t.message);
          ]
        in
        E.button ~style:toast_style ~interaction ~attrs
          ~on_click:(config.dismiss t.id) (E.text t.message))
      toasts
  in
  E.column ~style ~attrs:config.attrs toast_elements
