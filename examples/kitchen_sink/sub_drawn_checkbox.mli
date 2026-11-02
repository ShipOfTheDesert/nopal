(** A drawn checkbox — kitchen sink section.

    The platform's checkbox replaced by a box drawn from typed styles: a square
    with a 1 px hairline border and a radius of 4 on the field colour, which
    fills teal with a white tick when ticked. The box is 20 px on a compact
    viewport and 18 px otherwise. Styles carry no breakpoints, so the size is
    this view's own choice from the viewport it is handed, the way any view
    chooses its layout.

    The body goes under a section titled by its caller and holds six examples,
    each a checkbox carrying an [aria-label] and a [data-testid]:

    - [drawn-checkbox-unticked]: the design, starting unticked;
    - [drawn-checkbox-ticked]: the design, starting ticked;
    - [drawn-checkbox-focus-ring]: the design with a focused style that draws a
      2 px ring as a shadow — zero offset, zero blur, a spread of 2 — because a
      style has no outline of its own, and a ticked style that sets no shadow
      leaves the ring in place while the box is ticked;
    - [drawn-checkbox-inline]: the design with no interaction states at all, the
      shape whose base style would otherwise be applied inline;
    - [drawn-checkbox-hover-background]: the design with a hover style that sets
      a background, which the ticked fill still wins over while ticked;
    - [drawn-checkbox-disabled]: disabled and ticked. Nopal adds no disabled
      look to a drawn box, so this example switches both its base style and its
      ticked style to muted ones itself. It dispatches nothing.

    Every example except the disabled one toggles through {!msg}. *)

(** Which of the five toggleable examples a message is about. *)
type example =
  | Unticked_start  (** [drawn-checkbox-unticked]. *)
  | Ticked_start  (** [drawn-checkbox-ticked]. *)
  | Focus_ring  (** [drawn-checkbox-focus-ring]. *)
  | No_interaction  (** [drawn-checkbox-inline]. *)
  | Hover_background  (** [drawn-checkbox-hover-background]. *)

type model
(** The ticked state of each toggleable example. *)

(** The section's messages. *)
type msg =
  | Toggled of example * bool
      (** The example was toggled to the given ticked state. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Every toggleable example unticked except [Ticked_start]. No command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Toggled (example, ticked)] records [ticked] for [example] and nothing else.
    No command. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the six examples, each beside a line of text saying what it shows.
*)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, prefixed with
    [DrawnCheckbox:] and terminated with [;] so one fragment cannot prefix-alias
    another: for example [DrawnCheckbox:Toggled:Unticked_start:true;]. *)
