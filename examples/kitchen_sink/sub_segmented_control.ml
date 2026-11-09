open Nopal_element
open Nopal_style
open Nopal_ui

type model = { threshold : string; window : string; refusing : string }

type msg =
  | Threshold_selected of string
  | Window_selected of string
  | Refusing_selected of string

let init () =
  ({ threshold = "1h"; window = "30d"; refusing = "kept" }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Threshold_selected value ->
      ({ model with threshold = value }, Nopal_mvu.Cmd.none)
  | Window_selected value -> ({ model with window = value }, Nopal_mvu.Cmd.none)
  | Refusing_selected _ -> (model, Nopal_mvu.Cmd.none)

let outline_color = Style.hex "#948775"
let divider_color = Style.hex "#CFC6B8"
let selected_fill = Style.hex "#02403A"
let selected_text = Style.hex "#FFFDF9"
let ring_color = Style.rgba 11 97 88 0.35

(* Every paint field is written out, so no style inherits a look it did not ask
   for. *)
let paint ?background ?border ?shadow () =
  { Style.background; border; opacity = 1.0; shadow; overflow = Visible }

let group_style =
  {
    Style.layout =
      { Style.default_layout with direction = Some Column_dir; gap = Some 8.0 };
    paint = paint ();
    text = Style.default_text;
  }

let segments_style =
  {
    Style.layout = { Style.default_layout with direction = Some Row_dir };
    paint =
      paint
        ~border:
          {
            Style.width = 1.0;
            style = Solid;
            color = outline_color;
            radius = 6.0;
            corners = None;
          }
        ();
    text = Style.default_text;
  }

let divider_style =
  {
    Style.layout = { Style.default_layout with width = Some (Fixed 1.0) };
    paint = paint ~background:divider_color ();
    text = Style.default_text;
  }

let segment_layout =
  {
    Style.default_layout with
    direction = Some Row_dir;
    height = Some (Fixed 38.0);
  }

let segment_style =
  { Style.layout = segment_layout; paint = paint (); text = Style.default_text }

let selected_segment_style =
  {
    Style.layout = segment_layout;
    paint = paint ~background:selected_fill ();
    text = Style.default_text;
  }

let label_layout =
  Style.padding 0.0 12.0 0.0 12.0
    {
      Style.default_layout with
      direction = Some Row_dir;
      main_align = Some Center;
      cross_align = Some Center;
    }

let segment_label_style =
  { Style.layout = label_layout; paint = paint (); text = Style.default_text }

let selected_segment_label_style =
  {
    Style.layout = label_layout;
    paint = paint ();
    text =
      Text.default |> Text.color selected_text |> Text.font_weight Font.Medium;
  }

(* Zero offset and zero blur make the shadow read as a ring; the spread alone
   gives it its width. *)
let segment_interaction =
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

let control ~id ~label ~segments ~selected ~on_select =
  Segmented_control.make ~label
    ~segments:
      (List.map
         (fun (value, text) -> Segmented_control.segment ~value text)
         segments)
    ~selected ~on_select
  |> Segmented_control.with_id id
  |> Segmented_control.with_group_style group_style
  |> Segmented_control.with_segments_style segments_style
  |> Segmented_control.with_segment_style segment_style
  |> Segmented_control.with_segment_label_style segment_label_style
  |> Segmented_control.with_selected_segment_style selected_segment_style
  |> Segmented_control.with_selected_segment_label_style
       selected_segment_label_style
  |> Segmented_control.with_divider_style divider_style
  |> Segmented_control.with_segment_interaction segment_interaction
  |> Segmented_control.view

let do_nothing_button ~testid label =
  Element.button ~attrs:[ ("data-testid", testid) ] (Element.text label)

let view model =
  Element.column
    ~style:
      {
        Style.layout =
          {
            Style.default_layout with
            cross_align = Some Start;
            gap = Some 16.0;
          };
        paint = paint ();
        text = Style.default_text;
      }
    [
      do_nothing_button ~testid:"segmented-control-before" "Before the controls";
      control ~id:"segmented-threshold" ~label:"Alert threshold"
        ~segments:
          [
            ("none", "None");
            ("15m", "15 min");
            ("1h", "1 hour");
            ("1d", "1 day");
            ("custom", "Custom");
          ]
        ~selected:model.threshold
        ~on_select:(fun value -> Threshold_selected value);
      control ~id:"segmented-window" ~label:"Time window"
        ~segments:
          [ ("7d", "7d"); ("30d", "30d"); ("90d", "90d"); ("all", "All") ]
        ~selected:model.window
        ~on_select:(fun value -> Window_selected value);
      control ~id:"segmented-refusing" ~label:"Refusing control"
        ~segments:[ ("kept", "Kept"); ("refused", "Refused") ]
        ~selected:model.refusing
        ~on_select:(fun value -> Refusing_selected value);
      do_nothing_button ~testid:"segmented-control-after" "After the controls";
    ]

let serialize_msg msg =
  let ctor, value =
    match msg with
    | Threshold_selected value -> ("Threshold_selected", value)
    | Window_selected value -> ("Window_selected", value)
    | Refusing_selected value -> ("Refusing_selected", value)
  in
  Printf.sprintf "SegmentedControl:%s:%s;" ctor value
