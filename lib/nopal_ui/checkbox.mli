(** Labelled checkbox component. *)

type 'msg config = {
  label : string;
  checked : bool;
  disabled : bool;
  on_toggle : (bool -> 'msg) option;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
}
(** Checkbox configuration. [label] and [checked] are behavioural — both
    required in {!make}. *)

val make : label:string -> checked:bool -> 'msg config
(** [make ~label ~checked] returns a config with [disabled = false],
    [on_toggle = None], no style/interaction override, and empty attrs. *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** [view config] renders a horizontal Row containing: 1. An [Element.checkbox]
    with the config's checked/disabled/on_toggle state 2. An [Element.text]
    label

    When [disabled] is [true], [on_toggle] is suppressed and the checkbox
    primitive carries [disabled = true]. *)
