open Nopal_test.Test_renderer

let test_focus_on_button_click () =
  let _model, rendered, cmds =
    run_app_with_cmds ~init:Focus_keyboard.init ~update:Focus_keyboard.update
      ~view:Focus_keyboard.view
      [ Focus_keyboard.Focus_input ]
  in
  let root = tree rendered in
  Alcotest.(check bool)
    "has focus button" true
    (Option.is_some (find (By_text "Focus Input") root));
  Alcotest.(check bool)
    "has demo input" true
    (Option.is_some (find (By_attr ("id", "demo-input")) root));
  Alcotest.(check bool)
    "has trap toggle" true
    (Option.is_some (find (By_attr ("data-testid", "trap-toggle")) root));
  Alcotest.(check bool)
    "shows no-key text" true
    (Option.is_some (find (By_text "No key trapped yet") root));
  let focus_ids = List.concat_map Nopal_mvu.Cmd.extract_focuses cmds in
  Alcotest.(check (list string))
    "clicking Focus Input produces Cmd.focus \"demo-input\"" [ "demo-input" ]
    focus_ids

(* The keydown handler of the single keydown subscription in [subs], or [None]
   if there is none. The trap is a unified [Sub.on_key]/[Sub.on_keydown], which
   normalizes to a single [Keydown] atom. *)
let keydown_handler subs =
  match Nopal_mvu.Sub.atoms subs with
  | [ Keydown { handler; _ } ] -> Some handler
  | _ -> Option.none

let test_keydown_prevent_subscription_active () =
  let model =
    Focus_keyboard.{ last_key = ""; trap_keys = true; created = false }
  in
  let subs = Focus_keyboard.subscriptions model in
  match keydown_handler subs with
  | None ->
      Alcotest.fail "expected a keydown subscription when trap_keys = true"
  | Some f -> (
      match f "Tab" with
      | Some (_msg, prevent) ->
          Alcotest.(check bool) "Tab should be prevented" true prevent
      | None -> Alcotest.fail "expected handler to return Some for \"Tab\"")

let test_keydown_prevent_subscription_inactive () =
  let model =
    Focus_keyboard.{ last_key = ""; trap_keys = false; created = false }
  in
  let subs = Focus_keyboard.subscriptions model in
  let result = keydown_handler subs in
  Alcotest.(check bool)
    "no keydown subscription when trap_keys = false" true
    (Option.is_none result)

let test_key_trapped_updates_last_key () =
  let model, _rendered, cmds =
    run_app_with_cmds ~init:Focus_keyboard.init ~update:Focus_keyboard.update
      ~view:Focus_keyboard.view
      [ Focus_keyboard.Key_trapped "Tab" ]
  in
  Alcotest.(check string) "last_key updated" "Tab" model.last_key;
  let focus_ids = List.concat_map Nopal_mvu.Cmd.extract_focuses cmds in
  Alcotest.(check (list string))
    "Key_trapped produces no focus commands" [] focus_ids;
  let root = tree _rendered in
  Alcotest.(check bool)
    "shows trapped key text" true
    (Option.is_some (find (By_text "Last key: Tab") root))

(* FR-3 fixture wiring: the create-and-focus control must, in a single update,
   render the new input and emit [Cmd.focus "created-input"] for it. This is the
   pure-MVU counterpart of the [focus-on-create] e2e — the e2e verifies the
   deferred-focus DOM timing, this verifies the model/view/command wiring the
   e2e depends on. *)
let test_create_and_focus_renders_and_focuses_input () =
  let _model, rendered, cmds =
    run_app_with_cmds ~init:Focus_keyboard.init ~update:Focus_keyboard.update
      ~view:Focus_keyboard.view
      [ Focus_keyboard.Create_and_focus ]
  in
  let root = tree rendered in
  Alcotest.(check bool)
    "renders the created input" true
    (Option.is_some (find (By_attr ("id", "created-input")) root));
  let focus_ids = List.concat_map Nopal_mvu.Cmd.extract_focuses cmds in
  Alcotest.(check (list string))
    "Create_and_focus produces Cmd.focus \"created-input\"" [ "created-input" ]
    focus_ids

let test_created_input_absent_before_click () =
  let _model, rendered, _cmds =
    run_app_with_cmds ~init:Focus_keyboard.init ~update:Focus_keyboard.update
      ~view:Focus_keyboard.view []
  in
  let root = tree rendered in
  Alcotest.(check bool)
    "no created input until Create_and_focus" false
    (Option.is_some (find (By_attr ("id", "created-input")) root))

let () =
  Alcotest.run "focus_keyboard kitchen sink"
    [
      ( "structural",
        [
          Alcotest.test_case "focus on button click" `Quick
            test_focus_on_button_click;
          Alcotest.test_case "create and focus renders and focuses input" `Quick
            test_create_and_focus_renders_and_focuses_input;
          Alcotest.test_case "created input absent before click" `Quick
            test_created_input_absent_before_click;
          Alcotest.test_case "keydown_prevent subscription active" `Quick
            test_keydown_prevent_subscription_active;
          Alcotest.test_case "keydown_prevent subscription inactive" `Quick
            test_keydown_prevent_subscription_inactive;
          Alcotest.test_case "Key_trapped updates last_key" `Quick
            test_key_trapped_updates_last_key;
        ] );
    ]
