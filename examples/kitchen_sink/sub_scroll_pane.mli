(** Relative-scroll kitchen sink subapp.

    A fixed-height pane of paragraphs of unequal height that the model moves by
    a signed multiple of the pane's own visible height. Nothing here measures
    anything: the application asks for half a viewport and the backend, which is
    the only party that knows the pane's geometry, works out where that lands.

    The pane carries a DOM id of its own, which is how a request names it. That
    is the difference between this section and the reveal section beside it: a
    reveal names a keyed descendant and is compared for change, while a relative
    movement is not idempotent and cannot be compared at all, so it is issued as
    a command and acted on exactly once.

    One container carries both declarations at once, and the waypoint control
    changes the reveal and issues a relative movement in the same update. Both
    write the same scroll offset, so the section is the visible form of the
    order they are applied in: the reveal moves the pane first and the relative
    movement then moves it again from wherever the reveal left it.

    A third control is the order's last stage, and the only one no shim can
    settle. It moves the pane a whole viewport and focuses a field a paragraph
    well down the pane carries, in one update, leaving the reveal alone so that
    exactly two writers contend. The focus is drained after the relative
    movement and carries no [preventScroll], so the browser's own
    scroll-into-view has the final word: the pane comes to rest where focus put
    it, not where the movement asked for.

    Two things a browser-level test needs and cannot read off the screen. The
    Ctrl chords are a document-level subscription that prevents the browser
    default, so they stay unsubscribed until the [data-field="scroll-pane-keys"]
    checkbox is ticked: Ctrl+D is the browser's own bookmark shortcut, and a
    permanently-live subscription would take it away from every other section on
    the page. And the model holds no scroll offset, because the offset lives in
    the container and nothing reports it back — so the only thing telemetry can
    show is that a movement was asked for, which is what the move counter in
    {!serialize_model} exists to say. *)

val container_id : string
(** The DOM id the pane is rendered with, and the same string every request
    names it by. One constant rather than two literals, so a request cannot
    address a container this section does not render. *)

val row_keys : string list
(** Every paragraph's key, in the order the paragraphs are rendered. The
    paragraphs are fixed: neither their number nor their heights change with the
    model, so only the viewport ever moves. *)

val waypoint_keys : string list
(** The keys of the paragraphs the waypoint control cycles through, in cycle
    order. Both sit far enough down the pane that reaching either is a real
    movement, and far enough from the end that the half-viewport nudge which
    follows the reveal has somewhere to go. The cycle is over these keys alone:
    once the control has been used the marker never returns to the first
    paragraph. *)

val focus_target_id : string
(** The DOM id of the focusable field one paragraph carries, and the id the
    focus control's [Cmd.focus] names. One constant rather than two literals,
    for the same reason {!container_id} is one. The field sits far enough down
    the pane to be off screen when the section loads — focusing a row already in
    view moves nothing — and far enough from the end that the browser can align
    it without the pane clamping at its own maximum offset. *)

type model = {
  marker : string;
      (** Key of the paragraph the pane is currently asked to bring into view.
          It starts on the first paragraph, whose top the pane already shows, so
          the first render asks for no movement at all. *)
  keys_enabled : bool;
      (** Whether the two Ctrl chords are currently subscribed. *)
  moves : int;
      (** How many relative movements have been asked for since the page loaded.
          Nothing the section does depends on it — no request, no reveal and no
          subscription is derived from it. It is rendered into the readout and
          reported by {!serialize_model} so that a test driving the same
          interaction twice has a model value that differs between the two,
          which a repeated message alone does not give it. *)
}
(** The subapp model. It holds no scroll offset: the offset is the container's
    and no channel reports it back, which is the whole reason a relative
    movement has to be expressed as a multiple of the visible height rather than
    computed here. *)

(** The subapp's messages. *)
type msg =
  | Half_page_down  (** Move the pane forward by half its own visible height. *)
  | Half_page_up
      (** Move it back by the same amount. A pane already at the start does not
          move, and that is not an error. *)
  | Waypoint_advanced
      (** Cycle the revealed paragraph to the next waypoint and, in the same
          update, ask the pane to back off half a viewport from wherever the
          reveal leaves it. The one control that exercises both writers at once.
      *)
  | Far_row_focused
      (** Ask the pane to move forward a whole visible height — not the half the
          chords use, so the position the movement alone would reach is outside
          every position focus could leave the pane in — and, in the same
          update, focus the field at {!focus_target_id}. The one control that
          reaches the last stage of the drain order: focus is applied after the
          relative movement and takes no [preventScroll], so the browser's own
          scroll-into-view has the final word on where the pane rests. The
          revealed paragraph is deliberately left alone, so exactly two of the
          three writers contend. *)
  | Keys_toggled of bool  (** Subscribe or unsubscribe the two Ctrl chords. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model: the first paragraph marked, the chords unsubscribed, no
    movements asked for, and no command. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Moves the marker or the keyboard gate, and emits the relative-scroll
    requests — batched with a focus for {!Far_row_focused}. A request is emitted
    once per message and never replayed, so two identical presses move the pane
    twice. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the keyboard toggle, the waypoint control, the focus control, a
    readout of the marker and the move count, and the pane itself carrying its
    id, its test anchor and the paragraph it is asked to reveal. One paragraph
    down the pane carries the focusable field at {!focus_target_id}: [Cmd.focus]
    does nothing to a plain box, so the row a focus names has to be something
    the platform will focus. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** The two Ctrl chords when the keyboard gate is on, and nothing at all when it
    is off. Both prevent the browser default, which is what the gate exists to
    keep from being permanent. *)

val serialize_model : model -> string
(** Telemetry serializer. Each field is terminated with a trailing [;] so a
    substring assertion cannot prefix-alias a longer value, and the marker is
    quoted so punctuation inside a key cannot look like a delimiter. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, also [;]-terminated. Lives
    here rather than at the entry point so the message and model fragments stay
    described by one module. *)
