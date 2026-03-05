(** Commands — pure descriptions of side effects.

    A command is a value that describes work the runtime should perform.
    Application code never executes effects directly — it returns commands from
    [init] and [update], and the runtime interprets them. *)

type 'msg dispatch = 'msg -> unit
(** A function that sends a message to the MVU runtime for processing. *)

type 'msg t
(** Abstract command type. Application code cannot pattern-match on this. *)

val none : 'msg t
(** A command that does nothing. *)

val batch : 'msg t list -> 'msg t
(** Combine multiple commands. Nested batches are flattened by the runtime. *)

val perform : ('msg dispatch -> unit) -> 'msg t
(** [perform f] creates a command for a {b synchronous, immediate} effect.

    The thunk [f] receives a [dispatch] function, performs a short, non-blocking
    operation, and calls [dispatch] exactly once before returning. The runtime
    may call [f] on the current execution tick.

    Use [perform] when:
    - Reading a value that is available right now (e.g. current time, a random
      number, a value from synchronous storage).
    - Dispatching a message derived from a pure computation that is factored out
      of [update] for clarity.

    {[
      (* Generate a random ID and dispatch it *)
      Cmd.perform (fun dispatch ->
          let id = Random.int 1_000_000 in
          dispatch (Got_id id))
    ]}

    {[
      (* Read a synchronous value *)
      Cmd.perform (fun dispatch ->
          let now = get_current_time () in
          dispatch (Time_read now))
    ]} *)

val task : ('msg dispatch -> unit) -> 'msg t
(** [task f] creates a command for an {b asynchronous, deferred} effect.

    The callback [f] receives a [dispatch] function and may hold onto it,
    calling [dispatch] zero or more times at a later point. The runtime treats
    [f] as potentially long-lived — it will not block on [f] returning.

    Use [task] when:
    - Making an HTTP request or other I/O that completes later.
    - Setting up a one-shot timer or callback.
    - Performing work that may produce multiple messages over time.
    - The effect may fail silently (zero dispatches is valid).

    {[
      (* Fetch data from an API *)
      Cmd.task (fun dispatch ->
          http_get "/api/items" (fun response ->
              dispatch (Items_loaded response)))
    ]}

    {[
      (* One-shot timer (prefer Cmd.after for simple delays) *)
      Cmd.task (fun dispatch ->
          set_timeout 500 (fun () -> dispatch Timer_fired))
    ]} *)

val after : int -> 'msg -> 'msg t
(** [after ms msg] dispatches [msg] after [ms] milliseconds.

    This is a convenience over [task] for the common case of a single delayed
    message. *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** Transform the message type of a command. *)

val execute : 'msg dispatch -> 'msg t -> unit
(** [execute dispatch cmd] interprets a command tree, calling [dispatch] for
    each message produced. Used by the runtime. *)

val extract_after : 'msg t -> (int * 'msg) option
(** [extract_after cmd] extracts the delay and message from an [after] command.
    Returns [None] if [cmd] is not an [after]. *)
