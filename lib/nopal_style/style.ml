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
}

type paint = {
  background : color option;
  border : border option;
  opacity : float;
  shadow : shadow option;
  overflow : overflow;
}

type t = { layout : layout; paint : paint; text : Text.t }

let default_border =
  { width = 0.; style = No_border; color = Transparent; radius = 0. }

let default_shadow = { x = 0.; y = 0.; blur = 0.; color = Transparent }

let default_layout =
  {
    direction = None;
    main_align = None;
    cross_align = None;
    wrap = None;
    gap = None;
    padding_top = None;
    padding_right = None;
    padding_bottom = None;
    padding_left = None;
    width = None;
    height = None;
    flex_grow = None;
  }

let default_paint =
  {
    background = None;
    border = None;
    opacity = 1.0;
    shadow = None;
    overflow = Visible;
  }

let default_text = Text.default

let default =
  { layout = default_layout; paint = default_paint; text = default_text }

let rgba r g b a = Rgba { r; g; b; a }
let hex s = Hex s
let named s = Named s
let transparent = Transparent
let with_layout f s = { s with layout = f s.layout }
let with_paint f s = { s with paint = f s.paint }
let set_layout l s = { s with layout = l }
let set_paint p s = { s with paint = p }
let with_text f s = { s with text = f s.text }
let set_text t s = { s with text = t }

let padding top right bottom left l =
  {
    l with
    padding_top = Some top;
    padding_right = Some right;
    padding_bottom = Some bottom;
    padding_left = Some left;
  }

let padding_all v l = padding v v v v l
let empty = default

let equal_color a b =
  match (a, b) with
  | Rgba r1, Rgba r2 ->
      Int.equal r1.r r2.r
      && Int.equal r1.g r2.g
      && Int.equal r1.b r2.b
      && Float.equal r1.a r2.a
  | Hex s1, Hex s2 -> String.equal s1 s2
  | Named s1, Named s2 -> String.equal s1 s2
  | Transparent, Transparent -> true
  | (Rgba _ | Hex _ | Named _ | Transparent), _ -> false

let equal_border_style a b =
  match (a, b) with
  | Solid, Solid -> true
  | Dashed, Dashed -> true
  | Dotted, Dotted -> true
  | No_border, No_border -> true
  | (Solid | Dashed | Dotted | No_border), _ -> false

let equal_border (a : border) (b : border) =
  Float.equal a.width b.width
  && equal_border_style a.style b.style
  && equal_color a.color b.color
  && Float.equal a.radius b.radius

let equal_shadow a b =
  Float.equal a.x b.x
  && Float.equal a.y b.y
  && Float.equal a.blur b.blur
  && equal_color a.color b.color

let equal_size a b =
  match (a, b) with
  | Fill, Fill -> true
  | Hug, Hug -> true
  | Fixed f1, Fixed f2 -> Float.equal f1 f2
  | Fraction f1, Fraction f2 -> Float.equal f1 f2
  | (Fill | Hug | Fixed _ | Fraction _), _ -> false

let equal_direction a b =
  match (a, b) with
  | Row_dir, Row_dir -> true
  | Column_dir, Column_dir -> true
  | (Row_dir | Column_dir), _ -> false

let equal_align a b =
  match (a, b) with
  | Start, Start -> true
  | Center, Center -> true
  | End_, End_ -> true
  | Stretch, Stretch -> true
  | Space_between, Space_between -> true
  | (Start | Center | End_ | Stretch | Space_between), _ -> false

let equal_layout a b =
  Option.equal equal_direction a.direction b.direction
  && Option.equal equal_align a.main_align b.main_align
  && Option.equal equal_align a.cross_align b.cross_align
  && Option.equal Bool.equal a.wrap b.wrap
  && Option.equal Float.equal a.gap b.gap
  && Option.equal Float.equal a.padding_top b.padding_top
  && Option.equal Float.equal a.padding_right b.padding_right
  && Option.equal Float.equal a.padding_bottom b.padding_bottom
  && Option.equal Float.equal a.padding_left b.padding_left
  && Option.equal equal_size a.width b.width
  && Option.equal equal_size a.height b.height
  && Option.equal Float.equal a.flex_grow b.flex_grow

let equal_overflow a b =
  match (a, b) with
  | Visible, Visible -> true
  | Hidden, Hidden -> true
  | (Visible | Hidden), _ -> false

let equal_paint a b =
  Option.equal equal_color a.background b.background
  && Option.equal equal_border a.border b.border
  && Float.equal a.opacity b.opacity
  && Option.equal equal_shadow a.shadow b.shadow
  && equal_overflow a.overflow b.overflow

let equal a b =
  equal_layout a.layout b.layout
  && equal_paint a.paint b.paint
  && Text.equal a.text b.text
