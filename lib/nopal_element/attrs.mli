(** Resolving a lookup against an attribute list.

    An attribute list is the [~attrs] a view hands a builder, carried on
    {!Element.t} as a [(string * string) list]. This module holds the single
    definition of what a repeated key in such a list resolves to, so that the
    backends which answer attribute questions cannot answer them differently.

    Everything here is pure and compiles on native OCaml; it references nothing
    else in this package. *)

val resolve : string -> (string * string) list -> string option
(** [resolve name attrs] is the value [name] resolves to in [attrs], or [None]
    when no pair in [attrs] declares [name].

    A duplicate key resolves to the {b last} pair, which is what a browser
    leaves on an element after writing the list in order. Total: every list
    answers, and a pair whose value is the empty string answers [Some ""] — a
    declared empty value is a value, not an absence.

    This is the within-list tier of the precedence rule stated under
    {!Element.box} — {i within the list, the last pair wins}. The tier above it,
    a typed-field derivation outranking the list, is each renderer's own to
    apply; this answers only what the list itself says. *)
