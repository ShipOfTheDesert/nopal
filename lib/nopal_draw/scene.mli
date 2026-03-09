(** Scene tree type for 2D drawing.

    Describes shapes, text, groups, and clipping regions as a pure value tree.
*)

(** Compositing blend mode for groups. *)
type blend =
  | Normal
  | Multiply
  | Screen
  | Overlay
  | Darken
  | Lighten
  | Color_dodge
  | Color_burn
  | Hard_light
  | Soft_light
  | Difference
  | Exclusion

type text_anchor =
  | Start
  | Middle
  | End_anchor  (** Horizontal text alignment relative to the anchor point. *)

type text_baseline =
  | Top
  | Middle_baseline
  | Bottom
  | Alphabetic  (** Vertical text alignment relative to the anchor point. *)

type t =
  | Rect of {
      x : float;
      y : float;
      w : float;
      h : float;
      rx : float;
      ry : float;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Circle of {
      cx : float;
      cy : float;
      r : float;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Ellipse of {
      cx : float;
      cy : float;
      rx : float;
      ry : float;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Line of {
      x1 : float;
      y1 : float;
      x2 : float;
      y2 : float;
      stroke : Paint.stroke;
    }
  | Path of {
      segments : Path.segment list;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Polygon of {
      points : (float * float) list;
      fill : Paint.t;
      stroke : Paint.stroke option;
    }
  | Polyline of { points : (float * float) list; stroke : Paint.stroke }
  | Text of {
      x : float;
      y : float;
      content : string;
      font_size : float;
      font_family : Nopal_style.Font.family;
      font_weight : Nopal_style.Font.weight;
      fill : Paint.t;
      anchor : text_anchor;
      baseline : text_baseline;
    }
  | Group of {
      opacity : float;
      blend : blend;
      transforms : Transform.t list;
      children : t list;
    }
  | Clip of { shape : t; children : t list }
      (** A node in the 2D scene tree. *)

val rect :
  ?rx:float ->
  ?ry:float ->
  ?fill:Paint.t ->
  ?stroke:Paint.stroke ->
  x:float ->
  y:float ->
  w:float ->
  h:float ->
  unit ->
  t
(** [rect ~x ~y ~w ~h ()] creates a rectangle. Optional [rx]/[ry] set corner
    radii for rounded rectangles. *)

val circle :
  ?fill:Paint.t ->
  ?stroke:Paint.stroke ->
  cx:float ->
  cy:float ->
  r:float ->
  unit ->
  t
(** [circle ~cx ~cy ~r ()] creates a circle centered at [(cx, cy)]. *)

val ellipse :
  ?fill:Paint.t ->
  ?stroke:Paint.stroke ->
  cx:float ->
  cy:float ->
  rx:float ->
  ry:float ->
  unit ->
  t
(** [ellipse ~cx ~cy ~rx ~ry ()] creates an ellipse with separate x/y radii. *)

val line :
  ?stroke:Paint.stroke ->
  x1:float ->
  y1:float ->
  x2:float ->
  y2:float ->
  unit ->
  t
(** [line ~x1 ~y1 ~x2 ~y2 ()] creates a line segment. *)

val path : ?fill:Paint.t -> ?stroke:Paint.stroke -> Path.segment list -> t
(** [path segments] creates a path from a list of segments. *)

val polygon : ?fill:Paint.t -> ?stroke:Paint.stroke -> (float * float) list -> t
(** [polygon points] creates a closed polygon. *)

val polyline : ?stroke:Paint.stroke -> (float * float) list -> t
(** [polyline points] creates an open polyline (stroke only). *)

val text :
  ?font_size:float ->
  ?font_family:Nopal_style.Font.family ->
  ?font_weight:Nopal_style.Font.weight ->
  ?fill:Paint.t ->
  ?anchor:text_anchor ->
  ?baseline:text_baseline ->
  x:float ->
  y:float ->
  string ->
  t
(** [text ~x ~y content] creates styled text at [(x, y)]. Defaults: font_size
    16, Sans_serif, Normal weight, solid black, Start anchor, Alphabetic
    baseline. *)

val group :
  ?opacity:float -> ?blend:blend -> ?transforms:Transform.t list -> t list -> t
(** [group children] creates a group with shared opacity, blend mode, and
    transforms applied to all children. *)

val clip : shape:t -> t list -> t
(** [clip ~shape children] clips [children] to the outline of [shape]. *)

val equal : t -> t -> bool
(** Structural equality for scene nodes. *)
