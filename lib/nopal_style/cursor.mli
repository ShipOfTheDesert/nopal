(** Cursor types for interactive elements.

    Platform-agnostic cursor variants. Backend packages translate them into
    platform-specific cursor specifications. *)

type t = Default | Pointer | Crosshair | Text | Grab | Grabbing | None_cursor

val equal : t -> t -> bool
(** Structural equality for cursor types. *)

val to_css_string : t -> string
(** CSS string representation of a cursor type. *)
