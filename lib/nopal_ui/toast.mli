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
  toast_style : (variant -> Nopal_style.Style.t) option;
  toast_interaction : (variant -> Nopal_style.Interaction.t) option;
}
(** Configuration for rendering a toast stack. [dismiss] is required — it
    constructs the message dispatched when a toast is clicked or auto-dismissed.

    [style] and [interaction] are the stack container and the uniform per-toast
    interaction respectively; the last two fields are the per-variant override
    surface. The supported route to them is {!with_toast_style} and
    {!with_toast_interaction} rather than writing them by hand; they are fields
    because a setter needs somewhere to put its value, and a caller who builds
    this record as a complete literal must supply them. *)

(** {1 Construction} *)

val make : dismiss:(string -> 'msg) -> 'msg config
(** [make ~dismiss] returns a config with [dismiss] as the message constructor.
    Style and interaction default to [None] (variant-based styling). Attrs
    default to [[]]. Neither per-variant override is set. *)

(** {1:overrides Overrides} *)

val with_toast_style :
  (variant -> Nopal_style.Style.t) -> 'msg config -> 'msg config
(** [with_toast_style f config] styles each toast with [f]'s answer for that
    toast's variant, {e replacing} {!default_style_for}; nothing is merged. The
    function must answer for all four variants, and [f] receives the variant of
    the toast being rendered, so a stack showing two variants at once gets two
    styles.

    To keep the built-in look and change part of it, compose:
    [with_toast_style (fun v -> Style.with_paint … (default_style_for v))].
    {!default_style_for} stays exposed for exactly that.

    Note [config.style] is a different decision: it is the stack container's own
    style and this setter does not touch it.

    What this reaches stops at the toast element. The toast {e message}'s
    typography is reached through this style's [text] component inheriting into
    the message text node in a browser, which [nopal_test] does not model, so a
    structural assertion speaks for the toast element only. *)

val with_toast_interaction :
  (variant -> Nopal_style.Interaction.t) -> 'msg config -> 'msg config
(** [with_toast_interaction f config] gives each toast [f]'s answer for that
    toast's variant, {e replacing} {!default_interaction_for}; nothing is
    merged. The function must answer for all four variants.

    This outranks [config.interaction]: the resolution is this setter first,
    then [config.interaction] (the same interaction for every variant), then
    {!default_interaction_for}. A caller who sets both gets the per-variant
    answer, which is the more specific of the two. *)

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
(** Renders the toast stack. Each toast carries the interaction anchor
    [data-action="toast-dismiss"]. This anchor is the E2E selector contract (RFC
    0112) and is asserted by [test_anchors.ml].

    Render the toast stack. Each toast carries [aria-live] per variant:
    Info/Success use ["polite"], Warning/Error use ["assertive"]. Each toast is
    a clickable element that dispatches [config.dismiss id] on click.
    [config.style] is the stack container's own style. Each toast's style is
    {!with_toast_style}'s answer for that toast's variant when the caller set
    one, and {!default_style_for}'s otherwise; its interaction is
    {!with_toast_interaction}'s answer, else [config.interaction], else
    {!default_interaction_for}'s. Empty list renders an empty container.

    Every attribute above is the component's and is unaffected by either
    override: a restyled toast keeps its [aria-live], its [data-variant], its
    [aria-label] and the [data-action] anchor. *)

(** {1 Variant defaults}

    The three functions below are the answers the overrides in
    {!section-overrides} displace. They are exposed so a caller can compose with
    them — pass [fun v -> f (default_style_for v)] to {!with_toast_style} to
    keep the built-in look and change part of it — which is the supported route
    to a partly-custom toast. Rendering a toast stack by hand is not: it forgoes
    [aria-live], the [data-action] anchor and the dismiss wiring, none of which
    these functions give back. *)

val aria_live_for : variant -> string
(** Returns ["polite"] for Info/Success, ["assertive"] for Warning/Error. This
    is what {!val-view} puts on each toast; a caller cannot replace it, because
    the announcement urgency of a toast is not a visual decision. Exposed for
    testing and for asserting it. *)

val default_style_for : variant -> Nopal_style.Style.t
(** Built-in style for a toast variant — what each toast carries unless
    {!with_toast_style} says otherwise. *)

val default_interaction_for : variant -> Nopal_style.Interaction.t
(** Built-in interaction (hover/pressed) for a toast variant — what each toast
    carries unless {!with_toast_interaction} or [config.interaction] says
    otherwise. *)
