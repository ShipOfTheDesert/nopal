(** Layer 3 telemetry surface for Tauri (RFC 0110).

    The most exposed, most explicit telemetry opt-in. Given a
    {!Nopal_runtime.Telemetry.handle} (obtainable only from
    [Runtime.Make.create_with_telemetry] / [Nopal_web.mount_with_telemetry]),
    {!expose} mirrors every recorded event into the Tauri host process so the
    log is queryable from {e outside} the webview via {!get_telemetry}. Nothing
    here is reachable unless the application both holds a handle and calls
    {!expose}, so the surface is unforgeable and greppable (REQ-N2).

    The host-side Rust commands ([get_telemetry], [simulate_tray_click],
    [simulate_back_pressed]) are always compiled but inert until {!expose}
    starts forwarding events. *)

val expose : Nopal_runtime.Telemetry.handle -> unit
(** [expose handle] registers a {!Nopal_runtime.Telemetry.on_record} forwarder
    that emits each recorded event to the Tauri host as a [nopal:telemetry]
    event, where the host appends it to a process-side mirror. After this call,
    {!get_telemetry} returns the log from outside the webview, and synthetic
    triggers ([simulate_tray_click]) round-trip back into the mirror (REQ-F2). A
    no-op surface unless called. *)

val get_telemetry :
  unit -> (Nopal_runtime.Telemetry.event list, string) result Nopal_mvu.Task.t
(** [get_telemetry ()] queries the host-side mirror via [Ipc.invoke] and
    resolves with [Ok events] (oldest first) or [Error msg] if the Tauri runtime
    is unavailable, the IPC rejects, or the mirror payload is malformed.

    A {e non-draining} read: it does not empty the host mirror, so successive
    calls see the same events — in parity with the browser
    [__nopal_telemetry__.getEvents] bridge, which is also non-draining. The
    mirror does not grow unbounded because the host caps it (drop-oldest), in
    parity with the browser-side [Nopal_runtime.Telemetry] bound (feature 0120
    FR-7).

    Async (a {!Nopal_mvu.Task.t}, not a synchronous [result]) because the IPC
    reply only arrives via a promise — see RFC 0110 Implementation Decision 3.
    The error path resolves with [Error] rather than hanging (per the
    [nopal-task-from-callback-error-path] convention). *)
