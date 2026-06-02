(** Nopal Runtime — platform-agnostic MVU loop with Lwd reactivity.

    This package wires {!Nopal_mvu.App.S} modules to Lwd's reactive primitives.
    Backends subscribe to the reactive element tree and render it to their
    target platform. *)

module Sub_manager = Sub_manager
(** Subscription lifecycle manager. *)

module Runtime = Runtime
(** MVU runtime functor. *)

(** In-process record of MVU loop activity, the cross-platform E2E correctness
    contract (ADR 0108). This is the {e narrowed} public surface: only the query
    operations are exposed. The recording target and [record_*] operations are
    package-internal, so a {!Telemetry.handle} can only be obtained from
    [Runtime.Make.create_with_telemetry] — it is unforgeable. *)
module Telemetry : sig
  type event = Telemetry.event =
    | Message of string
    | Model_transition of { before : string; after : string }
    | Command of string
    | Subscription of string
        (** Re-exported with type identity so events queried here are the same
            type the runtime records internally. *)

  type handle = Telemetry.handle
  (** Identity shared with the internal recorder's handle, yet still abstract
      (the internal type is abstract and the recording operations stay hidden):
      a handle can only come from [Runtime.Make.create_with_telemetry] and
      cannot be forged. *)

  val events : handle -> event list
  (** The recorded events, oldest first. *)

  val clear : handle -> unit
  (** Empty the log. *)

  val on_record : handle -> (event -> unit) -> unit -> unit
  (** Register a sink invoked for each event as it is recorded. Returns a
      disposer that unregisters the sink. Sinks compose. *)

  val pp_events : Format.formatter -> event list -> unit
  (** Human-readable dump for failure diagnostics. *)
end
