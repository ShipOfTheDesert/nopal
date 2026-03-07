(** DOM renderer for Nopal element trees.

    Creates and patches real DOM nodes from ['msg Element.t] values. Manages
    event listener lifecycle so that handlers are wired/unwired on
    reconciliation. *)

type 'msg t
(** Opaque handle to a rendered DOM subtree. Holds the live node tree for
    reconciliation on the next update. *)

val create :
  dispatch:('msg -> unit) ->
  parent:Brr.El.t ->
  'msg Nopal_element.Element.t ->
  'msg t
(** [create ~dispatch ~parent element] renders [element] into fresh DOM nodes,
    appends them to [parent], and returns a handle for future reconciliation.
    Event listeners dispatch messages via [dispatch]. *)

val update :
  dispatch:('msg -> unit) -> 'msg t -> 'msg Nopal_element.Element.t -> unit
(** [update ~dispatch handle new_element] reconciles the previously rendered
    tree against [new_element], patching the DOM in place. Reuses existing DOM
    nodes where possible. Updates event listeners if handlers changed. *)

val dom_node : 'msg t -> Jv.t
(** [dom_node handle] returns the top-level DOM node for this rendered tree.
    Returns a comment node for [Empty], a span for [Text], or the element node
    for all other variants. *)
