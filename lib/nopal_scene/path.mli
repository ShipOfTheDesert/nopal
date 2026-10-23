(** Path segment types and trivial builders for 2D drawing.

    Higher-level algorithms (smooth curves, area fills, arcs) live in
    {!Nopal_draw.Path}. *)

(** The way an arc turns as seen on screen. Angles are in radians from the
    positive x axis, and y grows downward, so increasing angles turn clockwise
    as seen. *)
type direction =
  | Clockwise  (** Runs from the start angle towards increasing angles. *)
  | Anticlockwise  (** Runs from the start angle towards decreasing angles. *)

type segment =
  | Move_to of { x : float; y : float }
  | Line_to of { x : float; y : float }
  | Bezier_to of {
      cp1x : float;
      cp1y : float;
      cp2x : float;
      cp2y : float;
      x : float;
      y : float;
    }
  | Quad_to of { cpx : float; cpy : float; x : float; y : float }
  | Arc_to of {
      cx : float;
      cy : float;
      r : float;
      start_angle : float;
      end_angle : float;
      direction : direction;
    }
      (** An arc from [start_angle] to [end_angle] that turns in [direction].
          Every renderer resolves it by the same rules:
          - an arc that spans a full turn or more in [direction] draws the full
            circle;
          - equal angles draw nothing;
          - when the start angle is greater than the end angle, the arc still
            runs in [direction], whichever way that is;
          - a valid arc brings the pen to its start point, even when it draws
            nothing, and a zero radius is valid: the pen reaches the centre;
          - an arc whose centre, radius or either angle is non-finite, or whose
            radius is negative, is invalid: it adds nothing to the path and the
            pen stays where it was. *)
  | Close  (** Close the current sub-path back to its starting point. *)

val move_to : x:float -> y:float -> segment
(** Move the pen to [(x, y)] without drawing. *)

val line_to : x:float -> y:float -> segment
(** Draw a straight line to [(x, y)]. *)

val bezier_to :
  cp1x:float ->
  cp1y:float ->
  cp2x:float ->
  cp2y:float ->
  x:float ->
  y:float ->
  segment
(** Draw a cubic Bezier curve to [(x, y)] with control points. *)

val quad_to : cpx:float -> cpy:float -> x:float -> y:float -> segment
(** Draw a quadratic Bezier curve to [(x, y)] with one control point. *)

val arc_to :
  cx:float ->
  cy:float ->
  r:float ->
  start_angle:float ->
  end_angle:float ->
  direction:direction ->
  segment
(** Draw a circular arc centered at [(cx, cy)] with radius [r], turning in
    [direction]. *)

val close : segment
(** Close the current sub-path back to its starting point. *)

val equal_direction : direction -> direction -> bool
(** Structural equality on directions. *)

val pp_direction : Format.formatter -> direction -> unit
(** Print a direction as its constructor name. *)

val equal_segment : segment -> segment -> bool
(** Structural equality for path segments (tolerance 1e-10). *)
