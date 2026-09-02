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
    desktop: fires exactly once with zero insets. Apps need this only when they
    want the raw insets — viewport population is automatic via
    {!safe_area_source}. *)

val on_keyboard_height_change : (int -> 'msg) -> 'msg Nopal_mvu.Sub.t
(** Subscription (key ["nopal:keyboard-height"]) delivering soft-keyboard height
    in logical px: the height when shown, [0] when hidden. Dispatches [0] once
    at setup. On desktop: fires exactly once with [0]. *)

val safe_area_source :
  (Nopal_element.Viewport.safe_area -> unit) -> unit -> unit
(** Native viewport-population hook for [Nopal_web.mount] [~safe_area_source].
    [safe_area_source set] registers the native safe-area listener (dispatching
    [zero_insets] to [set] once at setup), and returns an unlisten cleanup. This
    is the mechanism by which the runtime populates [Viewport.safe_area]
    automatically.

    Supplied to [mount] on every Tauri host except iOS: the native bridge
    delivers real insets on Android and a harmless zero inset on desktop, so
    callers gate on a Tauri-host check — [__TAURI_INTERNALS__] present (not
    undefined) on the JS global, as [examples/kitchen_sink/main.ml] spells it —
    and on [not] {!Os.is_ios}. On iOS no source must be passed — it falls back
    to the CSS [env()] safe-area insets; supplying this there would feed a
    broken value while also suppressing that fallback. *)

val on_back_pressed : 'msg -> 'msg Nopal_mvu.Sub.t
(** [on_back_pressed msg] subscribes to the hardware back button, dispatching
    [msg] on each press. Keyed ["nopal:back-pressed"], listening for the Rust
    event of the same name: on Android the hardware button and the back swipe
    gesture fire it through [MainActivity]'s [OnBackPressedCallback] and the
    [notify_back_pressed] command, and [simulate_back_pressed] fires it on every
    platform.

    This is the capability an application {b without} a router needs, and it is
    an alternative to {!enable_hardware_back} rather than a companion to it —
    see that function for which to pick. It delivers the press straight to
    [update] with no [window.history] round trip, so it does not depend on a
    history entry existing.

    The key is fixed, so an application subscribes at most once. The runtime's
    subscription diff admits one subscription per key and is first-wins:
    batching a second [on_back_pressed] does not register a second listener, it
    reports a duplicate-key error and drops the loser. Where two parts of an
    application need the press, subscribe once and fan the msg out in [update].

    No setup-time dispatch: a press is an event, not a signal, so unlike
    {!on_safe_area_change} and {!on_keyboard_height_change} nothing is delivered
    until the button is pressed. Desktop has no hardware back button, so there
    the subscription fires only via [simulate_back_pressed].

    {b Tauri hosts only, and not a silent no-op off one.} Setup registers
    through [__TAURI_INTERNALS__] and calls [transformCallback] on it, so
    subscribing outside a Tauri host (a plain browser) throws at setup rather
    than quietly never firing — [Nopal_web]'s interpretation of a [Sub.custom]
    atom does not catch it. A shared application must gate the subscription on
    the same Tauri-host check {!safe_area_source} describes:
    [__TAURI_INTERNALS__] present (not undefined) on the JS global, as
    [examples/kitchen_sink/main.ml] spells it. This is shared with the safe-area
    and keyboard-height subscriptions, not particular to this one. *)

val enable_hardware_back : unit -> unit
(** Idempotently register a listener for the Rust [nopal:back-pressed] event. On
    Android the hardware back button fires it for real, wired through
    [MainActivity]'s [OnBackPressedCallback] into the [notify_back_pressed]
    command; the [simulate_back_pressed] debug IPC command fires the same event
    on every platform (the Tauri E2E's trigger). Each firing calls
    [window.history.back()]. Desktop has no hardware back button, so the event
    fires there only via [simulate_back_pressed].

    {b Requires a router.} [window.history.back()] raises a [popstate] only when
    there is a history entry to return to, which means only when the application
    has pushed one — i.e. only when it drives navigation through
    {!Nopal_platform.Router} (or calls {!push_state} itself). In an application
    that pushes no history entry the press does nothing at all: no [popstate],
    no [on_navigate], no message. Worse than nothing on Android, where
    [OnBackPressedCallback] is registered with [true] and has already swallowed
    the press, so the app does not background either. Such an application wants
    {!on_back_pressed} instead.

    The two are independent listeners on the same event and neither suppresses
    the other: an application that calls this {i and} subscribes to
    {!on_back_pressed} gets both effects from one press. Pick one. *)

val parse_safe_area : string -> Nopal_element.Viewport.safe_area option
(** Parse a ["top=<i>;right=<i>;bottom=<i>;left=<i>;"] safe-area payload into
    insets. Pure; exposed for testing only (cf. [Os.platform_of_string]).
    Returns [None] on malformed input. *)

val parse_keyboard_height : string -> int option
(** Parse a soft-keyboard height payload (["<i>"] logical px) into pixels. Pure;
    exposed for testing only. Returns [None] on malformed input. *)
