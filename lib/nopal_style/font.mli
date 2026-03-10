(** Font family and weight types for text rendering.

    These types are platform-agnostic. Backend packages translate them into
    platform-specific font specifications. *)

type family = System_ui | Sans_serif | Serif | Monospace | Custom of string

type weight =
  | Thin
  | Extra_light
  | Light
  | Normal
  | Medium
  | Semi_bold
  | Bold
  | Extra_bold
  | Black

val equal_family : family -> family -> bool
(** Structural equality for font families. *)

val equal_weight : weight -> weight -> bool
(** Structural equality for font weights. *)

val family_to_css_string : family -> string
(** CSS string representation of a font family. Custom families are quoted. *)

val weight_to_css_string : weight -> string
(** CSS string representation of a font weight. Returns numeric "100"–"900". *)

val weight_to_int : weight -> int
(** Numeric value of a font weight (100–900). *)
