(** Filesystem-backed implementation of {!Nopal_storage.S} for Tauri.

    One file per key under a single app-data subdirectory ([nopal_storage]
    inside [BaseDirectory.AppLocalData]), via [tauri-plugin-fs]. Keys are
    percent-encoded into flat filenames so they cannot escape that directory
    (see [Fs_store] for the encoding scheme). Values survive relaunch.

    Requires [tauri-plugin-fs] registered in [src-tauri/src/lib.rs] and an [fs]
    capability in [capabilities/default.json] scoped to
    [$APPLOCALDATA/nopal_storage]. {!Make} is generative to match the
    platform-capability constructor shape; all instances share the one
    underlying directory (persistence is the point). *)

module Make () : Nopal_storage.S
