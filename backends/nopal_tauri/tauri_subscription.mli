(** Race-free Tauri event-listener subscriptions (RFC 0118, REQ-F8).

    A Tauri [plugin:event|listen] IPC resolves its unlisten function
    asynchronously — on a later microtask. A subscription torn down inside that
    window (cleanup before the listen IPC resolves) must still unlisten the
    moment the registration arrives, or the native listener leaks and a
    re-subscribe stacks a second live listener. This module models the
    registration as a [Pending | Active | Cancelled] state machine that honours
    a cleanup racing ahead of resolution, and is the only way [nopal_tauri]
    builds event-listener subscriptions. *)

val make :
  key:string ->
  event:string ->
  decode:(Jv.t -> 'msg option) ->
  'msg Nopal_mvu.Sub.t
(** [make ~key ~event ~decode] is a {!Nopal_mvu.Sub.custom} (keyed [key]) that
    listens for Tauri events named [event]. Each delivered event object is
    passed to [decode]; [Some msg] dispatches [msg] and [None] drops it, so a
    malformed host payload is ignored rather than raising. Cleanup is race-free
    against the async listen resolution; a registration failure is reported via
    the runtime on_error default path (the console under jsoo). *)

val listen_managed : event:string -> (Jv.t -> unit) -> unit -> unit
(** [listen_managed ~event on_event] registers a native listener for [event],
    passing each delivered event object to [on_event], and returns a cleanup
    function robust to the listen IPC resolving after cleanup (the same state
    machine as {!make}). It is the lower-level seam for subscriptions that need
    a setup-time dispatch {!make} cannot express — e.g. the safe-area and
    keyboard-height signals, which deliver a degenerate value at setup before
    any native event arrives. Added in RFC 0118 Implementation Decision 6. *)
