(** Tauri platform navigation via the browser History API.

    Implements [Nopal_router.Platform.S] using [window.history] for
    push/replace/back and the [popstate] event for navigation listening. Pass
    [(module Platform_tauri)] to [Router.create] for Tauri applications.

    Under the hood, Tauri applications run in a webview, so the navigation
    primitives are identical to the web backend. This module exists as a
    distinct entry point so applications can depend on [nopal_tauri] without
    pulling in [nopal_web]. *)

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
