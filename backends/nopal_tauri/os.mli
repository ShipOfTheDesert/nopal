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

val is_ios : unit -> bool
(** [is_ios ()] is a synchronous best-effort iOS probe, distinct from the async
    typed {!val-platform}: it reads the same [__TAURI_OS_PLUGIN_INTERNALS__]
    Tauri global and is [true] only when it reports ["ios"]. That global is
    present only under a Tauri host, so [is_ios ()] is [false] in a plain
    browser and on Android/desktop. Callers use it as the mount-time carve-out
    for the native safe-area source: iOS is the one target where wiring the
    native source produces a broken value that also suppresses the CSS [env()]
    fallback, so the source is supplied on every Tauri host except iOS (Android
    delivers real insets, desktop a harmless zero inset — NFR-1). *)

val to_string : platform -> string
(** [to_string p] returns a human-readable name: ["Windows"], ["macOS"],
    ["Linux"], ["iOS"], or ["Android"]. *)

val platform_of_string : string -> platform option
(** [platform_of_string s] parses a Tauri API response string into a platform
    variant. Returns [None] for unrecognized strings. Exposed for testing. *)

val read_platform_string : Jv.t -> string option
(** [read_platform_string internals] reads the ["platform"] field off the Tauri
    os-plugin internals object, returning [Some s] only when that field is a JS
    string ([typeof = "string"]) and [None] otherwise (absent, [undefined], or a
    non-string value). This [Jv.is_string]-style guard is what keeps {!is_ios}
    and {!val-platform} total at the FFI edge: a non-string is mapped to a safe
    [None]/[Error] rather than coerced by [Jv.to_string]. Exposed for testing.
*)
