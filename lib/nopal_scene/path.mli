(** Path segment types and trivial builders for 2D drawing.

    Higher-level algorithms (smooth curves, area fills, arcs) live in
    {!Nopal_draw.Path}. *)

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

val equal_segment : segment -> segment -> bool
(** Structural equality for path segments (tolerance 1e-10). *)
