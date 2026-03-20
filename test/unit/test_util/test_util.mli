(** Shared test utilities for Nopal unit tests. *)

val string_contains : string -> sub:string -> bool
(** [string_contains s ~sub] returns [true] if [sub] appears anywhere in [s]. *)

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
