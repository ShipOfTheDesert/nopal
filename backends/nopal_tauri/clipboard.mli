(** The system clipboard through the Tauri clipboard plugin, for
    {!Nopal_mvu.Cmd.write_clipboard}.

    Pass {!write} as [~write_clipboard] to [Nopal_web.mount] in a Tauri app, so
    the write goes to the host's clipboard rather than the webview's Clipboard
    API.

    The host must register the [tauri-plugin-clipboard-manager] crate (2.x),
    [.plugin(tauri_plugin_clipboard_manager::init())], and its capability must
    grant the write, with this line in the [permissions] list of
    [capabilities/default.json]: [["clipboard-manager:allow-write-text"]]. That
    permission grants writing plain text and nothing else: in particular, it
    does not grant reading the clipboard, and no other clipboard permission is
    needed. *)

val write : string -> ((unit, Nopal_mvu.Clipboard.error) result -> unit) -> unit
(** [write text resolve] asks the host to place [text] on the clipboard, and
    calls [resolve] exactly once with the outcome when the host answers.

    Outcomes:
    - [Ok ()] when the host wrote the text.
    - [Error Not_permitted] when the host's access control refused the command:
      the capability does not grant [clipboard-manager:allow-write-text], denies
      it, or the plugin is not registered.
    - [Error (Failed reason)] for any other refusal, with the host's message as
      [reason], including ["Tauri runtime not available"] when the page is not
      running inside Tauri. [reason] never contains [text].
    - [Error (Failed reason)] when issuing the command throws (a missing or
      broken [invoke]), with the thrown error's message as [reason]; the
      engine's messages for this carry no argument values.

    It never resolves [Error Unavailable]. *)
