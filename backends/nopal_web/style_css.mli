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

    [white-space] is the one property two fields feed, because CSS folds two
    independent axes into it: whether runs of spaces and tabs collapse
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
    significant. *)

val of_style : Nopal_style.Style.t -> css_prop list
(** [of_style style] returns the CSS properties for [style]. Only non-default
    values are emitted — a default [Style.t] produces [[]]. *)

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
    focused, then pressed. Returns [""] when the interaction has no states. *)
