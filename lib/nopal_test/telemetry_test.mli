(** Native telemetry harness for MVU apps (RFC 0110 Stage 4).

    Drives an app through the {e real} MVU loop while recording, so the captured
    history matches exactly what a production runtime records — there is no
    separate fold to drift out of sync (cf. {!Test_renderer.run_app}, which
    deliberately ignores commands and subscriptions). The OCaml-side assertion
    helpers match on the public {!Nopal_runtime.Telemetry.event} surface and the
    fragment-substring contract shared with the Playwright side. *)

val run_with_telemetry :
  (module Nopal_mvu.App.S with type model = 'model and type msg = 'msg) ->
  ?serialize_msg:('msg -> string) ->
  ?serialize_model:('model -> string) ->
  'msg list ->
  'model * Nopal_runtime.Telemetry.event list
(** [run_with_telemetry (module A) ?serialize_msg ?serialize_model msgs] builds
    a telemetry runtime for [A] via
    {!Nopal_runtime.Runtime.Make.create_with_telemetry} with an immediate
    scheduler (so {!Nopal_mvu.Cmd.after} fires synchronously), starts it,
    dispatches each message in [msgs] in order, and returns the final model
    together with the recorded event list (oldest first).

    Each serialiser defaults to [fun _ -> "<opaque>"] (same as the underlying
    constructor). The runtime itself now reports and swallows callback
    exceptions, so the harness reconstructs the dump-then-fail contract: if
    [A.update] or [A.subscriptions] raises during dispatch, the recorded history
    is dumped to [stderr] via {!Nopal_runtime.Telemetry.pp_events} and that
    exception is re-raised UNCHANGED with its backtrace intact (REQ-F5/F7).
    Failures the runtime only surfaces as a string — exceptions from
    {!Nopal_mvu.Cmd} effect thunks or from a serialiser — are instead reported
    as a [Failure] carrying their descriptions, after the same history dump.
    Either way the recorder's log is cleared on exit, so a subsequent run starts
    clean. *)

(** {2 Assertion helpers}

    Each raises [Failure] with a diagnostic listing the actual recorded events
    when the expectation is unmet (REQ-F3). Matching is by substring fragment,
    the contract shared with the Playwright assertions. *)

val assert_dispatched :
  Nopal_runtime.Telemetry.event list -> fragment:string -> unit
(** Pass if some [Message] event contains [fragment]. *)

val assert_sequence :
  Nopal_runtime.Telemetry.event list -> fragments:string list -> unit
(** Pass if each fragment appears as a [Message] in order, with unrelated events
    allowed between consecutive matches. Fails if a fragment is missing or the
    fragments appear out of order. *)

val assert_model_contains :
  Nopal_runtime.Telemetry.event list -> fragment:string -> unit
(** Pass if some [Model_transition]'s [after] field contains [fragment]. *)
