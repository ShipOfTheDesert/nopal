(** Filesystem primitives for the Tauri storage backend.

    Bridges [tauri-plugin-fs] IPC commands ([plugin:fs|*]) into
    {!Nopal_mvu.Task.t}, via [__TAURI_INTERNALS__.invoke] — the same low-level
    interface [nopal_tauri] uses (this package does not depend on
    [nopal_tauri]). Every operation is confined to a single app-data
    subdirectory ([nopal_storage] under [BaseDirectory.AppLocalData]); the Tauri
    [fs] capability is scoped to exactly that directory.

    Each key becomes one flat file in the scoped directory, named by
    {!Nopal_fs_key.encode_key} — a percent-encoding stricter than URI encoding
    that neutralises path separators, ["."], and uppercase so a key can never
    escape the directory or collide on a case-insensitive filesystem. A filename
    that does not decode cleanly is skipped by {!list_keys} (the scoped
    directory is expected to hold only files this module wrote). *)

val ensure_dir : unit -> (unit, Nopal_storage.error) result Nopal_mvu.Task.t
(** [ensure_dir ()] creates the scoped directory if absent (recursive [mkdir],
    idempotent). Resolves [Error (Backend_unavailable _)] outside a Tauri
    runtime. *)

val read_text :
  key:string -> (string, Nopal_storage.error) result Nopal_mvu.Task.t
(** [read_text ~key] reads the file for [key]. The caller must confirm the file
    exists first (via {!list_keys}); reading an absent file resolves [Error _],
    not [Ok]. *)

val write_text :
  key:string ->
  value:string ->
  (unit, Nopal_storage.error) result Nopal_mvu.Task.t
(** [write_text ~key ~value] writes [value] to the file for [key], creating it
    if absent. Sent as a raw-body [plugin:fs|write_text_file] invoke (path and
    options in request headers), matching the [tauri-plugin-fs] v2 contract. *)

val remove : key:string -> (unit, Nopal_storage.error) result Nopal_mvu.Task.t
(** [remove ~key] deletes the file for [key]. Removing an absent file resolves
    [Error _]; callers that need delete-absent to succeed must guard with
    {!list_keys}. *)

val list_keys :
  unit -> (string list, Nopal_storage.error) result Nopal_mvu.Task.t
(** [list_keys ()] reads the scoped directory and decodes each entry name back
    to its key, skipping names that are not well-formed (see
    {!Nopal_fs_key.decode_filename}). Order is unspecified. *)
