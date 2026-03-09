(** Path segments and builder utilities for 2D drawing.

    Paths are sequences of segments describing outlines for shapes, curves, and
    chart elements like area fills and donut arcs. *)

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
    }
  | Close  (** A single path segment. *)

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
  segment
(** Draw a circular arc centered at [(cx, cy)] with radius [r]. *)

val close : segment
(** Close the current sub-path back to its starting point. *)

val smooth_curve : (float * float) list -> segment list
(** [smooth_curve points] generates a smooth Catmull-Rom spline through the
    given points, converted to cubic Bezier segments. *)

val straight_line : (float * float) list -> segment list
(** [straight_line points] generates Move_to + Line_to segments. *)

val closed_area : (float * float) list -> segment list
(** [closed_area points] generates Move_to + Line_to + Close segments, suitable
    for filled area shapes. *)

val arc_segment :
  cx:float ->
  cy:float ->
  r:float ->
  start_angle:float ->
  end_angle:float ->
  segment list
(** [arc_segment] generates segments for a pie/wedge arc. *)

val donut_arc :
  cx:float ->
  cy:float ->
  inner_r:float ->
  outer_r:float ->
  start_angle:float ->
  end_angle:float ->
  segment list
(** [donut_arc] generates segments for a donut/ring arc between two radii. *)

val equal_segment : segment -> segment -> bool
(** Structural equality for path segments. *)
