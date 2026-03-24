(** Internal IPC helper for invoking Tauri commands.

    Provides the shared [__TAURI_INTERNALS__.invoke] call used by all
    nopal_tauri modules. Not part of the public API. *)

val invoke : string -> (string * Jv.t) array -> Jv.t
(** [invoke cmd args] calls [__TAURI_INTERNALS__.invoke(cmd, \{args...\})].
    Returns a JS Promise as [Jv.t]. If the Tauri runtime is not available,
    returns a rejected promise with ["Tauri runtime not available"]. *)
