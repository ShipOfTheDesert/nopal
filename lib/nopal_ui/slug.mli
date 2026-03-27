(** URL-safe slug generation from human-readable strings. *)

val slugify : string -> string
(** [slugify s] lowercases [s], replaces whitespace and non-alphanumeric
    characters with hyphens, collapses consecutive hyphens, and trims
    leading/trailing hyphens. *)
