(** Shared test utilities for Nopal unit tests. *)

val string_contains : string -> sub:string -> bool
(** [string_contains s ~sub] returns [true] if [sub] appears anywhere in [s]. *)

val pp_selector : Format.formatter -> Nopal_test.Test_renderer.selector -> unit
val error_testable : Nopal_test.Test_renderer.error Alcotest.testable
