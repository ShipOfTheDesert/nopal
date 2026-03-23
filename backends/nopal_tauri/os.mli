(** Typed OCaml bindings to the Tauri Os API.

    Provides access to host platform detection via the Tauri os plugin. Uses the
    [Fut.await] callback pattern — if the Tauri runtime is not available, the
    callback is simply never invoked. *)

type platform = Windows | MacOS | Linux | IOS | Android

val platform : platform Nopal_mvu.Task.t
(** [platform] is a task that calls the Tauri os plugin [platform()] command.
    When the promise resolves, the task produces the detected platform variant.
    If the platform string is not recognized, the task does not resolve. *)

val to_string : platform -> string
(** [to_string p] returns a human-readable name: ["Windows"], ["macOS"],
    ["Linux"], ["iOS"], or ["Android"]. *)

val platform_of_string : string -> platform option
(** [platform_of_string s] parses a Tauri API response string into a platform
    variant. Returns [None] for unrecognized strings. Exposed for testing. *)
