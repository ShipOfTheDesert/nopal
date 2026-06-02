(** An ordered, in-process record of MVU loop activity.

    This is the {e wide} package-internal interface: it exposes the [recorder]
    (the recording target threaded into the MVU loop) and the [record_*]
    operations that {!Runtime} needs. The public re-export in
    {!Nopal_runtime.Telemetry} narrows this to the query surface only, so a
    {!handle} cannot be forged outside this package — the only way to obtain one
    is [Runtime.Make.create_with_telemetry], which calls {!create}. *)

type event =
  | Message of string  (** A dispatched message, serialised (or [<opaque>]). *)
  | Model_transition of { before : string; after : string }
      (** A model state change across one [update]. *)
  | Command of string  (** A command issued, by kind ([Cmd.describe]). *)
  | Subscription of string
      (** A subscription that fired, by kind ([Sub.describe]). *)

type recorder
(** The recording target threaded into the MVU loop. Internally
    [On of log | Off]; {!off} is a shared constant. A runtime built by
    {!Runtime.Make.create} holds {!off}; one built by
    [Runtime.Make.create_with_telemetry] holds an [On] recorder. *)

type handle
(** A query view onto an [On] recorder's log. The public re-export keeps this
    abstract with no constructor. *)

val off : recorder
(** The non-recording target. A shared constant — no allocation. *)

val create : unit -> recorder * handle
(** A fresh [On] recorder with an empty log, and a query handle onto the same
    log. *)

val record_message : recorder -> 'msg -> serialize:('msg -> string) -> unit
(** When [On], append [Message (serialize msg)]. When [Off], returns immediately
    without forcing [serialize] or boxing [msg] (REQ-N1). *)

val record_transition :
  recorder -> before:'m -> after:'m -> serialize:('m -> string) -> unit
(** When [On], append [Model_transition]. [Off]: no-op, no serialisation. *)

val record_command : recorder -> string -> unit
(** When [On], append [Command label]. [Off]: no-op. *)

val record_subscription : recorder -> string -> unit
(** When [On], append [Subscription label]. [Off]: no-op. *)

val events : handle -> event list
(** The recorded events, oldest first. *)

val clear : handle -> unit
(** Empty the log. Registered sinks are retained. *)

val on_record : handle -> (event -> unit) -> unit -> unit
(** Register a sink invoked for each event as it is recorded, in registration
    order. Returns a disposer that unregisters this sink; call it to stop
    receiving events (e.g. a one-shot waiter that has resolved) so sinks do not
    accumulate. Used by the Tauri forwarder to mirror events into the host
    process (REQ-F2). Sinks compose. *)

val pp_events : Format.formatter -> event list -> unit
(** Human-readable dump for failure diagnostics (REQ-F3/F7). *)
