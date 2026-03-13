(** Pure scene description types for Nopal.

    [Nopal_scene] contains the types and constructors for colors, paints,
    transforms, paths, and scene nodes. It has no platform dependencies and
    compiles on native OCaml.

    Higher-level path algorithms (smooth curves, area fills, arcs) and
    data-to-pixel scales live in {!Nopal_draw}. *)

module Color = Color
(** Float RGBA color type with hex parsing, HSL conversion, and palettes. *)

module Paint = Paint
(** Fill and stroke paint: solid colors, linear/radial gradients. *)

module Transform = Transform
(** Affine transforms: translate, scale, rotate, skew, matrix. *)

module Path = Path
(** Path segment types and trivial builders. *)

module Scene = Scene
(** Scene tree nodes: shapes, text, groups, and clipping. *)
