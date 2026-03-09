(** Canvas 2D scene renderer.

    Interprets [Nopal_draw.Scene.t] lists into Canvas 2D draw calls via Brr. *)

val render : Brr_canvas.C2d.t -> Nopal_draw.Scene.t list -> unit
(** [render ctx scene] clears the canvas and draws all scene nodes onto [ctx].
*)

val setup_hidpi :
  Brr.El.t -> Brr_canvas.C2d.t -> width:float -> height:float -> unit
(** [setup_hidpi el ctx ~width ~height] configures the canvas element [el] and
    context [ctx] for high-DPI rendering. Sets the canvas buffer to physical
    pixels ([width * devicePixelRatio]) and the CSS size to logical pixels
    ([width], [height]). Scales [ctx] by [devicePixelRatio] so drawing
    coordinates remain logical. *)
