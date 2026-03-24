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
    if it does not already exist. *)

val on_double_click : 'msg -> 'msg Nopal_mvu.Sub.t
(** [on_double_click msg] subscribes to tray icon double-click events.
    Dispatches [msg] each time the tray icon is double-clicked. Shares the same
    TrayIcon instance as {!on_click}. *)

val set_icon : string -> unit Nopal_mvu.Task.t
(** [set_icon path] updates the tray icon image to the file at [path]. Resolves
    with [()] when the operation completes. If no TrayIcon exists (no active
    subscription), the task never resolves. *)

val set_tooltip : string -> unit Nopal_mvu.Task.t
(** [set_tooltip text] updates the tray icon tooltip to [text]. Resolves with
    [()] when the operation completes. If no TrayIcon exists, the task never
    resolves. *)

val set_visible : bool -> unit Nopal_mvu.Task.t
(** [set_visible flag] shows the tray icon when [flag] is [true], hides it when
    [false]. Resolves with [()] when the operation completes. If no TrayIcon
    exists, the task never resolves. *)
