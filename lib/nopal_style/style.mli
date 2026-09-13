(** Typed style properties for Nopal elements.

    [Style.t] describes layout constraints and visual paint for an element. It
    is platform-agnostic — no CSS, DOM, or browser concepts. Backend packages
    translate [Style.t] into platform rendering. *)

(** {1 Supporting types} *)

type direction = Row_dir | Column_dir
type align = Start | Center | End_ | Stretch | Space_between

(** How much room one dimension of an element asks for.

    [Fixed n] is honoured. On the axis its container lays children out along, an
    element sized [Fixed n] is not squeezed below [n], whatever its siblings'
    content would prefer, and it does not collapse away when it has no content
    of its own to hold it open. The guarantee runs in that one direction only:
    it forecloses the squeeze, and it says nothing about growth, so a
    [layout.flex_grow] set beside a [Fixed] size still lets the element take
    more than [n] — which is the caller asking for it.

    The other three are flexible by construction, and a renderer may give them
    less room than they ask for. [Fill] takes the room that is left, which is
    how two [Fill] siblings resolve to half of their container each. [Hug] takes
    what its own content needs. [Fraction f] asks for the fraction [f] of the
    container, and is reduced under pressure like the other two rather than held
    at [f].

    The guarantee covers the container's main axis, which is the only axis where
    siblings compete for room; a size on the cross axis behaves as it always
    has. It also covers only elements a container lays out: an element whose
    parent lays nothing out has no main axis, and its sizes are unaffected. The
    same holds for a root mounted into a container this framework did not build:
    its axis is not knowable from inside, so the guarantee is unavailable there
    even when the host does lay its children out. *)
type size = Fill | Hug | Fixed of float | Fraction of float

(** Color values. Defined in [Color], which sits below [Text] so that both a
    text style and a box paint can name it, and re-exported here by a type
    equation rather than a plain abbreviation so the four constructors stay
    usable through the [Style] spelling. The two spellings denote one type and
    are equally supported. *)
type color = Color.t =
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

type shadow = {
  x : float;
  y : float;
  blur : float;
  spread : float;
  color : color;
}
(** [spread] is a length in pixels applied before the blur: positive grows the
    shadow's box on every side, negative contracts it. *)

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
(** Zero offset, zero blur, zero spread, transparent. *)

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
