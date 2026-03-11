(** Color scales for mapping data values to colors.

    Sequential scales interpolate between two colors across a data range.
    Diverging scales interpolate through a midpoint color, useful for data with
    a meaningful center (e.g. zero, average). *)

type t
(** A color scale mapping data values to colors. *)

val sequential : low:Nopal_draw.Color.t -> high:Nopal_draw.Color.t -> t
(** [sequential ~low ~high] creates a scale interpolating from [low] to [high].
*)

val diverging :
  low:Nopal_draw.Color.t ->
  mid:Nopal_draw.Color.t ->
  high:Nopal_draw.Color.t ->
  ?midpoint:float ->
  unit ->
  t
(** [diverging ~low ~mid ~high ?midpoint ()] creates a diverging scale.
    [midpoint] defaults to [0.0]. Values below midpoint interpolate low->mid;
    above interpolate mid->high. *)

val apply : t -> min:float -> max:float -> float -> Nopal_draw.Color.t
(** [apply scale ~min ~max value] maps [value] to a color. Values outside
    [min, max] are clamped. *)
