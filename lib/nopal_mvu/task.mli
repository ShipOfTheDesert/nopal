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

type cancellation_token
(** An opaque token used to cancel a running task. *)

val cancellable :
  (cancellation_token -> 'a t) -> cancellation_token * ('a, string) result t
(** [cancellable (fun token -> task)] wraps [task] so its result is delivered as
    [Ok value] on success or [Error "cancelled"] if cancelled before completion.
    Returns a token that can be passed to {!cancel}.

    The builder function receives the token, allowing platform backends to
    register {!set_on_cancel} hooks before the task is wrapped. If the task does
    not need the token, use [cancellable (fun _token -> task)].

    If the task has already resolved when [cancel] is called, the original [Ok]
    result is preserved. *)

val cancel : cancellation_token -> unit
(** [cancel token] signals cancellation. Idempotent — calling [cancel] multiple
    times or after the task has completed is a no-op. If an [on_cancel] hook has
    been registered via {!set_on_cancel}, it is called exactly once on first
    cancellation. *)

val set_on_cancel : cancellation_token -> (unit -> unit) -> unit
(** [set_on_cancel token f] registers a callback that [cancel] will invoke. Used
    by platform backends to wire cancellation to I/O abort mechanisms (e.g.,
    [AbortController]). If the token is already cancelled when [set_on_cancel]
    is called, [f] is invoked immediately. Only one hook may be registered; a
    second call replaces the first. *)

val is_cancelled : cancellation_token -> bool
(** [is_cancelled token] returns [true] if [cancel] has been called on this
    token. Used by platform backends to check cancellation state and wire it to
    I/O abort mechanisms (e.g., [AbortController]). *)

module Syntax : sig
  val ( let* ) : 'a t -> ('a -> 'b t) -> 'b t
  (** Bind operator: [let* x = task in body] is [bind (fun x -> body) task]. *)

  val ( let+ ) : 'a t -> ('a -> 'b) -> 'b t
  (** Map operator: [let+ x = task in expr] is [map (fun x -> expr) task]. *)
end
