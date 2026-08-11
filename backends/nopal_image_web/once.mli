(** A one-shot wrapper for an action that must run at most once per pipeline
    run. No platform types. *)

val wrap : ('a -> unit) -> 'a -> unit
(** [wrap f] is a function that applies [f] to its argument the first time it is
    called and does nothing on every later call.

    It exists for actions that both release a resource and deliver an outcome,
    where the two must happen together and exactly once. A pipeline reaches such
    an action from more than one place - the successful exit, and the failure
    exit of the region that surrounds it - and the second call is not an error
    to report but a duplicate to drop.

    The first call is marked as having happened before [f] runs, not after, so
    an [f] that raises part way through is still not run a second time. A caller
    that needs the raise to reach it should let it propagate: this drops
    repetitions, it does not swallow failures. *)
