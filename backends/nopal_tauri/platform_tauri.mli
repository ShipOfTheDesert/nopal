(** Tauri platform capabilities: History-API navigation + filesystem storage.

    Implements {!Nopal_platform.Platform.S}. Tauri applications run in a
    webview, so navigation maps onto [window.history] (push/replace/back) and
    the [popstate] event exactly as the web backend does; [storage] is a
    filesystem-backed {!Nopal_storage.S} via {!Nopal_storage_tauri.Make}
    ([tauri-plugin-fs]). Pass [(module Platform_tauri)] to
    {!Nopal_platform.Router.create} (which needs only [NAV]) or to an
    application functor over {!Nopal_platform.Platform.S}.

    This module exists as a distinct entry point so applications can depend on
    [nopal_tauri] without pulling in [nopal_web]. *)

include Nopal_platform.Platform.S

val on_safe_area_change :
  (Nopal_element.Viewport.safe_area -> 'msg) -> 'msg Nopal_mvu.Sub.t
(** Subscription (built on [Sub.custom], key ["nopal:safe-area"]) delivering the
    current safe-area insets and re-delivering on change (e.g. orientation).
    Dispatches [Viewport.zero_insets] once at setup, then native values. On
    desktop: fires exactly once with zero insets (REQ-F4, REQ-N1). Apps need
    this only when they want the raw insets — viewport population is automatic
    via {!safe_area_source}. *)

val on_keyboard_height_change : (int -> 'msg) -> 'msg Nopal_mvu.Sub.t
(** Subscription (key ["nopal:keyboard-height"]) delivering soft-keyboard height
    in logical px: the height when shown, [0] when hidden. Dispatches [0] once
    at setup. On desktop: fires exactly once with [0] (REQ-F5, REQ-N1). *)

val safe_area_source :
  (Nopal_element.Viewport.safe_area -> unit) -> unit -> unit
(** Native viewport-population hook for {!Nopal_web.mount} [~safe_area_source].
    [safe_area_source set] registers the native safe-area listener (dispatching
    [zero_insets] to [set] once at setup), and returns an unlisten cleanup. This
    is the mechanism behind REQ-F4's "runtime populates [Viewport.safe_area]
    automatically". *)

val enable_hardware_back : unit -> unit
(** Idempotently register a listener for the Rust [nopal:back-pressed] event
    (fired by the Android hardware back button and by the
    [simulate_back_pressed] debug IPC command). Each firing calls
    [window.history.back()], producing a [popstate] the router's existing
    [on_navigate] subscription consumes — no app code required (REQ-F3). Inert
    on desktop (the event never fires). *)

val parse_safe_area : string -> Nopal_element.Viewport.safe_area option
(** Parse a ["top=<i>;right=<i>;bottom=<i>;left=<i>;"] safe-area payload into
    insets. Pure; exposed for testing only (cf. [Os.platform_of_string]).
    Returns [None] on malformed input. *)

val parse_keyboard_height : string -> int option
(** Parse a soft-keyboard height payload (["<i>"] logical px) into pixels. Pure;
    exposed for testing only. Returns [None] on malformed input. *)
