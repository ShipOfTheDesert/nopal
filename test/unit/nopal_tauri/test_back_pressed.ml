(* [Platform_tauri.on_back_pressed] — the router-less half of the hardware-back
   contract.

   [enable_hardware_back] answers a [nopal:back-pressed] event with
   [window.history.back()]. That only reaches the application if a history entry
   exists to go back to, i.e. only if the application installed a
   {!Nopal_platform.Router} and pushed one. A router-less application pushes
   nothing, so [history.back()] at the initial entry raises no [popstate], no
   navigation subscription fires, and the press reaches nothing at all — while
   Android's [OnBackPressedCallback(true)] has already swallowed it, so the app
   does not background either. That is the gap [on_back_pressed] closes: the
   press is delivered as a msg, with no history round trip.

   This is a test binary of its own rather than more cases in
   [test_nopal_tauri_signals.ml] deliberately. [enable_hardware_back] registers a
   process-lifetime listener it offers no way to remove, so any binary that calls
   it can no longer observe a press that touches nothing — and "touches nothing"
   is precisely what the [history] assertion below is for. Keeping the two apart
   makes that assertion true by construction instead of true by test ordering.

   Runs under tauri_shim.js: [__nopal_deliver] invokes the registered handlers
   for an event synchronously, mirroring how Tauri dispatches a host [app.emit]
   to in-webview listeners, and [__nopal_resolve_listen] settles the in-flight
   [plugin:event|listen] registration. *)

module Sub = Nopal_mvu.Sub
module Platform = Nopal_tauri.Platform_tauri

let reset () = ignore (Jv.call Jv.global "__nopal_reset_subs" [||])
let resolve_listen () = ignore (Jv.call Jv.global "__nopal_resolve_listen" [||])
let listen_count () = Jv.to_int (Jv.get Jv.global "__nopal_listen_count")
let unlisten_count () = Jv.to_int (Jv.get Jv.global "__nopal_unlisten_count")

(* A counting stand-in for [window.history], installed once for the whole
   binary. Node defines no [history] global, so without it a stray [back ()]
   would throw a TypeError inside the delivering handler rather than showing up
   as a failed assertion. Counting rather than merely absorbing the call is what
   lets [test_press_does_not_touch_history] state the contract positively. *)
let history_back_calls = ref 0

let () =
  Jv.set Jv.global "history"
    (Jv.obj
       [| ("back", Jv.callback ~arity:1 (fun _ -> incr history_back_calls)) |])

(* The payload is [Jv.null]: the Rust side emits [app.emit ("nopal:back-pressed",
   ())], and a unit payload arrives as JS [null]. *)
let deliver_back_pressed () =
  ignore
    (Jv.call Jv.global "__nopal_deliver"
       [| Jv.of_string "nopal:back-pressed"; Jv.null |])

(* Run the subscription's setup with a recording dispatch, returning the
   dispatched values (most-recent-first, read through the returned thunk) and the
   cleanup. *)
let drive sub =
  match Sub.atoms sub with
  | [ Custom { setup; _ } ] ->
      let dispatched = ref [] in
      let cleanup = setup (fun v -> dispatched := v :: !dispatched) in
      ((fun () -> !dispatched), cleanup)
  | _ -> Alcotest.fail "expected a single custom atom from on_back_pressed"

(* The whole point: a host back press dispatches the application's msg, with no
   router, no pushed history entry and no [popstate] anywhere in the path. *)
let test_press_dispatches_msg () =
  reset ();
  let dispatched, cleanup = drive (Platform.on_back_pressed `Back) in
  Alcotest.(check int)
    "nothing dispatched before the press" 0
    (List.length (dispatched ()));
  deliver_back_pressed ();
  Alcotest.(check int)
    "the press dispatches exactly one msg" 1
    (List.length (dispatched ()));
  (match dispatched () with
  | [ `Back ] -> ()
  | _ -> Alcotest.fail "expected the subscribed msg");
  cleanup ()

(* Unlike [on_safe_area_change] and [on_keyboard_height_change], which dispatch a
   degenerate value at setup so the desktop "fires once" contract holds, a back
   press is an event and not a signal: there is no current value to deliver. A
   setup-time dispatch would pop the application's first screen on launch. *)
let test_setup_dispatches_nothing () =
  reset ();
  let dispatched, cleanup = drive (Platform.on_back_pressed `Back) in
  Alcotest.(check int)
    "setup dispatches nothing" 0
    (List.length (dispatched ()));
  cleanup ()

(* [on_back_pressed] is independent of [enable_hardware_back], not layered over
   it: subscribing alone must not produce the [window.history.back()] the other
   function exists to produce. An application that wants both effects calls both;
   one press then does both, which is why the two doc comments say to pick one.
   [enable_hardware_back] is never called in this binary.

   The delivery assertion is load-bearing, not decoration: without it a
   [deliver_back_pressed ()] that reaches no handler at all — event-name drift
   between the two sides, a [Tauri_subscription] registration regression — reads
   0 back for want of an event rather than for want of a [back ()], and the case
   passes while pinning nothing. The affirmative arm below cannot see that mode,
   because it never goes through the subscription. This line is where it is
   closed. *)
let test_press_does_not_touch_history () =
  reset ();
  history_back_calls := 0;
  let dispatched, cleanup = drive (Platform.on_back_pressed `Back) in
  deliver_back_pressed ();
  Alcotest.(check int)
    "the press was in fact delivered" 1
    (List.length (dispatched ()));
  Alcotest.(check int)
    "the subscription never calls history.back()" 0 !history_back_calls;
  cleanup ()

(* The affirmative arm for the case above. "the counter reads 0" is an assertion
   of absence, and an absence assertion is vacuous unless something on the same
   fixture proves the counter can reach 1: were the stand-in ever to stop being
   installed, or to stop counting, the case above would stay green while pinning
   nothing at all. So this one drives the stand-in through [Platform.back] — the
   very function [enable_hardware_back]'s handler runs, so a regression in that
   binding reddens here too — with no subscription in the picture, and reads 1
   back. [enable_hardware_back] itself is deliberately not the route: its
   listener is registered for the process lifetime, and this binary must never
   register it.

   Those two modes are all this closes. It does not close the third — that
   [deliver_back_pressed ()] reaches no handler at all, so the case above reads
   0 for want of an event rather than for want of a [back ()]. This case never
   goes through the subscription, so it cannot see that; the case above closes it
   itself, with its own "the press was in fact delivered" assertion.

   Both cases set the counter to 0 themselves, so neither depends on running
   before or after the other. *)
let test_history_stand_in_counts_a_real_back_call () =
  history_back_calls := 0;
  Platform.back ();
  Alcotest.(check int)
    "Platform.back () reaches the counting stand-in" 1 !history_back_calls

(* Each subscription is its own race-free registration: one
   [plugin:event|listen] at setup, one [plugin:event|unlisten] at cleanup, and a
   second cleanup is a no-op. This is what distinguishes the subscription from
   [enable_hardware_back]'s raw, unremovable [Event.listen]. *)
let test_subscription_registers_and_unlistens_once () =
  reset ();
  let before = listen_count () in
  let _dispatched, cleanup = drive (Platform.on_back_pressed `Back) in
  Alcotest.(check int)
    "setup registers exactly one listener" 1
    (listen_count () - before);
  resolve_listen ();
  cleanup ();
  cleanup ();
  Alcotest.(check int) "cleanup unlistens exactly once" 1 (unlisten_count ())

(* A claim about the seam, not about the runtime: two listeners registered on
   the setup function both hear one press, rather than the later registration
   replacing the earlier. [drive] calls [setup] by hand, so this never reaches
   [Sub_manager] — which admits one subscription per key and would keep only the
   first, the key being fixed. An application subscribes once and fans out in
   [update]. *)
let test_two_seam_listeners_both_hear_one_press () =
  reset ();
  let first, cleanup_first = drive (Platform.on_back_pressed `First) in
  let second, cleanup_second = drive (Platform.on_back_pressed `Second) in
  deliver_back_pressed ();
  Alcotest.(check int)
    "the first seam listener heard the press" 1
    (List.length (first ()));
  Alcotest.(check int)
    "the second seam listener heard the press" 1
    (List.length (second ()));
  cleanup_first ();
  cleanup_second ()

let () =
  Alcotest.run "Platform_tauri.on_back_pressed"
    [
      ( "delivery",
        [
          Alcotest.test_case "a host back press dispatches the msg" `Quick
            test_press_dispatches_msg;
          Alcotest.test_case "setup dispatches nothing" `Quick
            test_setup_dispatches_nothing;
          Alcotest.test_case "two seam listeners both hear one press" `Quick
            test_two_seam_listeners_both_hear_one_press;
        ] );
      ( "independence",
        [
          Alcotest.test_case "the history stand-in counts a real back call"
            `Quick test_history_stand_in_counts_a_real_back_call;
          Alcotest.test_case "a press does not call history.back()" `Quick
            test_press_does_not_touch_history;
        ] );
      ( "registration",
        [
          Alcotest.test_case "registers once and unlistens once" `Quick
            test_subscription_registers_and_unlistens_once;
        ] );
    ]
