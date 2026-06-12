(** Typed OCaml bindings to the Tauri Store plugin.

    Provides persistent key-value storage via {!Nopal_mvu.Task.t}. All
    operations return [result] types to surface errors to the application. The
    store is backed by a single JSON file ([nopal_store.json]) managed by
    [tauri-plugin-store].

    Requires the [store:default] capability in
    [tauri/src-tauri/capabilities/default.json] and [tauri-plugin-store]
    registered in [src-tauri/src/lib.rs]. *)

val error_to_string : Jv.t -> string
(** [error_to_string err] renders an IPC rejection value as a message. Total
    over the shapes Tauri produces: serde-serialized plain strings (command
    errors), JS [Error] objects (transport failures), and null/undefined.
    Exposed for unit tests. *)

val decode_get_response : Jv.t -> (string option, string) result
(** [decode_get_response jv] decodes the tauri-plugin-store v2 [get] wire shape
    — a [[value, found]] pair — into [Ok (Some value)] / [Ok None]. Exposed for
    unit tests. *)

val get : string -> (string option, string) result Nopal_mvu.Task.t
(** [get key] retrieves the value associated with [key]. Resolves with
    [Ok (Some value)] when the key exists, [Ok None] when absent, or [Error msg]
    on failure. *)

val set : string -> string -> (unit, string) result Nopal_mvu.Task.t
(** [set key value] stores [value] under [key]. Resolves with [Ok ()] when the
    operation completes, or [Error msg] on failure. Note: this writes to the
    in-memory store; call {!save} to flush to disk. *)

val delete : string -> (unit, string) result Nopal_mvu.Task.t
(** [delete key] removes the entry for [key]. Resolves with [Ok ()] when the
    operation completes, or [Error msg] on failure. *)

val clear : unit -> (unit, string) result Nopal_mvu.Task.t
(** [clear ()] removes all entries from the store. Resolves with [Ok ()] when
    the operation completes, or [Error msg] on failure. *)

val save : unit -> (unit, string) result Nopal_mvu.Task.t
(** [save ()] flushes the store to disk. Resolves with [Ok ()] when the
    operation completes, or [Error msg] on failure. *)
