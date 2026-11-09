(** The semantics every single-choice radio group in this library shares: the
    group's name, the ids that tie each radio to its label, the group
    container's role and naming, each option's radio, and each option's native
    label.

    A component built on this module owns only its layout — which boxes hold the
    radios and labels, and how they are styled. Everything a screen reader, the
    keyboard or an E2E anchor relies on is decided here, once, so two components
    that render a radio group cannot disagree about it.

    This module is not part of the public API. It is reachable only through
    dune's generated alias [Nopal_ui__Radio_semantics], which carries no
    stability promise. *)

type t
(** The identity of one radio group: its label, its optional explicit id and its
    optional explicit name. Every id and the name below derive from it. *)

val make : id:string option -> label:string -> name:string option -> t
(** [make ~id ~label ~name] is the group whose human-readable label is [label].
    [id], when [Some], replaces the label-derived id everywhere and is used
    verbatim. [name], when [Some], replaces the label-derived radio group name.
    The two are independent: an explicit id leaves the name derived from
    [label]. *)

val group_name : t -> string
(** [group_name group] is the [name] every radio of the group shares, so the
    platform selects one at a time and arrow keys move within it: the explicit
    name when one was given, otherwise the slugified label. Each radio also
    carries it as its [data-field] attribute. *)

val control_id : t -> string
(** [control_id group] is the group container's id: the explicit id when one was
    given, otherwise the slugified label. Every other id is derived from it. *)

val group_label_id : t -> string
(** [group_label_id group] is the id of the group's visible label element:
    {!control_id} followed by ["-label"]. *)

val option_id : t -> value:string -> string
(** [option_id group ~value] is the id of the radio for [value]: {!control_id}
    followed by a hyphen and the slugified [value]. The derivation is keyed by
    the value alone, so options must have distinct values for their ids to be
    distinct. It is total and never raises. *)

val option_label_id : t -> value:string -> string
(** [option_label_id group ~value] is the id of the label element for [value]:
    {!option_id} followed by ["-label"]. *)

(** How the group container gets its accessible name. *)
type naming =
  | Named_by_visible_label
      (** [aria-labelledby] pointing at {!group_label_id}. The component must
          render an element carrying that id. *)
  | Named_by_aria_label  (** [aria-label] carrying the group's label text. *)

val group_attrs :
  t -> naming:naming -> attrs:(string * string) list -> (string * string) list
(** [group_attrs group ~naming ~attrs] is the group container's attribute list,
    in this order: [("role", "radiogroup")], the naming pair,
    [("id", control_id group)], then [attrs] last, unchanged. *)

val option_radio :
  ?style:Nopal_style.Style.t ->
  ?interaction:Nopal_style.Interaction.t ->
  t ->
  value:string ->
  selected:string ->
  disabled:bool ->
  presentation:Nopal_style.Presentation.t ->
  on_select:(string -> 'msg) option ->
  'msg Nopal_element.Element.t
(** [option_radio group ~value ~selected ~disabled ~presentation ~on_select] is
    the radio for [value]. It is checked exactly when [selected = value], so the
    checked state always comes from the value the caller passes and never from
    what the platform last showed.

    Its attributes are, in order, [("id", option_id group ~value)],
    [("aria-labelledby", option_label_id group ~value)] and
    [("data-field", group_name group)]; its [name] is {!group_name}. Selecting
    it dispatches [f value] when [on_select] is [Some f]. A [disabled] radio
    carries no selection handler at all, whatever [on_select] is. *)

val option_label :
  ?style:Nopal_style.Style.t ->
  t ->
  value:string ->
  'msg Nopal_element.Element.t list ->
  'msg Nopal_element.Element.t
(** [option_label group ~value children] is the native label for the radio for
    [value]: an {!Nopal_element.Element.label} whose only attribute is
    [("id", option_label_id group ~value)], whose [control_id] is
    [option_id group ~value], and whose content is [children]. A press on it
    selects and focuses that radio. *)
