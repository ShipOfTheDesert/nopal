(** A checked path on the page's own origin — the only destination an in-app
    ({!Link.Route}) or a new-tab ({!Link.New_tab}) link can carry.

    The accepted set is every string that starts with exactly one [/], where the
    character after it, if there is one, is neither [/] nor a backslash.
    Anything may follow, including a query and a fragment: ["/"] and
    ["/a/b?q=1#h"] are accepted.

    The first rule keeps out a string a browser would read as a URL of its own,
    [javascript:alert(1)] among them, and a path relative to the current page.
    The second keeps out a protocol-relative URL: ["//host/x"] names another
    host. A backslash counts as [/] because a browser resolving a path against
    an [http] or [https] page reads every backslash as [/], so ["/\\host/x"]
    names another host too. A backslash anywhere after the second character only
    changes which in-app path is named, and is accepted.

    A string carrying a control character (U+0000 to U+001F, or U+007F)
    anywhere, or a space at either end, is refused before the rules above are
    applied. Browsers strip those before reading a URL, so ["/\t/host"] is
    ["//host"] to a browser, whatever it looks like here.

    Pure and native: no function here raises. *)

type t
(** A path accepted by {!of_string}. *)

(** Why {!of_string} refused its input. Each case carries the input it refused,
    unchanged. *)
type error =
  | Not_absolute of { input : string }
      (** The input does not start with [/]. The empty string is one. *)
  | Protocol_relative of { input : string }
      (** The input starts with [/] and its second character is [/] or a
          backslash. *)
  | Control_character of { input : string }
      (** The input carries a control character, or begins or ends with a space.
      *)

val of_string : string -> (t, error) result
(** [of_string input] is [Ok] of [input] when it is in the accepted set, and
    [Error] naming the first rule it breaks otherwise. The control-character
    rule is checked first, then the leading [/], then the second character. *)

val to_string : t -> string
(** [to_string path] is the input [path] was accepted from, unchanged. *)
