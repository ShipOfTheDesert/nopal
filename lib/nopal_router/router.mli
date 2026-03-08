(** Type-safe bidirectional router.

    A router converts between URL paths and application-defined route values.
    Navigation commands integrate with the MVU loop via [Cmd.t] and [Sub.t]. The
    router holds a platform reference but never exposes it — route values flow
    through the application model via messages. *)

type 'route t

val create :
  platform:(module Platform.S) ->
  parse:(string -> 'route option) ->
  to_path:('route -> string) ->
  not_found:'route ->
  'route t
(** [create ~platform ~parse ~to_path ~not_found] builds a router.

    [parse] converts a URL path string to a route value, returning [None] for
    unrecognized paths. [to_path] converts a route value back to a URL path
    string. [not_found] is the route value used when [parse] returns [None].

    The router does not own or manage route state — the application model holds
    the current route. The router provides commands and subscriptions that the
    MVU loop uses to keep the model and URL in sync. *)

val current : 'route t -> 'route
(** [current router] reads the platform's current path and parses it. Returns
    [not_found] if the path does not match any route.

    Primarily used during [init] to set the initial route from the URL:

    {[
      let init () =
        let route = Router.current router in
        ({ route }, Cmd.none)
    ]} *)

val push : 'route t -> 'route -> 'msg Nopal_mvu.Cmd.t
(** [push router route] returns a command that navigates to [route] by pushing a
    new history entry. *)

val replace : 'route t -> 'route -> 'msg Nopal_mvu.Cmd.t
(** [replace router route] returns a command that navigates to [route] by
    replacing the current history entry. *)

val back : 'route t -> 'msg Nopal_mvu.Cmd.t
(** [back router] returns a command that navigates to the previous history
    entry. *)

val on_navigate : 'route t -> ('route -> 'msg) -> 'msg Nopal_mvu.Sub.t
(** [on_navigate router to_msg] returns a subscription that dispatches
    [to_msg route] whenever the browser navigates via popstate (e.g.
    back/forward buttons). Unknown paths dispatch [to_msg not_found]. *)
