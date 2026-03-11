(** Visible domain range for pan/zoom and time filtering.

    A domain window represents the currently visible X-axis range. Charts use
    this to clip data to the visible region and to support pan and zoom
    interactions. *)

type t = { x_min : float; x_max : float }

val create : x_min:float -> x_max:float -> t
val equal : t -> t -> bool
val width : t -> float

val pan : t -> delta:float -> t
(** [pan t ~delta] shifts the window by [delta] along the X axis. *)

val zoom : t -> center:float -> factor:float -> t
(** [zoom t ~center ~factor] zooms around [center]. New width = old width *
    factor. Factor < 1.0 zooms in, factor > 1.0 zooms out. The center point
    maintains its relative position within the window. *)
