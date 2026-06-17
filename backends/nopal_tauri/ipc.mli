(** Internal IPC helper for invoking Tauri commands.

    Provides the shared [__TAURI_INTERNALS__.invoke] call used by all
    nopal_tauri modules. Not part of the public API. *)

val invoke : string -> (string * Jv.t) array -> Jv.t
(** [invoke cmd args] calls [__TAURI_INTERNALS__.invoke(cmd, \{args...\})].
    Returns a JS Promise as [Jv.t]. If the Tauri runtime is not available,
    returns a rejected promise with ["Tauri runtime not available"]. *)

val error_to_string : Jv.t -> string
(** [error_to_string err] renders an IPC rejection value as a message. Total
    over the shapes Tauri produces: serde-serialized plain strings (command
    errors), JS [Error] objects (transport failures), and null/undefined. *)

val invoke_result :
  ok:(Jv.t -> 'a) ->
  string ->
  (string * Jv.t) array ->
  (('a, string) result -> unit) ->
  unit
(** [invoke_result ~ok cmd args resolve] invokes [cmd] and resolves
    [Ok (ok response)] on success or [Error (error_to_string rejection)] on
    failure — never leaving the resolver uncalled (REQ-F5: a failed op resolves
    instead of hanging). Shaped as a {!Nopal_mvu.Task.from_callback} body. *)
