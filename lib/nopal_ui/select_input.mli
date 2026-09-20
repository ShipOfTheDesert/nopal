(** Labelled select dropdown component. *)

type 'msg config = {
  label : string;
  options : Nopal_element.Element.select_option list;
  selected : string;
  placeholder : string option;
  disabled : bool;
  on_change : (string -> 'msg) option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
  id : string option;
  label_style : Nopal_style.Style.t option;
  wrapper_style : Nopal_style.Style.t option;
  on_label_click : 'msg option;
}
(** Select configuration. [label], [options], and [selected] are behavioural —
    all required in {!make}.

    The last four fields are the override surface. The supported route to them
    is {!with_id}, {!with_label_style}, {!with_wrapper_style} and
    {!with_on_label_click} rather than writing them by hand; they are fields
    because a setter needs somewhere to put its value, and a caller who builds
    this record as a complete literal must supply them. *)

val make :
  label:string ->
  options:Nopal_element.Element.select_option list ->
  selected:string ->
  'msg config
(** [make ~label ~options ~selected] returns a config with [placeholder = None],
    [disabled = false], [on_change = None], no style/interaction override, empty
    attrs, and no id, label style, wrapper style or label-click message. *)

val with_id : string -> 'msg config -> 'msg config
(** [with_id id config] sets the identifier the select carries, which the label
    element's own id is derived from as [id ^ "-label"]. Both halves of the
    {!view} association move together. Without it the identifier is the
    slugified label.

    This is the supported route to the control's id. Pushing [("id", _)] through
    [config.attrs] also replaces it, at the second tier of the attribute
    precedence rule, but leaves [aria-labelledby] pointing at the label as
    before, so a caller taking that route owns re-pointing the association.

    It does {e not} move [data-field], which stays on the slugified label: that
    anchor is the E2E selector contract and {!view} documents it as independent
    of the id. *)

val with_label_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_label_style style config] puts [style] on the label element — the box
    that carries the label's identifier and wraps its text. The style
    {e replaces} whatever the label had; nothing is merged. Its [text] component
    is passed to the label's text node explicitly, so a weight or colour set
    here is observable structurally and not only in a browser. *)

val with_wrapper_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_wrapper_style style config] puts [style] on the column that holds the
    label and the select. The style {e replaces}; nothing is merged. This is the
    route to the gap between the label and the control. *)

val with_on_label_click : 'msg -> 'msg config -> 'msg config
(** [with_on_label_click msg config] dispatches [msg] when a pointer goes down
    on the label element. A view function cannot issue a command, so focusing
    the control is the application's line: [update] answers this message with
    [Cmd.focus (control_id config)]. Without this setter the label carries no
    pointer handler at all. *)

val control_id : 'msg config -> string
(** [control_id config] is the identifier the select element carries, and
    therefore the argument [Cmd.focus] needs. It is [config.id] when the caller
    set one and the slugified label otherwise, with no suffix.

    The derivation is keyed by the label alone, so two controls on one page
    whose labels slugify the same share an id — and with it the label element's
    [id ^ "-label"] — and no uniqueness is invented for them. A page that
    renders two names one of them with {!with_id}. *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** Renders the select. The trigger carries [data-action="select-open"] plus
    [data-field=slug(label)]. These anchors are the E2E selector contract (RFC
    0112) and are asserted by [test_anchors.ml]. [data-field] is derived from
    the label alone and is {e not} moved by {!with_id}.

    [view config] renders a vertical column, styled by {!with_wrapper_style},
    containing:

    1. A label element — a box carrying [("id", control_id config ^ "-label")]
    and styled by {!with_label_style}, wrapping the label text 2. An
    [Element.select] with the config's options, selected value, disabled state,
    and on_change handler, carrying [("id", control_id config)] and
    [("aria-labelledby", control_id config ^ "-label")]

    When [placeholder] is [Some text], a disabled option with [value = ""] and
    [label = text] is prepended to the options list. That option is a generated
    child and carries no identifier of its own: nothing points at it and it is
    not a focus target.

    To override the accessible name, point [aria-labelledby] at your own
    element; [aria-label] no longer takes effect on this control. The select is
    named by [aria-labelledby] pointing at the label element above, and carries
    no [aria-label] of its own. An [("aria-label", _)] pair pushed through
    [config.attrs] survives in the tree but does not name the control, because
    [aria-labelledby] wins the accessible-name computation.

    When [disabled] is [true], [on_change] is suppressed and the select
    primitive carries [disabled = true]. *)
