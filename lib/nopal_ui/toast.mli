(** Toast notification component.

    Renders a stack of dismissible toast notifications with variant-based
    styling and optional auto-dismiss via {!Nopal_mvu.Cmd.after}. *)

(** {1 Types} *)

(** Toast variant — determines visual styling. *)
type variant = Info | Success | Warning | Error

type toast = { id : string; variant : variant; message : string }
(** A single toast notification. *)

type 'msg config = {
  dismiss : string -> 'msg;
  style : Nopal_style.Style.t option;
  interaction : Nopal_style.Interaction.t option;
  attrs : (string * string) list;
}
(** Configuration for rendering a toast stack. [dismiss] is required — it
    constructs the message dispatched when a toast is clicked or auto-dismissed.
*)

(** {1 Construction} *)

val make : dismiss:(string -> 'msg) -> 'msg config
(** [make ~dismiss] returns a config with [dismiss] as the message constructor.
    Style and interaction default to [None] (variant-based styling). Attrs
    default to [[]]. *)

(** {1 State helpers} *)

val add :
  variant:variant ->
  message:string ->
  id:string ->
  ?duration_ms:int ->
  dismiss:(string -> 'msg) ->
  toast list ->
  toast list * 'msg Nopal_mvu.Cmd.t
(** Append a new toast and return the updated list. When [duration_ms] is
    provided, the returned [Cmd.t] schedules auto-dismiss via [Cmd.after].
    Otherwise returns [Cmd.none]. The caller must include the returned command
    from [update]. *)

val dismiss : string -> toast list -> toast list
(** Remove the toast with the given [id]. Returns the list unchanged if no toast
    matches. *)

(** {1 View} *)

val view : 'msg config -> toast list -> 'msg Nopal_element.Element.t
(** Render the toast stack. Each toast carries [aria-live] per variant:
    Info/Success use ["polite"], Warning/Error use ["assertive"]. Each toast is
    a clickable element that dispatches [config.dismiss id] on click.
    [config.style] controls the container layout only — individual toast styling
    always uses {!default_style_for}. Empty list renders an empty container. *)

(** {1 Styling} *)

val aria_live_for : variant -> string
(** Returns ["polite"] for Info/Success, ["assertive"] for Warning/Error.
    Exposed for testing and for developers building custom toast views. *)

val default_style_for : variant -> Nopal_style.Style.t
(** Built-in style for a toast variant. Exposed for testing and for developers
    who want to extend rather than replace styling. *)

val default_interaction_for : variant -> Nopal_style.Interaction.t
(** Built-in interaction (hover/pressed) for a toast variant. Exposed for
    developers who want to extend rather than replace interaction styling. *)
