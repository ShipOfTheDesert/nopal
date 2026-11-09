(** Sideways-reveal kitchen sink subapp.

    A row of fixed-width tabs, far wider in total than the narrow scroll
    container holding it, and beside it a second container whose content
    overflows both ways. The chosen tab lives in the model, and the strip
    follows because the view names it as the child it wants brought into view;
    the second container names one far cell the same way. That cell lies wholly
    past the container's right edge and wholly below its bottom edge, and short
    of both far ends, so revealing it moves the container along both axes and
    stops before either limit. Two further strips repeat the tabs on a reversed
    x axis, one under [dir=rtl] and one in vertical-rl, to show that choosing a
    tab leaves their scrollLeft alone. No application code here touches the DOM,
    measures anything, or moves focus.

    The section mounts with the last tab chosen, so the strip has to move
    sideways on its very first render, before anyone has touched it: a current
    tab that is only shown once the choice changes is not shown on arrival.

    A browser-level test reaches the parts by these attributes. The strip is
    [data-testid="reveal-tabs-strip"] and the two-way container
    [data-testid="reveal-tabs-grid"], both on the scroll containers themselves.
    Tab [i], counting from [0], is [data-testid="reveal-tabs-tab-<i>"], and the
    cell at row [r] and column [c] is [data-testid="reveal-tabs-cell-<r>-<c>"].
    Two more strips repeat the tabs, keyed the same: [reveal-tabs-rtl-strip],
    with tabs [reveal-tabs-rtl-tab-<i>], is horizontal-tb under [dir=rtl]; and
    [reveal-tabs-vertical-strip], with tabs [reveal-tabs-vertical-tab-<i>], is
    rendered with no writing mode so a browser test can set vertical-rl on it.
    Both have a reversed x axis, so choosing a tab must not write their
    scrollLeft. The tab chooser is the select [data-field="reveal-tabs-choice"],
    whose option values are the tab keys. The alignment controls are the buttons
    [data-action="reveal-tabs-align-nearest"], [-start], [-center] and [-end].
    The readout of the current choice is [data-testid="reveal-tabs-readout"].
    The cover list, a vertical list whose rows are wider than it is, is
    [reveal-tabs-cover-list], with rows [reveal-tabs-cover-row-<i>] keyed like
    the tabs; its column is 700.4px wide, so each row's rect is fractional. *)

val tab_keys : string list
(** Every tab's key, in the order the tabs are rendered. *)

type model = {
  chosen : string;
      (** Key of the chosen tab, and therefore of the child the strip is asked
          to bring into view. *)
  align : Nopal_element.Reveal.align;
      (** Where the revealed child is asked to come to rest, in both containers.
      *)
}
(** The subapp model. The choice is held as a key rather than an index so the
    reveal request is derived from it directly, with no lookup that could fail.
*)

(** The subapp's messages. *)
type msg =
  | Tab_chosen of string
      (** Choose the tab with this key. A key naming no tab is held as given;
          the strip then asks for a child it does not contain, which moves
          nothing. *)
  | Align_selected of Nopal_element.Reveal.align
      (** Choose the alignment the next reveal comes to rest under. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** Initial model: the last tab chosen, under the nearest alignment. *)

val update : model -> msg -> model * msg Nopal_mvu.Cmd.t
(** Changes the choice or the alignment. Nothing else happens: a container moves
    because the next view names a different request, not because this function
    asked it to. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** Renders the tab chooser, the four alignment controls, a readout of the
    choice and alignment, the strip of tabs each keyed by its own key, the
    right-to-left strip and the vertical-rl strip (a captioned column) that
    repeat the tabs on a reversed x axis, and the two-way container of cells,
    whose rows and cells are keyed too, and the cover list of rows wider than
    itself, captioned and keyed like the tabs. *)

val serialize_model : model -> string
(** Telemetry serializer. Each field is terminated with a trailing [;] so a
    substring assertion cannot prefix-alias a longer value, and the chosen key
    is quoted so punctuation inside it cannot look like a delimiter. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, also [;]-terminated. *)
