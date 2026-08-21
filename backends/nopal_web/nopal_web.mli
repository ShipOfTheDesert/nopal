(** Web backend for Nopal.

    Renders a Nopal application into the browser DOM using Brr. This is the only
    package that depends on browser APIs — application code imports only
    [nopal_mvu] and [nopal_element]. *)

type mounted = { unmount : unit -> unit }
(** Teardown handle returned by {!mount}. [unmount ()] releases everything the
    mount registered: it cancels the rAF render loop, disconnects the
    [ResizeObserver], shuts down the runtime (which tears down every active
    subscription listener — keydown, resize, visibility, intervals), and calls
    the [safe_area_source] unlisten when one was supplied. It is idempotent — a
    second call is inert and never raises — so repeated mount->unmount cycles
    never accumulate listeners or observers (feature 0121, FR-4).

    {!Blob_store} is deliberately outside its scope: blobs are application-owned
    data, not mount-registered resources, so unmounting leaves every stored blob
    resolvable — an upload still in flight at teardown keeps a working handle,
    and a blob registered with no mount in the picture has no mount to be
    released by. Releasing one is always an explicit caller act. *)

type mounted_with_telemetry = {
  telemetry : Nopal_runtime.Telemetry.handle;
  unmount : unit -> unit;
}
(** Teardown handle returned by {!mount_with_telemetry}. [telemetry] is the
    runtime's telemetry handle (formerly {!mount_with_telemetry}'s direct
    return); [unmount] tears the mount down exactly as {!mounted}'s does. *)

val mount :
  ?safe_area_source:((Nopal_element.Viewport.safe_area -> unit) -> unit -> unit) ->
  ?on_error:(string -> unit) ->
  (module Nopal_mvu.App.S with type model = 'model and type msg = 'msg) ->
  Brr.El.t ->
  mounted
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

    [~on_error] is the mount's single fault sink, and two layers report through
    it. It is forwarded to {!Nopal_runtime.Runtime.Make.create}, which sends it
    a description of any exception raised by the app's [update],
    [subscriptions], an effect thunk, or telemetry serialization, and of every
    post-shutdown dispatch that is dropped. It also receives the faults the
    frame itself catches — an exception escaping the DOM reconcile (which runs
    the app's [view]), the relative-scroll drain, or the focus drain — since
    nothing above a [requestAnimationFrame] callback would catch those, and
    without this they would reach the browser as uncaught errors the application
    cannot observe. Every description names the stage that failed, then the
    exception, then its backtrace: [render pass], [scroll drain] (a failing
    request also names its container id, in brackets), [focus drain], and the
    runtime's own labels alongside them.

    The two layers differ only in where a fault goes when [~on_error] is
    omitted: the runtime falls back to its own default (console report), the
    frame to this backend's, which tags the line with the backend name and
    writes it to standard error. Supplying [~on_error] therefore also routes
    render-pass and drain faults to it — the kitchen sink wires it to a visible
    toast as the reference pattern for surfacing faults in a packaged app, so a
    [view] that raises surfaces there too.

    This wires everything together: runtime creation, Lwd root subscription, DOM
    rendering, and event dispatch. It records no telemetry and installs no
    inspection surface — see {!mount_with_telemetry} for the telemetry sibling.

    Returns a {!mounted} whose [unmount] tears the whole thing down again; a
    long-lived single-page app can ignore it, but a host that mounts and
    discards apps must call it to avoid leaking the rAF loop, the observer, and
    the subscription listeners. *)

val mount_with_telemetry :
  ?safe_area_source:((Nopal_element.Viewport.safe_area -> unit) -> unit -> unit) ->
  ?on_error:(string -> unit) ->
  (module Nopal_mvu.App.S with type model = 'model and type msg = 'msg) ->
  ?serialize_msg:('msg -> string) ->
  ?serialize_model:('model -> string) ->
  Brr.El.t ->
  mounted_with_telemetry
(** [mount_with_telemetry (module MyApp) ?serialize_msg ?serialize_model target]
    is the telemetry sibling of {!mount} (and accepts the same
    [~safe_area_source] and [~on_error] hooks): it builds the runtime via
    {!Nopal_runtime.Runtime.Make.create_with_telemetry}, drives it exactly as
    {!mount} does, installs the [window.__nopal_telemetry__] browser bridge over
    its handle (RFC 0110, Layer 2), and returns that handle as the [telemetry]
    field of a {!mounted_with_telemetry} — paired with the same [unmount]
    teardown {!mount} yields.

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

val web_interpret_atom :
  dispatch:('msg -> unit) ->
  'msg Nopal_mvu.Sub.atom ->
  (unit -> unit, string) result
(** The web backend's per-atom subscription interpreter, handed to the runtime
    via {!Nopal_runtime.Runtime.Make.create} [~interpret_atom] and from there to
    [Sub_manager.diff]. Sets up one atom against the browser — [Every] via
    [setInterval], [Keydown]/[Keyup]/[Resize] via [window] listeners, and
    [Visibility] via a [document] [visibilitychange] listener — and returns its
    cleanup, or [Error] for an atom the web backend cannot serve. [Custom] runs
    its setup; [Viewport] is a no-op because the viewport is delivered through
    [set_viewport], not a listener. Exhaustive over [Sub.atom]: a new
    constructor is a compile error here, never a silent no-op (REQ-F3). Exposed
    as the interpreter over the public [atom] type so its behaviour is
    unit-testable directly. *)

module Style_css = Style_css
(** Re-exported for direct access. *)

module Style_sheet = Style_sheet
(** Re-exported for direct access. *)

module Renderer = Renderer
(** Re-exported for direct access. *)

module Canvas_renderer = Canvas_renderer
(** Re-exported for direct access (FR-7 canvas clear/hidpi tests). *)

module Platform_web = Platform_web
(** Web platform navigation via the browser History API. *)

val drain_focus : string Queue.t -> unit
(** [drain_focus pending] focuses each queued element id in FIFO order, emptying
    the queue. The runtime interprets [Cmd.focus] synchronously during dispatch,
    before the rAF DOM patch, so the web backend buffers focus requests and
    calls this once per frame after {!Renderer.update} (FR-3). Exposed for unit
    testing the drain order and last-wins result; not part of the behavioural
    API. *)

val drain_scroll_by :
  ?on_error:(string -> unit) ->
  (string * Nopal_element.Scroll_delta.t) Queue.t ->
  unit
(** [drain_scroll_by pending] applies each queued relative-scroll request in
    request order, emptying the queue. A request names its container by DOM id;
    the container's own scroll offset, visible height and content height are
    measured, {!Nopal_element.Scroll_delta.offset_for} is asked where the
    container must sit, and only an answer it gives is written. Both ways of not
    acting are the same no-op and neither is reported: an id naming nothing, and
    a measurement that leaves the container where it already is.

    [on_error] receives a description of any exception a request's measurement
    or write raises — naming the stage and the container id of the request that
    failed, so several queued requests stay tellable apart, and carrying the
    exception and its backtrace — and the drain carries on with the rest of the
    queue. Stopping at the failing request would strand the ones behind it, to
    be applied on a later frame against a layout one patch newer, which is what
    draining after the patch exists to prevent. It defaults to a report on
    standard error; {!mount} and {!mount_with_telemetry} pass their own
    [on_error] through, so an application's fault sink sees these too.

    Requests compose rather than overwrite, because each is measured against the
    offset the container holds when it is applied. Called once per frame after
    {!Renderer.update} and before the focus drain, so a request sizes itself
    against the layout the frame produced. The frame is also the only place it
    is called, so requests issued while the page is hidden — where the browser
    produces no frames — are not dropped but accumulate, and the first visible
    frame applies the whole backlog composed; an application issuing them from a
    timer can gate that on {!Nopal_mvu.Sub.on_visibility_change}.

    Alongside that unbounded backlog, and recorded for the same reason it is —
    as a decision rather than an oversight — the drain says nothing about what
    it did. Four different situations reach the same silent outcome: an id
    naming no element, an id naming an element with nothing to scroll, a
    platform measurement that is not finite, and a delta the application
    computed that is not finite. A telemetry log records that a relative-scroll
    command was issued and never whether it landed, so a mis-typed id and a
    container that would not have moved are indistinguishable from outside.
    {!Nopal_mvu.Cmd.focus} sets the precedent that a request naming nothing is a
    no-op and not a fault, and that is deliberately kept here. The trigger for
    revisiting it is the first consumer that has to tell those two apart —
    debugging a scroll that does not happen, with an id it cannot verify. Giving
    the drain an outcome to report before then would be a guess at what the
    outcome should say.

    Exposed for unit testing that ordering and that arithmetic; not part of the
    behavioural API. *)

module Storage = Storage
(** Browser localStorage access. See {!Storage}. *)

module Blob_store = Nopal_blob_web.Blob_store
(** Session-local handle-to-blob registry, re-exported so an application that
    already depends on the renderer can resolve the handles a file input hands
    it without taking a second dependency. See {!Nopal_blob_web.Blob_store}. *)
