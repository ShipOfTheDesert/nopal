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
}
(** Button configuration. All fields except [variant] have sensible defaults. *)

val default : variant -> 'msg config
(** [default v] returns a config for variant [v] with [disabled = false],
    [loading = false], [on_click = None], default style/interaction, and empty
    attrs. *)

val view :
  'msg config -> 'msg Nopal_element.Element.t -> 'msg Nopal_element.Element.t
(** [view config child] renders a button element.

    When [config.disabled] is [true], the element includes
    [("aria-disabled", "true")] and click events are suppressed.

    When [config.loading] is [true], the element includes
    [("aria-busy", "true")] and click events are suppressed.

    The [config.style] and [config.interaction] fields, when [Some], override
    the variant's default styling. User-supplied [config.attrs] are merged with
    ARIA attrs (user attrs take precedence on conflict). *)

val variant_to_string : variant -> string
(** [variant_to_string v] returns a lowercase string name for test/debug. *)
