open Nopal_test.Test_renderer
module Sub_subscriptions = Kitchen_sink_app__Sub_subscriptions

let vp = Nopal_element.Viewport.desktop

(* Must match [Sub_subscriptions.timer_key] — the identity the runtime diff keys
   the live timer on. Hard-coded here so a rename that silently drops the key
   from the subscription tree is caught. *)
let timer_key = "subs-timer"
let has_key sub key = List.mem key (Nopal_mvu.Sub.keys sub)

(* The section is the living reference for the five built-in subs. The behaviour
   that matters for the runtime is that toggling the timer control adds/removes
   the [every] key from [subscriptions] — that is exactly what the diff engine
   keys on to start/stop the interval. *)
let test_subscriptions_section_renders_and_toggles_timer_sub_key () =
  let model, _ = Sub_subscriptions.init () in
  let root = tree (render (Sub_subscriptions.view vp model)) in
  let toggle = find (By_attr ("data-testid", "subs-timer-toggle")) root in
  Alcotest.(check bool) "timer toggle rendered" true (Option.is_some toggle);
  Alcotest.(check bool)
    "timer sub absent initially" false
    (has_key (Sub_subscriptions.subscriptions model) timer_key);
  let model_on, _ =
    Sub_subscriptions.update model Sub_subscriptions.ToggleTimer
  in
  Alcotest.(check bool)
    "timer sub added after toggle on" true
    (has_key (Sub_subscriptions.subscriptions model_on) timer_key);
  let model_off, _ =
    Sub_subscriptions.update model_on Sub_subscriptions.ToggleTimer
  in
  Alcotest.(check bool)
    "timer sub removed after toggle off" false
    (has_key (Sub_subscriptions.subscriptions model_off) timer_key)

let () =
  Alcotest.run "kitchen_sink_subscriptions_section"
    [
      ( "structure",
        [
          Alcotest.test_case "renders and toggles timer sub key" `Quick
            test_subscriptions_section_renders_and_toggles_timer_sub_key;
        ] );
    ]
