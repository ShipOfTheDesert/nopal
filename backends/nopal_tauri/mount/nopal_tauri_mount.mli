(** The entry point that mounts a Nopal application inside a Tauri webview.

    Mount a Tauri app through this module rather than through [Nopal_web]
    directly. It renders with [Nopal_web] and supplies every handler a webview
    needs from the host: {!Nopal_tauri.Clipboard.write} for
    {!Nopal_mvu.Cmd.write_clipboard}, and {!Nopal_tauri.Opener.open_url} so a
    link opens outside the app and the webview stays on it. [Nopal_web.mount]
    refuses to mount on a Tauri page without an opener; this entry point always
    has one.

    It lives apart from [nopal_tauri], which binds the Tauri API and depends on
    no UI package. The host must register the clipboard and opener plugins and
    grant their permissions, as {!Nopal_tauri.Clipboard} and
    {!Nopal_tauri.Opener} describe. *)

val mount :
  ?safe_area_source:((Nopal_element.Viewport.safe_area -> unit) -> unit -> unit) ->
  ?on_error:(string -> unit) ->
  (module Nopal_mvu.App.S with type model = 'model and type msg = 'msg) ->
  Brr.El.t ->
  Nopal_web.mounted
(** [mount (module MyApp) target] is [Nopal_web.mount] with
    [~write_clipboard:Nopal_tauri.Clipboard.write] and
    [~open_external:Nopal_tauri.Opener.open_url]. [~safe_area_source] and
    [~on_error] are passed through unchanged, so whether to supply
    [Nopal_tauri.Platform_tauri.safe_area_source] on a given platform stays the
    caller's choice. *)

val mount_with_telemetry :
  ?safe_area_source:((Nopal_element.Viewport.safe_area -> unit) -> unit -> unit) ->
  ?on_error:(string -> unit) ->
  (module Nopal_mvu.App.S with type model = 'model and type msg = 'msg) ->
  ?serialize_msg:('msg -> string) ->
  ?serialize_model:('model -> string) ->
  Brr.El.t ->
  Nopal_web.mounted_with_telemetry
(** [mount_with_telemetry (module MyApp) ?serialize_msg ?serialize_model target]
    is [Nopal_web.mount_with_telemetry] with the same two handlers {!mount}
    supplies, and every other argument passed through unchanged. *)
