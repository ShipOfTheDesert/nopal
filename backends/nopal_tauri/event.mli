(** Typed OCaml bindings to the Tauri Event API.

    Provides event emission and listening via the Tauri JavaScript API. Each
    function uses the [Fut.await] callback pattern. If the Tauri runtime is not
    available, callbacks are simply never invoked. *)

type event = { payload : string }
(** The payload delivered to an event listener callback. *)

type unlisten = unit -> unit
(** A function that removes a previously registered listener. *)

val payload_of_jv : Jv.t -> string
(** [payload_of_jv jv] reads the [payload] field of a delivered Tauri event
    object as a string, decoding a [null] payload (a Rust unit [app.emit]) as
    [""] rather than raising. Exposed so {!Tauri_subscription} [decode] callers
    share the same null-safe extraction. *)

val emit : string -> string -> (unit, string) result Nopal_mvu.Task.t
(** [emit name payload] emits a named event with [payload] via the Tauri event
    system. Resolves with [Ok ()] when the emission completes, or [Error msg] if
    the IPC rejects (REQ-F5). *)

val listen : string -> (event -> unit) -> (unlisten -> unit) -> unit
(** [listen name on_event on_unlisten] registers a listener for events named
    [name]. Each time the event fires, [on_event] is called with the event
    payload. When registration completes, [on_unlisten unlisten] is called where
    [unlisten] is a function that, when called, removes the listener. *)
