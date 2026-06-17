(* Negative-path coverage for the Tauri ops that now resolve [(_, string) result]
   (RFC 0118, REQ-F5 / REQ-N1). Before this task, [Window]/[App]/[Event.emit]
   ops logged a rejection to the console and never called [resolve], so the task
   HUNG — a failed op silently stalled any [let*] chain built over it. Each op
   now resolves [Error msg] on a rejected IPC.

   These tests drive that synchronously through [tauri_shim.js]: with
   [__nopal_set_invoke_failure true] the shim's [invoke] returns a SYNCHRONOUS
   thenable that rejects, so the op's single [Jv.Promise.then'] error
   continuation fires inside the test (a real Tauri host rejects asynchronously —
   that window is irrelevant to the resolve-vs-hang contract under test).
   [Os.platform] reads [__TAURI_OS_PLUGIN_INTERNALS__] synchronously, so its
   unknown-platform path is driven by [__nopal_set_os_platform]. *)

module Task = Nopal_mvu.Task
module Window = Nopal_tauri.Window
module Os = Nopal_tauri.Os
module App = Nopal_tauri.App
module Event = Nopal_tauri.Event

let set_invoke_failure b =
  ignore (Jv.call Jv.global "__nopal_set_invoke_failure" [| Jv.of_bool b |])

let set_os_platform s =
  ignore (Jv.call Jv.global "__nopal_set_os_platform" [| Jv.of_string s |])

let reset () = ignore (Jv.call Jv.global "__nopal_reset_subs" [||])

(* Run a task to completion synchronously and return its delivered value, or
   [None] if the task never resolved (the pre-fix hang). *)
let run_sync task =
  let out = ref None in
  Task.run task (fun v -> out := Some v);
  !out

(* Assert a [(_, string) result] task resolved exactly once with an [Error]
   carrying a non-empty message. *)
let check_resolves_error label task =
  match run_sync task with
  | Some (Error msg) ->
      Alcotest.(check bool)
        (label ^ ": error message is non-empty")
        true
        (String.length msg > 0)
  | Some (Ok _) -> Alcotest.failf "%s: expected Error, resolved Ok" label
  | None -> Alcotest.failf "%s: task hung — never resolved" label

(* A representative slice of the 15 window ops: a unit op, a bool query, and the
   record-returning [inner_size] query, so all three [ok] mappers are exercised
   on the failure path. *)
let test_window_op_failure_resolves_error () =
  reset ();
  set_invoke_failure true;
  check_resolves_error "set_title" (Window.set_title "x");
  check_resolves_error "is_fullscreen" Window.is_fullscreen;
  check_resolves_error "inner_size" Window.inner_size

let test_os_unknown_platform_resolves_error () =
  reset ();
  set_os_platform "haiku";
  check_resolves_error "platform" Os.platform

let test_app_version_failure_resolves_error () =
  reset ();
  set_invoke_failure true;
  check_resolves_error "get_version" App.get_version

let test_event_emit_failure_resolves_error () =
  reset ();
  set_invoke_failure true;
  check_resolves_error "emit" (Event.emit "nopal:test-evt" "payload")

let () =
  Alcotest.run "nopal_tauri_results"
    [
      ( "ops_resolve_error",
        [
          Alcotest.test_case "window op failure resolves Error" `Quick
            test_window_op_failure_resolves_error;
          Alcotest.test_case "os unknown platform resolves Error" `Quick
            test_os_unknown_platform_resolves_error;
          Alcotest.test_case "app version failure resolves Error" `Quick
            test_app_version_failure_resolves_error;
          Alcotest.test_case "event emit failure resolves Error" `Quick
            test_event_emit_failure_resolves_error;
        ] );
    ]
