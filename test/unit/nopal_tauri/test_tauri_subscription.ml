(* Registration-lifecycle coverage for [Tauri_subscription] (RFC 0118, REQ-F8).

   [Event.listen] delivers its unlisten function asynchronously — the listen IPC
   resolves on a later microtask. A subscription torn down inside that window
   (cleanup before the listen promise resolves) must still unlisten the moment
   the registration arrives, or the native listener leaks (the bug the old
   [Tray] ref-based teardown carried). [Tauri_subscription] models the
   registration as a [Pending | Active | Cancelled] state machine that closes
   that race.

   These tests drive that machine through [tauri_shim.js], which returns a
   SYNCHRONOUS thenable for [plugin:event|listen]: [__nopal_resolve_listen] /
   [__nopal_reject_listen] fire the OCaml [then'] continuation synchronously, so
   a registration resolving (or failing) is observable inside a synchronous
   Alcotest case. [__nopal_unlisten_count] counts [plugin:event|unlisten] calls
   and [__nopal_console_errors] captures the reported failures. *)

module Sub = Nopal_mvu.Sub
module Tauri_subscription = Nopal_tauri.Tauri_subscription

let reset () = ignore (Jv.call Jv.global "__nopal_reset_subs" [||])
let resolve_listen () = ignore (Jv.call Jv.global "__nopal_resolve_listen" [||])
let reject_listen () = ignore (Jv.call Jv.global "__nopal_reject_listen" [||])
let unlisten_count () = Jv.to_int (Jv.get Jv.global "__nopal_unlisten_count")

let console_error_count () =
  Jv.to_int (Jv.get (Jv.get Jv.global "__nopal_console_errors") "length")

(* Run the [Sub.custom] setup [make] produces, returning its cleanup. The decode
   is irrelevant here — no event is delivered — so it ignores its input; fixing
   ['msg] to [unit] keeps the sub monomorphic. *)
let setup_make () =
  let sub =
    Tauri_subscription.make ~key:"k" ~event:"nopal:test-evt"
      ~decode:(fun (_ : Jv.t) -> (None : unit option))
  in
  match Sub.atoms sub with
  | [ Custom { setup; _ } ] -> setup (fun _ -> ())
  | _ ->
      Alcotest.fail "expected a single custom atom from Tauri_subscription.make"

(* Cleanup fires while the listen IPC is still in flight (state [Pending]); when
   the registration finally resolves, the unlisten must run on arrival rather
   than being dropped — otherwise the native listener leaks. *)
let test_cleanup_before_registration_unlistens_on_arrival () =
  reset ();
  let cleanup = setup_make () in
  cleanup ();
  resolve_listen ();
  Alcotest.(check int)
    "unlisten runs once the late registration arrives" 1 (unlisten_count ())

(* A rejected listen IPC must be reported (the runtime on_error default path is
   the console under jsoo) and must NOT spuriously unlisten anything. *)
let test_registration_failure_reported () =
  reset ();
  let cleanup = setup_make () in
  reject_listen ();
  Alcotest.(check bool)
    "registration failure is reported" true
    (console_error_count () >= 1);
  Alcotest.(check int)
    "no unlisten on a failed registration" 0 (unlisten_count ());
  cleanup ()

(* Normal lifecycle: registration resolves first (state [Active]); the first
   cleanup unlistens exactly once and a second cleanup is a no-op. *)
let test_normal_cleanup_after_registration_unlistens_once () =
  reset ();
  let cleanup = setup_make () in
  resolve_listen ();
  cleanup ();
  cleanup ();
  Alcotest.(check int) "unlisten runs exactly once" 1 (unlisten_count ())

let () =
  Alcotest.run "Tauri_subscription"
    [
      ( "registration",
        [
          Alcotest.test_case "cleanup before registration unlistens on arrival"
            `Quick test_cleanup_before_registration_unlistens_on_arrival;
          Alcotest.test_case "registration failure reported" `Quick
            test_registration_failure_reported;
          Alcotest.test_case "normal cleanup after registration unlistens once"
            `Quick test_normal_cleanup_after_registration_unlistens_once;
        ] );
    ]
