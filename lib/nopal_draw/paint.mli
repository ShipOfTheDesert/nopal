(** Paint types for fill and stroke styling.

    Supports solid colors and linear/radial gradients with validated stops. *)

type gradient_stop = { offset : float; color : Color.t }
(** A color stop in a gradient. [offset] is in 0.0-1.0 range. *)

type t =
  | Solid of Color.t
  | Linear_gradient of {
      x0 : float;
      y0 : float;
      x1 : float;
      y1 : float;
      stops : gradient_stop list;
    }
  | Radial_gradient of {
      cx : float;
      cy : float;
      r : float;
      stops : gradient_stop list;
    }
  | No_paint  (** Paint describes how a shape is filled or stroked. *)

type line_cap = Butt | Round_cap | Square  (** Line endpoint style. *)
type line_join = Miter | Round_join | Bevel  (** Line corner joint style. *)

type stroke = {
  paint : t;
  width : float;
  dash : float list;
  dash_offset : float;
  line_cap : line_cap;
  line_join : line_join;
}
(** Stroke style for shape outlines. *)

val solid : Color.t -> t
(** [solid color] creates a solid fill paint. *)

val no_paint : t
(** No paint — the shape is not filled or stroked. *)

val linear_gradient :
  x0:float ->
  y0:float ->
  x1:float ->
  y1:float ->
  stops:gradient_stop list ->
  (t, string) result
(** [linear_gradient ~x0 ~y0 ~x1 ~y1 ~stops] creates a linear gradient. Stops
    must be non-empty; offsets are clamped to 0.0-1.0 and sorted. *)

val radial_gradient :
  cx:float ->
  cy:float ->
  r:float ->
  stops:gradient_stop list ->
  (t, string) result
(** [radial_gradient ~cx ~cy ~r ~stops] creates a radial gradient. Stops must be
    non-empty; offsets are clamped to 0.0-1.0 and sorted. *)

val stroke :
  ?width:float ->
  ?dash:float list ->
  ?dash_offset:float ->
  ?line_cap:line_cap ->
  ?line_join:line_join ->
  t ->
  stroke
(** [stroke paint] creates a stroke style. Defaults: width 1.0, no dash, {!Butt}
    cap, {!Miter} join. *)

val equal : t -> t -> bool
(** Structural equality for paints. *)

val equal_stroke : stroke -> stroke -> bool
(** Structural equality for strokes. *)
