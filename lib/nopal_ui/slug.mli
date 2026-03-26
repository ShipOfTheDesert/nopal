(** URL-safe slug generation from human-readable strings. *)

val slugify : string -> string
(** [slugify s] lowercases [s] and replaces every non-alphanumeric character
    with ['-']. Used internally for deterministic ID generation (e.g.
    [aria-describedby] linkage). *)
