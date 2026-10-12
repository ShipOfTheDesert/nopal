(* [Nopal_tauri.Clipboard.write] against [tauri_shim.js].

   The shim records each clipboard-manager invoke and PARKS its settlement,
   resolving, or rejecting with a string the case chooses, until the case calls
   [__nopal_clipboard_flush]: a real promise settles on a later turn, so each
   case asserts nothing has resolved when [write] returns, flushes, and reads
   back every outcome in order. "Exactly one" is an assertion, not an
   assumption.

   The rejection strings are the host's own: the debug-build wording names the
   command as [clipboard-manager.write_text] and says why it is refused, the
   release-build wording is one fixed sentence. Both mean the capability does
   not grant the write, or the plugin is not registered. *)

module Clipboard = Nopal_tauri.Clipboard

let key = "nopal-test-key-7Q2"
let reset () = ignore (Jv.call Jv.global "__nopal_reset_subs" [||])

let set_rejection reason =
  ignore
    (Jv.call Jv.global "__nopal_set_clipboard_rejection"
       [| Jv.of_string reason |])

let show_error : Nopal_mvu.Clipboard.error -> string = function
  | Not_permitted -> "Error Not_permitted"
  | Unavailable -> "Error Unavailable"
  | Failed reason -> Printf.sprintf "Error (Failed %S)" reason

let show_outcome = function
  | Ok () -> "Ok ()"
  | Error e -> show_error e

let outcome =
  Alcotest.testable
    (fun fmt o -> Format.pp_print_string fmt (show_outcome o))
    ( = )

let flush () = ignore (Jv.call Jv.global "__nopal_clipboard_flush" [||])

let set_throw message =
  ignore
    (Jv.call Jv.global "__nopal_set_clipboard_throw" [| Jv.of_string message |])

let outcomes_of_write () =
  let seen = ref [] in
  Clipboard.write key (fun o -> seen := o :: !seen);
  Alcotest.(check int)
    "nothing resolved before the turn ends" 0 (List.length !seen);
  flush ();
  let after_flush = List.rev !seen in
  flush ();
  Alcotest.(check int)
    "a second drain delivers nothing more" (List.length after_flush)
    (List.length !seen);
  after_flush

let invokes () =
  Jv.to_list Fun.id (Jv.get Jv.global "__nopal_clipboard_invokes")

let write_invokes_clipboard_plugin_command () =
  reset ();
  Alcotest.(check (list outcome))
    "the write resolves once, Ok" [ Ok () ] (outcomes_of_write ());
  match invokes () with
  | [ invoke ] ->
      Alcotest.(check string)
        "command" "plugin:clipboard-manager|write_text"
        (Jv.to_string (Jv.get invoke "cmd"));
      Alcotest.(check string)
        "text argument" key
        (Jv.to_string (Jv.get (Jv.get invoke "args") "text"))
  | other ->
      Alcotest.failf "expected exactly one clipboard invoke, got %d"
        (List.length other)

let outcomes_of_rejection reason =
  reset ();
  set_rejection reason;
  outcomes_of_write ()

let check_rejection ~expect reason =
  Alcotest.(check (list outcome))
    reason [ expect ]
    (outcomes_of_rejection reason)

let tauri_decode_maps_acl_strings () =
  let not_permitted = Error Nopal_mvu.Clipboard.Not_permitted in
  List.iter
    (check_rejection ~expect:not_permitted)
    [
      "clipboard-manager.write_text not allowed. Permissions associated with \
       this command: clipboard-manager:allow-write-text";
      "clipboard-manager.write_text not allowed on window \"other\", webview \
       \"other\", URL: local\n\n\
       allowed on: [windows: \"main\", URL: local]\n\n\
       referenced by: capability: default, permission: \
       clipboard-manager:allow-write-text";
      "clipboard-manager.write_text not allowed. Plugin not found";
      "clipboard-manager.write_text explicitly denied on origin local\n\n\
       referenced by: capability: default, permission: \
       clipboard-manager:deny-write-text";
      "Command plugin:clipboard-manager|write_text not allowed by ACL";
      (* tauri-2.10.3 src/plugin.rs:993, the rejection when the crate is a
         dependency but [.plugin(tauri_plugin_clipboard_manager::init())] was
         never called. *)
      "plugin clipboard-manager not found";
    ];
  let unrelated = "the clipboard is held by another process" in
  check_rejection ~expect:(Error (Failed unrelated)) unrelated;
  reset ();
  Alcotest.(check (list outcome))
    "a resolved invoke is Ok" [ Ok () ] (outcomes_of_write ())

let thrown_invoke_resolves_failed_once () =
  reset ();
  let message = "invoke is broken" in
  set_throw message;
  (* A throw happens before [invoke] returns, so the outcome is in hand at
     once, and a later drain must add nothing. *)
  let seen = ref [] in
  Clipboard.write key (fun o -> seen := o :: !seen);
  flush ();
  match List.rev !seen with
  | [ Error (Failed reason) ] ->
      Alcotest.(check string) "the thrown message is the reason" message reason;
      Alcotest.(check bool)
        "the reason does not contain the copied text" false
        (Test_util.string_contains reason ~sub:key)
  | other ->
      Alcotest.failf "expected one Error (Failed _), got %d outcomes"
        (List.length other)

let absent_tauri_resolves_failed_once () =
  reset ();
  ignore (Jv.call Jv.global "__nopal_hide_tauri" [||]);
  let seen = outcomes_of_write () in
  ignore (Jv.call Jv.global "__nopal_restore_tauri" [||]);
  Alcotest.(check (list outcome))
    "one Failed outcome"
    [ Error (Failed "Tauri runtime not available") ]
    seen;
  Alcotest.(check int) "nothing reached the host" 0 (List.length (invokes ()))

let () =
  Alcotest.run "nopal_tauri_clipboard"
    [
      ( "write",
        [
          Alcotest.test_case "write_invokes_clipboard_plugin_command" `Quick
            write_invokes_clipboard_plugin_command;
          Alcotest.test_case "tauri_decode_maps_acl_strings" `Quick
            tauri_decode_maps_acl_strings;
          Alcotest.test_case "thrown_invoke_resolves_failed_once" `Quick
            thrown_invoke_resolves_failed_once;
          Alcotest.test_case "absent_tauri_resolves_failed_once" `Quick
            absent_tauri_resolves_failed_once;
        ] );
    ]
