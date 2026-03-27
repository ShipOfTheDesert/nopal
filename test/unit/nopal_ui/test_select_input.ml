open Nopal_test.Test_renderer
module SI = Nopal_ui.Select_input
module E = Nopal_element.Element

type msg = Changed of string

let msg_testable =
  Alcotest.testable
    (fun fmt (Changed v) -> Format.fprintf fmt "Changed %s" v)
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
        ] );
    ]
