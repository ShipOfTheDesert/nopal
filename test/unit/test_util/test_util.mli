(** Shared test utilities for Nopal unit tests. *)

val string_contains : string -> sub:string -> bool
(** [string_contains s ~sub] returns [true] if [sub] appears anywhere in [s]. *)

val contains_fragment : string -> fragment:string -> bool
(** [contains_fragment record ~fragment] is [string_contains] with the left-hand
    side anchored: [fragment] has to begin [record] or follow the space that
    separates it from the fragment before it.

    A serialized model record joins [field=value;] fragments with a space, so
    every fragment is bounded on the right by its own ';' and on the left by
    nothing at all. That is enough until one field name ends in another —
    [original_byte_size=] ends in [byte_size=] — at which point an unanchored
    search for the shorter field is satisfied by the longer field's fragment
    whenever the two values coincide. Use this wherever a field name is a suffix
    of another field name in the same record; [string_contains] stays correct
    for everything else. *)

val pp_selector : Format.formatter -> Nopal_test.Test_renderer.selector -> unit
val error_testable : Nopal_test.Test_renderer.error Alcotest.testable
val node_pp : Format.formatter -> Nopal_test.Test_renderer.node -> unit

val node_equal :
  Nopal_test.Test_renderer.node -> Nopal_test.Test_renderer.node -> bool

val node_testable : Nopal_test.Test_renderer.node Alcotest.testable

val check_node :
  string ->
  Nopal_test.Test_renderer.node ->
  Nopal_test.Test_renderer.node ->
  unit

val count_unique : ('a -> 'a -> bool) -> 'a list -> int
(** [count_unique eq lst] returns the number of distinct elements in [lst] using
    [eq] for equality comparison. *)
