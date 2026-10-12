let command = "plugin:clipboard-manager|write_text"

(* How tauri 2.10.3 words an access-control refusal, read from its source. The
   version is pinned by name because scripts/lint-classes compares it with the
   one in tauri/src-tauri/Cargo.lock, so a bump goes red until these strings are
   rechecked: a reworded refusal would otherwise decode as [Failed] with the
   host's message, which still resolves once but loses [Not_permitted].

   A debug build rejects with the message [resolve_access_message] builds in
   src/ipc/authority.rs, which starts with one of these prefixes; a release
   build rejects with the fixed sentence of the ACL check in src/webview/mod.rs.
   The "not allowed" prefix also begins the debug message for a command the
   plugin does not have (authority.rs:404, "Command not found"); that is
   harmless, since both mean the host will not run the write. A plugin that was
   never registered is rejected by src/plugin.rs:993 with the exact string
   below. *)
let debug_refusal_prefixes =
  [
    "clipboard-manager.write_text not allowed";
    "clipboard-manager.write_text explicitly denied";
  ]

let release_refusal = "Command " ^ command ^ " not allowed by ACL"
let plugin_not_registered = "plugin clipboard-manager not found"

let is_acl_refusal reason =
  String.equal reason release_refusal
  || String.equal reason plugin_not_registered
  || List.exists
       (fun prefix -> String.starts_with ~prefix reason)
       debug_refusal_prefixes

let error_of_rejection reason : Nopal_mvu.Clipboard.error =
  match is_acl_refusal reason with
  | true -> Not_permitted
  | false -> Failed reason

(* [Ipc.invoke] throws synchronously when [invoke] is missing or throws, and
   [Jv.Promise.then'] throws on a non-thenable. The engine's own messages for
   these ("not a function") carry no argument values, so the message is kept:
   it makes the failure diagnosable without exposing [text]. *)
let no_reason = "the clipboard write failed and the platform gave no reason"

let error_of_exn : exn -> Nopal_mvu.Clipboard.error = function
  | Jv.Error e -> (
      match Jstr.to_string (Jv.Error.message e) with
      | "" -> Failed no_reason
      | message -> Failed message)
  | e -> Failed (Printexc.to_string e)

let write text resolve =
  Nopal_mvu.Task.run
    (Nopal_mvu.Task.guard_once ~on_exn:error_of_exn (fun resolve ->
         Ipc.invoke_result ~ok:ignore command
           [| ("text", Jv.of_string text) |]
           (function
             | Ok () -> resolve (Ok ())
             | Error reason -> resolve (Error (error_of_rejection reason)))))
    resolve
