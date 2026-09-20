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

(* The section overrides the per-variant toast style and interaction, composing
   with the exposed variant defaults rather than discarding them. Both halves are asserted: the override's own non-default
   values reached the toast element, and the default background it composed over
   survived. Without the second half a setter that silently replaced the whole
   style would read as success. *)
let test_section_toast_carries_the_overrides () =
  let model, _ = Sub_toast.init () in
  let model, _ = Sub_toast.update model ShowInfo in
  let r = render (Sub_toast.view vp model) in
  let node =
    match find (By_attr ("data-variant", "info")) (tree r) with
    | Some node -> node
    | None -> Alcotest.fail "the info toast is missing"
  in
  let paint =
    match style node with
    | Some (s : Nopal_style.Style.t) -> s.Nopal_style.Style.paint
    | None -> Alcotest.fail "the info toast carries no style at all"
  in
  (match paint.border with
  | Some b ->
      Alcotest.(check (float 0.001))
        "the override's border width" 2.0 b.Nopal_style.Style.width;
      Alcotest.(check (float 0.001)) "the override's corner radius" 0.0 b.radius
  | None -> Alcotest.fail "the info toast carries no border");
  Alcotest.(check bool)
    "the composed-over default background survives" true
    (Option.equal Nopal_style.Color.equal paint.background
       (Some (Nopal_style.Color.hex "#d0e8ff")));
  let hover =
    Option.bind (interaction node) (fun (i : Nopal_style.Interaction.t) ->
        i.hover)
  in
  Alcotest.(check bool)
    "the interaction override reached the toast" true (Option.is_some hover)

let () =
  Alcotest.run "kitchen_sink_toast_section"
    [
      ( "structure",
        [
          Alcotest.test_case "renders trigger buttons" `Quick
            test_view_renders_trigger_buttons;
          Alcotest.test_case "with toast shows toast" `Quick
            test_view_with_toast_shows_toast;
          Alcotest.test_case "toast carries the section's overrides" `Quick
            test_section_toast_carries_the_overrides;
        ] );
    ]
