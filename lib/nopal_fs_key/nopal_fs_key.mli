(** Key↔filename encoding for filesystem-backed storage backends.

    Native-clean (no platform deps): the encoding is pure string manipulation,
    so it is shared by the Tauri filesystem backend and tested independently of
    any Tauri runtime.

    {2 Encoding scheme}

    Each key becomes one flat filename. The full key is percent-encoded: every
    byte outside the unreserved set (lowercase ASCII letters, digits, hyphen and
    underscore) is written as ["%XX"] (uppercase hex). This is deliberately
    stricter than URI percent-encoding:

    - [/] and other path separators (including backslash) are encoded, so a key
      is never interpreted as a path — [../../etc/passwd] becomes a single
      filename and cannot escape the scoped directory.
    - [.] is encoded, so the keys [.] and [..] cannot name the current or parent
      directory.
    - Uppercase ASCII letters are encoded, so distinct keys cannot collide on a
      case-insensitive filesystem (["Foo"] and ["foo"] map to different
      filenames). *)

val encode_key : string -> string
(** [encode_key key] percent-encodes [key] into a flat filename per the scheme
    documented above. Total; never produces a path separator, ["."], or [".."].
*)

val decode_filename : string -> string option
(** [decode_filename name] reverses {!encode_key}. Accepts both upper- and
    lowercase hex digits. Returns [None] for a name that is not well-formed
    percent-encoding (e.g. a stray ["%"] or non-hex digits). *)
