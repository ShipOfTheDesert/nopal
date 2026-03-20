(** Typed OCaml bindings to the Tauri App API.

    Provides access to application metadata from tauri.conf.json via the Tauri
    JavaScript API. Each function uses the [Fut.await] callback pattern — if the
    Tauri runtime is not available, the callback is simply never invoked. *)

val get_name : (string -> unit) -> unit
(** [get_name f] calls the Tauri [getName()] API. When the promise resolves,
    [f name] is called with the application name from tauri.conf.json. *)

val get_version : (string -> unit) -> unit
(** [get_version f] calls the Tauri [getVersion()] API. When the promise
    resolves, [f version] is called with the application version from
    tauri.conf.json. *)

val get_tauri_version : (string -> unit) -> unit
(** [get_tauri_version f] calls the Tauri [getTauriVersion()] API. When the
    promise resolves, [f version] is called with the Tauri runtime version. *)
