(** SVG scene renderer.

    Renders [Nopal_scene.Scene.t] values to well-formed SVG 1.1 strings. No
    platform dependencies — compiles on native OCaml. *)

module Svg_fmt = Svg_fmt
(** Low-level SVG string formatting. Exposed for unit testing. *)

val render :
  name:Nopal_scene.Graphic_name.t ->
  width:float ->
  height:float ->
  Nopal_scene.Scene.t list ->
  string
(** [render ~name ~width ~height scenes] produces a well-formed SVG 1.1 string.

    The output includes an [xmlns] declaration, [viewBox] set to
    [0 0 width height], and all scene nodes rendered as SVG elements. Gradients
    and clip paths are collected into a [<defs>] block.

    [name] is the only source of the root [<svg>]'s accessible attributes. A
    [Named n] root carries [role="img"] and [aria-label="n"], with [n]
    XML-escaped, and is exposed as one image with that name. A [Decorative] root
    carries [aria-hidden="true"] and neither of the other two. No other
    accessibility attribute is derived, and [render] takes no attribute list.
    Should it gain one, [name] outranks any accessibility attribute in it.

    These attributes govern the string only where it is used inline or as a
    standalone document. An SVG shown through an [<img>] has its internal
    attributes ignored by assistive technology, so such an image is named by the
    [name] given to [Nopal_element.Element.image], and the string passed as its
    source is rendered with [Graphic_name.decorative]. *)
