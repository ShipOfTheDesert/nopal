(** Hand-written [Jv] bindings to [window.indexedDB].

    [brr] ships no IndexedDB module, so these are raw bindings over the global
    object, following the same convention as [nopal_tauri]'s IPC bindings. Every
    [IDBRequest] is bridged through {!Nopal_mvu.Task.from_callback}, resolving
    exactly once on [onsuccess] / [onerror]. On [onerror] the request's
    [DOMException] is classified: recognised [name]s map to
    {!Nopal_storage.Quota_exceeded} / {!Nopal_storage.Permission_denied}, every
    other failure maps to {!Nopal_storage.Backend_error}. *)

type db
(** An opened IndexedDB database handle. *)

val open_db :
  name:string ->
  store:string ->
  (db, Nopal_storage.error) result Nopal_mvu.Task.t
(** [open_db ~name ~store] opens database [name], creating object store [store]
    on first creation ([onupgradeneeded]). Resolves
    [Error (Backend_unavailable _)] when [window.indexedDB] is absent. *)

val get :
  db ->
  store:string ->
  key:string ->
  (string option, Nopal_storage.error) result Nopal_mvu.Task.t
(** [get db ~store ~key] resolves [Ok (Some v)] when present, [Ok None] when the
    record is absent, and [Error (Backend_error _)] if a stored value is not a
    string — {!put} only ever writes strings, so a non-string indicates an
    out-of-band write into this store rather than a value this module wrote. *)

val put :
  db ->
  store:string ->
  key:string ->
  value:string ->
  (unit, Nopal_storage.error) result Nopal_mvu.Task.t
(** [put db ~store ~key ~value] stores [value] under the out-of-line [key]. *)

val delete :
  db ->
  store:string ->
  key:string ->
  (unit, Nopal_storage.error) result Nopal_mvu.Task.t
(** [delete db ~store ~key] removes [key]; absent keys resolve [Ok ()]. *)

val get_all_keys :
  db ->
  store:string ->
  (string list, Nopal_storage.error) result Nopal_mvu.Task.t
(** [get_all_keys db ~store] lists every key in [store], order unspecified. *)

val clear :
  db -> store:string -> (unit, Nopal_storage.error) result Nopal_mvu.Task.t
(** [clear db ~store] empties [store] only; sibling object stores and
    [localStorage] are untouched. *)

val close : db -> unit
(** [close db] closes the connection [db]. Callers that open a handle per
    operation must close it once the operation resolves: a connection left open
    holds a [versionchange] block that stalls the next schema-version upgrade
    ([onupgradeneeded]). [close] cannot fail and never raises — a closed
    connection simply rejects further transactions. *)
