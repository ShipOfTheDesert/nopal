(** Typed OCaml bindings to the Tauri JavaScript API.

    This library provides zero-dependency access to Tauri platform capabilities
    via js_of_ocaml and Brr. It does NOT depend on any nopal UI packages. The
    entry point that mounts an application in a Tauri webview needs [nopal_web],
    so it is the separate sub-library [nopal_tauri.mount], module
    [Nopal_tauri_mount]. *)

module App = App
module Clipboard = Clipboard
module Event = Event
module Opener = Opener
module Os = Os
module Platform_tauri = Platform_tauri
module Store = Store
module Tauri_subscription = Tauri_subscription
module Telemetry = Telemetry
module Tray = Tray
module Window = Window
