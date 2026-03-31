(** SVG scene renderer.

    Renders [Nopal_scene.Scene.t] values to well-formed SVG 1.1 strings. No
    platform dependencies — compiles on native OCaml. *)

module Svg_fmt = Svg_fmt
(** Low-level SVG string formatting. Exposed for unit testing. *)

val render : width:float -> height:float -> Nopal_scene.Scene.t list -> string
(** [render ~width ~height scenes] produces a well-formed SVG 1.1 string.

    The output includes an [xmlns] declaration, [viewBox] set to
    [0 0 width height], and all scene nodes rendered as SVG elements. Gradients
    and clip paths are collected into a [<defs>] block. *)
