(** Pure structural test renderer for Nopal elements.

    Renders ['msg Element.t] into an inspectable [node] tree, provides query
    helpers and event simulation, and runs MVU loop cycles — all without a
    browser or js_of_ocaml. *)

(** {1 Node tree} *)

type node =
  | Empty
  | Text of { content : string; text_style : Nopal_style.Text.t option }
  | Element of {
      tag : string;
      attrs : (string * string) list;
      children : node list;
      interaction : Nopal_style.Interaction.t;
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

val text_style : node -> Nopal_style.Text.t option
(** [text_style node] returns [Some style] if the node is a [Text] with a text
    style set, [None] for plain [Text], [Empty], and [Element] nodes. *)

val interaction : node -> Nopal_style.Interaction.t option
(** [interaction node] returns [Some interaction] if the node is an [Element],
    [None] for [Empty] and [Text]. *)

val has_hover : node -> bool
(** [has_hover node] returns [true] if the node is an [Element] whose
    interaction has a hover style set. *)

val has_pressed : node -> bool
(** [has_pressed node] returns [true] if the node is an [Element] whose
    interaction has a pressed style set. *)

val has_focused : node -> bool
(** [has_focused node] returns [true] if the node is an [Element] whose
    interaction has a focused style set. *)

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

val toggle : selector -> 'msg rendered -> (unit, error) result
(** [toggle selector rendered] finds the first checkbox matching [selector],
    reads its [checked] attribute, and invokes its [on_toggle] handler with the
    negated value. Returns [Error (Not_found selector)] if no element matches,
    [Error (No_handler ...)] if the element has no toggle handler. *)

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

val pointer_move :
  selector -> x:float -> y:float -> 'msg rendered -> (unit, error) result
(** [pointer_move selector ~x ~y rendered] finds the first canvas element
    matching [selector], invokes its [on_pointer_move] handler with the given
    coordinates, and appends the resulting message. Returns
    [Error (Not_found selector)] if no element matches, [Error (No_handler ...)]
    if the element has no pointer_move handler. *)

val pointer_click :
  selector -> x:float -> y:float -> 'msg rendered -> (unit, error) result
(** [pointer_click selector ~x ~y rendered] finds the first canvas element
    matching [selector], invokes its [on_click] handler with the given
    coordinates, and appends the resulting message. Returns
    [Error (Not_found selector)] if no element matches, [Error (No_handler ...)]
    if the element has no pointer_click handler. *)

val pointer_leave : selector -> 'msg rendered -> (unit, error) result
(** [pointer_leave selector rendered] finds the first canvas element matching
    [selector], invokes its [on_pointer_leave] handler, and appends the
    resulting message. Returns [Error (Not_found selector)] if no element
    matches, [Error (No_handler ...)] if the element has no pointer_leave
    handler. *)

val pointer_down :
  selector -> x:float -> y:float -> 'msg rendered -> (unit, error) result
(** [pointer_down selector ~x ~y rendered] finds the first canvas element
    matching [selector], invokes its [on_pointer_down] handler with the given
    coordinates, and appends the resulting message. *)

val pointer_up :
  selector -> x:float -> y:float -> 'msg rendered -> (unit, error) result
(** [pointer_up selector ~x ~y rendered] finds the first canvas element matching
    [selector], invokes its [on_pointer_up] handler with the given coordinates,
    and appends the resulting message. *)

val draw_wheel :
  selector ->
  delta_y:float ->
  x:float ->
  y:float ->
  'msg rendered ->
  (unit, error) result
(** [draw_wheel selector ~delta_y ~x ~y rendered] finds the first canvas element
    matching [selector], invokes its [on_wheel] handler with the given delta and
    coordinates, and appends the resulting message. *)

(** {2 Box pointer/wheel events} *)

val box_pointer_move :
  selector -> x:float -> y:float -> 'msg rendered -> (unit, error) result
(** [box_pointer_move selector ~x ~y rendered] finds the first box element
    matching [selector], invokes its [on_pointer_move] handler with the given
    coordinates, and appends the resulting message. Returns
    [Error (Not_found selector)] if no element matches, [Error (No_handler ...)]
    if the element has no pointer_move handler. *)

val box_pointer_leave : selector -> 'msg rendered -> (unit, error) result
(** [box_pointer_leave selector rendered] finds the first box element matching
    [selector], invokes its [on_pointer_leave] handler, and appends the
    resulting message. Returns [Error (Not_found selector)] if no element
    matches, [Error (No_handler ...)] if the element has no pointer_leave
    handler. *)

val box_pointer_down :
  selector -> x:float -> y:float -> 'msg rendered -> (unit, error) result
(** [box_pointer_down selector ~x ~y rendered] finds the first box element
    matching [selector], invokes its [on_pointer_down] handler with the given
    coordinates, and appends the resulting message. *)

val box_pointer_up :
  selector -> x:float -> y:float -> 'msg rendered -> (unit, error) result
(** [box_pointer_up selector ~x ~y rendered] finds the first box element
    matching [selector], invokes its [on_pointer_up] handler with the given
    coordinates, and appends the resulting message. *)

val box_wheel :
  selector ->
  delta_y:float ->
  x:float ->
  y:float ->
  'msg rendered ->
  (unit, error) result
(** [box_wheel selector ~delta_y ~x ~y rendered] finds the first box element
    matching [selector], invokes its [on_wheel] handler with the given delta and
    coordinates, and appends the resulting message. *)

(** {1 MVU loop} *)

val run_app :
  init:(unit -> 'model * 'msg Nopal_mvu.Cmd.t) ->
  update:('model -> 'msg -> 'model * 'msg Nopal_mvu.Cmd.t) ->
  view:(Nopal_element.Viewport.t -> 'model -> 'msg Nopal_element.Element.t) ->
  ?viewport:Nopal_element.Viewport.t ->
  'msg list ->
  'model * 'msg rendered
(** [run_app ~init ~update ~view ?viewport msgs] runs a minimal MVU loop: calls
    [init] to get the initial model (ignoring the command), folds [update] over
    [msgs] (ignoring commands), calls [view viewport] on the final model, and
    renders the result. [viewport] defaults to
    {!Nopal_element.Viewport.desktop}. Returns the final model and the rendered
    output. *)

val run_app_with_cmds :
  init:(unit -> 'model * 'msg Nopal_mvu.Cmd.t) ->
  update:('model -> 'msg -> 'model * 'msg Nopal_mvu.Cmd.t) ->
  view:(Nopal_element.Viewport.t -> 'model -> 'msg Nopal_element.Element.t) ->
  ?viewport:Nopal_element.Viewport.t ->
  'msg list ->
  'model * 'msg rendered * 'msg Nopal_mvu.Cmd.t list
(** [run_app_with_cmds ~init ~update ~view ?viewport msgs] is like {!run_app}
    but also collects all commands produced during [init] and each [update].
    Returns the final model, rendered output, and the list of commands in order
    (init command first, then one per update message). *)
