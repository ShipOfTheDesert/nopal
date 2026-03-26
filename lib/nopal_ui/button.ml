type variant = Primary | Secondary | Destructive | Ghost | Icon

type 'msg config = {
  variant : variant;
  disabled : bool;
  loading : bool;
  on_click : 'msg option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
}

let default variant =
  {
    variant;
    disabled = false;
    loading = false;
    on_click = None;
    style = None;
    interaction = None;
    attrs = [];
  }

let variant_to_string = function
  | Primary -> "primary"
  | Secondary -> "secondary"
  | Destructive -> "destructive"
  | Ghost -> "ghost"
  | Icon -> "icon"

module S = Nopal_style.Style
module I = Nopal_style.Interaction
module E = Nopal_element.Element

let base_style =
  S.default |> S.with_layout (fun l -> l |> S.padding 6.0 16.0 6.0 16.0)

let default_style_for variant =
  match variant with
  | Primary ->
      base_style
      |> S.with_paint (fun p ->
          {
            p with
            background = Some (S.hex "#4a90d9");
            border =
              Some
                {
                  width = 1.0;
                  style = Solid;
                  color = S.hex "#3a7bc8";
                  radius = 6.0;
                };
            shadow =
              Some { x = 0.0; y = 1.0; blur = 3.0; color = S.rgba 0 0 0 0.2 };
          })
  | Secondary ->
      base_style
      |> S.with_paint (fun p ->
          {
            p with
            background = Some (S.hex "#e9ecef");
            border =
              Some
                {
                  width = 1.0;
                  style = Solid;
                  color = S.hex "#dee2e6";
                  radius = 6.0;
                };
          })
  | Destructive ->
      base_style
      |> S.with_paint (fun p ->
          {
            p with
            background = Some (S.hex "#e06060");
            border =
              Some
                {
                  width = 1.0;
                  style = Solid;
                  color = S.hex "#c84040";
                  radius = 6.0;
                };
            shadow =
              Some { x = 0.0; y = 1.0; blur = 3.0; color = S.rgba 0 0 0 0.2 };
          })
  | Ghost ->
      base_style
      |> S.with_paint (fun p ->
          {
            p with
            border =
              Some
                {
                  width = 0.0;
                  style = Solid;
                  color = S.rgba 0 0 0 0.0;
                  radius = 6.0;
                };
          })
  | Icon ->
      S.default
      |> S.with_layout (fun l ->
          {
            l with
            padding_top = Some 4.0;
            padding_right = Some 4.0;
            padding_bottom = Some 4.0;
            padding_left = Some 4.0;
          })
      |> S.with_paint (fun p ->
          {
            p with
            border =
              Some
                {
                  width = 0.0;
                  style = Solid;
                  color = S.rgba 0 0 0 0.0;
                  radius = 6.0;
                };
          })

let default_interaction_for variant =
  match variant with
  | Primary ->
      {
        I.default with
        hover =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#5ba0e9") }));
        pressed =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#2a6ab8") }));
      }
  | Secondary ->
      {
        I.default with
        hover =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#d0d8df") }));
        pressed =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#bcc4cc") }));
      }
  | Destructive ->
      {
        I.default with
        hover =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#c84040") }));
        pressed =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.hex "#a03030") }));
      }
  | Ghost ->
      {
        I.default with
        hover =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.rgba 0 0 0 0.05) }));
        pressed =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.rgba 0 0 0 0.1) }));
      }
  | Icon ->
      {
        I.default with
        hover =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.rgba 0 0 0 0.1) }));
        pressed =
          Some
            (S.default
            |> S.with_paint (fun p ->
                { p with background = Some (S.rgba 0 0 0 0.15) }));
      }

let view config child =
  let style =
    match config.style with
    | Some s -> s
    | None -> default_style_for config.variant
  in
  let interaction =
    match config.interaction with
    | Some i -> i
    | None -> default_interaction_for config.variant
  in
  let suppressed = config.disabled || config.loading in
  let on_click = if suppressed then None else config.on_click in
  let aria_attrs =
    (if config.disabled then [ ("aria-disabled", "true") ] else [])
    @ if config.loading then [ ("aria-busy", "true") ] else []
  in
  let variant_attr = [ ("data-variant", variant_to_string config.variant) ] in
  (* User attrs come last so they take precedence on key collision
     (last-writer-wins when the renderer sets DOM attributes sequentially). *)
  let attrs = aria_attrs @ variant_attr @ config.attrs in
  E.button ~style ~interaction ~attrs ?on_click child
