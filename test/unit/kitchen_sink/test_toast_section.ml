open Nopal_test.Test_renderer
module Sub_toast = Kitchen_sink_app__Sub_toast

let vp = Nopal_element.Viewport.desktop

let test_view_renders_trigger_buttons () =
  let model, _ = Sub_toast.init () in
  let r = render (Sub_toast.view vp model) in
  let root = tree r in
  let info_btn = find (By_attr ("data-testid", "toast-trigger-info")) root in
  let success_btn =
    find (By_attr ("data-testid", "toast-trigger-success")) root
  in
  let warning_btn =
    find (By_attr ("data-testid", "toast-trigger-warning")) root
  in
  let error_btn = find (By_attr ("data-testid", "toast-trigger-error")) root in
  Alcotest.(check bool) "info trigger" true (Option.is_some info_btn);
  Alcotest.(check bool) "success trigger" true (Option.is_some success_btn);
  Alcotest.(check bool) "warning trigger" true (Option.is_some warning_btn);
  Alcotest.(check bool) "error trigger" true (Option.is_some error_btn)

let test_view_with_toast_shows_toast () =
  let model, _ = Sub_toast.init () in
  let model, _ = Sub_toast.update model ShowInfo in
  let r = render (Sub_toast.view vp model) in
  let root = tree r in
  let toast = find (By_attr ("data-variant", "info")) root in
  Alcotest.(check bool) "info toast visible" true (Option.is_some toast);
  match toast with
  | Some node ->
      let content = text_content node in
      Alcotest.(check bool)
        "has notification text" true
        (Test_util.string_contains content ~sub:"info notification")
  | None -> Alcotest.fail "unreachable"

let () =
  Alcotest.run "kitchen_sink_toast_section"
    [
      ( "structure",
        [
          Alcotest.test_case "renders trigger buttons" `Quick
            test_view_renders_trigger_buttons;
          Alcotest.test_case "with toast shows toast" `Quick
            test_view_with_toast_shows_toast;
        ] );
    ]
