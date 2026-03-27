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
}
(** TextInput configuration. [label] and [value] are required — use {!make}. *)

val make : label:string -> value:string -> 'msg config
(** [make ~label ~value] returns a config with the given label and value. All
    optional fields default to [None], [disabled] to [false], [attrs] to [[]].
*)

val error_id : 'msg config -> string
(** [error_id config] returns the identifier used for [aria-describedby]
    linkage. If [config.id] is [Some id], returns [id ^ "-error"]. Otherwise,
    derives the ID by slugifying [config.label] and appending ["-error"]. *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** [view config] renders a vertical column containing:

    1. A label ([Element.text]) 2. An input ([Element.input]) with the config's
    value, placeholder, and event handlers 3. When [config.error] is [Some msg],
    an error text ([Element.text]) with [("role", "alert")] and
    [("id", error_id config)]; the input gains
    [("aria-describedby", error_id config)]

    When [config.disabled] is [true], the input carries [("disabled", "")] and
    event handlers are suppressed. *)
