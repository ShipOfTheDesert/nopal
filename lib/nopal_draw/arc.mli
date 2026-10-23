(** The sweep rules every renderer resolves an arc segment by.

    An arc segment names a start angle, an end angle and a
    {!Nopal_scene.Path.direction}. Each renderer turns that into one signed
    sweep through {!resolve}, so canvas and SVG cannot read the same segment two
    ways. Angles are in radians from the positive x axis; y grows downward, so a
    positive sweep turns clockwise as seen.

    The rules follow the text of the HTML canvas [arc()] specification:
    - In [Clockwise], an end angle at least a full turn above the start draws
      the full circle, a sweep of [2π]. In [Anticlockwise], an end angle at
      least a full turn below the start draws the full circle, a sweep of [-2π].
    - Otherwise the arc runs from the point at the start angle to the point at
      the end angle in the given direction, so its sweep is at most a full turn.
      This holds whichever angle is larger: a [Clockwise] arc from [π] to [π/2]
      sweeps [3π/2], the long way round.
    - Two angles that name the same point draw nothing: equal angles, and also a
      [Clockwise] arc from [2π] down to [0], since the points coincide and the
      sweep in the given direction is below a full turn. The sweep is [0.].
    - A valid arc always brings the pen to its start point, even when its sweep
      is [0.]. A zero radius is valid: the start point is the centre.
    - An arc whose centre, radius or either angle is non-finite is invalid. It
      adds nothing to the path, and the pen stays where it was.
    - An arc with a negative radius is also invalid, with the same result. This
      departs from the specification, where [arc()] throws [IndexSizeError] on a
      negative radius. A throw while rendering would take down the whole view
      over one bad value, so the arc is dropped instead, as the specification
      itself does for non-finite arguments. Dropping it moves no pen, so both
      renderers treat a negative radius identically.

    A renderer never passes an invalid arc to its platform. *)

type resolved =
  | Invalid  (** The arc adds nothing to the path, and the pen does not move. *)
  | Sweep of { start : float; sweep : float }
      (** [start] is the start angle reduced into the half-open range from [0.]
          to [2π], and [sweep] the signed sweep in radians, in [[-2π, 2π]]. The
          arc runs from [start] to [start + sweep]. [sweep] is non-negative for
          [Clockwise] and non-positive for [Anticlockwise]. A sweep of [0.]
          moves the pen to the start point and draws nothing. Renderers use
          these two values and never the raw start angle, which can be too large
          to add a sweep to. *)

val resolve :
  Nopal_scene.Path.direction ->
  cx:float ->
  cy:float ->
  r:float ->
  start_angle:float ->
  end_angle:float ->
  resolved
(** [resolve direction ~cx ~cy ~r ~start_angle ~end_angle] is the sweep of the
    arc by the rules above. It is total: every input, including NaN, an
    infinity, and finite angles whose difference overflows, gives [Invalid] or a
    [Sweep] in range. *)
