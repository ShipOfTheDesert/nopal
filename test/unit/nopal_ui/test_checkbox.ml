open Nopal_test.Test_renderer
module C = Nopal_ui.Checkbox
module E = Nopal_element.Element

type msg = Toggled of bool | Label_clicked

let msg_testable =
  Alcotest.testable
    (fun fmt -> function
      | Toggled b -> Format.fprintf fmt "Toggled %b" b
      | Label_clicked -> Format.fprintf fmt "Label_clicked")
    ( = )

let find_checkbox node =
  match find (By_tag "checkbox") node with
  | Some n -> n
  | None -> Alcotest.fail "expected a checkbox element"

(* --- Structure --- *)

let test_label_text_rendered () =
  let config =
    {
      (C.make ~label:"Accept terms" ~checked:false) with
      on_toggle = Some (fun b -> Toggled b);
    }
  in
  let r = render (C.view config) in
  let label = text_content (tree r) in
  Alcotest.(check bool) "label present" true (String.length label > 0);
  Alcotest.(check bool)
    "label text matches" true
    (Test_util.string_contains label ~sub:"Accept terms")

let test_checkbox_before_label () =
  let config = C.make ~label:"Agree" ~checked:true in
  let r = render (C.view config) in
  match tree r with
  | Element { children; _ } -> (
      match children with
      | first :: _ -> (
          match first with
          | Element { tag = "checkbox"; _ } -> ()
          | Element _
          | Empty
          | Text _ ->
              Alcotest.fail "first child should be checkbox")
      | [] -> Alcotest.fail "expected children in row")
  | Empty
  | Text _ ->
      Alcotest.fail "expected element (row) at top level"

(* --- Disabled --- *)

let test_disabled_checkbox_has_disabled () =
  let config = { (C.make ~label:"Off" ~checked:false) with disabled = true } in
  let r = render (C.view config) in
  let cb = find_checkbox (tree r) in
  Alcotest.(check (option string))
    "disabled is true" (Some "true") (attr "disabled" cb)

let test_disabled_suppresses_on_toggle () =
  let config =
    {
      (C.make ~label:"Off" ~checked:false) with
      disabled = true;
      on_toggle = Some (fun b -> Toggled b);
    }
  in
  let r = render (C.view config) in
  let result = toggle (By_tag "checkbox") r in
  (match result with
  | Ok () -> Alcotest.fail "expected toggle to fail on disabled checkbox"
  | Error _ -> ());
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

(* --- Events --- *)

let test_on_toggle_dispatches () =
  let config =
    {
      (C.make ~label:"Enable" ~checked:false) with
      on_toggle = Some (fun b -> Toggled b);
    }
  in
  let r = render (C.view config) in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check (result unit Test_util.error_testable))
    "toggle ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "toggled to true" [ Toggled true ] (messages r)

(* --- Label element, identifier and association --- *)

let style_testable = Test_util.style_testable
let text_style_testable = Test_util.text_style_testable
let bold_label_style = Test_util.bold_label_style

let wide_row_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with Nopal_style.Style.gap = Some 12.0 })

let find_or_fail = Test_util.find_or_fail
let base_label = "Accept terms"
let base () = C.make ~label:base_label ~checked:false

let test_label_box_carries_the_generated_id () =
  let r = render (C.view (base ())) in
  let label_node =
    find_or_fail "expected a label element carrying id=accept-terms-label"
      (By_attr ("id", "accept-terms-label"))
      (tree r)
  in
  Alcotest.(check string) "label text" base_label (text_content label_node);
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
  let r = render (C.view (base ())) in
  let cb = find_checkbox (tree r) in
  match attr "aria-labelledby" cb with
  | None -> Alcotest.fail "expected aria-labelledby on the checkbox"
  | Some target ->
      let named =
        find_or_fail "aria-labelledby names no element in the tree"
          (By_attr ("id", target))
          (tree r)
      in
      Alcotest.(check string)
        "the named element is the visible label" base_label (text_content named);
      Alcotest.(check (option string))
        "aria-label no longer names the control" None (attr "aria-label" cb)

let test_with_id_overrides_both_halves () =
  let r = render (C.view (C.with_id "terms" (base ()))) in
  let cb = find_checkbox (tree r) in
  Alcotest.(check (option string)) "control id" (Some "terms") (attr "id" cb);
  Alcotest.(check (option string))
    "labelledby follows it" (Some "terms-label")
    (attr "aria-labelledby" cb);
  let label_node =
    find_or_fail "expected the label id to move with the explicit id"
      (By_attr ("id", "terms-label"))
      (tree r)
  in
  Alcotest.(check string) "label text" base_label (text_content label_node);
  Alcotest.(check bool)
    "the slug-derived label id is replaced, not joined" false
    (Option.is_some (find (By_attr ("id", "accept-terms-label")) (tree r)));
  Alcotest.(check (option string))
    "the E2E anchor stays on the label slug" (Some "accept-terms")
    (attr "data-field" cb)

let test_control_id_names_the_focus_target () =
  let derived = base () in
  Alcotest.(check string)
    "derived from the label" "accept-terms" (C.control_id derived);
  Alcotest.(check (option string))
    "the accessor names the rendered control"
    (Some (C.control_id derived))
    (attr "id" (find_checkbox (tree (render (C.view derived)))));
  let explicit = C.with_id "terms" derived in
  Alcotest.(check string) "explicit id wins" "terms" (C.control_id explicit);
  Alcotest.(check (option string))
    "the accessor follows the explicit id"
    (Some (C.control_id explicit))
    (attr "id" (find_checkbox (tree (render (C.view explicit)))))

let test_label_style_reaches_the_label_node () =
  let r = render (C.view (C.with_label_style bold_label_style (base ()))) in
  let label_node =
    find_or_fail "expected the label element"
      (By_attr ("id", "accept-terms-label"))
      (tree r)
  in
  Alcotest.(check (option style_testable))
    "label style on the label box" (Some bold_label_style) (style label_node);
  let text_node =
    find_or_fail "expected the label's text node" (By_text base_label)
      label_node
  in
  Alcotest.(check (option text_style_testable))
    "the style's text component reaches the text node"
    (Some bold_label_style.Nopal_style.Style.text) (text_style text_node)

let test_row_style_reaches_the_row () =
  let r = render (C.view (C.with_row_style wide_row_style (base ()))) in
  Alcotest.(check (option style_testable))
    "row style on the control-to-label row" (Some wide_row_style)
    (style (tree r))

let test_label_click_dispatches_the_configured_message () =
  let without = render (C.view (base ())) in
  Alcotest.(check bool)
    "no pointer handler on the label without the setter" true
    (Result.is_error
       (box_pointer_down
          (By_attr ("id", "accept-terms-label"))
          ~x:0.0 ~y:0.0 without));
  let r = render (C.view (C.with_on_label_click Label_clicked (base ()))) in
  let result =
    box_pointer_down (By_attr ("id", "accept-terms-label")) ~x:3.0 ~y:4.0 r
  in
  Alcotest.(check (result unit Test_util.error_testable))
    "pointer down ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "label click dispatched" [ Label_clicked ] (messages r)

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_checkbox"
    [
      ( "structure",
        [
          Alcotest.test_case "label text rendered" `Quick
            test_label_text_rendered;
          Alcotest.test_case "checkbox before label" `Quick
            test_checkbox_before_label;
        ] );
      ( "disabled",
        [
          Alcotest.test_case "disabled checkbox has disabled" `Quick
            test_disabled_checkbox_has_disabled;
          Alcotest.test_case "disabled suppresses on_toggle" `Quick
            test_disabled_suppresses_on_toggle;
        ] );
      ( "events",
        [
          Alcotest.test_case "on_toggle dispatches" `Quick
            test_on_toggle_dispatches;
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
          Alcotest.test_case "row style reaches the row" `Quick
            test_row_style_reaches_the_row;
        ] );
    ]
