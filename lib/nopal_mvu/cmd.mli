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

val task : 'msg Task.t -> 'msg t
(** [task t] creates a command from an asynchronous {!Task.t}.

    The task [t] describes an async operation that eventually produces a
    message. The runtime executes the task and dispatches the resulting message.

    Use [task] when:
    - Making an HTTP request or other I/O that completes later.
    - Composing async operations with [Task.map] / [Task.bind].

    {[
      (* Fetch data from an API *)
      Cmd.task
        (let open Task.Syntax in
         let+ response = Http.get "/api/items" in
         Items_loaded response)
    ]} *)

val after : int -> 'msg -> 'msg t
(** [after ms msg] dispatches [msg] after [ms] milliseconds.

    This is a convenience over [task] for the common case of a single delayed
    message. *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** Transform the message type of a command. *)

val execute : 'msg dispatch -> 'msg t -> unit
(** [execute dispatch cmd] interprets a command tree, calling [dispatch] for
    each message produced. Ignores [after] nodes — use {!interpret} when [after]
    must be handled via a platform scheduler. Useful in tests that don't need
    scheduling. *)

val extract_after : 'msg t -> (int * 'msg) option
(** [extract_after cmd] extracts the delay and message from an [after] command.
    Returns [None] if [cmd] is not an [after]. *)

val interpret :
  dispatch:'msg dispatch ->
  schedule_after:(int -> 'msg -> unit) ->
  'msg t ->
  unit
(** [interpret ~dispatch ~schedule_after cmd] processes the entire command tree
    in a single pass. [Perform] and [Task] nodes are executed with [dispatch].
    [After] nodes are passed to [schedule_after]. [None] is ignored.

    Note: [schedule_after] receives the raw message (['msg]), not a callback.
    The runtime wraps this to produce the [(int -> (unit -> unit) -> unit)]
    signature expected by platform schedulers (adding lifecycle guards before
    dispatching). *)
