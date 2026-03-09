(** Font family and weight types for text rendering.

    These types are platform-agnostic. Backend packages translate them into
    platform-specific font specifications. *)

type family = Sans_serif | Serif | Monospace | Custom of string
type weight = Normal | Bold

val equal_family : family -> family -> bool
(** Structural equality for font families. *)

val equal_weight : weight -> weight -> bool
(** Structural equality for font weights. *)

val family_to_css_string : family -> string
(** CSS string representation of a font family. Custom families are quoted. *)

val weight_to_css_string : weight -> string
(** CSS string representation of a font weight. *)
