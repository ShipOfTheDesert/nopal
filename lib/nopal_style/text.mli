(** Typed text/typography properties for Nopal elements.

    [Text.t] describes text presentation: font, size, weight, alignment,
    decoration, overflow. All fields are [option] — [None] means the property is
    unset, letting the platform default or CSS inheritance apply. *)

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

(** {1 Defaults} *)

val default : t
(** All fields [None]. *)

(** {1 Builders} *)

val font_family : Font.family -> t -> t
(** [font_family fam t] sets [font_family] to [Some fam]. *)

val font_size : float -> t -> t
(** [font_size rem t] sets [font_size] to [Some rem]. *)

val font_weight : Font.weight -> t -> t
(** [font_weight w t] sets [font_weight] to [Some w]. *)

val line_height : line_height -> t -> t
(** [line_height lh t] sets [line_height] to [Some lh]. *)

val letter_spacing : letter_spacing -> t -> t
(** [letter_spacing ls t] sets [letter_spacing] to [Some ls]. *)

val text_align : text_align -> t -> t
(** [text_align a t] sets [text_align] to [Some a]. *)

val text_decoration : text_decoration -> t -> t
(** [text_decoration d t] sets [text_decoration] to [Some d]. *)

val text_transform : text_transform -> t -> t
(** [text_transform tr t] sets [text_transform] to [Some tr]. *)

val text_overflow : text_overflow -> t -> t
(** [text_overflow ov t] sets [text_overflow] to [Some ov]. *)

val italic : bool -> t -> t
(** [italic b t] sets [italic] to [Some b]. *)

(** {1 Comparison} *)

val equal : t -> t -> bool
(** Field-by-field equality. Uses [Float.equal] for [font_size] and float fields
    inside [line_height] and [letter_spacing]. *)

val equal_line_height : line_height -> line_height -> bool
val equal_letter_spacing : letter_spacing -> letter_spacing -> bool
val equal_text_align : text_align -> text_align -> bool
val equal_text_decoration : text_decoration -> text_decoration -> bool
val equal_text_transform : text_transform -> text_transform -> bool
val equal_text_overflow : text_overflow -> text_overflow -> bool
