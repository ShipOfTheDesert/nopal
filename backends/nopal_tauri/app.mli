(** Typed OCaml bindings to the Tauri App API.

    Provides access to application metadata from tauri.conf.json via the Tauri
    JavaScript API. Each function returns a {!Nopal_mvu.Task.t} that resolves
    when the Tauri promise completes. *)

val get_name : string Nopal_mvu.Task.t
(** [get_name] calls the Tauri [getName()] API and resolves with the application
    name from tauri.conf.json. *)

val get_version : string Nopal_mvu.Task.t
(** [get_version] calls the Tauri [getVersion()] API and resolves with the
    application version from tauri.conf.json. *)

val get_tauri_version : string Nopal_mvu.Task.t
(** [get_tauri_version] calls the Tauri [getTauriVersion()] API and resolves
    with the Tauri runtime version. *)
