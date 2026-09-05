(** Translate [Style.t] to inline CSS.

    This module converts Nopal's typed style values into CSS property-value
    pairs. It is an internal concern of [nopal_web] — application code never
    calls these functions directly. *)

type css_prop = { property : string; value : string }
(** A single CSS property-value pair. *)

val of_text : Nopal_style.Text.t -> css_prop list
(** [of_text text] returns the CSS properties for [text]. Only [Some] fields
    emit properties — [Text.default] produces [[]]. A set colour emits [color],
    which paints the glyphs; the box background is [of_style]'s concern.
    Ellipsis overflow emits [text-overflow:ellipsis] and [overflow:hidden].

    [white-space] is the first of two properties two fields feed, because CSS
    folds two independent axes into it: whether runs of spaces and tabs collapse
    ([Text.whitespace]) and whether a line breaks ([Text.text_overflow]'s [Wrap]
    and [No_wrap], with [Ellipsis] implying [No_wrap] and [Clip] implying
    neither). It is therefore resolved once from the pair and appears at most
    once in the result, never emitted from either field's own arm. Both axes
    unset emits nothing at all, so an unstyled element keeps the document
    default. Otherwise: [Preserve] gives [pre-wrap], or [pre] where the wrapping
    axis says no; an unset or [Collapse] whitespace gives [normal], or [nowrap]
    on the same condition. [Some Collapse] is not the same as [None] — it emits,
    so a descendant can climb out of an inherited preserving ancestor.

    Two consequences of folding both axes into one property. First, every one of
    those four values sets both axes, so an unset [Text.whitespace] stops
    inheriting as soon as [Text.text_overflow] is set — [normal] and [nowrap]
    reset collapsing on an element whose ancestor declared [pre-wrap]. A
    descendant that wants the ancestor's preservation and its own wrapping must
    author both. Second, [pre] and [pre-wrap] preserve line breaks as well as
    spaces and tabs, so [Preserve] also makes a newline in the content
    significant.

    [font-variant-numeric] is the second property two fields feed, for a
    different reason: CSS folds several independent numeric axes into it, of
    which two are expressed here — the advance width numerals take
    ([Text.figure_spacing]) and the forms they take ([Text.figure_style]). It is
    likewise resolved once from the pair and appears at most once in the result,
    never emitted from either field's own arm. Both axes unset emits nothing at
    all, so an unstyled element keeps the document default. Otherwise each set
    axis that is not the typeface's own default contributes one keyword, spacing
    before style — [tabular-nums] or [proportional-nums], then [lining-nums] or
    [oldstyle-nums] — and a pair contributing no keyword between them emits
    [normal]. [Some Normal_spacing] is not the same as [None]: it emits, so a
    descendant can climb out of an ancestor that set the axis, and
    [Some Normal_style] does the same on the other axis.

    The consequence is the one [white-space] carries. Every value of this
    property names both axes, so an unset [Text.figure_spacing] stops inheriting
    as soon as [Text.figure_style] is set, and an ancestor's value for the unset
    axis is lost on that element. An author who wants both must author both.
    What the declaration then draws is typeface-dependent: a font that does not
    carry the requested figure set ignores it silently, with no error and no
    fallback, which is a property of the font rather than of this encoding. *)

val of_style : Nopal_style.Style.t -> css_prop list
(** [of_style style] returns the CSS properties for [style]. Only non-default
    values are emitted — a default [Style.t] produces [[]].

    [box-shadow] carries the shadow's spread as a fourth length, after the blur
    and before the colour, which is the position the CSS grammar reads as
    spread. A zero spread omits that fourth length entirely rather than writing
    [0px], so a shadow that names no spread emits the same three-length
    declaration it emitted before spread was expressible; the two paint
    identically, so the omission loses nothing. A negative spread is a valid
    contraction of the shadow and is emitted. *)

val to_inline_string : css_prop list -> string
(** [to_inline_string props] joins property-value pairs into a semicolon-
    separated inline style string. Returns [""] for an empty list. *)

val apply_cursor : Brr.El.t -> Nopal_style.Cursor.t option -> unit
(** [apply_cursor el cursor] sets or clears the cursor inline style on [el]. *)

val base_class_rule : class_name:string -> css_prop list -> string
(** [base_class_rule ~class_name props] generates a CSS class rule:
    [.class_name \{ prop:value; prop:value; \}]. No [!important]. Returns [""]
    for an empty prop list. *)

val split_css_rules : string -> string list
(** [split_css_rules css] splits a concatenated CSS string like
    [".a:hover\{...\}.a:active\{...\}"] into individual rule strings by tracking
    brace depth. Returns [[]] for an empty string. *)

val normalize_key : string -> string -> string
(** [normalize_key css class_name] replaces all occurrences of [class_name] in
    [css] with a fixed placeholder so that structurally identical interactions
    produce the same cache key regardless of class name. *)

val interaction_rules : class_name:string -> Nopal_style.Interaction.t -> string
(** [interaction_rules ~class_name interaction] generates CSS pseudo-class rules
    without [!important]. Pseudo-class selectors ([.class:hover]) have higher
    specificity than the base class selector ([.class]), so normal cascade
    handles overrides. Precedence is encoded by rule order: hover first, then
    focused, then pressed. Returns [""] when the interaction has no states.

    [Interaction.focused] emits [.class:focus-visible], not [.class:focus], and
    the two are not interchangeable. A browser matches [:focus-visible] only
    when it judges a focus ring to be wanted, which in practice means keyboard
    focus: a mouse click focuses the element without matching it, by design, so
    a style placed here is deliberately invisible to a pointer user. That is the
    intended behaviour of a focus ring, not a defect to be routed around by
    reaching for [:focus].

    It does constrain how an automated check drives focus. Calling [focus()] on
    a text input matches [:focus-visible] in Chromium, because a text field is
    always taken to want the ring — observed, in the Playwright interaction
    case, which focuses an input that way and reads back a real computed style.
    Calling it on a button does not, so a check that needs a focused button has
    to press Tab — assumed: nothing in this repository exercises it. A check
    that focuses by clicking asserts the absence the browser is supposed to
    produce, so it passes whether or not the rule was ever emitted. *)
