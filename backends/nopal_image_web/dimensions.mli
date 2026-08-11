(** Pure target sizing for the downscale passes. No platform types. *)

val fit : src_width:int -> src_height:int -> max_edge:int -> int * int
(** [fit ~src_width ~src_height ~max_edge] is the [(width, height)] to draw a
    [src_width] by [src_height] source at so that neither edge exceeds
    [max_edge].

    The source aspect ratio is preserved to within a whole pixel, and the longer
    of the two returned edges is exactly [max_edge] whenever a cap is applied. A
    source whose long edge already sits at or under [max_edge] comes back
    unchanged: this never enlarges, because added pixels carry no detail and
    cost upload bytes.

    Neither returned edge is ever zero. An extreme aspect ratio scales its short
    edge below one pixel, and a degenerate source with a zero edge scales to
    nothing at all; both are floored at one pixel rather than yielding a canvas
    with no area.

    [max_edge] is expected to be positive, which is what [Config.max_edge] and
    [Config.metric_edge] guarantee. This is total for every [int] all the same:
    a zero or negative cap floors both edges at one pixel, so it returns a
    usable size rather than raising - but the returned long edge is then that
    floor rather than [max_edge]. *)
