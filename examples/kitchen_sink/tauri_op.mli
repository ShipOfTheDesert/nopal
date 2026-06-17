(** Result-task chaining for the Tauri ops (RFC 0118, REQ-F5).

    Every [Window]/[App]/[Os]/[Event.emit] Tauri op resolves
    [('a, string) result Nopal_mvu.Task.t]. [Make] builds [let*]/[let+]
    operators that sequence the happy path and route the FIRST [Error] to a
    caller-supplied [tauri_op_error] message, so a failed op neither hangs the
    chain nor vanishes silently. Distinct from {!Nopal_mvu.Task.Syntax}, which
    binds the raw value: the [Store] arms keep using [Task.Syntax] because they
    pass the [result] through to their own [*Result] messages. *)

module Make (M : sig
  type msg
  (** The application message type. *)

  val tauri_op_error : string -> msg
  (** Wraps a failed Tauri op's error string into the message that surfaces it.
  *)
end) : sig
  val ( let* ) :
    ('a, string) result Nopal_mvu.Task.t ->
    ('a -> M.msg Nopal_mvu.Task.t) ->
    M.msg Nopal_mvu.Task.t
  (** [let* x = op in k] runs [op]; on [Ok v] it continues with [k v], on
      [Error e] it short-circuits to [Task.return (tauri_op_error e)]. *)

  val ( let+ ) :
    ('a, string) result Nopal_mvu.Task.t ->
    ('a -> M.msg) ->
    M.msg Nopal_mvu.Task.t
  (** [let+ x = op in f x] maps [Ok v] to [f v] and [Error e] to
      [tauri_op_error e]. *)
end
