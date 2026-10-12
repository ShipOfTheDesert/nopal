(** Clipboard — the outcome vocabulary of {!Cmd.write_clipboard}.

    A clipboard write either succeeds or fails for one of the reasons below. The
    reason is a variant so an application can tell a refusal from a missing
    platform without reading a message. *)

type error =
  | Not_permitted
      (** The platform refused the write. In a browser: the permission was
          denied, or the write was not issued within the user activation of a
          gesture. On Tauri: permission not granted, or plugin not registered —
          both are setup mistakes with the same fix, granting the write
          permission to the clipboard plugin in the app's capabilities. *)
  | Unavailable
      (** The platform offers no clipboard to write to: the page is not a secure
          context, the browser lacks the asynchronous Clipboard API, or the
          backend has no clipboard at all. *)
  | Failed of string
      (** Any other failure. The string is the platform's reason, for display or
          logging; it never contains the copied text. *)
