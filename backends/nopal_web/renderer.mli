(** DOM renderer for Nopal element trees.

    Creates and patches real DOM nodes from ['msg Element.t] values. Manages
    event listener lifecycle so that handlers are wired/unwired on
    reconciliation. *)

type 'msg t
(** Opaque handle to a rendered DOM subtree. Holds the live node tree for
    reconciliation on the next update. *)

type opener =
  Nopal_element.Url.t ->
  ((unit, Nopal_element.Link.open_error) result -> unit) ->
  unit
(** [open_external url resolve] shows [url] outside the app, in the system
    browser, and calls [resolve] with the outcome. *)

(** Where links are rendered, which decides what a click on one does
    ({!Nopal_element.Link.decide}). *)
type link_host =
  | Browser
      (** A web browser. A click the link does not take over is left to the
          browser, which follows the link itself. *)
  | Webview of { open_external : opener }
      (** An application webview. A click on an external link is handed to
          [open_external], so the webview never navigates away from the app; the
          first answer settles the outcome: if it is [Error], the link's
          [on_open_failed] message is dispatched once; later answers are
          absorbed. An exception raised by [open_external] before it answers is
          that failure too, as [Failed] with a reason naming the exception's
          constructor only, since its message may carry the URL. *)

val create :
  ?link_host:link_host ->
  dispatch:('msg -> unit) ->
  parent:Brr.El.t ->
  'msg Nopal_element.Element.t ->
  'msg t
(** [create ?link_host ~dispatch ~parent element] renders [element] into fresh
    DOM nodes, appends them to [parent], and returns a handle for future
    reconciliation. Event listeners dispatch messages via [dispatch].

    [link_host] is where the links in the tree are rendered, for the life of the
    handle: every {!update} keeps it. A click on a link prevents the platform
    default only when the link takes the click over. Omitted, it is [Browser].
*)

val update :
  dispatch:('msg -> unit) -> 'msg t -> 'msg Nopal_element.Element.t -> unit
(** [update ~dispatch handle new_element] reconciles the previously rendered
    tree against [new_element], patching the DOM in place. Reuses existing DOM
    nodes where possible. Updates event listeners if handlers changed. *)

val reveal_request_count : 'msg t -> int
(** [reveal_request_count handle] is how many scroll containers asked, during
    the most recent {!create} or {!update}, for a child to be brought into view.
    A container asks when it gains a request or changes the one it carries, and
    never when it carries none or repeats the one it already had, so this counts
    changes rather than containers. The window is one pass: a pass clears the
    count before it patches anything, so the number always describes the pass
    that just finished and never accumulates across passes. Exposed for unit
    testing which changes are collected; not part of the behavioural API. *)

val container_main_axis :
  'msg Nopal_element.Element.t -> Style_css.main_axis option
(** [container_main_axis el] is the axis [el] lays its children out along, and
    [None] when [el] lays nothing out — it answers for the children, not for
    [el] itself, because whether a declared size can be squeezed is settled one
    level up.

    [Row] is always horizontal and [Column] always vertical: both write their
    direction onto the node after the style is applied, so the constructor wins
    over a style asking for the other axis. [Box] and [Form] read their style's
    direction, and an absent one means vertical here, not the horizontal an
    absent CSS [flex-direction] would mean. Every remaining variant is [None],
    including those holding a child: only these four are laid out as flex
    containers, so nothing else puts a child on a main axis. That last clause is
    a fact about the renderer rather than something derived from it — the same
    four variants, and only those four, call [apply_container_base_style] — so a
    fifth flex container added there needs an arm here in the same change, and a
    comment at that function says so from the other side.

    Exposed for unit testing the resolution; not part of the behavioural API. *)

val dom_node : 'msg t -> Jv.t
(** [dom_node handle] returns the top-level DOM node for this rendered tree.
    Returns a comment node for [Empty], a span for [Text], or the element node
    for all other variants — including the [<input type="file">] a [File_input]
    renders as. *)
