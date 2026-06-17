(** Typed OCaml bindings to the Tauri TrayIcon API.

    Provides tray icon event subscriptions via {!Nopal_mvu.Sub.custom} and tray
    state management via {!Nopal_mvu.Task.t}. A single TrayIcon instance is
    created lazily when the first subscription activates and destroyed when all
    subscriptions are removed.

    Requires the [tray-icon:default] capability in
    [tauri/src-tauri/capabilities/default.json] and a [trayIcon] entry in
    [tauri.conf.json]. *)

val on_click : 'msg -> 'msg Nopal_mvu.Sub.t
(** [on_click msg] subscribes to tray icon single-click events. Dispatches [msg]
    each time the tray icon is clicked. Creates the TrayIcon on first activation
    if it does not already exist.

    Desktop only: a system tray exists only on desktop targets. On mobile and
    web there is no tray, so the subscription is inert — it never fires (this is
    not an error). *)
