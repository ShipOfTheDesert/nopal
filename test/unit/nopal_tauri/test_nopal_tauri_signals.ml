(* Unit coverage for the [Platform_tauri] mobile-signal subscriptions and the
   hardware-back listener (RFC 0116, Tasks 2 / 5).

   - REQ-N1: [on_safe_area_change] / [on_keyboard_height_change] must dispatch
     their degenerate value (zero insets / 0) exactly once at subscription setup,
     so the desktop "fires once" contract holds without a native event ever
     arriving. We drive the [Sub.custom] setup directly via [Sub.extract_custom]
     with a recording dispatch.
   - REQ-F3: [enable_hardware_back] must be idempotent — a second call registers
     no additional [nopal:back-pressed] listener.

   These reach [Event.listen], so they run under tauri_shim.js, which stubs
   [__TAURI_INTERNALS__] (no native event is ever delivered) and counts
   [plugin:event|listen] registrations on [globalThis.__nopal_listen_count]. *)

module Viewport = Nopal_element.Viewport
module Platform = Nopal_tauri.Platform_tauri

let listen_count () = Jv.to_int (Jv.get Jv.global "__nopal_listen_count")

(* Run a [custom] subscription's setup with a recording dispatch and return the
   list of dispatched values (most-recent-first) plus the cleanup. *)
let drive_custom sub =
  match Nopal_mvu.Sub.extract_custom sub with
  | None -> Alcotest.fail "expected a custom subscription"
  | Some setup ->
      let dispatched = ref [] in
      let cleanup = setup (fun v -> dispatched := v :: !dispatched) in
      (!dispatched, cleanup)

let test_on_safe_area_change_dispatches_zero_at_setup () =
  let sub = Platform.on_safe_area_change (fun insets -> insets) in
  let dispatched, _cleanup = drive_custom sub in
  match dispatched with
  | [ insets ] ->
      Alcotest.(check int) "top is zero" 0 (Viewport.safe_area_top insets);
      Alcotest.(check int) "right is zero" 0 (Viewport.safe_area_right insets);
      Alcotest.(check int) "bottom is zero" 0 (Viewport.safe_area_bottom insets);
      Alcotest.(check int) "left is zero" 0 (Viewport.safe_area_left insets)
  | other ->
      Alcotest.failf "expected exactly one setup dispatch, got %d"
        (List.length other)

let test_on_keyboard_height_change_dispatches_zero_at_setup () =
  let sub = Platform.on_keyboard_height_change (fun h -> h) in
  let dispatched, _cleanup = drive_custom sub in
  Alcotest.(check (list int)) "setup dispatches exactly [0]" [ 0 ] dispatched

(* REQ-F3 regression (e2e back.e2e.ts): a Rust [app.emit (name, ())] delivers a
   [null] payload to the in-webview handler. Decoding must not throw — the
   original [Jv.to_string] on [null] raised a TypeError inside the handler, so
   [on_event] never ran and the hardware-back chain silently died. *)
let test_listen_decodes_null_payload_as_empty_string () =
  let received = ref None in
  Nopal_tauri.Event.listen "nopal:test-null-payload"
    (fun (ev : Nopal_tauri.Event.event) -> received := Some ev.payload)
    (fun _unlisten -> ());
  ignore
    (Jv.call Jv.global "__nopal_deliver"
       [| Jv.of_string "nopal:test-null-payload"; Jv.null |]);
  match !received with
  | Some payload ->
      Alcotest.(check string) "null payload decodes to \"\"" "" payload
  | None -> Alcotest.fail "listener was never invoked for a null payload"

let test_listen_delivers_string_payload_verbatim () =
  let received = ref None in
  Nopal_tauri.Event.listen "nopal:test-string-payload"
    (fun (ev : Nopal_tauri.Event.event) -> received := Some ev.payload)
    (fun _unlisten -> ());
  ignore
    (Jv.call Jv.global "__nopal_deliver"
       [| Jv.of_string "nopal:test-string-payload"; Jv.of_string "Left" |]);
  Alcotest.(check (option string))
    "string payload is delivered verbatim" (Some "Left") !received

let test_enable_hardware_back_is_idempotent () =
  let before = listen_count () in
  Platform.enable_hardware_back ();
  let after_first = listen_count () in
  Platform.enable_hardware_back ();
  let after_second = listen_count () in
  Alcotest.(check int)
    "first call registers exactly one back listener" 1 (after_first - before);
  Alcotest.(check int)
    "second call registers no additional listener" 0
    (after_second - after_first)

let () =
  Alcotest.run "nopal_tauri_signals"
    [
      ( "subscriptions",
        [
          Alcotest.test_case "on_safe_area_change dispatches zero at setup"
            `Quick test_on_safe_area_change_dispatches_zero_at_setup;
          Alcotest.test_case
            "on_keyboard_height_change dispatches zero at setup" `Quick
            test_on_keyboard_height_change_dispatches_zero_at_setup;
        ] );
      ( "event_listen",
        [
          Alcotest.test_case "listen decodes null payload as \"\"" `Quick
            test_listen_decodes_null_payload_as_empty_string;
          Alcotest.test_case "listen delivers string payload verbatim" `Quick
            test_listen_delivers_string_payload_verbatim;
        ] );
      ( "hardware_back",
        [
          Alcotest.test_case "enable_hardware_back is idempotent" `Quick
            test_enable_hardware_back_is_idempotent;
        ] );
    ]
