(** Typed, platform-agnostic 2D drawing DSL for Nopal.

    [Nopal_draw] provides a pure scene description that view functions return
    inside {!Nopal_element.Element.Draw} nodes. The scene tree is interpreted by
    the platform backend (e.g. Canvas 2D in [nopal_web]).

    This package has no browser or platform dependencies and compiles on native
    OCaml. It depends only on {!Nopal_style} for shared font types. *)

module Color = Color
(** Float RGBA color type with hex parsing, HSL conversion, and palettes. *)

module Paint = Paint
(** Fill and stroke paint: solid colors, linear/radial gradients. *)

module Transform = Transform
(** Affine transforms: translate, scale, rotate, skew, matrix. *)

module Path = Path
(** Path segments and builder utilities (Catmull-Rom, area, arcs). *)

module Scene = Scene
(** Scene tree nodes: shapes, text, groups, and clipping. *)

module Scale = Scale
(** Linear scale for mapping data domain values to pixel range values. *)
