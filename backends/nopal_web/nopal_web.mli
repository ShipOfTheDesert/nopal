(** Web backend for Nopal.

    Renders a Nopal application into the browser DOM using Brr. This is the only
    package that depends on browser APIs — application code imports only
    [nopal_mvu] and [nopal_element]. *)

val mount :
  (module Nopal_mvu.App.S with type model = 'model and type msg = 'msg) ->
  Brr.El.t ->
  unit
(** [mount (module MyApp) target] creates a runtime for [MyApp], renders the
    initial view into [target], and subscribes to reactive updates. The runtime
    uses [window.setTimeout] for [Cmd.after].

    On mount, injects CSS custom properties that bridge
    [env(safe-area-inset-{top,right,bottom,left})] values into JS-readable form,
    reads them once, and passes them to the viewport. For safe area insets to
    report non-zero values on devices with hardware obstructions (e.g. iPhone
    notch), the page must include
    {v <meta name="viewport" content="viewport-fit=cover"> v}.

    A [ResizeObserver] on [target] triggers viewport updates. The observer uses
    [target] as a resize trigger but reads dimensions from
    [window.innerWidth]/[window.innerHeight], so the viewport always reflects the
    full browser window regardless of the target element's own size. This is
    correct when [target] fills the viewport (the expected usage). If [target] is
    embedded in a larger page and does not resize with the window, viewport
    updates may not fire.

    This is the only function application code calls from [nopal_web]. It wires
    everything together: runtime creation, Lwd root subscription, DOM rendering,
    and event dispatch. *)

val parse_css_px : string -> int
(** [parse_css_px raw] parses a CSS pixel value string (e.g. ["42"], ["42px"],
    ["44.5px"]) and returns the integer pixel count. Fractional values are
    truncated. Returns [0] for empty or unparseable strings. *)

module Style_css = Style_css
(** Re-exported for direct access. *)

module Renderer = Renderer
(** Re-exported for direct access. *)

module Platform_web = Platform_web
(** Web platform navigation via the browser History API. *)
