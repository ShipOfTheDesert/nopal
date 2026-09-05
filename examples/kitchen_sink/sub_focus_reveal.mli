(** Focus-revealed note kitchen sink subapp.

    A focusable container that shows a note while focus is anywhere inside it
    and hides the note again once focus has left the whole container. This is
    the keyboard-accessible tooltip: the note is reachable with the keyboard
    alone, and it is the model, not a style rule, that decides whether it is on
    screen.

    That distinction is the point of the section. A [:focus] style rule can
    already recolour a container, but nothing the model holds changes when it
    fires, so nothing can be rendered, counted or reported from it. Here the
    container dispatches a message on each focus edge, the update function flips
    a flag, and the note is a child the view renders or does not render.

    The container's edges cover its whole subtree. Focus arriving on anything
    inside it is an arrival, and only focus leaving every element inside it is a
    departure — which is why the note survives the user reaching the control
    inside the note itself. A container whose note vanished the moment the user
    tabbed into it would be unusable by keyboard, and that control exists to put
    the case on screen rather than leave it to a test.

    Two things a browser-level test needs and cannot read off the screen. The
    first is that tabbing from the container into the control inside the note
    fires no edge at all: the note staying on screen does not prove it, because
    a departure immediately followed by an arrival would leave the note on
    screen too, and the two are indistinguishable by looking. The edge count in
    {!serialize_model} is what separates them, and it is the only thing here
    that does. The second is that the reveal has exactly one writer. The reset
    control clears the edge count and the acknowledgement and deliberately
    leaves the reveal alone, so no assertion about the note can be satisfied by
    a control that set it directly. *)

type model = {
  revealed : bool;
      (** Whether the note is currently rendered. Written by the two focus edges
          and by nothing else, so what is on screen is exactly what the platform
          last reported about focus. *)
  edges : int;
      (** How many focus edges the container has reported since the count was
          last cleared. Nothing rendered depends on it beyond the readout: it
          exists so that a spec can tell "no edge was reported" from "a
          departure and an arrival were reported in that order", which the
          reveal flag alone cannot distinguish because both leave it set. *)
  acknowledged : bool;
      (** Whether the control inside the note has been used. It is the note's
          own focusable child, and the reason the container has a focusable
          descendant at all. *)
}
(** The subapp model. *)

(** The subapp's messages. *)
type msg =
  | Focus_entered
      (** Focus arrived somewhere inside the container. Reveals the note and
          counts an edge. *)
  | Focus_left
      (** Focus left the container entirely. Hides the note and counts an edge.
          Moving between two elements inside the container is not this message:
          the platform reports the move, and the backend's containment guard
          rules it out before any message is dispatched. *)
  | Hint_acknowledged
      (** The control inside the note was used. It changes the model so that
          reaching the control by keyboard has a visible result, rather than
          being a tab stop that does nothing. *)
  | Demo_reset
      (** Clear the edge count and the acknowledgement. The control that sends
          it sits immediately before the container in tab order, which is what
          gives a keyboard-driven test somewhere deterministic to start from
          instead of counting tab stops from the top of the page. It does not
          touch the reveal. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model: the note hidden, no edges reported, the note's control not
    yet used, and no command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Applies the message to the model. Emits no commands at all: every edge is
    inbound, and nothing here asks the platform to do anything. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the reset control, the focusable container carrying both edge
    handlers, the note when the model says it is revealed, and a readout of the
    reveal state, the edge count and the acknowledgement. The container is
    labelled and given a grouping role: a tab stop with no accessible name is
    reachable and unannounced, which is worse for a screen reader than not being
    reachable at all.

    The container also carries a focused interaction style, and it is the one
    thing here the model has no part in: the ring is a [:focus-visible] rule the
    browser applies, while the note is a transition the two events caused. Both
    mechanisms are on screen precisely because the section's subject is the
    difference between them, and because a tab stop with no visible focus
    indicator is worse than one the keyboard cannot reach. The ring is a shadow
    drawn by spread alone rather than a wider border, so it paints outside the
    container without displacing anything after it. *)

val serialize_model : model -> string
(** Telemetry serializer. Each field is terminated with a trailing [;] so a
    substring assertion cannot prefix-alias a longer value — an edge count of 1
    is otherwise a prefix of 12 — and the field names are prefixed so they
    cannot collide with another section's fragments in the same string. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, also [;]-terminated. Lives
    here rather than at the entry point so the message and model fragments stay
    described by one module. *)
