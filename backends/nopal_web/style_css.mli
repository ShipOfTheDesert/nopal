(** Translate [Style.t] to inline CSS.

    This module converts Nopal's typed style values into CSS property-value
    pairs. It is an internal concern of [nopal_web] — application code never
    calls these functions directly. *)

type css_prop = { property : string; value : string }
(** A single CSS property-value pair. *)

val of_text : Nopal_style.Text.t -> css_prop list
(** [of_text text] returns the CSS properties for [text]. Only [Some] fields
    emit properties — [Text.default] produces [[]]. Ellipsis overflow emits
    [text-overflow:ellipsis], [overflow:hidden], and [white-space:nowrap]. *)

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
