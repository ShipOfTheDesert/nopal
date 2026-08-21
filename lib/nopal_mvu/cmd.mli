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
(** [perform f] creates a command for a general effect that needs direct access
    to [dispatch].

    The thunk [f] receives a [dispatch] function and may call it zero, one, or
    many times, either synchronously or asynchronously. The runtime queues each
    dispatched message safely — re-entrant and async calls are handled.

    Use [perform] when:
    - The effect dispatches {b zero} messages (fire-and-forget side effects).
    - The effect dispatches {b many} messages over time (event listeners,
      streaming).
    - Reading a synchronous value and dispatching it immediately.

    For effects that produce {b exactly one} message asynchronously, prefer
    {!task} with a {!Task.t} — it composes better and supports cancellation.

    {[
      (* Fire-and-forget — zero dispatches *)
      Cmd.perform (fun _dispatch -> log_to_console "something happened")
    ]}

    {[
      (* Synchronous read — one dispatch *)
      Cmd.perform (fun dispatch ->
          let now = get_current_time () in
          dispatch (Time_read now))
    ]}

    {[
      (* Event listener — many dispatches over time *)
      Cmd.perform (fun dispatch ->
          setup_listener (fun event -> dispatch (Got_event event)))
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

val focus : string -> 'msg t
(** [focus id] requests that the element with the given [id] receives focus. The
    runtime interprets this by calling the platform's focus mechanism. Focus
    commands carry no message — they are pure side effects.

    Focus is the last of the three stages a frame applies, and it takes no
    [preventScroll], so it decides where a scroll container lands when it is
    batched with a movement of that container. See {!scroll_by}. *)

val scroll_by : string -> Nopal_element.Scroll_delta.t -> 'msg t
(** [scroll_by id delta] asks the platform to move the scroll container carrying
    the DOM id [id] by [delta]. One-shot: it is acted on once and never
    replayed, so several in one batch compose rather than overwrite. An [id]
    naming nothing, or naming something that cannot scroll, is a no-op and not
    an error. On a backend that renders no elements the request is inert, which
    is also not an error. Like {!focus}, it carries no message.

    The [id] is resolved in the document's own namespace, not the issuing
    application's: two applications mounted into one page share it, so a
    container id both of them use names one element and either can move it. Ids
    a page may host more than one of want a prefix that says which mount they
    belong to.

    This and a scroll container's [reveal] declaration both write one
    container's scroll offset, and a frame carrying both applies them in a fixed
    order: reveal first, relative scroll second, focus last. The imperative
    request wins over the derived one because the application issued it in that
    update. Focus is last and takes no [preventScroll], so batching {!focus} on
    an off-screen target with a [scroll_by] lands at focus's position, not the
    scroll's. *)

val map : ('a -> 'b) -> 'a t -> 'b t
(** Transform the message type of a command. *)

val is_none : 'msg t -> bool
(** [is_none cmd] is [true] iff [cmd] is {!none}. Lets callers skip empty
    commands without depending on the [{!describe}] ["none"] label string. *)

val describe : 'msg t -> string
(** A stable label naming the command's top-level constructor ([none] | [batch]
    | [perform] | [task] | [after] | [focus] | [scroll_by]), for telemetry
    [Command] events. Total over the variant. *)

val execute : 'msg dispatch -> 'msg t -> unit
(** [execute dispatch cmd] interprets a command tree, calling [dispatch] for
    each message produced. It acts on [perform] and [task] nodes only, and
    ignores all three of the others: [after], [focus] and [scroll_by] are each
    dropped with no report that a request was there. That makes it a test-only
    interpreter, for suites whose assertions are about the messages an app
    dispatches and nothing else. A suite that must see a delayed, focused or
    scrolled effect uses {!interpret} instead, which takes a handler for each of
    the three and so cannot drop one silently. *)

val extract_after : 'msg t -> (int * 'msg) option
(** [extract_after cmd] extracts the delay and message from an [after] command.
    Returns [None] if [cmd] is not an [after]. *)

val extract_focus : 'msg t -> string option
(** [extract_focus cmd] extracts the element id from a [focus] command. Returns
    [None] if [cmd] is not a [focus]. *)

val extract_focuses : 'msg t -> string list
(** [extract_focuses cmd] collects all focus ids from a command tree, recursing
    into [batch]. *)

val extract_scroll_bys : 'msg t -> (string * Nopal_element.Scroll_delta.t) list
(** [extract_scroll_bys cmd] collects every relative-scroll request in a command
    tree, recursing into [batch], in issue order. This is the only way a
    structural test can see the request: unlike a declaration on an element, a
    command leaves no trace in the element tree. *)

val interpret :
  focus:(string -> unit) ->
  scroll_by:(string -> Nopal_element.Scroll_delta.t -> unit) ->
  dispatch:'msg dispatch ->
  schedule_after:(int -> 'msg -> unit) ->
  'msg t ->
  unit
(** [interpret ~focus ~scroll_by ~dispatch ~schedule_after cmd] processes the
    entire command tree in a single pass. [Perform] and [Task] nodes are
    executed with [dispatch]. [After] nodes are passed to [schedule_after].
    [Focus] nodes call [focus] with the element id. [Scroll_by] nodes call
    [scroll_by] with the container id and the delta. [None] is ignored.

    [scroll_by] is a required label rather than an optional one: an interpreter
    allowed to omit it would discard the request without saying so, which is the
    silently-dropped-effect shape this codebase rules out.

    Note: [schedule_after] receives the raw message (['msg]), not a callback.
    The runtime wraps this to produce the [(int -> (unit -> unit) -> unit)]
    signature expected by platform schedulers (adding lifecycle guards before
    dispatching). *)
