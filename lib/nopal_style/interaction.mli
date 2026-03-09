(** Typed interaction state overrides for interactive elements.

    Each field is an optional {!Style.t} that, when present, overrides the
    element's base style for that state. Only set properties take effect — unset
    properties inherit from the base style. *)

type t = {
  hover : Style.t option;
  pressed : Style.t option;
  focused : Style.t option;
}

val default : t
(** All fields [None] — no interaction styles. *)

val equal : t -> t -> bool
(** Structural equality using {!Style.equal} on each field. *)

val has_any : t -> bool
(** [true] if at least one field is [Some]. Used by the renderer to skip
    stylesheet injection for elements with no interaction styles. *)
