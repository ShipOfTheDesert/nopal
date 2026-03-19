(** Shared test utilities for Nopal unit tests. *)

val string_contains : string -> sub:string -> bool
(** [string_contains s ~sub] returns [true] if [sub] appears anywhere in [s]. *)
