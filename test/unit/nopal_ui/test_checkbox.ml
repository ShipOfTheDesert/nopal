open Nopal_test.Test_renderer
module C = Nopal_ui.Checkbox
module E = Nopal_element.Element

type msg = Toggled of bool

let msg_testable =
  Alcotest.testable
    (fun fmt (Toggled b) -> Format.fprintf fmt "Toggled %b" b)
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
          | _ -> Alcotest.fail "first child should be checkbox")
      | [] -> Alcotest.fail "expected children in row")
  | _ -> Alcotest.fail "expected element (row) at top level"

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
        ] );
    ]
