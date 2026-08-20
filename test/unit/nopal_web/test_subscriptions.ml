(* Behavioural coverage for the five browser-backed subscriptions the web
   backend interprets (REQ-F3): [every], [keydown], [keyup], [resize], and
   [visibility]. These exercise {!Nopal_web.web_interpret_atom} directly over
   the public {!Nopal_mvu.Sub.atom} type — the interpreter is the unit under
   test, so each case constructs the atom, sets it up against the shimmed DOM
   (see subs_shim.js), fires the corresponding browser event, and asserts on
   what the interpreter dispatched and on cleanup. Driving the interpreter
   directly (rather than through [mount]) is the only way to reach a [Keyup]
   handler that returns [None] — the public [Sub.on_keyup] always dispatches —
   and to assert per-atom [preventDefault] behaviour. *)

module Sub = Nopal_mvu.Sub

type msg =
  | Tick
  | Resized of int * int
  | Visible of bool
  | Keydown_msg of string
  | Keyup_msg of string

let msg_to_string = function
  | Tick -> "Tick"
  | Resized (w, h) -> Printf.sprintf "Resized(%d,%d)" w h
  | Visible b -> Printf.sprintf "Visible(%b)" b
  | Keydown_msg k -> Printf.sprintf "Keydown(%s)" k
  | Keyup_msg k -> Printf.sprintf "Keyup(%s)" k

let msg_t =
  Alcotest.testable
    (fun fmt m -> Format.pp_print_string fmt (msg_to_string m))
    ( = )

let window () = Jv.get Jv.global "window"
let document () = Jv.get Jv.global "document"

(* A dispatch sink recording every message in dispatch order. *)
let make_recorder () =
  let received = ref [] in
  let dispatch msg = received := msg :: !received in
  (dispatch, fun () -> List.rev !received)

(* Set up an atom or fail loudly: the interpreter must serve all five
   built-ins, so an [Error] here is a test failure, not an expected branch. *)
let setup_or_fail atom dispatch =
  match Nopal_web.web_interpret_atom ~dispatch atom with
  | Ok cleanup -> cleanup
  | Error e -> Alcotest.failf "web_interpret_atom returned Error: %s" e

(* Dispatch a keyboard event of [event_type] carrying [key] and both modifier
   flags on [window], and return it so the caller can read [defaultPrevented].
   [ctrlKey] and [shiftKey] are set explicitly so the interpreter's modifier
   read is unambiguous. Neither is optional and neither defaults: each flag
   changes which string the interpreter builds, so a case that leaves one unsaid
   is not stating its own input. They are labelled because they are two
   booleans, which a call site can otherwise transpose silently. *)
let fire_key event_type ~key ~ctrl ~shift =
  let opts =
    Jv.obj
      [|
        ("key", Jv.of_string key);
        ("ctrlKey", Jv.of_bool ctrl);
        ("shiftKey", Jv.of_bool shift);
      |]
  in
  let ev =
    Jv.new'
      (Jv.get Jv.global "KeyboardEvent")
      [| Jv.of_string event_type; opts |]
  in
  ignore (Jv.call (window ()) "dispatchEvent" [| ev |]);
  ev

let fire_plain target event_type =
  let ev = Jv.new' (Jv.get Jv.global "Event") [| Jv.of_string event_type |] in
  ignore (Jv.call target "dispatchEvent" [| ev |])

let test_every_dispatches_on_interval_and_stops_on_removal () =
  let dispatch, received = make_recorder () in
  let cleanup =
    setup_or_fail
      (Sub.Every { key = "timer"; interval_ms = 1000; tick = (fun () -> Tick) })
      dispatch
  in
  let fire () = ignore (Jv.call (window ()) "__nopal_fire_intervals" [||]) in
  fire ();
  fire ();
  Alcotest.(check (list msg_t))
    "two ticks while subscribed" [ Tick; Tick ] (received ());
  cleanup ();
  fire ();
  Alcotest.(check (list msg_t))
    "cleared interval stops firing" [ Tick; Tick ] (received ())

let test_resize_dispatches_dimensions () =
  let dispatch, received = make_recorder () in
  let cleanup =
    setup_or_fail
      (Sub.Resize { key = "r"; handler = (fun w h -> Resized (w, h)) })
      dispatch
  in
  let w = window () in
  Jv.set w "innerWidth" (Jv.of_int 1024);
  Jv.set w "innerHeight" (Jv.of_int 768);
  fire_plain w "resize";
  Alcotest.(check (list msg_t))
    "resize dispatches current window dimensions"
    [ Resized (1024, 768) ]
    (received ());
  cleanup ();
  Jv.set w "innerWidth" (Jv.of_int 640);
  fire_plain w "resize";
  Alcotest.(check (list msg_t))
    "no dispatch after cleanup removes the listener"
    [ Resized (1024, 768) ]
    (received ())

let test_visibility_change_dispatches_flag () =
  let dispatch, received = make_recorder () in
  let cleanup =
    setup_or_fail
      (Sub.Visibility { key = "v"; handler = (fun b -> Visible b) })
      dispatch
  in
  let doc = document () in
  Jv.set doc "visibilityState" (Jv.of_string "hidden");
  fire_plain doc "visibilitychange";
  Jv.set doc "visibilityState" (Jv.of_string "visible");
  fire_plain doc "visibilitychange";
  Alcotest.(check (list msg_t))
    "visibility flag tracks document.visibilityState"
    [ Visible false; Visible true ]
    (received ());
  cleanup ()

let test_keydown_some_true_prevents_default () =
  let dispatch, received = make_recorder () in
  let handler key =
    if String.equal key "Enter" then Some (Keydown_msg key, true)
    else Option.none
  in
  let cleanup = setup_or_fail (Sub.Keydown { key = "k"; handler }) dispatch in
  let ev = fire_key "keydown" ~key:"Enter" ~ctrl:false ~shift:false in
  Alcotest.(check (list msg_t))
    "matched keydown dispatches" [ Keydown_msg "Enter" ] (received ());
  Alcotest.(check bool)
    "preventDefault called for Some (_, true)" true
    (Jv.to_bool (Jv.get ev "defaultPrevented"));
  cleanup ()

let test_keydown_none_ignores_key () =
  let dispatch, received = make_recorder () in
  let handler key =
    if String.equal key "Enter" then Some (Keydown_msg key, true)
    else Option.none
  in
  let cleanup = setup_or_fail (Sub.Keydown { key = "k"; handler }) dispatch in
  let ev = fire_key "keydown" ~key:"x" ~ctrl:false ~shift:false in
  Alcotest.(check (list msg_t))
    "unmatched key dispatches nothing" [] (received ());
  Alcotest.(check bool)
    "preventDefault not called for None" false
    (Jv.to_bool (Jv.get ev "defaultPrevented"));
  cleanup ()

let test_keyup_filter_drops_none () =
  let dispatch, received = make_recorder () in
  let handler key =
    if String.equal key "a" then Some (Keyup_msg key) else Option.none
  in
  let cleanup = setup_or_fail (Sub.Keyup { key = "u"; handler }) dispatch in
  ignore (fire_key "keyup" ~key:"b" ~ctrl:false ~shift:false);
  ignore (fire_key "keyup" ~key:"a" ~ctrl:false ~shift:false);
  Alcotest.(check (list msg_t))
    "only the matched keyup dispatches" [ Keyup_msg "a" ] (received ());
  cleanup ()

(* The single subscription both modifier-tightening arms below share: it matches
   the whole string ["ArrowDown"] and nothing else. It is built here rather than
   twice at the two call sites so that "the same fixture" is literal. The
   absence arm asserts that nothing dispatches while Ctrl is held, and that can
   only mean the modifier read caused the absence if the affirmative arm proves
   this identical subscription does dispatch without it. *)
let bare_arrow_down_atom () =
  Sub.Keydown
    {
      key = "arrows";
      handler =
        (fun key ->
          if String.equal key "ArrowDown" then Some (Keydown_msg key, false)
          else Option.none);
    }

let test_ctrl_chord_does_not_match_bare_subscription () =
  let dispatch, received = make_recorder () in
  let cleanup = setup_or_fail (bare_arrow_down_atom ()) dispatch in
  ignore (fire_key "keydown" ~key:"ArrowDown" ~ctrl:true ~shift:false);
  Alcotest.(check (list msg_t))
    "Ctrl+ArrowDown does not reach a subscription naming the bare key" []
    (received ());
  cleanup ()

let test_bare_key_still_dispatches () =
  let dispatch, received = make_recorder () in
  let cleanup = setup_or_fail (bare_arrow_down_atom ()) dispatch in
  ignore (fire_key "keydown" ~key:"ArrowDown" ~ctrl:false ~shift:false);
  Alcotest.(check (list msg_t))
    "the same subscription still dispatches on the bare key"
    [ Keydown_msg "ArrowDown" ]
    (received ());
  cleanup ()

let test_ctrl_chord_dispatches_its_own_subscription () =
  let dispatch, received = make_recorder () in
  let handler key =
    if String.equal key "Ctrl+d" then Some (Keydown_msg key, false)
    else Option.none
  in
  let cleanup =
    setup_or_fail (Sub.Keydown { key = "chord"; handler }) dispatch
  in
  ignore (fire_key "keydown" ~key:"d" ~ctrl:true ~shift:false);
  Alcotest.(check (list msg_t))
    "a Ctrl chord subscription fires on the chord" [ Keydown_msg "Ctrl+d" ]
    (received ());
  cleanup ()

(* [event_key] is applied on the Keyup interpreter arm as well as the Keydown
   one, so a fold reaching only the keydown listener would leave every case
   above green. This is the arm that fails when that happens. *)
let test_ctrl_chord_folds_on_the_keyup_arm () =
  let dispatch, received = make_recorder () in
  let handler key =
    if String.equal key "Ctrl+d" then Some (Keyup_msg key) else Option.none
  in
  let cleanup = setup_or_fail (Sub.Keyup { key = "chord"; handler }) dispatch in
  ignore (fire_key "keyup" ~key:"d" ~ctrl:true ~shift:false);
  Alcotest.(check (list msg_t))
    "the keyup arm folds Ctrl the same way" [ Keyup_msg "Ctrl+d" ] (received ());
  cleanup ()

let test_shift_tab_still_dispatches () =
  let dispatch, received = make_recorder () in
  let handler key =
    if String.equal key "Shift+Tab" then Some (Keydown_msg key, false)
    else Option.none
  in
  let cleanup =
    setup_or_fail (Sub.Keydown { key = "tabbing"; handler }) dispatch
  in
  ignore (fire_key "keydown" ~key:"Tab" ~ctrl:false ~shift:true);
  Alcotest.(check (list msg_t))
    "the shipped Shift chord is unchanged"
    [ Keydown_msg "Shift+Tab" ]
    (received ());
  cleanup ()

(* [Sub.on_key] returns a subscription tree, not an atom. [Sub.atoms] is the
   sole public interpreter over that tree and is how a backend receives any
   subscription, so reducing through it is the real path rather than a test-only
   shortcut. Exactly one atom is expected: [on_key] builds a single [On_keydown]
   node with no [batch] around it. *)
let single_atom sub =
  match Sub.atoms sub with
  | [ atom ] -> atom
  | ([] | _ :: _ :: _) as atoms ->
      Alcotest.failf "expected on_key to yield exactly one atom, got %d"
        (List.length atoms)

(* Every case above builds its [Keydown] record by hand, which leaves
   [Sub.on_key] — the convenience constructor a subscriber actually reaches for,
   and the spelling [sub.mli] advertises — untested on the chord path. Its
   whole-string [String.equal] against [~key:] is what makes ["Ctrl+d"] name the
   chord, so the bare [d] is fired first on the same fixture: a constructor that
   ignored [~key:] and dispatched on every key would otherwise pass. The single
   expected message therefore pins both halves — the chord matches and the bare
   key, a substring of it, does not. *)
let test_on_key_matches_the_chord_spelling () =
  let dispatch, received = make_recorder () in
  let cleanup =
    setup_or_fail
      (single_atom
         (Sub.on_key "chord" ~key:"Ctrl+d" ~prevent:false (Keydown_msg "Ctrl+d")))
      dispatch
  in
  ignore (fire_key "keydown" ~key:"d" ~ctrl:false ~shift:false);
  ignore (fire_key "keydown" ~key:"d" ~ctrl:true ~shift:false);
  Alcotest.(check (list msg_t))
    "on_key ~key:\"Ctrl+d\" fires on the chord and not on the bare key"
    [ Keydown_msg "Ctrl+d" ] (received ());
  cleanup ()

let () =
  Alcotest.run "nopal_web subscriptions"
    [
      ( "interpreter",
        [
          Alcotest.test_case "every dispatches on interval and stops on removal"
            `Quick test_every_dispatches_on_interval_and_stops_on_removal;
          Alcotest.test_case "resize dispatches dimensions" `Quick
            test_resize_dispatches_dimensions;
          Alcotest.test_case "visibility change dispatches flag" `Quick
            test_visibility_change_dispatches_flag;
          Alcotest.test_case "keydown Some (_, true) prevents default" `Quick
            test_keydown_some_true_prevents_default;
          Alcotest.test_case "keydown None ignores key" `Quick
            test_keydown_none_ignores_key;
          Alcotest.test_case "keyup filter drops None" `Quick
            test_keyup_filter_drops_none;
          Alcotest.test_case "ctrl chord does not match bare subscription"
            `Quick test_ctrl_chord_does_not_match_bare_subscription;
          Alcotest.test_case "bare key still dispatches" `Quick
            test_bare_key_still_dispatches;
          Alcotest.test_case "ctrl chord dispatches its own subscription" `Quick
            test_ctrl_chord_dispatches_its_own_subscription;
          Alcotest.test_case "ctrl chord folds on the keyup arm" `Quick
            test_ctrl_chord_folds_on_the_keyup_arm;
          Alcotest.test_case "shift+tab still dispatches" `Quick
            test_shift_tab_still_dispatches;
          Alcotest.test_case "on_key matches the chord spelling" `Quick
            test_on_key_matches_the_chord_spelling;
        ] );
    ]
