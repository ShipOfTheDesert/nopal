(** Linear scale: maps a domain range to an output range.

    Useful for mapping data values to pixel coordinates and back. *)

type t = {
  domain_min : float;
  domain_max : float;
  range_min : float;
  range_max : float;
}

val create : domain:float * float -> range:float * float -> t
(** [create ~domain:(lo, hi) ~range:(lo, hi)] creates a linear scale. *)

val apply : t -> float -> float
(** [apply scale v] maps a domain value to the output range. *)

val invert : t -> float -> float
(** [invert scale v] maps a range value back to the domain. *)

val equal : t -> t -> bool
(** Structural equality for scales. *)
