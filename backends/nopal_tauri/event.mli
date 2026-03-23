(** Typed OCaml bindings to the Tauri Event API.

    Provides event emission and listening via the Tauri JavaScript API. Each
    function uses the [Fut.await] callback pattern. If the Tauri runtime is not
    available, callbacks are simply never invoked. *)

type event = { payload : string }
(** The payload delivered to an event listener callback. *)

type unlisten = unit -> unit
(** A function that removes a previously registered listener. *)

val emit : string -> string -> unit Nopal_mvu.Task.t
(** [emit name payload] emits a named event with [payload] via the Tauri event
    system. Resolves with [()] when the emission completes. *)

val listen : string -> (event -> unit) -> (unlisten -> unit) -> unit
(** [listen name on_event on_unlisten] registers a listener for events named
    [name]. Each time the event fires, [on_event] is called with the event
    payload. When registration completes, [on_unlisten unlisten] is called where
    [unlisten] is a function that, when called, removes the listener. *)
