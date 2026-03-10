(** Chart padding for axis and label margins. *)

type t = { top : float; right : float; bottom : float; left : float }

val default : t
(** [{top = 40.; right = 20.; bottom = 40.; left = 50.}] *)

val equal : t -> t -> bool
(** Structural equality for padding. *)
