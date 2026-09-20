(** URL-safe slug generation from human-readable strings. *)

val slugify : string -> string
(** [slugify s] lowercases [s], replaces whitespace and non-alphanumeric
    characters with hyphens, collapses consecutive hyphens, and trims
    leading/trailing hyphens. *)

val derive_id :
  explicit:string option -> label:string -> ?suffix:string -> unit -> string
(** [derive_id ~explicit ~label ?suffix ()] returns the identifier a component
    gives a control: [explicit] when the caller set one, otherwise
    [slugify label]. When [suffix] is given it is appended after a single
    hyphen, so [~suffix:"error"] on the label ["First Name"] yields
    ["first-name-error"].

    Two properties callers rely on that the type does not show. [explicit] is
    used verbatim — never slugified — and it wins even when it is the empty
    string, so [~explicit:(Some "")] answers [""], or ["-error"] under that
    suffix, rather than falling back to the label. An empty [label] slugifies to
    the empty string, so with no explicit id the answer is likewise [""] or
    ["-error"]: the function is total and never raises, and it deliberately
    invents no non-empty fallback, because [Text_input.error_id] has always
    answered that way and is now expressed through this function. *)
