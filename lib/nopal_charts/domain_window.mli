(** Visible domain range for pan/zoom and time filtering.

    A domain window represents the currently visible X-axis range. Charts use
    this to clip data to the visible region and to support pan and zoom
    interactions.

    {b Important:} [pan] and [zoom] do not clamp the result to your data bounds.
    Use {!clamp} after every [pan]/[zoom] to prevent the window from sliding
    past the data range (which would render an empty chart). *)

type t = { x_min : float; x_max : float }

val create : x_min:float -> x_max:float -> t
val equal : t -> t -> bool
val width : t -> float

val pan : t -> delta:float -> t
(** [pan t ~delta] shifts the window by [delta] along the X axis. Does not clamp
    — pipe the result through {!clamp} to stay in bounds. *)

val zoom : t -> center:float -> factor:float -> t
(** [zoom t ~center ~factor] zooms around [center]. New width = old width *
    factor. Factor < 1.0 zooms in, factor > 1.0 zooms out. The center point
    maintains its relative position within the window. Does not clamp — pipe the
    result through {!clamp} to stay in bounds. *)

val clamp : data_min:float -> data_max:float -> t -> t
(** [clamp ~data_min ~data_max t] constrains [t] so the window stays within the
    data bounds. The window is shifted (not resized) to keep at least part of
    the data visible. *)
