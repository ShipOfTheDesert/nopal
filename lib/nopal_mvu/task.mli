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

val guard :
  on_exn:(exn -> 'e) -> ((('a, 'e) result -> unit) -> unit) -> ('a, 'e) result t
(** [guard ~on_exn f] is {!from_callback} for a result-typed task that also
    catches any exception raised {e synchronously} while [f] runs, resolving
    [Error (on_exn e)] instead of letting it escape. Platform backends bridge
    JavaScript interop here: a call such as [IDBObjectStore.transaction] or
    [Fetch.Request.init] can throw synchronously, and an uncaught exception
    would leave the task unresolved forever (the resolver is never called).

    Only synchronous exceptions are caught. A failure surfaced later from an
    asynchronous callback (e.g. an [onerror] event or a rejected promise) fires
    on the event loop, outside [f], and must be resolved explicitly by [f]
    itself. [f] must resolve at most once before returning — [guard] does not
    deduplicate, so a body that resolves and then raises would resolve twice. *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** [map f task] transforms the result of [task] by applying [f]. *)

val bind : ('a -> 'b t) -> 'a t -> 'b t
(** [bind f task] sequences two tasks: runs [task], passes its result to [f],
    then runs the resulting task. *)

val run : 'a t -> ('a -> unit) -> unit
(** [run task resolver] executes [task], calling [resolver] with the produced
    value. This is used by the runtime to execute tasks and by tests to observe
    results. *)

(** The result of a cancellable task: either the wrapped task [Completed] with
    its value, or [Cancelled]. Cancellation is a constructor, not a sentinel
    value layered into ['a], so callers never string-match to detect it. For a
    fallible task ['a] is itself [('ok, string) result], so callers match
    [Completed (Ok v) | Completed (Error e) | Cancelled]. *)
type 'a outcome = Completed of 'a | Cancelled

type cancellation_token
(** An opaque token used to cancel a running task. *)

val cancellable :
  (cancellation_token -> 'a t) -> cancellation_token * 'a outcome t
(** [cancellable (fun token -> task)] wraps [task] so its result is delivered as
    [Completed value] on success or [Cancelled] if cancelled before completion.
    Returns a token that can be passed to {!cancel}.

    The wrapped task delivers EXACTLY ONE outcome under every interleaving:
    - cancel before the inner task completes → [Cancelled], delivered at cancel
      time and not dependent on the aborted work ever resolving;
    - the inner task completes first → [Completed value]; a later [cancel]
      delivers nothing.

    The builder function receives the token, allowing platform backends to
    register {!set_on_cancel} hooks before the task is wrapped. If the task does
    not need the token, use [cancellable (fun _token -> task)]. *)

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
