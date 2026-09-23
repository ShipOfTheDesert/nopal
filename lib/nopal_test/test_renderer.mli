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
      style : Nopal_style.Style.t;
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
    event simulation support. The message list starts empty.

    The rule this renderer implements is:
    {b typed-field derivations beat the [~attrs] list; within the list, the last
       pair wins.} Those are two tiers and they are not the same tier. A typed
    field sits above the list; a pair a component put into that list sits inside
    it and loses to a caller's later pair of the same name.

    The mechanism here is an overlay. A pair derived from a typed field is
    appended after the view's own [attrs], and a duplicate key resolves to the
    last pair, so a derivation wins lookup over a caller-supplied pair of the
    same name while every other pair the view declared is left where it was.
    Within [attrs] itself the same resolution applies: the last pair the view
    wrote is the one {!attr}, a {!By_attr} selector, and the selector {!click},
    {!input}, {!submit}, {!submit_form}, {!keydown} and {!select_files} resolve,
    all answer with.

    The web backend carries the same rule by a different mechanism — it applies
    the declared list before it writes any derivation — so on the keys it writes
    as real attributes the two renderers answer identically, which is the whole
    value of asserting on this one. Those keys are ["disabled"], ["accept"],
    ["capture"], ["multiple"], ["placeholder"], a radio's ["name"], a control's
    ["type"], an input's ["required"], ["aria-required"] and ["autocomplete"],
    and a form's ["autocomplete"] and ["novalidate"]. On ["disabled"],
    ["multiple"], ["required"] and ["novalidate"] the two agree on which side
    wins and not on the value: this renderer carries ["true"] where the browser
    carries a presence attribute. A checkbox's, radio's or file picker's
    ["type"] is this renderer's tag rather than a pair; an input's [input_type]
    is a ["type"] pair here as there. A box's [focusable] is a first-tier
    derivation in both, but each renderer spells it in its own vocabulary — a
    tab-order attribute there, ["focusable"] here — so there is no shared key to
    compare. ["checked"], ["value"] and ["selected"] are {e not} among them: the
    browser carries all three as JS properties and never as attributes, so a
    caller's pair of one of those names is not overruled there. This renderer
    still overlays them, as a faithful read-out of the typed field, and an
    assertion on one of the three is a statement about this renderer alone.
    [Element.draw] carries neither a style nor an attribute list, so it is
    structurally outside the rule, and a backend nobody has written is bound by
    nothing here: a rule holds where a test holds it.

    A derivation asserts a value and never denies one. Where a typed field
    declines — a picker configuring no [capture], a control that is not
    [disabled] — no pair is contributed for that key, so a pair [attrs] declared
    under the same name is uncovered rather than erased, and {!attr} reads back
    [None] where neither spoke. This holds for every declining derivation, the
    keys a browser spells as real attributes and whose absence it spells as
    removal, in one of two shapes. A [bool] asserts its key when [true] and
    contributes nothing when [false], so a [false] uncovers a caller's pair and
    cannot remove it: ["disabled"], ["multiple"], an input's ["required"] with
    the ["aria-required"] it carries, and a form's ["novalidate"]. An option, or
    an empty list, contributes nothing when absent: ["accept"], ["capture"], an
    input's ["autocomplete"] and its ["type"], and a form's ["autocomplete"]. An
    input's ["placeholder"] and a radio's ["name"] have no absent form and are
    contributed on every render.

    A scroll container's [reveal] declaration is surfaced for inspection as the
    derived attribute pairs ["reveal"] and ["reveal-align"], carried exactly as
    the view wrote them. A container that declares neither carries no attributes
    at all.

    Nothing marks a pair as derived, so the precedence does not run the other
    way: a container that supplies [("reveal", "decoy")] in [attrs] and declares
    no [reveal] reads back {!attr} ["reveal"] as [Some "decoy"], which is the
    caller's own attribute and not a declaration. A structural test asserting
    that a container asked for a reveal should use a key no [attrs] pair on that
    container spells.

    A box's [focusable] declaration is surfaced the same way, as the derived
    attribute ["focusable"] carrying the value ["true"]. It names the DSL's own
    concept rather than any platform's tab-order attribute, since how a tab stop
    is spelled is the backend's business. A box that is not focusable carries no
    such pair, so {!attr} ["focusable"] reads back [None] and every box that
    rendered before this attribute existed is unchanged. The precedence and the
    decoy caveat above apply here unaltered.

    Only the flag is surfaced. This renderer fires the selected node's own
    handler and models no event propagation, so the subtree scoping of a
    container's focus edges is not observable here and no assertion in this
    renderer may be read as evidence of it. *)

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

val style : node -> Nopal_style.Style.t option
(** [style node] returns [Some style] if the node is an [Element], [None] for
    [Empty] and [Text]. *)

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

val select_files :
  selector ->
  Nopal_element.Element.file_info list ->
  'msg rendered ->
  (unit, error) result
(** [select_files selector files rendered] finds the first file input matching
    [selector], invokes its file-selection handler with [files], and appends the
    resulting message. Passing [[]] simulates the user clearing the picker: the
    handler still fires, with an empty list, so a model tracking the selection
    is never left stale. Returns [Error (Not_found selector)] if no element
    matches, [Error (No_handler ...)] if the element has no file-selection
    handler. *)

val submit : selector -> 'msg rendered -> (unit, error) result
(** [submit selector rendered] finds the first element matching [selector],
    invokes its [on_submit] handler, and appends the resulting message. Returns
    [Error (Not_found selector)] if no element matches, [Error (No_handler ...)]
    if the element has no submit handler. A form's [on_submit] is not such a
    handler: [submit] on a form is [No_handler], and {!submit_form} is the
    simulator that reaches it. *)

val submit_form : selector -> 'msg rendered -> (unit, error) result
(** [submit_form selector rendered] finds the first element matching [selector],
    invokes the [on_submit] of the form it is, and appends the resulting
    message. Returns [Error (Not_found selector)] if no element matches, and
    [Error (No_handler { event = "submit"; _ })] if the element is not a form or
    is a form that authors no [on_submit]. It never walks: a field selected
    inside a form is not the form.

    Three simulators can reach a submit, and they are not synonyms.

    - {!submit} pokes the selected element's own [on_submit] — an input's —
      directly. It states what that handler dispatches once reached, not that a
      key reaches it: no [on_keydown] is consulted, and no form is reached.
    - {!submit_form} pokes the selected form's [on_submit] directly, standing
      for a submission however it arose — an Enter the form was deferred, or a
      submit button pressed. It consults no field's handlers, so it cannot show
      that an Enter in some field would have reached the form rather than been
      consumed on the way.
    - {!keydown} is the one that carries the submit contract: it presses a key
      in a field and follows {!Nopal_element.Submit_route.of_key} through the
      field's [on_keydown], then its [on_submit], then the nearest enclosing
      form's [on_submit]. A test asserting which handler answers an Enter uses
      [keydown]; the two pokes above cannot answer that question.

    None of the three models the platform's own share in a submission. A button
    inside a form submits it on the web — a button that names no type is a
    submit button there — but a structural {!click} reaches the button's own
    [on_click] only. And a browser submits a form on Enter only when the form
    has a submit button or holds a single text field, while [keydown] defers
    every unanswered Enter in a field to the form. Both are browser facts, and a
    browser-level test is where they are observed. *)

val dblclick : selector -> 'msg rendered -> (unit, error) result
(** [dblclick selector rendered] finds the first element matching [selector],
    invokes its [on_dblclick] handler, and appends the resulting message.
    Returns [Error (Not_found selector)] if no element matches,
    [Error (No_handler ...)] if the element has no dblclick handler. *)

val focus : selector -> 'msg rendered -> (unit, error) result
(** [focus selector rendered] finds the first element matching [selector],
    invokes its [on_focus] handler, and appends the resulting message. Returns
    [Error (Not_found selector)] if no element matches, [Error (No_handler ...)]
    if the element has no focus handler. *)

val blur : selector -> 'msg rendered -> (unit, error) result
(** [blur selector rendered] finds the first element matching [selector],
    invokes its [on_blur] handler, and appends the resulting message. Returns
    [Error (Not_found selector)] if no element matches, [Error (No_handler ...)]
    if the element has no blur handler. *)

val keydown : selector -> string -> 'msg rendered -> (unit, error) result
(** [keydown selector key rendered] finds the first element matching [selector]
    and answers a keydown of [key] on it by the submit contract that
    {!Nopal_element.Element} states and {!Nopal_element.Submit_route.of_key}
    decides, the same definition the web renderer answers from. The element's
    [on_keydown] is consulted first: [Some msg] appends [msg] and consumes the
    key. An Enter it declines, or an Enter on an element with no [on_keydown],
    goes on to the element's [on_submit] and appends that message. An Enter
    neither answers goes on to the nearest enclosing form and appends that
    form's [on_submit], or nothing when the form authors none. Any other key
    [on_keydown] declines appends nothing, and never reaches a form. At most one
    message is appended per call.

    Only an input defers to its form. An Enter on any other element inside a
    form reaches no form here, and a platform's own route from a key to a
    submission — a focused submit button activated by Enter, for one — is not
    modelled.

    An element carrying [on_submit] but no [on_keydown], or a bare input inside
    a form that authors [on_submit], therefore answers a keydown rather than
    returning [No_handler]: [Ok ()] with the answering message appended for
    Enter, and [Ok ()] with nothing appended for any other key.

    Returns [Error (Not_found selector)] if no element matches, and
    [Error (No_handler ...)] if the element has neither an [on_keydown] nor an
    [on_submit] handler and no enclosing form's [on_submit] stands behind it. *)

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

(** {2 Box focus events} *)

val box_focus : selector -> 'msg rendered -> (unit, error) result
(** [box_focus selector rendered] finds the first box element matching
    [selector], invokes its [on_focus] handler, and appends the resulting
    message. Returns [Error (Not_found selector)] if no element matches,
    [Error (No_handler ...)] if the element has no focus handler.

    This simulator fires the selected node's own handler and models no
    propagation. A real backend scopes a box's focus edges to its whole subtree,
    so focus landing on a descendant reaches the enclosing box and a move
    between two descendants of one box is not a leave; none of that is
    reproduced here. A structural test therefore pins which message a box
    dispatches, never which node's focus caused it, and cannot stand in for the
    browser-level test of the subtree behaviour. *)

val box_blur : selector -> 'msg rendered -> (unit, error) result
(** [box_blur selector rendered] finds the first box element matching
    [selector], invokes its [on_blur] handler, and appends the resulting
    message. Returns [Error (Not_found selector)] if no element matches,
    [Error (No_handler ...)] if the element has no blur handler.

    Like [box_focus], this fires the selected node's own handler and models no
    propagation; the subtree scoping a backend provides is not observable here.

    [blur] above is a distinct function resolving against an input, not a box.
*)

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
