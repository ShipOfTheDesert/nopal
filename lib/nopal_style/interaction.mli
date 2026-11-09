(** Typed interaction state overrides for interactive elements.

    Each field is an optional {!Style.t} that, when present, overrides the
    element's base style for that state. Only set properties take effect — unset
    properties inherit from the base style.

    {b Layer order.} When more than one state applies at once, a later state's
    set properties win over an earlier one's: [hover], then [focused_within],
    then [focused], then [pressed]. A drawn checkbox's ticked style wins over
    every interaction state. *)

type t = {
  hover : Style.t option;  (** While the pointer is over the element. *)
  pressed : Style.t option;  (** While the element is being pressed. *)
  focused : Style.t option;
      (** While the element itself has focus the platform shows as visible,
          typically focus that arrived by keyboard. *)
  focused_within : Style.t option;
      (** While the element or any of its descendants has focus, however the
          focus arrived: keyboard, pointer or script. *)
}

val default : t
(** All fields [None] — no interaction styles. *)

val equal : t -> t -> bool
(** Structural equality using {!Style.equal} on each field. *)

val has_any : t -> bool
(** [true] if at least one field is [Some]. Used by the renderer to skip
    stylesheet injection for elements with no interaction styles. *)
