(** Pure structural test renderer for Nopal elements.

    Renders ['msg Element.t] into an inspectable [node] tree, provides query
    helpers and event simulation, and runs MVU loop cycles — all without a
    browser or js_of_ocaml. *)

(** {1 Node tree} *)

type node =
  | Empty
  | Text of string
  | Element of {
      tag : string;
      attrs : (string * string) list;
      children : node list;
    }

(** {1 Selectors} *)

type selector =
  | By_tag of string
  | By_text of string
  | By_attr of string * string
  | First_child
  | Nth_child of int

(** {1 Rendered output} *)

type 'msg rendered
(** Opaque rendered tree with message accumulator and event handlers. *)

(** {1 Rendering} *)

val render : 'msg Nopal_element.Element.t -> 'msg rendered
(** [render element] renders an element tree into an inspectable node tree with
    event simulation support. The message list starts empty. *)

(** {1 Accessors} *)

val tree : 'msg rendered -> node
(** [tree rendered] returns the inspectable node tree. *)

val messages : 'msg rendered -> 'msg list
(** [messages rendered] returns the accumulated message list, oldest first. *)

val clear_messages : 'msg rendered -> unit
(** [clear_messages rendered] resets the message accumulator to empty. *)

(** {1 Querying} *)

val find : selector -> node -> node option
(** [find selector node] returns the first node matching [selector], searching
    depth-first. [By_text] matches [Text] nodes whose content contains the given
    substring. [First_child] and [Nth_child] select children of the given node
    by position (0-indexed). *)

val find_all : selector -> node -> node list
(** [find_all selector node] returns all nodes matching [selector], in
    depth-first order. [First_child] and [Nth_child] always return [[]] —
    positional selectors are meaningful only for single-node lookup via [find].
*)

val text_content : node -> string
(** [text_content node] returns the concatenated text of all [Text] descendants.
    Returns [""] for [Empty]. *)

val has_attr : string -> node -> bool
(** [has_attr name node] returns [true] if the node is an [Element] with an
    attribute named [name]. *)

val attr : string -> node -> string option
(** [attr name node] returns [Some value] if the node is an [Element] with an
    attribute named [name], [None] otherwise. *)

(** {1 Event simulation} *)

type error =
  | Not_found of selector
  | No_handler of { tag : string; event : string }

val click : selector -> 'msg rendered -> (unit, error) result
(** [click selector rendered] finds the first element matching [selector],
    invokes its [on_click] handler, and appends the resulting message. Returns
    [Error (Not_found selector)] if no element matches, [Error (No_handler ...)]
    if the element has no click handler. *)

val input : selector -> string -> 'msg rendered -> (unit, error) result
(** [input selector value rendered] finds the first input matching [selector],
    invokes its [on_change] handler with [value], and appends the resulting
    message. Returns [Error (Not_found selector)] if no element matches,
    [Error (No_handler ...)] if the element has no change handler. *)

val submit : selector -> 'msg rendered -> (unit, error) result
(** [submit selector rendered] finds the first element matching [selector],
    invokes its [on_submit] handler, and appends the resulting message. Returns
    [Error (Not_found selector)] if no element matches, [Error (No_handler ...)]
    if the element has no submit handler. *)

val dblclick : selector -> 'msg rendered -> (unit, error) result
(** [dblclick selector rendered] finds the first element matching [selector],
    invokes its [on_dblclick] handler, and appends the resulting message.
    Returns [Error (Not_found selector)] if no element matches,
    [Error (No_handler ...)] if the element has no dblclick handler. *)

val blur : selector -> 'msg rendered -> (unit, error) result
(** [blur selector rendered] finds the first element matching [selector],
    invokes its [on_blur] handler, and appends the resulting message. Returns
    [Error (Not_found selector)] if no element matches, [Error (No_handler ...)]
    if the element has no blur handler. *)

val keydown : selector -> string -> 'msg rendered -> (unit, error) result
(** [keydown selector key rendered] finds the first element matching [selector]
    and invokes its [on_keydown] handler with [key]. If the handler returns
    [Some msg], the message is appended; if [None], no message is dispatched.
    Returns [Error (Not_found selector)] if no element matches,
    [Error (No_handler ...)] if the element has no keydown handler. *)

(** {1 MVU loop} *)

val run_app :
  init:(unit -> 'model * 'msg Nopal_mvu.Cmd.t) ->
  update:('model -> 'msg -> 'model * 'msg Nopal_mvu.Cmd.t) ->
  view:('model -> 'msg Nopal_element.Element.t) ->
  'msg list ->
  'model * 'msg rendered
(** [run_app ~init ~update ~view msgs] runs a minimal MVU loop: calls [init] to
    get the initial model (ignoring the command), folds [update] over [msgs]
    (ignoring commands), calls [view] on the final model, and renders the
    result. Returns the final model and the rendered output. *)
