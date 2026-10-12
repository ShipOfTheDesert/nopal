(** A checked external URL — the only destination an external link can carry.

    The accepted set is every string that starts with one of the schemes [http],
    [https], [mailto] or [tel], compared without regard to case, followed by
    [:]. Nothing after the scheme is examined: in particular [//] is not
    required, so [https:foo] is accepted (a browser resolves it against the
    current page). Any other scheme is refused, which keeps [javascript:] and
    [data:] — the schemes that run script — out of every link, together with the
    rest of the schemes a browser would hand to some other program.

    A string carrying a control character (U+0000 to U+001F, or U+007F)
    anywhere, or a space at either end, is refused before its scheme is read.
    Browsers strip those before reading a scheme, so ["java\tscript:…"] and
    [" javascript:…"] are [javascript:] URLs to a browser, whatever they look
    like here.

    Pure and native: no function here raises. *)

type t
(** A URL accepted by {!of_string}. *)

(** Why {!of_string} refused its input. Each case carries the input it refused,
    unchanged. *)
type error =
  | Missing_scheme of { input : string }
      (** The input has no scheme: there is no [:], or what precedes the first
          [:] is empty or is not a scheme a browser would read as one (a scheme
          is an ASCII letter followed by letters, digits, [+], [-] or [.]). A
          browser reads such a string as a path relative to the current page. *)
  | Unsupported_scheme of { input : string; scheme : string }
      (** The input's scheme is not one of the four accepted. [scheme] is the
          scheme as written in [input], case preserved. *)
  | Control_character of { input : string }
      (** The input carries a control character, or begins or ends with a space.
      *)

val of_string : string -> (t, error) result
(** [of_string input] is [Ok] of [input] when it is in the accepted set, and
    [Error] naming the first rule it breaks otherwise. The control-character
    rule is checked first, then the scheme. *)

val to_string : t -> string
(** [to_string url] is the input [url] was accepted from, unchanged. *)
