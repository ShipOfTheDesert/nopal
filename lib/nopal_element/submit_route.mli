(** Which handler answers a keydown on an input — the submit contract, written
    once.

    Everything here is pure and compiles on native OCaml; it references nothing
    else in this package. Both renderers answer a keydown on an input by calling
    {!of_key} and carrying out the route it returns, so the contract is decided
    here and nowhere else: a renderer that resolved it independently could drift
    from the other and from this definition.

    The rule is one sentence:
    {b the nearest handler that accepts the Enter consumes it.} Three handlers
    can accept an Enter, nearest first — the input's [on_keydown], then the
    input's [on_submit], then the enclosing form's [on_submit]. A handler that
    accepts the Enter consumes it, and no handler further out sees it, so the
    route picks at most one of the three. That is not the same as one message
    per Enter: an Enter routed to the form is the platform's implicit
    submission, which clicks the form's default button when it has one, so that
    button's [on_click] is dispatched and then the form's [on_submit]. Which
    button that is, and whether the form submits at all, is decided outside this
    module.

    The cost of the rule is stated rather than hidden: in a form where one field
    carries its own [on_submit], Enter in that field dispatches a different
    message than Enter anywhere else in the form. That is the reason to author
    submission at one level — the form, or each input — and not to mix the two.

    Suppression of the platform default is narrower than consumption. Only an
    Enter suppresses it, because Enter is the only key that makes a form submit
    implicitly. A consuming [on_keydown] on any other key leaves that key's
    default in place, so a handler that records every keystroke does not stop
    its own input from receiving text. *)

(** The route a keydown takes. *)
type 'msg t =
  | Dispatch of { msg : 'msg; prevent_default : bool }
      (** A handler on this input answered: dispatch [msg] exactly once. When
          [prevent_default] is [true] the renderer must suppress the platform
          default for the key, which for an Enter is the enclosing form's
          implicit submission. It is [true] exactly when the key is Enter. *)
  | To_enclosing_form
      (** Nothing on this input answered an Enter. It is left to the enclosing
          form's implicit submission, which clicks the form's first submit
          button unless that button is disabled, and with no submit button
          submits only a form holding a single field that blocks implicit
          submission. With no enclosing form, nothing happens. The renderer
          dispatches nothing here on the input's behalf. *)
  | Nothing
      (** Nothing on this input answered a key other than Enter, and nothing
          further out will: no key but Enter reaches a form. *)

val of_key :
  key:string ->
  on_keydown:(string -> 'msg option) option ->
  on_submit:'msg option ->
  'msg t
(** [of_key ~key ~on_keydown ~on_submit] is the route a keydown of [key] takes
    on an input carrying [on_keydown] and [on_submit].

    [key] is the key's name as the platform reports it, Enter being ["Enter"]
    exactly. [on_keydown] is consulted first, and its answer is the consumption
    signal: [Some msg] consumes the key, whatever key it is, and the route is
    [Dispatch] of that message with [prevent_default] set only for Enter; [None]
    declines it, as does an absent handler. A declined Enter goes to
    [on_submit]: when present the route is [Dispatch] of it with
    [prevent_default] set, so the enclosing form does not also submit; when
    absent the route is [To_enclosing_form]. A declined key other than Enter is
    [Nothing], and [on_submit] never answers one.

    Total: every combination of arguments answers a route and none raises.

    Known limitation: [key] carries no notion of IME composition. WebKit reports
    [key = "Enter"] for the Enter that commits an IME composition, not only for
    the Enter that follows it, so an [on_keydown] or [on_submit] that answers
    ["Enter"] here also answers a composition-commit Enter, and the renderer
    suppresses the platform default for it exactly as it would for an ordinary
    Enter. The follow-up, due when a CJK-input consumer needs it, is an
    [isComposing] check at the FFI edge, ahead of the call into this module. *)
