(* Unit coverage for [Nopal_web.mount]'s teardown handle (feature 0121, FR-4 /
   L4). Mounting returns a [mounted] record whose [unmount] must release every
   listener/observer the mount registered — the subscription listeners (via
   runtime shutdown), the ResizeObserver, and the rAF render loop (and, when
   supplied, the safe-area unlisten) — and repeated mount->unmount cycles must
   not accumulate any of them. [unmount] is idempotent: a second call is inert
   and never raises (runtime [shutdown] raises on a second call).

   Runs under dom_shim + mount_shim + subs_shim: mount_shim tracks live
   ResizeObservers ([__nopal_observer_live]) and captures the rAF callback;
   subs_shim gives [window] a real listener registry with a per-type count
   ([__nopal_listener_count]), so the keydown listener the subscription
   registers is observable while mounted and its removal on unmount is provable. *)

module Sub = Nopal_mvu.Sub

(* A keydown subscription drives the model, so the window keydown listener is
   observable (subs_shim count) and its effect is visible in the rendered text:
   this is the concrete listener [unmount] must release. *)
module Key_app = struct
  type model = int
  type msg = Bump

  let init () = (0, Nopal_mvu.Cmd.none)
  let update model Bump = (model + 1, Nopal_mvu.Cmd.none)

  let view _vp model =
    Nopal_element.Element.Text
      { content = string_of_int model; text_style = None }

  let subscriptions _model =
    Sub.on_keydown "bump" (fun _key -> Some (Bump, false))
end

let key_module :
    (module Nopal_mvu.App.S
       with type model = Key_app.model
        and type msg = Key_app.msg) =
  (module Key_app)

let window () = Jv.get Jv.global "window"
let fresh_parent () = Brr.El.v (Jstr.v "div") []

(* The rendered root is [target]'s first child (a <span> from Element.Text); its
   textContent is the current model, so a keydown that dispatches [Bump] is
   observable in the DOM. *)
let first_child_text target =
  let node0 = Jv.get (Jv.get (Brr.El.to_jv target) "childNodes") "0" in
  Jv.to_string (Jv.get node0 "textContent")

let keydown_listener_count () =
  Jv.to_int
    (Jv.call (window ()) "__nopal_listener_count" [| Jv.of_string "keydown" |])

let live_observers () = Jv.to_int (Jv.get Jv.global "__nopal_observer_live")

(* Fire a window keydown carrying a plain key (no modifier), the trigger the
   Key_app subscription turns into a [Bump]. *)
let fire_keydown () =
  let opts =
    Jv.obj [| ("key", Jv.of_string "a"); ("shiftKey", Jv.of_bool false) |]
  in
  let ev =
    Jv.new'
      (Jv.get Jv.global "KeyboardEvent")
      [| Jv.of_string "keydown"; opts |]
  in
  ignore (Jv.call (window ()) "dispatchEvent" [| ev |])

(* Run exactly one rAF frame so a damaged tree re-renders into the DOM. After
   unmount the captured callback is the torn-down loop, which must no-op. *)
let run_frame () =
  let cb = Jv.get Jv.global "__nopal_raf_cb" in
  if not (Jv.is_undefined cb) then ignore (Jv.apply cb [| Jv.of_float 0. |])

(* While mounted the subscription and observer are live and drive the DOM; after
   [unmount] both are released and a subsequent keydown + frame is inert. *)
let test_unmount_releases_listeners () =
  let target = fresh_parent () in
  let m : Nopal_web.mounted = Nopal_web.mount key_module target in
  Alcotest.(check int)
    "one keydown listener while mounted" 1
    (keydown_listener_count ());
  Alcotest.(check int) "one live observer while mounted" 1 (live_observers ());
  fire_keydown ();
  run_frame ();
  Alcotest.(check string)
    "keydown bumps the model while mounted" "1" (first_child_text target);
  m.unmount ();
  Alcotest.(check int)
    "keydown listener removed on unmount" 0
    (keydown_listener_count ());
  Alcotest.(check int) "observer disconnected on unmount" 0 (live_observers ());
  fire_keydown ();
  run_frame ();
  Alcotest.(check string)
    "no dispatch and no DOM patch after unmount" "1" (first_child_text target)

(* A mount->unmount->mount->unmount cycle never leaves a stale listener or
   observer behind: the count is 1 while a single app is mounted and 0 once it
   is unmounted, at every step. *)
let test_remount_does_not_accumulate () =
  Alcotest.(check int) "no listeners before mount" 0 (keydown_listener_count ());
  Alcotest.(check int) "no observers before mount" 0 (live_observers ());
  let m1 : Nopal_web.mounted = Nopal_web.mount key_module (fresh_parent ()) in
  Alcotest.(check int)
    "one listener after first mount" 1
    (keydown_listener_count ());
  Alcotest.(check int) "one observer after first mount" 1 (live_observers ());
  m1.unmount ();
  let m2 : Nopal_web.mounted = Nopal_web.mount key_module (fresh_parent ()) in
  Alcotest.(check int)
    "still one listener after remount — no accumulation" 1
    (keydown_listener_count ());
  Alcotest.(check int)
    "still one observer after remount — no accumulation" 1 (live_observers ());
  m2.unmount ();
  Alcotest.(check int)
    "all listeners released after final unmount" 0
    (keydown_listener_count ());
  Alcotest.(check int)
    "all observers released after final unmount" 0 (live_observers ())

(* [unmount] is idempotent: a second call must not raise (runtime [shutdown]
   raises [Invalid_argument] on a second call) and leaves everything released. *)
let test_double_unmount_is_inert () =
  let m : Nopal_web.mounted = Nopal_web.mount key_module (fresh_parent ()) in
  m.unmount ();
  m.unmount ();
  Alcotest.(check int)
    "listeners stay released after double unmount" 0
    (keydown_listener_count ());
  Alcotest.(check int)
    "observers stay released after double unmount" 0 (live_observers ())

(* [mount_with_telemetry] returns the telemetry handle alongside [unmount]; the
   handle still backs the driven runtime and the teardown releases the same
   listeners. *)
let test_mount_with_telemetry_unmount () =
  let m : Nopal_web.mounted_with_telemetry =
    Nopal_web.mount_with_telemetry key_module (fresh_parent ())
  in
  Alcotest.(check int)
    "one keydown listener while mounted" 1
    (keydown_listener_count ());
  ignore (Nopal_runtime.Telemetry.events m.telemetry);
  m.unmount ();
  Alcotest.(check int)
    "keydown listener removed on unmount" 0
    (keydown_listener_count ());
  Alcotest.(check int) "observer disconnected on unmount" 0 (live_observers ())

let () =
  Alcotest.run "nopal_web mount unmount"
    [
      ( "unmount",
        [
          Alcotest.test_case "unmount releases subscription + observer" `Quick
            test_unmount_releases_listeners;
          Alcotest.test_case "remount does not accumulate" `Quick
            test_remount_does_not_accumulate;
          Alcotest.test_case "double unmount is inert" `Quick
            test_double_unmount_is_inert;
          Alcotest.test_case "mount_with_telemetry unmount" `Quick
            test_mount_with_telemetry_unmount;
        ] );
    ]
