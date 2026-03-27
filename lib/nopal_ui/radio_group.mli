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
}
(** Radio group configuration. [label], [options], and [selected] are
    behavioural — all required in {!make}. *)

val radio_option : ?disabled:bool -> value:string -> string -> radio_option
(** [radio_option ~value label] creates a radio option. [disabled] defaults to
    [false]. *)

val make :
  label:string -> options:radio_option list -> selected:string -> 'msg config
(** [make ~label ~options ~selected] returns a config with [name = None]
    (auto-generated from slugified label), [disabled = false],
    [on_select = None], no style/interaction override, and empty attrs. *)

val view : 'msg config -> 'msg Nopal_element.Element.t
(** [view config] renders a Column with [role="radiogroup"] and
    [aria-label=config.label] containing one Row per option. Each Row has an
    [Element.radio] (sharing the group name) and an [Element.text] label. When
    [config.disabled] is [true], all radios are disabled and [on_select] is
    suppressed. Per-option [disabled] is also respected. *)
