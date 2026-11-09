open Nopal_element
open Nopal_style

type example =
  | Unticked_start
  | Ticked_start
  | Focus_ring
  | No_interaction
  | Hover_background

type model = {
  unticked_start : bool;
  ticked_start : bool;
  focus_ring : bool;
  no_interaction : bool;
  hover_background : bool;
}

type msg = Toggled of example * bool

let init () =
  ( {
      unticked_start = false;
      ticked_start = true;
      focus_ring = false;
      no_interaction = false;
      hover_background = false;
    },
    Nopal_mvu.Cmd.none )

let update model (Toggled (example, ticked)) =
  let model =
    match example with
    | Unticked_start -> { model with unticked_start = ticked }
    | Ticked_start -> { model with ticked_start = ticked }
    | Focus_ring -> { model with focus_ring = ticked }
    | No_interaction -> { model with no_interaction = ticked }
    | Hover_background -> { model with hover_background = ticked }
  in
  (model, Nopal_mvu.Cmd.none)

(* The design's colours belong to this section, not to Nopal: a drawn checkbox
   has no default look, and these are one consumer's values shown as an
   example. *)
let field_color = Style.hex "#FFFDF9"
let hairline_color = Style.hex "#C9C3B8"
let ticked_fill = Style.hex "#02403A"
let mark_color = Style.hex "#FFFFFF"
let focus_ring_color = Style.rgba 2 64 58 0.5
let hover_fill = Style.hex "#E6EFEE"
let disabled_field_color = Style.hex "#F1EFEA"
let disabled_hairline_color = Style.hex "#DDD9D1"
let disabled_ticked_fill = Style.hex "#9DB3B0"

(* Every paint field is written out, so no example inherits a look it did not
   ask for. *)
let paint ?background ?border ?shadow () =
  { Style.background; border; opacity = 1.0; shadow; overflow = Visible }

let hairline color = { Style.width = 1.0; style = Solid; color; radius = 4.0 }

let style_of_paint p =
  { Style.layout = Style.default_layout; paint = p; text = Style.default_text }

(* The box is the larger size on a compact viewport, where it is a touch target
   on a phone. *)
let box_size vp =
  match Viewport.is_compact vp with
  | true -> 20.0
  | false -> 18.0

let box_style vp ~field ~border =
  {
    Style.layout =
      {
        Style.default_layout with
        width = Some (Fixed (box_size vp));
        height = Some (Fixed (box_size vp));
      };
    paint = paint ~background:field ~border:(hairline border) ();
    text = Style.default_text;
  }

let design_base vp = box_style vp ~field:field_color ~border:hairline_color

let design_appearance =
  Checkbox_appearance.Drawn
    {
      checked =
        style_of_paint
          (paint ~background:ticked_fill ~border:(hairline ticked_fill) ());
      mark = mark_color;
    }

let disabled_base vp =
  box_style vp ~field:disabled_field_color ~border:disabled_hairline_color

let disabled_appearance =
  Checkbox_appearance.Drawn
    {
      checked =
        style_of_paint
          (paint ~background:disabled_ticked_fill
             ~border:(hairline disabled_ticked_fill)
             ());
      mark = mark_color;
    }

(* A ring drawn as a shadow rather than a wider border: a style has no outline,
   and the ticked style sets no shadow, so the ring stays while the box is
   ticked. Zero offset and zero blur make the shadow read as a ring; the spread
   alone gives it its width. *)
let focus_ring_interaction =
  {
    Interaction.hover = None;
    pressed = None;
    focused =
      Some
        (style_of_paint
           (paint
              ~shadow:
                {
                  x = 0.0;
                  y = 0.0;
                  blur = 0.0;
                  spread = 2.0;
                  color = focus_ring_color;
                }
              ()));
    focused_within = None;
  }

let hover_background_interaction =
  {
    Interaction.hover = Some (style_of_paint (paint ~background:hover_fill ()));
    pressed = None;
    focused = None;
    focused_within = None;
  }

let no_interaction =
  {
    Interaction.hover = None;
    pressed = None;
    focused = None;
    focused_within = None;
  }

let row_style =
  {
    Style.layout =
      { Style.default_layout with gap = Some 8.0; cross_align = Some Center };
    paint = paint ();
    text = Style.default_text;
  }

let column_style =
  {
    Style.layout = { Style.default_layout with gap = Some 12.0 };
    paint = paint ();
    text = Style.default_text;
  }

let example_row checkbox caption =
  Element.row ~style:row_style [ checkbox; Element.text caption ]

let toggleable vp ~testid ~label ~interaction example ticked caption =
  example_row
    (Element.checkbox ~style:(design_base vp) ~interaction
       ~attrs:[ ("data-testid", testid); ("aria-label", label) ]
       ~appearance:design_appearance
       ~on_toggle:(fun v -> Toggled (example, v))
       ticked)
    caption

let view vp model =
  Element.column ~style:column_style
    [
      toggleable vp ~testid:"drawn-checkbox-unticked" ~label:"Drawn, unticked"
        ~interaction:no_interaction Unticked_start model.unticked_start
        "A hairline box on the field colour; ticking fills it teal with a \
         white tick.";
      toggleable vp ~testid:"drawn-checkbox-ticked" ~label:"Drawn, ticked"
        ~interaction:no_interaction Ticked_start model.ticked_start
        "The same design, starting ticked.";
      toggleable vp ~testid:"drawn-checkbox-focus-ring"
        ~label:"Drawn, with a focus ring" ~interaction:focus_ring_interaction
        Focus_ring model.focus_ring
        "Tab to it: a 2 px ring, drawn as a shadow, stays while ticked.";
      toggleable vp ~testid:"drawn-checkbox-inline"
        ~label:"Drawn, with no interaction" ~interaction:no_interaction
        No_interaction model.no_interaction
        "No interaction states at all; the ticked fill still wins.";
      toggleable vp ~testid:"drawn-checkbox-hover-background"
        ~label:"Drawn, with a hover background"
        ~interaction:hover_background_interaction Hover_background
        model.hover_background
        "Hover sets a background; while ticked, the teal fill wins over it.";
      example_row
        (Element.checkbox ~style:(disabled_base vp)
           ~attrs:
             [
               ("data-testid", "drawn-checkbox-disabled");
               ("aria-label", "Drawn, disabled and ticked");
             ]
           ~disabled:true ~appearance:disabled_appearance true)
        "Disabled and ticked: the muted look is the caller's own, in both \
         styles.";
    ]

let example_name example =
  match example with
  | Unticked_start -> "Unticked_start"
  | Ticked_start -> "Ticked_start"
  | Focus_ring -> "Focus_ring"
  | No_interaction -> "No_interaction"
  | Hover_background -> "Hover_background"

let serialize_msg (Toggled (example, ticked)) =
  Printf.sprintf "DrawnCheckbox:Toggled:%s:%b;" (example_name example) ticked
