(** Typed OCaml bindings to the Tauri Os API.

    Provides access to host platform detection via the Tauri os plugin. The
    platform is read from [__TAURI_OS_PLUGIN_INTERNALS__]; both an absent plugin
    and an unrecognized platform string resolve [Error] rather than hanging
    (REQ-F5). *)

type platform = Windows | MacOS | Linux | IOS | Android

val platform : (platform, string) result Nopal_mvu.Task.t
(** [platform] reads the host platform from the Tauri os plugin. Resolves with
    [Ok variant] for a recognized platform, or [Error msg] if the plugin is
    absent or the platform string is unrecognized. *)

val to_string : platform -> string
(** [to_string p] returns a human-readable name: ["Windows"], ["macOS"],
    ["Linux"], ["iOS"], or ["Android"]. *)

val platform_of_string : string -> platform option
(** [platform_of_string s] parses a Tauri API response string into a platform
    variant. Returns [None] for unrecognized strings. Exposed for testing. *)
