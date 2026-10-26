(** Font family and weight types for text rendering.

    These types are platform-agnostic. Backend packages translate them into
    platform-specific font specifications. *)

(** One font family: a generic family or a named face.

    The [Ui_*] generics name the platform's UI faces ([ui-sans-serif],
    [ui-serif], [ui-monospace], [ui-rounded]). Not every engine resolves them:
    Chromium renders each at the width of an unknown family, that is, in its
    default face. Place them before a {!Generic.t} in a {!type-stack} rather
    than using one alone.

    [Custom] takes the face's name exactly as written, never pre-escaped or
    pre-quoted: the serialisers quote and escape it. A name equal to a keyword
    stays a name, so [Custom "serif"] is a face called "serif", not the [Serif]
    generic.

    A family used alone has no last resort. When the face is missing, the engine
    falls back to its default face, which is often a serif. Use a {!type-stack}
    to name what renders instead. *)
type family =
  | System_ui
  | Sans_serif
  | Serif
  | Monospace
  | Ui_sans_serif
  | Ui_serif
  | Ui_monospace
  | Ui_rounded
  | Custom of string

(** The generics a stack may end in.

    The set is limited to the generics every target engine resolves to a real
    face. The [Ui_*] generics are excluded because an engine that does not
    resolve them falls through to its default face, which is the very outcome a
    last resort exists to prevent. [cursive] and [fantasy] name no predictable
    UI face, and [math], [emoji] and [fangsong] are not text faces, so none of
    them is offered. *)
module Generic : sig
  type t = System_ui | Sans_serif | Serif | Monospace

  val to_family : t -> family
  (** The same generic as a {!family}. *)
end

type stack
(** An ordered font stack: families tried in order, ending in a required
    {!Generic.t} last resort. *)

val stack : family list -> last_resort:Generic.t -> stack
(** [stack families ~last_resort] tries [families] in order, then [last_resort].
    [families] may be empty, giving a stack of the last resort alone. Omitting
    [~last_resort] does not yield a {!type-stack}. *)

val families : stack -> family list
(** The stack's families in order, the last resort last. Never empty. *)

val equal_stack : stack -> stack -> bool
(** Two stacks are equal when {!families} lists equal families in the same
    order. *)

type weight =
  | Thin
  | Extra_light
  | Light
  | Normal
  | Medium
  | Semi_bold
  | Bold
  | Extra_bold
  | Black

val equal_family : family -> family -> bool
(** Structural equality for font families. *)

val equal_weight : weight -> weight -> bool
(** Structural equality for font weights. *)

val family_to_css_string : family -> string
(** CSS representation of a font family. Generics are bare keywords.

    A [Custom] name is double-quoted. Inside the quotes, a double quote and a
    backslash are each preceded by a backslash, and [{], [}], [;] and every
    ASCII control character (U+0000 to U+001F and U+007F) are written as a
    lowercase CSS hex escape followed by one space: [Custom "a;b"] gives the
    quoted text a\3b b. No raw character that ends a string, a declaration or a
    rule reaches the output. Other characters, including spaces, commas and
    non-ASCII bytes, are written as given. An empty or whitespace-only name is
    serialised as written. *)

val stack_to_css_string : stack -> string
(** CSS [font-family] value of a stack: each of {!families} through
    {!family_to_css_string}, joined by [", "]. *)

val weight_to_css_string : weight -> string
(** CSS string representation of a font weight. Returns numeric "100"–"900". *)

val weight_to_int : weight -> int
(** Numeric value of a font weight (100–900). *)
