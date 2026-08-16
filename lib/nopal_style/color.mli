(** Color values for CSS authoring.

    Integer RGBA plus the hex, named and transparent spellings a stylesheet
    author expects. Platform-agnostic — no CSS, DOM or browser concepts here;
    backend packages serialise these values into whatever their target needs.

    This is a leaf module: it references nothing else in the package, which is
    what lets both the text style and the box paint name it.

    Distinct from [Nopal_scene.Color], the float 0.0-1.0 RGBA type used for
    graphics rendering. This one is the authoring type; that one is the GPU
    convention. The name is written plainly rather than as a cross-reference
    because this package does not depend on [nopal_scene] and odoc cannot
    resolve a reference that runs against the dependency direction. *)

type t =
  | Rgba of { r : int; g : int; b : int; a : float }
  | Hex of string
  | Named of string
  | Transparent

val rgba : int -> int -> int -> float -> t
(** [rgba r g b a] creates an RGBA color. The components are taken as given; no
    range clamping is performed. *)

val hex : string -> t
(** [hex s] creates a color from a hex string (e.g. ["#ff0000"]). The string is
    taken as given; no validation is performed. *)

val named : string -> t
(** [named s] creates a color from a named color (e.g. ["red"]). The string is
    taken as given; no validation is performed. *)

val transparent : t
(** The transparent color. *)

val equal : t -> t -> bool
(** Structural equality for colors. Uses [Float.equal] for alpha. *)
