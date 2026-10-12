(** The text pre-pass shared by {!Url} and {!Route_path}.

    Browsers strip control characters before reading a URL, so both checked
    types refuse them before looking at anything else. One definition keeps the
    two refusals from drifting apart. *)

val has_control_or_surrounding_space : string -> bool
(** [has_control_or_surrounding_space input] is [true] when [input] carries a
    control character (U+0000 to U+001F, or U+007F) anywhere, or a space at
    either end. *)
