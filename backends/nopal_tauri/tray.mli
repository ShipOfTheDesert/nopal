(** Typed OCaml bindings to the Tauri TrayIcon API.

    Provides tray icon event subscriptions via {!Nopal_mvu.Sub.custom} and tray
    state management via {!Nopal_mvu.Task.t}. A single TrayIcon instance is
    created lazily when the first subscription activates and destroyed when all
    subscriptions are removed.

    Requires the [tray-icon:default] capability in
    [tauri/src-tauri/capabilities/default.json] and a [trayIcon] entry in
    [tauri.conf.json]. *)

(** A tray-icon click kind, decoded once from the wire string at the FFI edge
    (class-2 guard, see docs/bug-classes/0002-stringly-typed-protocols.md).
    Exposed for the decoder round-trip property test (FR-5). *)
type click_type = Left | Double | Right | Middle

val click_type_of_string : string -> click_type option
(** [click_type_of_string s] decodes a Tauri tray-click wire token ([Left] /
    [Double] / [Right] / [Middle]) into a {!click_type}, returning [None] for an
    unrecognized token. Exposed for testing. *)

val on_click : 'msg -> 'msg Nopal_mvu.Sub.t
(** [on_click msg] subscribes to tray icon single-click events. Dispatches [msg]
    each time the tray icon is clicked. Creates the TrayIcon on first activation
    if it does not already exist.

    Desktop only: a system tray exists only on desktop targets. On mobile and
    web there is no tray, so the subscription is inert — it never fires (this is
    not an error). *)
