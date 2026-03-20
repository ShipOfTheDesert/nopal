(** Composable async tasks — a continuation monad.

    [Task.t] describes an async operation that will eventually produce a value.
    Tasks are pure descriptions — they do not execute until [run] is called. Use
    [let*] / [let+] syntax from {!Syntax} for readable chaining. *)

type 'a t
(** An async operation that eventually produces a value of type ['a]. *)

val return : 'a -> 'a t
(** [return x] wraps a pure value into a task that resolves immediately. *)

val from_callback : (('a -> unit) -> unit) -> 'a t
(** [from_callback f] creates a task from a callback-style async operation. [f]
    receives a resolver and must call it exactly once when the operation
    completes. This is the bridge for platform-specific async primitives. *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** [map f task] transforms the result of [task] by applying [f]. *)

val bind : ('a -> 'b t) -> 'a t -> 'b t
(** [bind f task] sequences two tasks: runs [task], passes its result to [f],
    then runs the resulting task. *)

val run : 'a t -> ('a -> unit) -> unit
(** [run task resolver] executes [task], calling [resolver] with the produced
    value. This is used by the runtime to execute tasks and by tests to observe
    results. *)

module Syntax : sig
  val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
  (** Bind operator: [let* x = task in body] is [bind (fun x -> body) task]. *)

  val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
  (** Map operator: [let+ x = task in expr] is [map (fun x -> expr) task]. *)
end
