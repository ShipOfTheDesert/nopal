(** Browser localStorage access.

    Wraps [Brr_io.Storage] for [window.localStorage], converting between OCaml
    [string] and [Jstr.t]. All operations are synchronous — safe to call
    directly from [update].

    Values persist across page reloads within the same origin. *)

val get : string -> string option
(** [get key] returns the value associated with [key] in localStorage, or [None]
    if the key does not exist. *)

val set : string -> string -> unit
(** [set key value] stores [value] under [key] in localStorage. Silently ignores
    quota-exceeded errors. *)

val remove : string -> unit
(** [remove key] deletes [key] from localStorage. Does nothing if the key does
    not exist. *)

val clear : unit -> unit
(** [clear ()] removes all keys from localStorage. *)
