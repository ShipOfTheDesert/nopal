(** Path segments and builder utilities for 2D drawing.

    Paths are sequences of segments describing outlines for shapes, curves, and
    chart elements like area fills and donut arcs. *)

include module type of Nopal_scene.Path

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
