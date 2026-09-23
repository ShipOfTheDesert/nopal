(** Button variant — determines default styling. *)
type variant = Primary | Secondary | Destructive | Ghost | Icon

type 'msg config = {
  variant : variant;
  disabled : bool;
  loading : bool;
  on_click : 'msg option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
  disabled_style : Nopal_style.Style.t option;
  loading_style : Nopal_style.Style.t option;
  button_type : Nopal_element.Element.button_type;
}
(** Button configuration. All fields except [variant] have sensible defaults.

    [disabled_style] and [loading_style] are the state-treatment override
    surface, and [button_type] says whether the button submits the form that
    encloses it. The supported route to those three is {!with_disabled_style},
    {!with_loading_style} and {!with_button_type} rather than writing them by
    hand; they are fields because a setter needs somewhere to put its value, and
    a caller who builds this record as a complete literal must supply them. *)

val default : variant -> 'msg config
(** [default v] returns a config for variant [v] with [disabled = false],
    [loading = false], [on_click = None], default style/interaction, empty
    attrs, no disabled or loading style, and [button_type = Push]: a button
    submits the form it sits in only when it is given [Submit]. *)

val with_button_type :
  Nopal_element.Element.button_type -> 'msg config -> 'msg config
(** [with_button_type t config] makes the button's type [t]. With [Submit],
    activating the button inside a {!Nopal_element.Element.form} dispatches its
    [on_click] and then submits the form; with [Push] it dispatches its
    [on_click] alone. *)

val with_disabled_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_disabled_style style config] gives the button [style] while
    [config.disabled] is [true]. It {e replaces} whatever the button would
    otherwise carry — [config.style] when the caller set one, the variant
    default otherwise; nothing is merged.

    Without it a disabled button looks exactly like an enabled one, which is
    what it has always done: the component draws no distinction of its own and
    {!view}'s [aria-disabled] is the only difference. So this setter introduces
    the visual decision rather than replacing one, and a button that sets
    neither state style renders as before.

    It does not touch [aria-disabled] or the inert state, both of which follow
    [config.disabled] and [config.loading] alone. *)

val with_loading_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_loading_style style config] gives the button [style] while
    [config.loading] is [true], on the same replacing terms as
    {!with_disabled_style}.

    When both states are true, the disabled style wins if it is set, and this
    one applies only if it is not. It does not touch [aria-busy] or
    [aria-disabled], both of which a loading button carries regardless, or the
    inert state. *)

val view :
  'msg config -> 'msg Nopal_element.Element.t -> 'msg Nopal_element.Element.t
(** [view config child] renders a button element of type [config.button_type].

    While [config.disabled] or [config.loading] is [true], the button is inert.
    A click on it dispatches nothing and submits nothing. An Enter in a field of
    its form does not submit through it either: when it is the form's first
    submit button, that Enter dispatches nothing at all, even if an enabled
    submit button follows it. The button stays focusable and in the tab order,
    and a focused button keeps focus when it becomes inert. Assistive technology
    announces it as disabled through [("aria-disabled", "true")], and a loading
    button also carries [("aria-busy", "true")].

    The [config.style] and [config.interaction] fields, when [Some], override
    the variant's default styling. On top of that, a button in a suppressed
    state carries {!with_disabled_style}'s style while [disabled] is [true],
    else {!with_loading_style}'s while [loading] is [true], else the style above
    — disabled first when both hold. A button with neither state style set
    renders exactly as it did before those setters existed.

    User-supplied [config.attrs] are merged with ARIA attrs (user attrs take
    precedence on conflict), except for ["type"] and ["aria-disabled"]: those
    are derived from [config.button_type] and the inert state, so a caller's
    ["type"] pair never takes effect and a caller's ["aria-disabled"] pair only
    while the button is neither disabled nor loading. *)

val variant_to_string : variant -> string
(** [variant_to_string v] returns a lowercase string name for test/debug. *)
