type line_height = Lh_normal | Lh_multiplier of float | Lh_px of float
type letter_spacing = Ls_normal | Ls_em of float
type text_align = Align_left | Align_center | Align_right | Align_justify
type text_decoration = Underline | Line_through | Overline | No_decoration
type text_transform = Uppercase | Lowercase | Capitalize | No_transform
type text_overflow = Clip | Ellipsis | Wrap | No_wrap

type t = {
  font_family : Font.family option;
  font_size : float option;
  font_weight : Font.weight option;
  line_height : line_height option;
  letter_spacing : letter_spacing option;
  text_align : text_align option;
  text_decoration : text_decoration option;
  text_transform : text_transform option;
  text_overflow : text_overflow option;
  italic : bool option;
}

let default =
  {
    font_family = None;
    font_size = None;
    font_weight = None;
    line_height = None;
    letter_spacing = None;
    text_align = None;
    text_decoration = None;
    text_transform = None;
    text_overflow = None;
    italic = None;
  }

let font_family v t = { t with font_family = Some v }
let font_size v t = { t with font_size = Some v }
let font_weight v t = { t with font_weight = Some v }
let line_height v t = { t with line_height = Some v }
let letter_spacing v t = { t with letter_spacing = Some v }
let text_align v t = { t with text_align = Some v }
let text_decoration v t = { t with text_decoration = Some v }
let text_transform v t = { t with text_transform = Some v }
let text_overflow v t = { t with text_overflow = Some v }
let italic v t = { t with italic = Some v }

let equal_line_height a b =
  match (a, b) with
  | Lh_normal, Lh_normal -> true
  | Lh_multiplier x, Lh_multiplier y -> Float.equal x y
  | Lh_px x, Lh_px y -> Float.equal x y
  | (Lh_normal | Lh_multiplier _ | Lh_px _), _ -> false

let equal_letter_spacing a b =
  match (a, b) with
  | Ls_normal, Ls_normal -> true
  | Ls_em x, Ls_em y -> Float.equal x y
  | (Ls_normal | Ls_em _), _ -> false

let equal_text_align a b =
  match (a, b) with
  | Align_left, Align_left -> true
  | Align_center, Align_center -> true
  | Align_right, Align_right -> true
  | Align_justify, Align_justify -> true
  | (Align_left | Align_center | Align_right | Align_justify), _ -> false

let equal_text_decoration a b =
  match (a, b) with
  | Underline, Underline -> true
  | Line_through, Line_through -> true
  | Overline, Overline -> true
  | No_decoration, No_decoration -> true
  | (Underline | Line_through | Overline | No_decoration), _ -> false

let equal_text_transform a b =
  match (a, b) with
  | Uppercase, Uppercase -> true
  | Lowercase, Lowercase -> true
  | Capitalize, Capitalize -> true
  | No_transform, No_transform -> true
  | (Uppercase | Lowercase | Capitalize | No_transform), _ -> false

let equal_text_overflow a b =
  match (a, b) with
  | Clip, Clip -> true
  | Ellipsis, Ellipsis -> true
  | Wrap, Wrap -> true
  | No_wrap, No_wrap -> true
  | (Clip | Ellipsis | Wrap | No_wrap), _ -> false

let equal a b =
  Option.equal Font.equal_family a.font_family b.font_family
  && Option.equal Float.equal a.font_size b.font_size
  && Option.equal Font.equal_weight a.font_weight b.font_weight
  && Option.equal equal_line_height a.line_height b.line_height
  && Option.equal equal_letter_spacing a.letter_spacing b.letter_spacing
  && Option.equal equal_text_align a.text_align b.text_align
  && Option.equal equal_text_decoration a.text_decoration b.text_decoration
  && Option.equal equal_text_transform a.text_transform b.text_transform
  && Option.equal equal_text_overflow a.text_overflow b.text_overflow
  && Option.equal Bool.equal a.italic b.italic
