(** Tauri platform capabilities: History-API navigation + filesystem storage.

    Implements {!Nopal_platform.Platform.S}. Tauri applications run in a
    webview, so navigation maps onto [window.history] (push/replace/back) and
    the [popstate] event exactly as the web backend does; [storage] is a
    filesystem-backed {!Nopal_storage.S} via {!Nopal_storage_tauri.Make}
    ([tauri-plugin-fs]). Pass [(module Platform_tauri)] to
    {!Nopal_platform.Router.create} (which needs only [NAV]) or to an
    application functor over {!Nopal_platform.Platform.S}.

    This module exists as a distinct entry point so applications can depend on
    [nopal_tauri] without pulling in [nopal_web]. *)

include Nopal_platform.Platform.S
