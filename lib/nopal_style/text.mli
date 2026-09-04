(** Typed text/typography properties for Nopal elements.

    [Text.t] describes text presentation: font, size, weight, alignment,
    decoration, color, overflow, whitespace, figures. All fields are [option] —
    [None] means the property is unset, letting the platform default or CSS
    inheritance apply. The exceptions are the fields that share a platform
    declaration with a sibling. [whitespace] is one, and only when
    [text_overflow] is also set: the two resolve to a single declaration, so an
    unset [whitespace] is overwritten rather than inherited there.
    [figure_spacing] and [figure_style] are the other, on the same footing and
    for the same reason. See their own comments below.

    Inheritance is a web-cascade property, not a Nopal one. A [Text.t] attached
    to a box reaches that box's descendants only where the target platform
    cascades — which the DOM backend does and a canvas or GPU backend does not.
    Every field here shares that semantic, [color] included. Portable authoring
    therefore puts the value on the text element itself rather than on an
    ancestor box.

    [whitespace] is inert on any backend that lays text out from a scene rather
    than from an element — a canvas or GPU path receives geometry and glyph
    runs, never a [Text.t], so there is nothing there to honour or ignore. Note
    that the polarity inverts once such a backend does shape text itself: a
    shaper is handed the string as written, so preserving the whitespace is its
    natural behaviour and [Collapse] is the side that has to be implemented. The
    DOM backend is the mirror image, because the document default collapses runs
    of spaces and tabs.

    [figure_spacing] and [figure_style] request an OpenType feature rather than
    describing geometry, so what they produce depends on the rendering typeface.
    A font that does not carry the requested figure set ignores the request
    silently: there is no error, no fallback and no way to detect it from here,
    and the text renders in the font's own figures. A correct declaration that
    changes nothing on screen is therefore the expected outcome for such a font,
    not a failure.

    The two figure axes also resolve to one platform declaration whose every
    value names both axes, so setting either one alone resets the other on that
    element and an ancestor's value for the unset axis is lost there. An author
    who wants both must author both. This is the same consequence [whitespace]
    carries with [text_overflow], for the same reason.

    Both figure axes are inert on any backend that lays text out from a scene
    rather than from an element, for the reason [whitespace] is: such a path
    receives geometry and glyph runs, never a [Text.t]. There is no inverted
    polarity to describe here, unlike [whitespace] — canvas text is styled
    through the CSS font shorthand, which carries no numeric-figure property,
    and the canvas surface exposes no equivalent attribute, so figures drawn
    that way take the typeface's own and nothing here can change them. *)

type line_height = Lh_normal | Lh_multiplier of float | Lh_px of float
type letter_spacing = Ls_normal | Ls_em of float
type text_align = Align_left | Align_center | Align_right | Align_justify
type text_decoration = Underline | Line_through | Overline | No_decoration
type text_transform = Uppercase | Lowercase | Capitalize | No_transform
type text_overflow = Clip | Ellipsis | Wrap | No_wrap

(** Whether runs of spaces and tabs in the content are significant. [Preserve]
    keeps them; [Collapse] states the opposite explicitly, which is what a
    descendant of a preserving ancestor needs on a platform where the property
    is inherited. [Preserve] also makes line breaks in the content significant:
    a newline in the string renders as a break rather than as more collapsible
    whitespace, because no platform value separates the two.

    This is only the collapsing axis: whether a line breaks stays with
    [text_overflow]'s [Wrap] and [No_wrap], and the two compose within one [t].
    They do not compose across the cascade, because they resolve to one
    declaration whose every value sets both axes: leaving [whitespace] unset
    while setting [text_overflow] emits a value that also resets collapsing, so
    an ancestor's [Preserve] is lost on that element. Authoring the wrapping
    axis on a descendant of a preserving ancestor therefore means authoring
    [Preserve] on it too. *)
type whitespace = Collapse | Preserve

(** Which advance width numerals take. [Tabular] gives every digit the same
    width so figures line up in a column; [Proportional] gives each its natural
    width. [Normal_spacing] asks for the typeface's own figures and is not the
    same as leaving the field unset: it emits a declaration, so a descendant of
    an element that set this axis can climb back out of it. *)
type figure_spacing = Tabular | Proportional | Normal_spacing

(** Which forms numerals take. [Lining] sits them on the baseline at a uniform
    height; [Oldstyle] lets them ascend and descend like lowercase letters.
    [Normal_style] is the explicit typeface default, on the same footing as
    [Normal_spacing] and distinct from leaving the field unset. *)
type figure_style = Lining | Oldstyle | Normal_style

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
  color : Color.t option;
  whitespace : whitespace option;
  figure_spacing : figure_spacing option;
  figure_style : figure_style option;
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

val color : Color.t -> t -> t
(** [color c t] sets [color] to [Some c]. *)

val whitespace : whitespace -> t -> t
(** [whitespace ws t] sets [whitespace] to [Some ws]. Leaving it [None] renders
    exactly as before; it does not mean [Collapse], which emits a declaration of
    its own. *)

val figure_spacing : figure_spacing -> t -> t
(** [figure_spacing fs t] sets [figure_spacing] to [Some fs]. Leaving it [None]
    renders exactly as before; it does not mean [Normal_spacing], which emits a
    declaration of its own. *)

val figure_style : figure_style -> t -> t
(** [figure_style fs t] sets [figure_style] to [Some fs]. Leaving it [None]
    renders exactly as before; it does not mean [Normal_style], which emits a
    declaration of its own. *)

(** {1 Comparison} *)

val equal : t -> t -> bool
(** Field-by-field equality. Uses [Float.equal] for [font_size] and float fields
    inside [line_height] and [letter_spacing], and [Color.equal] for [color], so
    the alpha component is compared float-safely too. *)

val equal_line_height : line_height -> line_height -> bool
val equal_letter_spacing : letter_spacing -> letter_spacing -> bool
val equal_text_align : text_align -> text_align -> bool
val equal_text_decoration : text_decoration -> text_decoration -> bool
val equal_text_transform : text_transform -> text_transform -> bool
val equal_text_overflow : text_overflow -> text_overflow -> bool
val equal_whitespace : whitespace -> whitespace -> bool
val equal_figure_spacing : figure_spacing -> figure_spacing -> bool
val equal_figure_style : figure_style -> figure_style -> bool
