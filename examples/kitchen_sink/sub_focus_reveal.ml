open Nopal_element
open Nopal_style

type model = { revealed : bool; edges : int; acknowledged : bool }
type msg = Focus_entered | Focus_left | Hint_acknowledged | Demo_reset

let init () =
  ({ revealed = false; edges = 0; acknowledged = false }, Nopal_mvu.Cmd.none)

let update model msg =
  match msg with
  | Focus_entered ->
      ( { model with revealed = true; edges = model.edges + 1 },
        Nopal_mvu.Cmd.none )
  | Focus_left ->
      ( { model with revealed = false; edges = model.edges + 1 },
        Nopal_mvu.Cmd.none )
  | Hint_acknowledged -> ({ model with acknowledged = true }, Nopal_mvu.Cmd.none)
  (* The reset clears the two values a repeated run would otherwise carry over,
     and deliberately leaves [revealed] alone. The reveal has exactly one
     writer — the two focus edges — so a control that could also set it would
     make every assertion about the note satisfiable without focus ever having
     moved. *)
  | Demo_reset ->
      ({ model with edges = 0; acknowledged = false }, Nopal_mvu.Cmd.none)

let border_color = Style.hex "#dee2e6"
let note_background = Style.hex "#e7f1fb"
let focus_ring_color = Style.rgba 74 144 217 0.6

let control_row_style =
  Style.default
  |> Style.with_layout (fun l ->
      { l with gap = Some 8.0; cross_align = Some Center })

let anchor_style =
  Style.default
  |> Style.with_layout (fun l ->
      Style.padding 10.0 12.0 10.0 12.0
        { l with gap = Some 8.0; width = Some (Fixed 360.0) })
  |> Style.with_paint (fun p ->
      {
        p with
        border =
          Some
            { width = 1.0; style = Solid; color = border_color; radius = 6.0 };
      })

(* The container's other affordance, and the one the model has no part in. The
   note tells the application that focus arrived; the ring tells the user, and
   it is a [:focus-visible] rule the browser applies on its own. A tab stop with
   no visible focus indicator is worse than one the keyboard cannot reach, so
   the section that exists to demonstrate focus carries both.

   The ring is a shadow rather than a wider border because a border participates
   in layout and would nudge everything after the container each time focus
   arrived. Zero offset and zero blur are what make the shadow read as a ring,
   and the spread alone is what gives it width. *)
let focus_ring_interaction =
  {
    Interaction.default with
    focused =
      Some
        (Style.default
        |> Style.with_paint (fun p ->
            {
              p with
              shadow =
                Some
                  {
                    x = 0.0;
                    y = 0.0;
                    blur = 0.0;
                    spread = 3.0;
                    color = focus_ring_color;
                  };
            }));
  }

let note_style =
  Style.default
  |> Style.with_layout (fun l ->
      Style.padding 8.0 10.0 8.0 10.0 { l with gap = Some 8.0 })
  |> Style.with_paint (fun p -> { p with background = Some note_background })

(* The note carries a control of its own, so that reaching into the note by
   keyboard is something the section does on screen rather than something only
   a test knows about. Tabbing from the container to this button moves focus
   inside the same container, which is not a departure and must not take the
   note away — the failure this arrangement exists to make visible. *)
let note_element model =
  Element.box ~style:note_style
    ~attrs:[ ("data-testid", "focus-reveal-note") ]
    [
      Element.text
        "Ctrl+K opens the command palette. This note is a child the view \
         renders only while the model says focus is inside the box.";
      Element.button
        ~attrs:[ ("data-action", "focus-reveal-ack") ]
        ~on_click:Hint_acknowledged
        (Element.text
           (match model.acknowledged with
           | true -> "Acknowledged"
           | false -> "Acknowledge"));
    ]

let view _vp model =
  Element.column
    ~attrs:[ ("data-testid", "focus-reveal-demo") ]
    [
      Element.text
        "Tab into the box below and a note appears; tab past it and the note \
         goes. The box reports each focus edge to the model as a message, so \
         the note is something the application decided to render. A :focus \
         style rule is the other mechanism and a different one: it can \
         recolour the box, but the model never learns that focus happened and \
         so has nothing to render, count or report. Both are on screen here: \
         the ring around the box is that style rule, painted by the browser \
         from a :focus-visible declaration the model never sees, while the \
         note is the model's own answer to the two events.";
      (* The reset control is deliberately the last focusable thing before the
         box, so a keyboard-driven test has a fixed place to start from and
         never has to count tab stops from the top of the page — a count every
         section added above this one would silently change. *)
      Element.row ~style:control_row_style
        [
          Element.button
            ~attrs:[ ("data-action", "focus-reveal-reset") ]
            ~on_click:Demo_reset
            (Element.text "Reset the edge count");
        ];
      Element.box ~style:anchor_style ~interaction:focus_ring_interaction
        ~focusable:true ~on_focus:Focus_entered ~on_blur:Focus_left
        ~attrs:
          [
            ("data-testid", "focus-reveal-box");
            (* A grouping role rather than none: the box is a tab stop, and a
               tab stop with no accessible name is reached and announced as
               nothing. The role is also what makes the label permitted here,
               and it is not a widget role, so a focusable control inside the
               box is not a control nested inside another control. *)
            ("role", "group");
            ("aria-label", "Command palette shortcut, with a note on focus");
          ]
        (Element.text "Command palette"
        ::
        (match model.revealed with
        | true -> [ note_element model ]
        | false -> []));
      Element.box
        ~attrs:[ ("data-testid", "focus-reveal-readout") ]
        [
          Element.text
            (Printf.sprintf "Note %s, %d focus edge(s), %s"
               (match model.revealed with
               | true -> "shown"
               | false -> "hidden")
               model.edges
               (match model.acknowledged with
               | true -> "acknowledged"
               | false -> "not acknowledged"));
        ];
    ]

let serialize_model model =
  Printf.sprintf "focus_note=%b; focus_edges=%d; focus_ack=%b;" model.revealed
    model.edges model.acknowledged

let serialize_msg msg =
  match msg with
  | Focus_entered -> "FocusReveal:Focus_entered;"
  | Focus_left -> "FocusReveal:Focus_left;"
  | Hint_acknowledged -> "FocusReveal:Hint_acknowledged;"
  | Demo_reset -> "FocusReveal:Demo_reset;"
