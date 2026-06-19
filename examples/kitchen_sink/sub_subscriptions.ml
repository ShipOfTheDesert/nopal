open Nopal_element
open Nopal_style

type model = {
  timer_on : bool;
  ticks : int;
  last_size : (int * int) option;
  visible : bool;
  last_key : string option;
}

type msg =
  | ToggleTimer
  | Tick
  | Resized of int * int
  | VisibilityChanged of bool
  | KeyCaptured of string

let init () =
  ( {
      timer_on = false;
      ticks = 0;
      last_size = None;
      visible = true;
      last_key = None;
    },
    Nopal_mvu.Cmd.none )

let update model msg =
  let model' =
    match msg with
    | ToggleTimer -> { model with timer_on = not model.timer_on }
    | Tick -> { model with ticks = model.ticks + 1 }
    | Resized (w, h) -> { model with last_size = Some (w, h) }
    | VisibilityChanged v -> { model with visible = v }
    | KeyCaptured k -> { model with last_key = Some k }
  in
  (model', Nopal_mvu.Cmd.none)

(* Subscription identity keys. The runtime diff adds/removes the underlying
   browser listener or interval as these keys appear/disappear across renders,
   so [timer_key] must enter the tree exactly when the timer is enabled. *)
let timer_key = "subs-timer"
let resize_key = "subs-resize"
let visibility_key = "subs-visibility"
let key_capture_key = "subs-keycapture"

(* A modest interval keeps the E2E fast without depending on rAF cadence —
   [setInterval] is independent of the headless rAF stall (RFC 0118 Risk). *)
let timer_interval_ms = 500

(* Styles *)

let toggle_button_style =
  Style.default
  |> Style.with_layout (fun l -> l |> Style.padding 6.0 16.0 6.0 16.0)
  |> Style.with_paint (fun p ->
      {
        p with
        background = Some (Style.hex "#4a90d9");
        border =
          Some
            {
              width = 1.0;
              style = Solid;
              color = Style.hex "#3a7bc8";
              radius = 6.0;
            };
      })
  |> Style.with_text (fun _ -> Text.default |> Text.font_weight Font.Bold)

let toggle_button_interaction =
  let hover =
    Style.default
    |> Style.with_paint (fun p ->
        { p with background = Some (Style.hex "#3a7bc8") })
  in
  { Interaction.default with hover = Some hover }

let row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center })

let body_style =
  Style.default |> Style.with_layout (fun l -> { l with gap = Some 8.0 })

(* View *)

let readout ~testid label =
  Element.box ~attrs:[ ("data-testid", testid) ] [ Element.text label ]

let view _vp model =
  let toggle_label = if model.timer_on then "Stop timer" else "Start timer" in
  let size_label =
    match model.last_size with
    | Some (w, h) -> Printf.sprintf "Window: %dx%d" w h
    | None -> "Window: (resize the window)"
  in
  let key_label =
    match model.last_key with
    | Some k -> "Last key: " ^ k
    | None -> "Last key: (press a key)"
  in
  Element.column ~style:body_style
    [
      Element.text
        "Live event sources managed by the runtime. The timer is an [every] \
         subscription whose key enters the tree only while enabled.";
      Element.row ~style:row_style
        [
          Element.button ~style:toggle_button_style
            ~interaction:toggle_button_interaction ~on_click:ToggleTimer
            ~attrs:[ ("data-testid", "subs-timer-toggle") ]
            (Element.text toggle_label);
          readout ~testid:"subs-tick-count"
            ("Ticks: " ^ string_of_int model.ticks);
        ];
      readout ~testid:"subs-resize-readout" size_label;
      readout ~testid:"subs-visibility-readout"
        ("Visible: " ^ string_of_bool model.visible);
      readout ~testid:"subs-key-readout" key_label;
    ]

(* Subscriptions *)

let subscriptions model =
  let base =
    [
      Nopal_mvu.Sub.on_resize resize_key (fun w h -> Resized (w, h));
      Nopal_mvu.Sub.on_visibility_change visibility_key (fun v ->
          VisibilityChanged v);
      Nopal_mvu.Sub.on_keydown key_capture_key (fun k ->
          Some (KeyCaptured k, false));
    ]
  in
  let all =
    if model.timer_on then
      Nopal_mvu.Sub.every timer_key timer_interval_ms (fun () -> Tick) :: base
    else base
  in
  Nopal_mvu.Sub.batch all
