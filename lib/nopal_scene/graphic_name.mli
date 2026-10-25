(** The accessible-name decision a graphic carries: a checked name, or
    decorative.

    A [Named] graphic is exposed to assistive technology as one image carrying
    that name. A [Decorative] graphic is absent from the accessibility tree.
    Decorative is a value of its own and never an empty name: a name that is
    empty or blank cannot be built.

    The accepted set is every string with at least one byte that is not blank. A
    blank byte is ASCII whitespace (tab, line feed, form feed, carriage return,
    space), any other C0 control (U+0000 to U+001F) or DEL (U+007F): none of
    them can be seen or read, and the SVG renderer drops the C0 controls. Any
    other character counts as content, so a name made only of a no-break space
    (U+00A0) or another Unicode space is accepted.

    The type is private: a consumer can match [Named] and [Decorative]
    exhaustively, but can build a [Named] only through {!named}.

    Pure and native: no function here raises. *)

type t = private
  | Named of string  (** A name accepted by {!named}, held unchanged. *)
  | Decorative  (** A graphic that carries no meaning of its own. *)

(** Why {!named} refused its input. The case carries the input it refused,
    unchanged. *)
type error =
  | Blank of { input : string }
      (** The input is empty, or every byte in it is ASCII whitespace, a C0
          control or DEL. *)

val named : string -> (t, error) result
(** [named input] is [Ok (Named input)] when [input] is in the accepted set, and
    [Error (Blank { input })] otherwise. [Ok] keeps the input unchanged: no
    whitespace is trimmed and no other normalisation is applied. *)

val decorative : t
(** [decorative] is [Decorative]. *)

val equal : t -> t -> bool
(** [equal a b] is [true] when both are [Decorative], or both are [Named] with
    equal strings, and [false] otherwise. *)

val aria_attrs : t -> (string * string option) list
(** [aria_attrs name] is the one table of accessibility attributes every
    renderer answers from. [Named n] gives [role="img"], [aria-label="n"] and
    the removal of [aria-hidden]; [Decorative] gives [aria-hidden="true"] and
    the removal of [role] and [aria-label]. A [None] value names a key to
    remove, which is what lets a reconcile across names leave exactly the new
    row behind. A renderer that only builds attributes keeps the [Some] pairs.
*)

val image_alt : t -> string
(** [image_alt name] is the [alt] text of an image: the label for [Named], and
    [""] for [Decorative], present and empty. *)
