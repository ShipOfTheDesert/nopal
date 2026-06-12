(** Web backend for Nopal.

    Renders a Nopal application into the browser DOM using Brr. This is the only
    package that depends on browser APIs — application code imports only
    [nopal_mvu] and [nopal_element]. *)

val mount :
  ?safe_area_source:((Nopal_element.Viewport.safe_area -> unit) -> unit -> unit) ->
  (module Nopal_mvu.App.S with type model = 'model and type msg = 'msg) ->
  Brr.El.t ->
  unit
(** [mount (module MyApp) target] creates a runtime for [MyApp], renders the
    initial view into [target], and subscribes to reactive updates. The runtime
    uses [window.setTimeout] for [Cmd.after].

    [~safe_area_source] supplies safe-area insets from a native source (e.g.
    [Nopal_tauri.Platform_tauri.safe_area_source]) instead of CSS
    [env(safe-area-inset-...)]. When given, mount registers it; each delivered
    inset is merged with the current window dimensions and pushed via the
    runtime's [set_viewport], and the [ResizeObserver] rebuild reuses the most
    recent native insets (not a fresh [env()] read), so an orientation update
    survives a subsequent resize. When omitted, behaviour is unchanged (one-shot
    [env()] read + resize). [nopal_web] stays Tauri-agnostic: the argument is an
    opaque function supplied by the entry point.

    On mount, injects CSS custom properties that bridge
    [env(safe-area-inset-{top,right,bottom,left})] values into JS-readable form,
    reads them once, and passes them to the viewport. For safe area insets to
    report non-zero values on devices with hardware obstructions (e.g. iPhone
    notch), the page must include:

    {v <meta name="viewport" content="viewport-fit=cover"> v}

    A [ResizeObserver] on [target] triggers viewport updates. The observer uses
    [target] as a resize trigger but reads dimensions from
    [window.innerWidth]/[window.innerHeight], so the viewport always reflects
    the full browser window regardless of the target element's own size. This is
    correct when [target] fills the viewport (the expected usage). If [target]
    is embedded in a larger page and does not resize with the window, viewport
    updates may not fire.

    This wires everything together: runtime creation, Lwd root subscription, DOM
    rendering, and event dispatch. It records no telemetry and installs no
    inspection surface — see {!mount_with_telemetry} for the telemetry sibling.
*)

val mount_with_telemetry :
  ?safe_area_source:((Nopal_element.Viewport.safe_area -> unit) -> unit -> unit) ->
  (module Nopal_mvu.App.S with type model = 'model and type msg = 'msg) ->
  ?serialize_msg:('msg -> string) ->
  ?serialize_model:('model -> string) ->
  Brr.El.t ->
  Nopal_runtime.Telemetry.handle
(** [mount_with_telemetry (module MyApp) ?serialize_msg ?serialize_model target]
    is the telemetry sibling of {!mount} (and accepts the same
    [~safe_area_source] native viewport hook): it builds the runtime via
    {!Nopal_runtime.Runtime.Make.create_with_telemetry}, drives it exactly as
    {!mount} does, installs the [window.__nopal_telemetry__] browser bridge over
    its handle (RFC 0110, Layer 2), and returns that handle.

    The on/off distinction is the function name and the [handle] return type —
    not an optional argument — mirroring the [create] / [create_with_telemetry]
    split one layer up (RFC 0110, Implementation Decision 2). Because this
    function both creates and drives the runtime, the bridge always backs the
    runtime that is actually running, so it can never read an empty log.

    [serialize_msg] / [serialize_model] render recorded values to the strings
    stored in [Message] and [Model_transition] events; each defaults to
    [fun _ -> "<opaque>"] (REQ-F4). The returned handle is unforgeable (it can
    only come from here or {!Nopal_runtime.Runtime.Make.create_with_telemetry})
    and is the input to Layer 3 ([Nopal_tauri.Telemetry.expose]).

    The bridge exposes [getEvents()] (returns the recorded events, then clears)
    and [waitForMessage(fragment, timeoutMs)] (resolves on the first [Message]
    containing [fragment], rejects on timeout). Installing it is an explicit,
    greppable opt-in; the application is responsible for gating reachability in
    release builds (REQ-N2). *)

val parse_css_px : string -> int
(** [parse_css_px raw] parses a CSS pixel value string (e.g. ["42"], ["42px"],
    ["44.5px"]) and returns the integer pixel count. Fractional values are
    truncated. Returns [0] for empty or unparseable strings. *)

module Style_css = Style_css
(** Re-exported for direct access. *)

module Style_sheet = Style_sheet
(** Re-exported for direct access. *)

module Renderer = Renderer
(** Re-exported for direct access. *)

module Platform_web = Platform_web
(** Web platform navigation via the browser History API. *)

module Storage = Storage
(** Browser localStorage access. See {!Storage}. *)
