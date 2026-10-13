(** Accessible text input with label and optional error message.

    Composes [Element.input] with a label and optional [role="alert"] error
    element linked via [aria-describedby]. *)

type 'msg config = {
  label : string;
  value : string;
  placeholder : string option;
  error : string option;
  disabled : bool;
  id : string option;
  on_change : (string -> 'msg) option;
  on_submit : 'msg option;
  on_blur : 'msg option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
  label_style : Nopal_style.Style.t option;
  wrapper_style : Nopal_style.Style.t option;
  error_style : Nopal_style.Style.t option;
  on_label_click : 'msg option;
  required : bool option;
  autocomplete : string option;
  input_type : Nopal_element.Element.input_type option;
  name : string option;
  on_keydown : (string -> 'msg option) option;
  on_focus : 'msg option;
}
(** TextInput configuration. [label] and [value] are required — use {!make}.

    The last ten fields are reached through setters. [label_style],
    [wrapper_style], [error_style] and [on_label_click] are the override
    surface, set by {!with_label_style}, {!with_wrapper_style},
    {!with_error_style} and {!with_on_label_click}. [required], [autocomplete],
    [input_type], [name], [on_keydown] and [on_focus] carry the input element's
    own fields through to it, set by {!with_required}, {!with_autocomplete},
    {!with_input_type}, {!with_name}, {!with_on_keydown} and {!with_on_focus},
    so no field of [Element.input] is reachable only through [config.attrs]. The
    supported route to all ten is the setter rather than writing them by hand;
    they are fields because a setter needs somewhere to put its value, and a
    caller who builds this record as a complete literal must supply them. *)

val make : label:string -> value:string -> 'msg config
(** [make ~label ~value] returns a config with the given label and value. All
    optional fields default to [None], [disabled] to [false], [attrs] to [[]].
*)

val with_id : string -> 'msg config -> 'msg config
(** [with_id id config] sets [config.id] — the identifier the input carries, and
    the one the label element's ([id ^ "-label"]) and the error slot's
    ([id ^ "-error"]) are derived from. Every half of the {!view} association
    moves together. Without it the identifier is the slugified label.

    It is a setter for a field this record has published from the start, so that
    the four labelled controls are reached the same way; assigning [id] directly
    remains equivalent. Pushing [("id", _)] through [config.attrs] also replaces
    the input's id, at the second tier of the attribute precedence rule, but
    leaves [aria-labelledby] pointing at the label as before, so a caller taking
    that route owns re-pointing the association.

    Unlike the checkbox's and the select's, this control's [data-field] anchor
    {e does} move with the id, because it has always carried {!control_id}
    rather than the slugified label. *)

val with_label_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_label_style style config] puts [style] on the label element — the box
    that carries the label's identifier and wraps its text. The style
    {e replaces} whatever the label had; nothing is merged. Its [text] component
    is passed to the label's text node explicitly, so a weight or colour set
    here is observable structurally and not only in a browser. *)

val with_wrapper_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_wrapper_style style config] puts [style] on the column that holds the
    label, the input and the error slot. The style {e replaces}; nothing is
    merged. This is the route to the gap between the label and the box. *)

val with_error_style : Nopal_style.Style.t -> 'msg config -> 'msg config
(** [with_error_style style config] puts [style] on the [role="alert"] error
    slot, which is rendered only when [config.error] is [Some]. The style
    {e replaces}; nothing is merged. Its [text] component is passed to the error
    message's text node explicitly, on the same footing as {!with_label_style}.
*)

val with_on_label_click : 'msg -> 'msg config -> 'msg config
(** [with_on_label_click msg config] dispatches [msg] when a pointer goes down
    on the label element. A view function cannot issue a command, so focusing
    the control is the application's line: [update] answers this message with
    [Cmd.focus (control_id config)]. Without this setter the label carries no
    pointer handler at all. *)

val with_required : bool -> 'msg config -> 'msg config
(** [with_required required config] passes [required] to the input's typed
    [required] field. With [true] the input carries [required] and
    [aria-required], and either replaces a pair for the same key in
    [config.attrs]. With [false], or without this setter, the input derives
    neither, and such a pair stands. *)

val with_autocomplete : string -> 'msg config -> 'msg config
(** [with_autocomplete token config] passes [token] — ["current-password"],
    ["email"], ["one-time-code"] and the rest of the platform's open set, as
    written — to the input's typed [autocomplete] field, which replaces an
    [("autocomplete", _)] pair in [config.attrs]. Without this setter the input
    derives none, and such a pair stands. *)

val with_input_type :
  Nopal_element.Element.input_type -> 'msg config -> 'msg config
(** [with_input_type kind config] passes [kind] to the input's typed
    [input_type] field, which the input carries as its [type] and which replaces
    a [("type", _)] pair in [config.attrs]. Without this setter the input
    derives no [type], and such a pair stands — the route for a kind
    [input_type] does not name. *)

val with_name : string -> 'msg config -> 'msg config
(** [with_name name config] passes [name] to the input's typed [name] field —
    the key the value is submitted under, and the one a password manager reads.
    It replaces a [("name", _)] pair in [config.attrs]. Without this setter the
    input derives none, and such a pair stands. *)

val with_on_keydown : (string -> 'msg option) -> 'msg config -> 'msg config
(** [with_on_keydown handler config] passes [handler] to the input's
    [on_keydown]. How it shares an Enter with [config.on_submit] and with an
    enclosing form is {!Nopal_element.Element}'s
    {{!Nopal_element.Element.section-submit_contract} submit contract}; the
    component adds no route of its own. Suppressed while [config.disabled] is
    [true]. *)

val with_on_focus : 'msg -> 'msg config -> 'msg config
(** [with_on_focus msg config] dispatches [msg] when the input takes focus.
    Suppressed while [config.disabled] is [true]. *)

val control_id : 'msg config -> string
(** [control_id config] is the identifier the input element carries, and
    therefore the argument [Cmd.focus] needs. It is [config.id] when the caller
    set one and the slugified label otherwise, with no suffix — the same value
    [data-field] carries.

    The derivation is keyed by the label alone, so two controls on one page
    whose labels slugify the same share an id — and with it the label element's
    [id ^ "-label"] and the error slot's [id ^ "-error"] — and no uniqueness is
    invented for them. A page that renders two names one of them with
    {!with_id}. *)

val error_id : 'msg config -> string
(** [error_id config] returns the identifier used for [aria-describedby]
    linkage. If [config.id] is [Some id], returns [id ^ "-error"]. Otherwise,
    derives the ID by slugifying [config.label] and appending ["-error"]. *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** Renders the text input, which carries [data-field=<input id>] (the [id],
    defaulting to the slugified label when unset). This anchor is the E2E
    selector contract and is asserted by [test_anchors.ml]. The input's own [id]
    carries that same value; [data-field] is unchanged by it.

    [view config] renders a vertical column, styled by {!with_wrapper_style},
    containing:

    1. A label element — a box carrying [("id", control_id config ^ "-label")]
    and styled by {!with_label_style}, wrapping the label text 2. An input
    ([Element.input]) with the config's value, placeholder, and event handlers,
    carrying [("id", control_id config)] and
    [("aria-labelledby", control_id config ^ "-label")] 3. When [config.error]
    is [Some msg], an error element styled by {!with_error_style} with
    [("role", "alert")] and [("id", error_id config)]; the input gains
    [("aria-describedby", error_id config)] and [("aria-invalid", "true")]

    [aria-invalid] is an ordinary pair ahead of [config.attrs]. With an error it
    is present, and a caller's [("aria-invalid", _)] pair in [config.attrs]
    replaces it. Without an error the component derives nothing, so a caller's
    pair stands.

    To override the accessible name, point [aria-labelledby] at your own
    element; [aria-label] no longer takes effect on this control. The input is
    named by [aria-labelledby] pointing at the label element above, and carries
    no [aria-label] of its own. An [("aria-label", _)] pair pushed through
    [config.attrs] survives in the tree but does not name the control, because
    [aria-labelledby] wins the accessible-name computation.

    Pushing [("id", _)] through [config.attrs] replaces the input's id at the
    [~attrs] tier of the attribute-precedence rule (see [CONTRIBUTING.md] §V)
    and leaves [aria-labelledby] pointing at the label as before, so a caller
    who takes that route owns re-pointing the association. The supported route
    is [config.id], which moves both halves together.

    When [config.disabled] is [true], the input carries [("disabled", "")] and
    its [on_change], [on_submit], [on_focus], [on_blur] and [on_keydown] are all
    suppressed. *)
