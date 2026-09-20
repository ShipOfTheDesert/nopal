(** Accessible radio button group component. *)

type radio_option = { label : string; value : string; disabled : bool }
(** A single option within a radio group. Use {!val-radio_option} to construct.
*)

type 'msg config = {
  label : string;
  options : radio_option list;
  selected : string;
  disabled : bool;
  name : string option;
  on_select : (string -> 'msg) option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
  id : string option;
  visible_label : bool option;
  label_style : Nopal_style.Style.t option;
  group_style : Nopal_style.Style.t option;
  option_label_style : Nopal_style.Style.t option;
  option_row_style : Nopal_style.Style.t option;
  on_label_click : (string -> 'msg) option;
}
(** Radio group configuration. [label], [options], and [selected] are
    behavioural — all required in {!make}.

    [style] and [interaction] land on each radio input, not on the group; the
    group container is {!with_group_style}.

    The last seven fields are the override surface. The supported route to them
    is {!with_id}, {!with_visible_label}, {!with_label_style},
    {!with_group_style}, {!with_option_label_style}, {!with_option_row_style}
    and {!with_on_label_click} rather than writing them by hand; they are fields
    because a setter needs somewhere to put its value, and a caller who builds
    this record as a complete literal must supply them. *)

val radio_option : ?disabled:bool -> value:string -> string -> radio_option
(** [radio_option ~value label] creates a radio option. [disabled] defaults to
    [false]. *)

val make :
  label:string -> options:radio_option list -> selected:string -> 'msg config
(** [make ~label ~options ~selected] returns a config with [name = None]
    (auto-generated from slugified label), [disabled = false],
    [on_select = None], no style/interaction override, empty attrs, and none of
    the override fields set: no id, no visible group label, no label, group,
    option-label or option-row style, and no label-click message. *)

val with_id : string -> 'msg config -> 'msg config
(** [with_id id config] sets the identifier the group container carries, and
    with it every identifier the group derives: each option becomes
    [id ^ "-" ^ slug value], each option's label element
    [id ^ "-" ^ slug value ^ "-label"], and the group's own label element
    [id ^ "-label"]. Every {!view} association moves with it. Without it the
    identifiers are derived from the slugified group label.

    This is the supported route to those ids. Pushing [("id", _)] through
    [config.attrs] also replaces the group's own id, at the second tier of the
    attribute precedence rule, but reaches no option and leaves every
    [aria-labelledby] pointing where it did, so a caller taking that route owns
    re-pointing the associations.

    It does {e not} move [data-field], which stays on the group [name]: that
    anchor is the E2E selector contract and {!view} documents it as independent
    of the id.

    Options must have distinct [value]s for their ids to be distinct; the
    derivation is keyed by the value, exactly as the shared group [name] already
    is. *)

val with_visible_label : bool -> 'msg config -> 'msg config
(** [with_visible_label true config] renders the group's [label] as an element
    of its own — the group's first child — and moves the group's accessible name
    from [aria-label] to [aria-labelledby] pointing at it.

    Without this setter, and with [false], the group renders no label element at
    all and keeps [aria-label]: there would be nothing for [aria-labelledby] to
    point at, and a group that grew a heading of its own would change the
    rendered tree of every existing consumer, including one that already built a
    heading around its absence. The opt-in is that decision, and {!view}
    describes both shapes.

    This is the one setter here that changes the rendered tree rather than an
    attribute or a style. *)

val with_label_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_label_style style config] puts [style] on the group's own label
    element — the one {!with_visible_label} opts into. The style {e replaces}
    whatever that element had; nothing is merged. Its [text] component is passed
    to the label's text node explicitly, so a weight or colour set here is
    observable structurally and not only in a browser.

    With no visible group label there is no element for it to land on, so this
    setter has no effect on its own. *)

val with_group_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_group_style style config] puts [style] on the group container — the
    column holding the option rows, which carries [role="radiogroup"]. The style
    {e replaces}; nothing is merged. This is the route to the spacing between
    options and to the group's own padding; [config.style] reaches each radio
    input instead, and the two are independent. *)

val with_option_label_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_option_label_style style config] puts [style] on every option's label
    element — the box that carries the option's label identifier and wraps its
    text. The style {e replaces}; nothing is merged, and it applies to all
    options alike. Its [text] component is passed to each label's text node
    explicitly, for the reason {!with_label_style} gives. *)

val with_option_row_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_option_row_style style config] puts [style] on every row that holds a
    radio input and its label. The style {e replaces}; nothing is merged. This
    is the route to the gap between an option's control and its label. *)

val with_on_label_click : (string -> 'msg) -> 'msg config -> 'msg config
(** [with_on_label_click f config] dispatches [f value] when a pointer goes down
    on the label element of the option whose value is [value]. A view function
    cannot issue a command, so selecting or focusing that option is the
    application's line: [update] answers the message with
    [Cmd.focus (option_id config ~value)], or with whatever the application
    wants a label press to mean — note that the native behaviour of a label for
    a radio is to {e select} it, which [on_select]'s message is the route to.

    The value is carried because a group has many controls and a single message
    could not say which label was pressed. Without this setter no option label
    carries a pointer handler at all. The group's own label never does: it has
    no single control to act on. *)

val control_id : 'msg config -> string
(** [control_id config] is the identifier the group container carries. It is
    [config.id] when the caller set one and the slugified group label otherwise,
    with no suffix. The group is not a focusable element, so this names the
    group for an [aria-*] reference rather than for [Cmd.focus]; the argument
    [Cmd.focus] needs is {!option_id}.

    The derivation is keyed by the group label alone, so two groups on one page
    whose labels slugify the same share an id — and with it every id derived
    from it — and no uniqueness is invented for them. A page that renders two
    names one of them with {!with_id}. *)

val option_id : 'msg config -> value:string -> string
(** [option_id config ~value] is the identifier the radio input for [value]
    carries, and therefore the argument [Cmd.focus] needs for that option. It is
    {!control_id} followed by a hyphen and the slugified [value].

    The derivation is keyed by the value alone: two options sharing a value
    share an id, as they already share the group [name], and no uniqueness is
    invented for them. The suffix space is flat, so an option whose [value]
    slugifies to ["label"] also collides with the group's own label element
    under {!with_visible_label} — give the group a different {!with_id}, or the
    option a different [value]. It is total and never raises — an empty [value]
    yields a trailing hyphen rather than a fallback, for the reason
    {!Slug.derive_id} documents. *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** Renders the radio group. Each option carries [data-field=<group name>] (the
    [name], defaulting to the slugified label). This anchor is the E2E selector
    contract (RFC 0112) and is asserted by [test_anchors.ml]. It is derived from
    the group [name] alone and is {e not} moved by {!with_id}.

    [view config] renders a Column with [role="radiogroup"], styled by
    {!with_group_style} and carrying [("id", control_id config)], containing one
    Row per option — styled by {!with_option_row_style} — and each Row holds:

    1. An [Element.radio] sharing the group name, carrying
    [("id", option_id config ~value)] and
    [("aria-labelledby", option_id config ~value ^ "-label")] 2. A label element
    — a box carrying that [aria-labelledby] target as its own id and styled by
    {!with_option_label_style}, wrapping the option's text

    To override an option's accessible name, point [aria-labelledby] at your own
    element; [aria-label] no longer takes effect on these radios. Each option is
    named by [aria-labelledby] pointing at its label element above, and carries
    no [aria-label] of its own. Note [config.attrs] reaches the group container
    only, never an option, so this is a change to what the component contributes
    rather than something a call site can undo per option.

    The group's own name is the one thing this does not move by default: without
    {!with_visible_label} the Column keeps [aria-label=config.label] and renders
    no label element, because there would be nothing for an [aria-labelledby] to
    point at. With the setter the Column's first child is the group's label
    element, styled by {!with_label_style} and carrying
    [(control_id config ^ "-label")], and the Column's name moves to
    [aria-labelledby] pointing at it. An [("aria-label", _)] pair pushed through
    [config.attrs] survives in the tree either way, but once the setter is used
    it does not name the group, because [aria-labelledby] wins the
    accessible-name computation.

    When [config.disabled] is [true], all radios are disabled and [on_select] is
    suppressed. Per-option [disabled] is also respected. *)
