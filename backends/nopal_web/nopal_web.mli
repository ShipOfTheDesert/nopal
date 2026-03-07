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

    This is the only function application code calls from [nopal_web]. It wires
    everything together: runtime creation, Lwd root subscription, DOM rendering,
    and event dispatch. *)

module Style_css = Style_css
(** Re-exported for direct access. *)

module Renderer = Renderer
(** Re-exported for direct access. *)
