(** Router-demo wizard — a minimal routed stepper example (RFC 0112).

    Demonstrates the three navigation primitives — push, replace, back — across
    a four-step wizard. The model is the current {!type:step} plus a [depth]
    counter mirroring the browser history depth, so a pushed transition (depth
    grows) is distinguishable from a replaced one (depth unchanged) without a
    browser. Imports stay platform-free ([nopal_mvu] / [nopal_element] /
    [nopal_ui] / [nopal_platform]); the thin [main.ml] is the only file that
    touches [nopal_web]. *)

type step = Step_one | Step_two | Step_three | Summary

type model = { step : step; depth : int }
(** [step] is the wizard's current page; [depth] mirrors the history depth so
    push vs replace is observable in tests. *)

type msg =
  | Next of step  (** push: advance to [step], deepening history. *)
  | Jump_to_summary  (** replace: jump to {!Summary} without deepening. *)
  | Back  (** pop: return to the previous step. *)
  | Route_changed of step
      (** browser-initiated navigation, from the popstate subscription. *)

val parse : string -> step option
(** [parse path] maps a URL path to a wizard step (matching on the final path
    segment so it works under any mount prefix), or [None] if unrecognised. *)

val to_path : step -> string
(** [to_path step] is the (relative) URL path for [step], so navigation resolves
    against the current document URL rather than the server root. *)

val init : step Nopal_platform.Router.t -> unit -> model * msg Nopal_mvu.Cmd.t
(** [init router ()] seeds the model from the router's current route at [depth]
    one. *)

val update :
  step Nopal_platform.Router.t -> model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [update router model msg] applies [msg], issuing the matching navigation
    command (push / replace / back) on [router]. *)

val view : Nopal_element.Viewport.t -> model -> msg Nopal_element.Element.t
(** [view _vp model] renders the wizard with call-site interaction anchors
    ([data-action="wizard-next"] / ["wizard-back"] / ["wizard-jump-summary"]).
*)

val subscriptions : step Nopal_platform.Router.t -> model -> msg Nopal_mvu.Sub.t
(** [subscriptions router _model] dispatches {!Route_changed} on popstate. *)

val serialize_msg : msg -> string
(** Telemetry rendering of a message, e.g. ["Next Step_two"]. *)

val serialize_model : model -> string
(** Telemetry rendering of the model, e.g. ["step=Step_two; depth=2;"]. Each
    field is terminated with [;] so substring assertions cannot prefix-alias. *)
