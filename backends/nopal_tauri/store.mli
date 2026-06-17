(** Typed OCaml bindings to the Tauri Store plugin.

    Persistent key-value storage via {!Nopal_mvu.Task.t}, backed by a single
    JSON file managed by [tauri-plugin-store]. A store must be {!load}ed before
    use: every operation takes the {!t} handle [load] returns, so a store you
    never loaded is unrepresentable (REQ-F6). All operations resolve [result]
    types to surface errors to the application.

    Requires the [store:default] capability in
    [tauri/src-tauri/capabilities/default.json] and [tauri-plugin-store]
    registered in [src-tauri/src/lib.rs]. *)

type t
(** An abstract handle to a loaded store, wrapping the [plugin:store|load]
    resource id that every rid-keyed store command must carry. *)

val error_to_string : Jv.t -> string
(** [error_to_string err] renders an IPC rejection value as a message. Total
    over the shapes Tauri produces: serde-serialized plain strings (command
    errors), JS [Error] objects (transport failures), and null/undefined.
    Exposed for unit tests. *)

val decode_get_response : Jv.t -> (string option, string) result
(** [decode_get_response jv] decodes the tauri-plugin-store v2 [get] wire shape
    — a [[value, found]] pair — into [Ok (Some value)] / [Ok None]. Exposed for
    unit tests. *)

val load : string -> (t, string) result Nopal_mvu.Task.t
(** [load path] loads (or reuses) the store backed by file [path], resolving
    with its handle. tauri-plugin-store v2 is rid-keyed: every subsequent
    operation must carry the resource id this returns. Resolves [Error msg] if
    the load IPC rejects. *)

val get : t -> string -> (string option, string) result Nopal_mvu.Task.t
(** [get store key] retrieves the value associated with [key]. Resolves with
    [Ok (Some value)] when the key exists, [Ok None] when absent, or [Error msg]
    on failure. *)

val set : t -> string -> string -> (unit, string) result Nopal_mvu.Task.t
(** [set store key value] stores [value] under [key]. Resolves with [Ok ()] when
    the operation completes, or [Error msg] on failure. Note: this writes to the
    in-memory store; call {!save} to flush to disk. *)

val delete : t -> string -> (unit, string) result Nopal_mvu.Task.t
(** [delete store key] removes the entry for [key]. Resolves with [Ok ()] when
    the operation completes, or [Error msg] on failure. *)

val clear : t -> (unit, string) result Nopal_mvu.Task.t
(** [clear store] removes all entries from the store. Resolves with [Ok ()] when
    the operation completes, or [Error msg] on failure. *)

val save : t -> (unit, string) result Nopal_mvu.Task.t
(** [save store] flushes the store to disk. Resolves with [Ok ()] when the
    operation completes, or [Error msg] on failure. *)
