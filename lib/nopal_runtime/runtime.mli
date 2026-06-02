(** Runtime — MVU loop powered by Lwd reactive primitives.

    Accepts any module satisfying {!Nopal_mvu.App.S} and drives the full MVU
    cycle: dispatch -> update -> view -> subscriptions. Model changes propagate
    reactively through [Lwd.t]. *)

module Make (A : Nopal_mvu.App.S) : sig
  type t
  (** Opaque runtime handle. *)

  val create :
    ?focus:(string -> unit) ->
    ?schedule_after:(int -> (unit -> unit) -> unit) ->
    unit ->
    t
  (** [create ?focus ?schedule_after ()] builds a runtime for the app [A].

      [focus id] is a platform-provided callback used to implement
      {!Nopal_mvu.Cmd.focus}. Defaults to a no-op. The web backend passes a
      callback that calls [document.getElementById(id).focus()].

      [schedule_after ms callback] is a platform-provided timer used to
      implement {!Nopal_mvu.Cmd.after}. Defaults to a no-op that silently drops
      delayed commands. For tests, pass [fun _ms f -> f ()] for immediate
      execution.

      [A.init] is called eagerly at creation time to establish the initial
      model. The returned command is stored and executed when {!start} is
      called. This means {!model} returns the init value immediately after
      [create], before [start] is called. *)

  val create_with_telemetry :
    ?focus:(string -> unit) ->
    ?schedule_after:(int -> (unit -> unit) -> unit) ->
    ?serialize_msg:(A.msg -> string) ->
    ?serialize_model:(A.model -> string) ->
    unit ->
    t * Telemetry.handle
  (** [create_with_telemetry ?focus ?schedule_after ?serialize_msg
       ?serialize_model ()] builds a runtime that records every dispatched
      message, model transition, issued command, and subscription firing into an
      in-process log, and returns it alongside the {!Telemetry.handle} that
      queries that log.

      [focus] and [schedule_after] behave exactly as in {!create}. The returned
      runtime has the same type [t] and identical loop semantics — telemetry
      only observes, it never alters dispatch behaviour (REQ-N3).

      [serialize_msg] / [serialize_model] render recorded values to the strings
      stored in [Message] and [Model_transition] events. Each defaults to
      [fun _ -> "<opaque>"]: omitting a serialiser still records the event, just
      with the [<opaque>] placeholder for that side (REQ-F4).

      The returned handle is the only one in existence for this runtime, and it
      cannot be forged elsewhere — this is the sole way to obtain a
      {!Telemetry.handle} (REQ-N1/N2). A runtime built by {!create} records
      nothing and yields no handle. *)

  val start : t -> unit
  (** Execute the init command, set up initial subscriptions, and begin
      accepting dispatches. The initial model is already set at {!create} time.

      The runtime lifecycle is [Created -> Running -> Shut_down]. [start]
      transitions from [Created] to [Running].

      Raises [Invalid_argument] if already started or shut down. *)

  val dispatch : t -> A.msg -> unit
  (** Enqueue a message. If no update is in progress, process it immediately.
      Otherwise it is queued and processed after the current update completes.

      Raises [Invalid_argument] if called before {!start} or after {!shutdown}.
  *)

  val model : t -> A.model
  (** The current model value. Primarily for testing. *)

  val view : t -> A.msg Nopal_element.Element.t Lwd.t
  (** The reactive element tree. Backends subscribe to this via [Lwd.root] /
      [Lwd.quick_sample]. Recomputes whenever the model changes. *)

  val viewport : t -> Nopal_element.Viewport.t
  (** The current viewport. Defaults to {!Nopal_element.Viewport.desktop}. *)

  val set_viewport : t -> Nopal_element.Viewport.t -> unit
  (** Update the viewport. If the new viewport is equal to the current one, this
      is a no-op (no rerender). Otherwise, the reactive view recomputes and any
      [on_viewport_change] subscriptions fire. *)

  val shutdown : t -> unit
  (** Stop all subscriptions and reject further dispatches. Transitions from
      [Running] to [Shut_down].

      Raises [Invalid_argument] if called before {!start} or already shut down.
  *)
end
