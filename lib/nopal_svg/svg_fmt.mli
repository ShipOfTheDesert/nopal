(** Low-level SVG string formatting.

    Used by {!Nopal_svg.render}. Exposed for unit testing of individual
    conversion functions. *)

type ctx
(** Rendering context that accumulates [<defs>] entries. *)

val create_ctx : unit -> ctx
(** Fresh context with empty defs and reset ID counter. *)

val color_to_css : Nopal_scene.Color.t -> string
(** [color_to_css c] produces ["rgba(R,G,B,A)"] with integer RGB (0-255) and
    float alpha. *)

val paint_to_fill_attr : ctx -> Nopal_scene.Paint.t -> string
(** Returns the SVG [fill="..."] attribute value. For gradients, registers a def
    and returns ["url(#grad-N)"]. [No_paint] returns ["none"]. *)

val stroke_to_attrs : ctx -> Nopal_scene.Paint.stroke -> string
(** Returns stroke-related SVG attribute string:
    [stroke="..." stroke-width="..." stroke-dasharray="..."
     stroke-dashoffset="..." stroke-linecap="..." stroke-linejoin="..."]. *)

val transform_to_attr : Nopal_scene.Transform.t -> string
(** Single transform to SVG transform function string. Angles are converted from
    radians to degrees. *)

val transforms_to_attr : Nopal_scene.Transform.t list -> string
(** List of transforms to a single [transform="..."] attribute value. *)

val path_to_d : Nopal_scene.Path.segment list -> string
(** Path segments to SVG [d="..."] attribute value. Arc_to is approximated as a
    series of Bezier curves. *)

val blend_to_css : Nopal_scene.Scene.blend -> string
(** Blend mode to CSS [mix-blend-mode] value. *)

val line_cap_to_string : Nopal_scene.Paint.line_cap -> string
(** Line cap to SVG string. *)

val line_join_to_string : Nopal_scene.Paint.line_join -> string
(** Line join to SVG string. *)

val render_node : ctx -> Buffer.t -> Nopal_scene.Scene.t -> unit
(** Render a single scene node, appending SVG to the buffer. *)

val defs_to_string : ctx -> string
(** Serialize all accumulated [<defs>] entries. *)
