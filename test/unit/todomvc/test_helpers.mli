(** Shared test helpers for TodoMVC unit and structural tests. *)

val noop_storage : (module Todomvc.Storage)
(** No-op storage that loads empty and discards saves. *)

val preloaded_storage : Todomvc.todo list -> (module Todomvc.Storage)
(** Storage pre-populated with the given todos. *)

val tracking_storage :
  unit -> (module Todomvc.Storage) * Todomvc.todo list list ref
(** Storage that records every save call. Returns the storage module and a ref
    to the list of saved states (most recent first). *)

val make_mock_platform : string -> (module Nopal_router.Platform.S)
(** [make_mock_platform initial_path] creates a mock platform for router testing
    without a browser. *)

val make_router :
  ?initial_path:string -> unit -> Todomvc.route Nopal_router.Router.t
(** [make_router ?initial_path ()] creates a router using a mock platform. *)
