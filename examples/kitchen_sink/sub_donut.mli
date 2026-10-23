(** Donut holes over a checkerboard — kitchen sink section.

    A donut's hole is only visibly empty when something other than a flat colour
    sits behind it: over a plain page, a hole and a disc painted in the page's
    colour look the same. This section draws two donuts over a checkerboard, so
    the hole has to show two colours at once, and nothing painted over it can
    match both.

    The scene is drawn twice: once on a canvas, and once as the
    {!Nopal_svg.render} output of the very same scene, loaded into an image as a
    percent-encoded [data:image/svg+xml] URI. The left donut has several
    segments; the right one is a single segment making a full turn.

    {2 Geometry}

    All coordinates are logical pixels from the top-left of the scene, and are
    the same on the canvas and in the image, which is laid out at exactly the
    scene's size. The checkerboard's cells are 40 px squares, and the cell whose
    top-left corner is at [(40i, 40j)] is {!checker_light} when [i + j] is even
    and {!checker_dark} when it is odd.

    - The multi-segment donut's hole is centred on [(140, 140)], a
      {!checker_light} cell; [(180, 140)] is a {!checker_dark} cell inside the
      same hole.
    - The full-turn donut's hole is centred on [(420, 140)], a {!checker_dark}
      cell; [(460, 140)] is a {!checker_light} cell inside the same hole.

    Every one of those points is the centre of its cell, 20 px from the cell's
    edges, and at least 30 px inside its hole. *)

val width : float
(** The scene's logical width: 560. *)

val height : float
(** The scene's logical height: 280. *)

val checker_light : Nopal_scene.Color.t
(** The checkerboard's light colour, opaque [rgb(250, 214, 165)]. *)

val checker_dark : Nopal_scene.Color.t
(** The checkerboard's dark colour, opaque [rgb(74, 108, 111)]. *)

val scene : Nopal_scene.Scene.t list
(** The checkerboard, then the multi-segment donut, then the full-turn donut, in
    paint order. Neither donut's hole is painted: the checkerboard shows through
    it because nothing is drawn there. *)

val view : unit -> 'msg Nopal_element.Element.t
(** The section, carrying the [data-testid] [donut-section]. The canvas sits in
    a box with the [data-testid] [donut-canvas], and the SVG image in a box with
    the [data-testid] [donut-svg]. Neither box nor anything inside it carries
    padding or a border, so the canvas and the image start at their box's
    top-left corner. *)
