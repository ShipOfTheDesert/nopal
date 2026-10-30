(** In-app and external links — kitchen sink subapp.

    The section shows a link to a route of its own, a link to an external site,
    a link that opens the kitchen sink's own page in a new tab, and two status
    lines: the route the section last followed, and whether the platform could
    open the external link.

    A plain primary click on the route link dispatches [Followed], and [update]
    answers it with {!Nopal_platform.Router.push}. The link's address comes from
    the same route through {!Nopal_platform.Router.destination}, so the address
    and the navigation cannot drift apart. A browser follows the external link
    itself, so [Open_failed] only arrives from a host that hands the link to a
    system browser and could not. The new-tab link dispatches nothing: the
    browser opens its tab. *)

(** The section's routes. Both are the kitchen sink's own page, under the
    [/kitchen_sink/] prefix the browser suite and the site serve it from:
    [Start] is [/kitchen_sink/] and [Target] is [/kitchen_sink/?links=target].
    They differ only in the query because no server the kitchen sink runs under
    falls back to the page for any other path, and a route link opened in a new
    tab must still load the page.

    Under Tauri the page is served at [/], not under [/kitchen_sink/], so
    [Target]'s path does not load on reload there; the route link is a
    browser-suite demonstration, and Tauri apps should use paths of their own.
*)
type route = Start | Target

val router :
  (module Nopal_platform.Platform.NAV) -> route Nopal_platform.Router.t
(** [router platform] is the section's router. A platform's path carries no
    query, so its [parse] recognises [Start] only; the section never reads its
    route back from the address. *)

type model
(** The subapp model: the route last followed and the last opener failure. *)

(** The subapp's messages. *)
type msg =
  | Followed of route  (** The route link was followed in-app. *)
  | Open_failed of Nopal_element.Link.open_error
      (** The platform could not open the external link. *)

val init : unit -> model * msg Nopal_mvu.Cmd.t
(** At [Start], with no opener failure. *)

val update :
  route Nopal_platform.Router.t -> model -> msg -> model * msg Nopal_mvu.Cmd.t
(** [Followed route] records [route] and pushes it through the router;
    [Open_failed] records the failure. *)

val view :
  route Nopal_platform.Router.t ->
  Nopal_element.Viewport.t ->
  model ->
  msg Nopal_element.Element.t
(** Renders the three links and both status lines. Every element a browser case
    reaches carries a [data-testid]: [links-route-link], [links-external-link],
    [links-new-tab-link], [links-current-route] and [links-open-status]. The
    route line also carries [data-route], [start] or [target]; the opener line
    carries [data-status], one of [idle], [not-permitted] or [failed]. A
    destination the router or a path or URL check refuses is shown as an error
    line in the link's place, never replaced by a default. *)

val serialize_msg : msg -> string
(** Telemetry serializer for the section's messages, prefixed with [Links:] and
    terminated with [;] so one fragment cannot prefix-alias another: for example
    [Links:Followed:Target;], [Links:Open_failed:Not_permitted;], and a [Failed]
    failure with the platform's quoted reason. *)
