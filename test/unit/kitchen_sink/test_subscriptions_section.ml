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

(* The key-capture readout echoes the modifier-folded key string the handler
   received, verbatim, which is what makes the section the running-page
   demonstration that a Ctrl chord is expressible at all. Both spellings are
   asserted as whole readout strings rather than by containment: "d" is a
   substring of "Ctrl+d", so a contains-check would pass on the wrong one and
   would also pass against a readout that hard-coded the prefix. *)
let key_readout model =
  let root = tree (render (Sub_subscriptions.view vp model)) in
  match find (By_attr ("data-testid", "subs-key-readout")) root with
  | Some node -> text_content node
  | None -> Alcotest.fail "subs-key-readout element missing"

let test_section_shows_the_chord () =
  let model, _ = Sub_subscriptions.init () in
  let chorded, _ =
    Sub_subscriptions.update model (Sub_subscriptions.KeyCaptured "Ctrl+d")
  in
  Alcotest.(check string)
    "chord echoed whole" "Last key: Ctrl+d" (key_readout chorded);
  let bare, _ =
    Sub_subscriptions.update model (Sub_subscriptions.KeyCaptured "d")
  in
  Alcotest.(check string)
    "bare key echoed whole" "Last key: d" (key_readout bare)

(* Implementation Decision 4 demonstrates the chord by the readout *plus* the
   section copy stating the contract, rather than by a second subscription — so
   the copy is a shipped design element, not incidental prose, and deleting it
   leaves every case above green. Only the two load-bearing tokens are pinned:
   the canonical-order spelling and the bare name a modifier keypress reports.
   Restating the paragraph would redden on every copy edit; this reddens only
   when the contract stops being stated. Read off the initial model, whose
   readout is the "(press a key)" placeholder, so neither token can be supplied
   by a captured key standing in for the copy. Existence is all this pins —
   where the paragraph sits in the section is not covered. *)
let test_section_copy_states_the_contract () =
  let model, _ = Sub_subscriptions.init () in
  let copy = text_content (tree (render (Sub_subscriptions.view vp model))) in
  Alcotest.(check bool)
    "copy states the canonical order" true
    (Test_util.string_contains copy ~sub:"Ctrl+Shift+key");
  Alcotest.(check bool)
    "copy names what a modifier keypress reports" true
    (Test_util.string_contains copy ~sub:"Control")

let () =
  Alcotest.run "kitchen_sink_subscriptions_section"
    [
      ( "structure",
        [
          Alcotest.test_case "renders and toggles timer sub key" `Quick
            test_subscriptions_section_renders_and_toggles_timer_sub_key;
          Alcotest.test_case "shows the chord" `Quick
            test_section_shows_the_chord;
          Alcotest.test_case "section copy states the contract" `Quick
            test_section_copy_states_the_contract;
        ] );
    ]
