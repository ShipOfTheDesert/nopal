(** Typed style properties for Nopal elements.

    [Style.t] describes layout constraints and visual paint for an element. It
    is platform-agnostic — no CSS, DOM, or browser concepts. Backend packages
    translate [Style.t] into platform rendering. *)

(** {1 Supporting types} *)

type direction = Row_dir | Column_dir
type align = Start | Center | End_ | Stretch | Space_between
type size = Fill | Hug | Fixed of float | Fraction of float

type color =
  | Rgba of { r : int; g : int; b : int; a : float }
  | Hex of string
  | Named of string
  | Transparent

type border_style = Solid | Dashed | Dotted | No_border

type border = {
  width : float;
  style : border_style;
  color : color;
  radius : float;
}

type shadow = { x : float; y : float; blur : float; color : color }
type overflow = Visible | Hidden
type position = Pos_static | Pos_relative | Pos_absolute | Pos_fixed

(** {1 Layout and Paint} *)

type layout = {
  direction : direction option;
  main_align : align option;
  cross_align : align option;
  wrap : bool option;
  gap : float option;
  padding_top : float option;
  padding_right : float option;
  padding_bottom : float option;
  padding_left : float option;
  width : size option;
  height : size option;
  flex_grow : float option;
  position : position option;
  top : float option;
  right : float option;
  bottom : float option;
  left : float option;
  z_index : int option;
}

type paint = {
  background : color option;
  border : border option;
  opacity : float;
  shadow : shadow option;
  overflow : overflow;
}

(** {1 Top-level style} *)

type t = { layout : layout; paint : paint; text : Text.t }

(** {1 Defaults} *)

val default_border : border
(** Zero-width, no-border-style, transparent, zero-radius. *)

val default_shadow : shadow
(** Zero offset, zero blur, transparent. *)

val default_layout : layout
(** All fields [None]. *)

val default_paint : paint
(** No background, no border, full opacity, no shadow, visible overflow. *)

val default_text : Text.t
(** [Text.default] — all fields [None]. *)

val default : t
(** [default_layout] + [default_paint] + [default_text]. *)

(** {1 Constructors} *)

val rgba : int -> int -> int -> float -> color
(** [rgba r g b a] creates an RGBA color. *)

val hex : string -> color
(** [hex s] creates a color from a hex string (e.g. ["#ff0000"]). *)

val named : string -> color
(** [named s] creates a color from a named color (e.g. ["red"]). *)

val transparent : color
(** The transparent color. *)

(** {1 Immutable update functions} *)

val with_layout : (layout -> layout) -> t -> t
(** [with_layout f style] returns a new style where [layout] is
    [f style.layout]. The original style is not mutated. *)

val with_paint : (paint -> paint) -> t -> t
(** [with_paint f style] returns a new style where [paint] is [f style.paint].
    The original style is not mutated. *)

val set_layout : layout -> t -> t
(** [set_layout l style] replaces the layout entirely. *)

val set_paint : paint -> t -> t
(** [set_paint p style] replaces the paint entirely. *)

val with_text : (Text.t -> Text.t) -> t -> t
(** [with_text f style] returns a new style where [text] is [f style.text]. The
    original style is not mutated. *)

val set_text : Text.t -> t -> t
(** [set_text t style] replaces the text entirely. *)

(** {1 Padding helpers} *)

val padding : float -> float -> float -> float -> layout -> layout
(** [padding top right bottom left layout] sets all four padding values to
    [Some]. *)

val padding_all : float -> layout -> layout
(** [padding_all v layout] sets all four padding sides to [Some v]. *)

(** {1 Comparison} *)

val equal_color : color -> color -> bool
(** Structural equality for colors. Uses [Float.equal] for alpha. *)

val equal_layout : layout -> layout -> bool
(** Structural equality for layouts. Uses [Float.equal] for float fields. *)

val equal_paint : paint -> paint -> bool
(** Structural equality for paints. Uses [Float.equal] for float fields. *)

val equal : t -> t -> bool
(** Structural equality for styles. *)

(** {1 Backward compatibility} *)

val empty : t
(** @deprecated Use [default] instead. *)
