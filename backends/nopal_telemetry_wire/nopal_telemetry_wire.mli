(** The single source of truth for the telemetry wire shape (RFC 0110).

    Telemetry events cross the OCaml/JS boundary as a tagged JS object
    ([{ kind; … }]) on two independent paths: the browser bridge ([nopal_web])
    installs it on [window.__nopal_telemetry__], and the Tauri forwarder
    ([nopal_tauri]) emits it as a [nopal:telemetry] event the Rust host parses
    into [serde_json::Value]. Both backends share this one codec so the
    encodings cannot drift; the TS decoder in
    [test/e2e/tests/nopal-telemetry.ts] mirrors the same shape on the assertion
    side.

    Lives in a [js_of_ocaml] backend (not native [nopal_runtime]) because the
    encoding is [Jv]-valued. *)

val event_to_jv : Nopal_runtime.Telemetry.event -> Jv.t
(** Encode one event as its tagged wire object. *)

val events_to_jv : Nopal_runtime.Telemetry.event list -> Jv.t
(** Encode a list of events as a JS array, preserving order. *)

val event_of_jv : Jv.t -> (Nopal_runtime.Telemetry.event, string) result
(** Decode one wire object produced by {!event_to_jv}. Returns [Error] on an
    unrecognised [kind] tag rather than raising. *)

val events_of_jv : Jv.t -> (Nopal_runtime.Telemetry.event list, string) result
(** Decode a JS array of wire objects, preserving order and short-circuiting to
    [Error] on the first malformed element. *)
