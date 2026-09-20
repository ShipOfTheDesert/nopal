open Nopal_test.Test_renderer
module SI = Nopal_ui.Select_input
module E = Nopal_element.Element

type msg = Changed of string | Label_clicked

let msg_testable =
  Alcotest.testable
    (fun fmt -> function
      | Changed v -> Format.fprintf fmt "Changed %s" v
      | Label_clicked -> Format.fprintf fmt "Label_clicked")
    ( = )

let options =
  [
    E.select_option ~value:"a" "Alpha";
    E.select_option ~value:"b" "Beta";
    E.select_option ~value:"c" "Gamma";
  ]

let base_config =
  {
    (SI.make ~label:"Fruit" ~options ~selected:"b") with
    on_change = Some (fun v -> Changed v);
  }

(* --- Structure --- *)

let test_label_text_rendered () =
  let r = render (SI.view base_config) in
  let label = text_content (tree r) in
  Alcotest.(check bool)
    "label present" true
    (Test_util.string_contains label ~sub:"Fruit")

let test_renders_all_options () =
  let r = render (SI.view base_config) in
  let opts = find_all (By_tag "option") (tree r) in
  Alcotest.(check int) "one option per entry" 3 (List.length opts)

(* --- Placeholder --- *)

let test_placeholder_prepended () =
  let config = { base_config with placeholder = Some "Choose..." } in
  let r = render (SI.view config) in
  let opts = find_all (By_tag "option") (tree r) in
  Alcotest.(check int) "extra placeholder option" 4 (List.length opts);
  match opts with
  | first :: _ ->
      Alcotest.(check (option string))
        "placeholder value is empty" (Some "") (attr "value" first);
      Alcotest.(check (option string))
        "placeholder label" (Some "Choose...") (attr "label" first);
      Alcotest.(check (option string))
        "placeholder is disabled" (Some "true") (attr "disabled" first)
  | [] -> Alcotest.fail "expected at least one option"

let test_no_placeholder_omits_extra_option () =
  let config = { base_config with placeholder = None } in
  let r = render (SI.view config) in
  let opts = find_all (By_tag "option") (tree r) in
  Alcotest.(check int) "option count matches input" 3 (List.length opts)

(* --- Disabled --- *)

let test_disabled_select_has_disabled () =
  let config = { base_config with disabled = true } in
  let r = render (SI.view config) in
  match find (By_tag "select") (tree r) with
  | Some sel ->
      Alcotest.(check (option string))
        "disabled is true" (Some "true") (attr "disabled" sel)
  | None -> Alcotest.fail "expected a select element"

let test_disabled_suppresses_on_change () =
  let config = { base_config with disabled = true } in
  let r = render (SI.view config) in
  let result = input (By_tag "select") "c" r in
  (match result with
  | Ok () -> Alcotest.fail "expected input to fail on disabled select"
  | Error _ -> ());
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

(* --- Placeholder edge cases --- *)

let test_placeholder_selected_when_empty () =
  let config =
    {
      (SI.make ~label:"Pick" ~options ~selected:"") with
      placeholder = Some "Choose...";
      on_change = Some (fun v -> Changed v);
    }
  in
  let r = render (SI.view config) in
  match find (By_tag "select") (tree r) with
  | Some sel ->
      Alcotest.(check (option string))
        "selected is empty string" (Some "") (attr "selected" sel)
  | None -> Alcotest.fail "expected a select element"

(* --- Events --- *)

let test_on_change_dispatches () =
  let r = render (SI.view base_config) in
  let result = input (By_tag "select") "c" r in
  Alcotest.(check (result unit Test_util.error_testable))
    "input ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "changed to c" [ Changed "c" ] (messages r)

(* --- Label element, identifier and association --- *)

let style_testable = Test_util.style_testable
let text_style_testable = Test_util.text_style_testable
let bold_label_style = Test_util.bold_label_style

let wide_wrapper_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with Nopal_style.Style.gap = Some 6.0 })

let find_or_fail = Test_util.find_or_fail

let find_select node =
  find_or_fail "expected a select element" (By_tag "select") node

let test_label_box_carries_the_generated_id () =
  let r = render (SI.view base_config) in
  let label_node =
    find_or_fail "expected a label element carrying id=fruit-label"
      (By_attr ("id", "fruit-label"))
      (tree r)
  in
  Alcotest.(check string) "label text" "Fruit" (text_content label_node);
  match label_node with
  | Element { tag = "box"; children = [ Text _ ]; _ } -> ()
  | Element { tag; _ } ->
      Alcotest.failf
        "the generated id sits on a %s wrapping the whole control, not on the \
         label element"
        tag
  | Empty
  | Text _ ->
      Alcotest.fail "expected the generated id on an element"

let test_control_is_named_by_labelledby_and_not_by_label () =
  let r = render (SI.view base_config) in
  let sel = find_select (tree r) in
  match attr "aria-labelledby" sel with
  | None -> Alcotest.fail "expected aria-labelledby on the select"
  | Some target ->
      let named =
        find_or_fail "aria-labelledby names no element in the tree"
          (By_attr ("id", target))
          (tree r)
      in
      Alcotest.(check string)
        "the named element is the visible label" "Fruit" (text_content named);
      Alcotest.(check (option string))
        "aria-label no longer names the control" None (attr "aria-label" sel)

let test_with_id_overrides_both_halves () =
  let r = render (SI.view (SI.with_id "size" base_config)) in
  let sel = find_select (tree r) in
  Alcotest.(check (option string)) "control id" (Some "size") (attr "id" sel);
  Alcotest.(check (option string))
    "labelledby follows it" (Some "size-label")
    (attr "aria-labelledby" sel);
  let label_node =
    find_or_fail "expected the label id to move with the explicit id"
      (By_attr ("id", "size-label"))
      (tree r)
  in
  Alcotest.(check string) "label text" "Fruit" (text_content label_node);
  Alcotest.(check bool)
    "the slug-derived label id is replaced, not joined" false
    (Option.is_some (find (By_attr ("id", "fruit-label")) (tree r)));
  Alcotest.(check (option string))
    "the E2E anchor stays on the label slug" (Some "fruit")
    (attr "data-field" sel)

let test_control_id_names_the_focus_target () =
  Alcotest.(check string)
    "derived from the label" "fruit"
    (SI.control_id base_config);
  Alcotest.(check (option string))
    "the accessor names the rendered control"
    (Some (SI.control_id base_config))
    (attr "id" (find_select (tree (render (SI.view base_config)))));
  let explicit = SI.with_id "size" base_config in
  Alcotest.(check string) "explicit id wins" "size" (SI.control_id explicit);
  Alcotest.(check (option string))
    "the accessor follows the explicit id"
    (Some (SI.control_id explicit))
    (attr "id" (find_select (tree (render (SI.view explicit)))))

let test_label_style_reaches_the_label_node () =
  let r = render (SI.view (SI.with_label_style bold_label_style base_config)) in
  let label_node =
    find_or_fail "expected the label element"
      (By_attr ("id", "fruit-label"))
      (tree r)
  in
  Alcotest.(check (option style_testable))
    "label style on the label box" (Some bold_label_style) (style label_node);
  let text_node =
    find_or_fail "expected the label's text node" (By_text "Fruit") label_node
  in
  Alcotest.(check (option text_style_testable))
    "the style's text component reaches the text node"
    (Some bold_label_style.Nopal_style.Style.text) (text_style text_node)

let test_wrapper_style_reaches_the_wrapper () =
  let r =
    render (SI.view (SI.with_wrapper_style wide_wrapper_style base_config))
  in
  Alcotest.(check (option style_testable))
    "wrapper style on the label-to-control column" (Some wide_wrapper_style)
    (style (tree r))

let test_label_click_dispatches_the_configured_message () =
  let without = render (SI.view base_config) in
  Alcotest.(check bool)
    "no pointer handler on the label without the setter" true
    (Result.is_error
       (box_pointer_down (By_attr ("id", "fruit-label")) ~x:0.0 ~y:0.0 without));
  let r = render (SI.view (SI.with_on_label_click Label_clicked base_config)) in
  let result =
    box_pointer_down (By_attr ("id", "fruit-label")) ~x:3.0 ~y:4.0 r
  in
  Alcotest.(check (result unit Test_util.error_testable))
    "pointer down ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "label click dispatched" [ Label_clicked ] (messages r)

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_select_input"
    [
      ( "structure",
        [
          Alcotest.test_case "label text rendered" `Quick
            test_label_text_rendered;
          Alcotest.test_case "renders all options" `Quick
            test_renders_all_options;
        ] );
      ( "placeholder",
        [
          Alcotest.test_case "placeholder prepended" `Quick
            test_placeholder_prepended;
          Alcotest.test_case "no placeholder omits extra option" `Quick
            test_no_placeholder_omits_extra_option;
          Alcotest.test_case "placeholder selected when empty" `Quick
            test_placeholder_selected_when_empty;
        ] );
      ( "disabled",
        [
          Alcotest.test_case "disabled select has disabled" `Quick
            test_disabled_select_has_disabled;
          Alcotest.test_case "disabled suppresses on_change" `Quick
            test_disabled_suppresses_on_change;
        ] );
      ( "events",
        [
          Alcotest.test_case "on_change dispatches" `Quick
            test_on_change_dispatches;
          Alcotest.test_case "label click dispatches the configured message"
            `Quick test_label_click_dispatches_the_configured_message;
        ] );
      ( "label, identifier and association",
        [
          Alcotest.test_case "label box carries the generated id" `Quick
            test_label_box_carries_the_generated_id;
          Alcotest.test_case "control is named by labelledby and not by label"
            `Quick test_control_is_named_by_labelledby_and_not_by_label;
          Alcotest.test_case "with_id overrides both halves" `Quick
            test_with_id_overrides_both_halves;
          Alcotest.test_case "control_id names the focus target" `Quick
            test_control_id_names_the_focus_target;
        ] );
      ( "style overrides",
        [
          Alcotest.test_case "label style reaches the label node" `Quick
            test_label_style_reaches_the_label_node;
          Alcotest.test_case "wrapper style reaches the wrapper" `Quick
            test_wrapper_style_reaches_the_wrapper;
        ] );
    ]
