let command = "plugin:opener|open_url"

(* How tauri 2.10.3 words an access-control refusal, read from its source, as in
   clipboard.ml: a debug build rejects with a message from src/ipc/authority.rs
   starting with one of these prefixes, a release build with the fixed sentence
   of src/webview/mod.rs, and a plugin that was never registered with the exact
   string of src/plugin.rs:993.

   How tauri-plugin-opener 2.5.3 words a scope refusal, read from its source:
   src/error.rs serializes [Error::ForbiddenUrl] as "Not allowed to open url "
   followed by the URL. It is the answer for a URL outside
   [opener:allow-default-urls], and the same refusal as the ACL's. *)
let debug_refusal_prefixes =
  [ "opener.open_url not allowed"; "opener.open_url explicitly denied" ]

let release_refusal = "Command " ^ command ^ " not allowed by ACL"
let plugin_not_registered = "plugin opener not found"
let scope_refusal_prefix = "Not allowed to open url "

let is_refusal reason =
  String.equal reason release_refusal
  || String.equal reason plugin_not_registered
  || String.starts_with ~prefix:scope_refusal_prefix reason
  || List.exists
       (fun prefix -> String.starts_with ~prefix reason)
       debug_refusal_prefixes

(* The plugin echoes the URL it was given, verbatim, in its own errors and in
   the launcher's. [replaceAll] with a string pattern matches it literally; the
   replacement holds no [$], so it is inserted as written. *)
let redact url reason =
  Jv.to_string
    (Jv.call (Jv.of_string reason) "replaceAll"
       [|
         Jv.of_string (Nopal_element.Url.to_string url); Jv.of_string "<url>";
       |])

let error_of_rejection url reason : Nopal_element.Link.open_error =
  match is_refusal reason with
  | true -> Not_permitted
  | false -> Failed (redact url reason)

let no_reason = "opening the link failed and the platform gave no reason"

(* [Ipc.invoke] throws synchronously when [invoke] is missing or throws, and
   [Jv.Promise.then'] throws on a non-thenable. *)
let error_of_exn url : exn -> Nopal_element.Link.open_error = function
  | Jv.Error e -> (
      match Jstr.to_string (Jv.Error.message e) with
      | "" -> Failed no_reason
      | message -> Failed (redact url message))
  | e -> Failed (redact url (Printexc.to_string e))

let open_url url resolve =
  Nopal_mvu.Task.run
    (Nopal_mvu.Task.guard_once ~on_exn:(error_of_exn url) (fun resolve ->
         Ipc.invoke_result ~ok:ignore command
           [| ("url", Jv.of_string (Nopal_element.Url.to_string url)) |]
           (function
             | Ok () -> resolve (Ok ())
             | Error reason -> resolve (Error (error_of_rejection url reason)))))
    resolve
