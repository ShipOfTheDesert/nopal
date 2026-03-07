(** Web platform navigation via the browser History API.

    Implements [Nopal_router.Platform.S] using [window.history] for
    push/replace/back and the [popstate] event for navigation listening. Pass
    [(module Platform_web)] to [Router.create] for web applications. *)

val current_path : unit -> string
(** Reads [window.location.pathname]. *)

val push_state : string -> unit
(** Calls [history.pushState]. *)

val replace_state : string -> unit
(** Calls [history.replaceState]. *)

val back : unit -> unit
(** Calls [history.back]. *)

val on_popstate : (string -> unit) -> unit -> unit
(** Listens for the [popstate] event on [window]. Returns a cleanup function
    that removes the listener. *)
