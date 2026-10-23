(** Path segments and builder utilities for 2D drawing.

    Paths are sequences of segments describing outlines for shapes, curves, and
    chart elements like area fills and donut arcs. *)

include module type of Nopal_scene.Path

val arc_to :
  ?direction:direction ->
  cx:float ->
  cy:float ->
  r:float ->
  start_angle:float ->
  end_angle:float ->
  unit ->
  segment
(** [arc_to ?direction ~cx ~cy ~r ~start_angle ~end_angle ()] is
    [Nopal_scene.Path.arc_to] with [direction] defaulting to [Clockwise]. *)

val smooth_curve : (float * float) list -> segment list
(** [smooth_curve points] generates a smooth Catmull-Rom spline through the
    given points, converted to cubic Bezier segments. *)

val straight_line : (float * float) list -> segment list
(** [straight_line points] generates Move_to + Line_to segments. *)

val closed_area : (float * float) list -> segment list
(** [closed_area points] generates Move_to + Line_to + Close segments, suitable
    for filled area shapes. *)

val arc_segment :
  ?direction:direction ->
  cx:float ->
  cy:float ->
  r:float ->
  start_angle:float ->
  end_angle:float ->
  unit ->
  segment list
(** [arc_segment] generates segments for a pie/wedge arc: a move to the start
    point, then an arc turning in [direction] (default [Clockwise]). *)

val donut_arc :
  ?direction:direction ->
  cx:float ->
  cy:float ->
  inner_r:float ->
  outer_r:float ->
  start_angle:float ->
  end_angle:float ->
  unit ->
  segment list
(** [donut_arc] generates segments for a donut/ring arc between two radii. The
    outer edge runs from [start_angle] to [end_angle] in [direction] (default
    [Clockwise]); the inner edge runs back from [end_angle] to [start_angle] in
    the opposite direction, so the ring encloses no part of the hole. *)
