(** The system browser through the Tauri opener plugin, for an external link
    followed in a Tauri webview.

    Pass {!open_url} as [~open_external] to [Nopal_web.mount] in a Tauri app, so
    an external link opens in the system browser and the webview stays on the
    app.

    The host must register the [tauri-plugin-opener] crate (2.x),
    [.plugin(tauri_plugin_opener::init())], and its capability must grant
    opening the URL, with these two lines in the [permissions] list of
    [capabilities/default.json]: [["opener:allow-open-url"]] and
    [["opener:allow-default-urls"]]. The first lets the webview call [open_url];
    the second scopes it to [http://*], [https://*], [mailto:*] and [tel:*], the
    schemes a {!Nopal_element.Url.t} can carry. Do not grant [opener:default]
    instead: besides opening URLs it lets the webview reveal any file in the
    system's file manager. *)

val open_url :
  Nopal_element.Url.t ->
  ((unit, Nopal_element.Link.open_error) result -> unit) ->
  unit
(** [open_url url resolve] asks the host to open [url] in the system's default
    application for it, and calls [resolve] exactly once with the outcome when
    the host answers.

    Outcomes:
    - [Ok ()] when the host handed [url] to the default application.
    - [Error Not_permitted] when the host refused: its capability does not grant
      [opener:allow-open-url], denies it, or the plugin is not registered; or
      the plugin's scope does not cover [url].
    - [Error (Failed reason)] for any other refusal, with the host's message as
      [reason], including ["Tauri runtime not available"] when the page is not
      running inside Tauri.
    - [Error (Failed reason)] when issuing the command throws (a missing or
      broken [invoke]), with the thrown error's message as [reason].

    Every occurrence of [url], as given, in a [reason] is replaced by ["<url>"].
    A launcher that echoes a normalised form of the URL is not caught, so
    [reason] is not guaranteed free of it. *)
