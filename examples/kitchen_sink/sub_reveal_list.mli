(** Reveal-a-child kitchen sink subapp.

    A keyboard-navigated list of rows of deliberately unequal height inside a
    fixed-height scroll container. The selection moves in the model, and the
    container follows because the view names the selected row as the child it
    wants brought into view. No application code here touches the DOM, measures
    anything, or moves focus.

    Two things a browser-level test needs and cannot read off the screen. The
    scroll container carries no attributes of its own — [Element.scroll] takes
    none, which is the gap this section exists to demonstrate — so it is reached
    as the only child of the box marked [data-testid="reveal-list-frame"]. And
    the arrow keys are a document-level subscription that prevents the browser
    default, so they stay unsubscribed until the [data-field="reveal-keys"]
    checkbox is ticked: left permanently on they would cancel arrow navigation
    everywhere else on the page, including the native radio group two sections
    away. *)

val row_keys : string list
(** Every row's key, in the order the rows are rendered. Keys look like file
    paths because the first consumer of a reveal keys its rows by path. *)

val hostile_key : string
(** The key of the one row whose key carries a double quote and a backslash.
    Rows are named by opaque application strings, so punctuation in a key must
    resolve to its row or do nothing at all; this row is what makes that claim
    executable rather than asserted. *)

type model = {
  selected : string;
      (** Key of the currently selected row, and therefore of the child the
          container is asked to bring into view. *)
  align : Nopal_element.Reveal.align;
      (** Where the revealed row is asked to come to rest. *)
  keys_enabled : bool;  (** Whether the arrow keys are currently subscribed. *)
}
(** The subapp model. The selection is held as a key rather than an index so the
    reveal request is derived from it directly, with no lookup that could fail.
*)

(** The subapp's messages. *)
type msg =
  | Select_next
      (** Move the selection one row down. The last row is a wall, not a wrap.
      *)
  | Select_previous
      (** Move it one row up. The first row is a wall, not a wrap. *)
  | Align_selected of Nopal_element.Reveal.align
      (** Choose the alignment the next reveal comes to rest under. *)
  | Keys_toggled of bool  (** Subscribe or unsubscribe the arrow keys. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model: the first row selected, the nearest alignment, and the arrow
    keys unsubscribed. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Moves the selection, the alignment or the keyboard gate. Nothing else
    happens: the container moves because the next view names a different child,
    not because this function asked it to. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the keyboard toggle, the four alignment controls, a readout of the
    current selection and alignment, and the scroll container holding every row
    keyed by its own key. The selected row is the child the container is asked
    to reveal. *)

val subscriptions : model -> msg Nopal_mvu.Sub.t
(** The two arrow keys when the keyboard gate is on, and nothing at all when it
    is off. Both prevent the browser default, so a page that would otherwise
    scroll underneath the list cannot mask the container moving. *)

val serialize_model : model -> string
(** Telemetry serializer. Each field is terminated with a trailing [;] so a
    substring assertion cannot prefix-alias a longer value, and the selected key
    is quoted so punctuation inside it cannot look like a delimiter. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, also [;]-terminated. Lives
    here rather than at the entry point so the message and model fragments stay
    described by one module. *)
