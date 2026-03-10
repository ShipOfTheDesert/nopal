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

val to_important_rule_body : css_prop list -> string
(** [to_important_rule_body props] formats property-value pairs as a CSS
    declaration block body with [!important] on each property. Needed for
    interaction pseudo-class rules to override inline base styles. Returns [""]
    for an empty list. *)

val interaction_rules : class_name:string -> Nopal_style.Interaction.t -> string
(** [interaction_rules ~class_name interaction] generates CSS pseudo-class rules
    for the given interaction. Returns a string containing [:hover],
    [:focus-visible], and/or [:active] rule blocks with [!important]
    declarations. Precedence is encoded by rule order: hover first, then
    focused, then pressed. Returns [""] when the interaction has no states. *)
