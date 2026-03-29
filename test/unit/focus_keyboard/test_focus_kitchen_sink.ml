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

let test_keydown_prevent_subscription_active () =
  let model = Focus_keyboard.{ last_key = ""; trap_keys = true } in
  let subs = Focus_keyboard.subscriptions model in
  match Nopal_mvu.Sub.extract_on_keydown_prevent subs with
  | None ->
      Alcotest.fail
        "expected on_keydown_prevent subscription when trap_keys = true"
  | Some f -> (
      match f "Tab" with
      | Some (_msg, prevent) ->
          Alcotest.(check bool) "Tab should be prevented" true prevent
      | None -> Alcotest.fail "expected callback to return Some for \"Tab\"")

let test_keydown_prevent_subscription_inactive () =
  let model = Focus_keyboard.{ last_key = ""; trap_keys = false } in
  let subs = Focus_keyboard.subscriptions model in
  let result = Nopal_mvu.Sub.extract_on_keydown_prevent subs in
  Alcotest.(check bool)
    "no on_keydown_prevent when trap_keys = false" true (Option.is_none result)

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

let () =
  Alcotest.run "focus_keyboard kitchen sink"
    [
      ( "structural",
        [
          Alcotest.test_case "focus on button click" `Quick
            test_focus_on_button_click;
          Alcotest.test_case "keydown_prevent subscription active" `Quick
            test_keydown_prevent_subscription_active;
          Alcotest.test_case "keydown_prevent subscription inactive" `Quick
            test_keydown_prevent_subscription_inactive;
          Alcotest.test_case "Key_trapped updates last_key" `Quick
            test_key_trapped_updates_last_key;
        ] );
    ]
