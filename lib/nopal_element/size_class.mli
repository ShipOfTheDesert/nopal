(** Material Design 3 window size classes.

    Compact: width < 600 Medium: 600 ≤ width < 840 Expanded: width ≥ 840 *)

type t = Compact | Medium | Expanded

val of_width : int -> t
(** Derive size class from pixel width. *)

val equal : t -> t -> bool
(** Structural equality on size classes. *)
