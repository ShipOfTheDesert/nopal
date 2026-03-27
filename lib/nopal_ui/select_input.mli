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
}
(** Select configuration. [label], [options], and [selected] are behavioural —
    all required in {!make}. *)

val make :
  label:string ->
  options:Nopal_element.Element.select_option list ->
  selected:string ->
  'msg config
(** [make ~label ~options ~selected] returns a config with [placeholder = None],
    [disabled = false], [on_change = None], no style/interaction override, and
    empty attrs. *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** [view config] renders a vertical Column containing: 1. An [Element.text]
    label 2. An [Element.select] with the config's options, selected value,
    disabled state, and on_change handler. When [placeholder] is [Some text], a
    disabled option with [value = ""] and [label = text] is prepended to the
    options list. When [disabled] is [true], [on_change] is suppressed and the
    select primitive carries [disabled = true]. *)
