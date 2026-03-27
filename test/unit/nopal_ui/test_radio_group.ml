open Nopal_test.Test_renderer
module RG = Nopal_ui.Radio_group

type msg = Selected of string

let msg_testable =
  Alcotest.testable
    (fun fmt (Selected v) -> Format.fprintf fmt "Selected %s" v)
    ( = )

let options =
  [
    RG.radio_option ~value:"a" "Alpha";
    RG.radio_option ~value:"b" "Beta";
    RG.radio_option ~value:"c" "Gamma";
  ]

let base_config =
  {
    (RG.make ~label:"Pick one" ~options ~selected:"b") with
    on_select = Some (fun v -> Selected v);
  }

(* --- Structure --- *)

let test_container_has_radiogroup_role () =
  let r = render (RG.view base_config) in
  let root = tree r in
  Alcotest.(check (option string))
    "role is radiogroup" (Some "radiogroup") (attr "role" root)

let test_container_has_aria_label () =
  let r = render (RG.view base_config) in
  let root = tree r in
  Alcotest.(check (option string))
    "aria-label matches" (Some "Pick one") (attr "aria-label" root)

let test_renders_all_options () =
  let r = render (RG.view base_config) in
  let radios = find_all (By_tag "radio") (tree r) in
  Alcotest.(check int) "one radio per option" 3 (List.length radios)

let test_selected_radio_is_checked () =
  let r = render (RG.view base_config) in
  let radios = find_all (By_tag "radio") (tree r) in
  let checked_values =
    List.filter_map
      (fun n ->
        match attr "checked" n with
        | Some "true" -> attr "name" n
        | _ -> None)
      radios
  in
  Alcotest.(check int) "exactly one checked" 1 (List.length checked_values)

let test_unselected_radios_not_checked () =
  let r = render (RG.view base_config) in
  let radios = find_all (By_tag "radio") (tree r) in
  let unchecked =
    List.filter (fun n -> attr "checked" n = Some "false") radios
  in
  Alcotest.(check int) "two unchecked" 2 (List.length unchecked)

(* --- Name --- *)

let test_name_auto_generated_from_label () =
  let r = render (RG.view base_config) in
  let radios = find_all (By_tag "radio") (tree r) in
  List.iter
    (fun n ->
      Alcotest.(check (option string))
        "name is slugified label" (Some "pick-one") (attr "name" n))
    radios

let test_name_override () =
  let config = { base_config with name = Some "custom" } in
  let r = render (RG.view config) in
  let radios = find_all (By_tag "radio") (tree r) in
  List.iter
    (fun n ->
      Alcotest.(check (option string))
        "name is custom" (Some "custom") (attr "name" n))
    radios

(* --- Disabled --- *)

let test_group_disabled_disables_all_radios () =
  let config = { base_config with disabled = true } in
  let r = render (RG.view config) in
  let radios = find_all (By_tag "radio") (tree r) in
  List.iter
    (fun n ->
      Alcotest.(check (option string))
        "disabled is true" (Some "true") (attr "disabled" n))
    radios

let test_group_disabled_suppresses_on_select () =
  let config = { base_config with disabled = true } in
  let r = render (RG.view config) in
  let result = click (By_tag "radio") r in
  (match result with
  | Ok () -> Alcotest.fail "expected click to fail on disabled radio"
  | Error _ -> ());
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

let test_option_disabled_disables_single_radio () =
  let opts =
    [
      RG.radio_option ~value:"a" "Alpha";
      RG.radio_option ~disabled:true ~value:"b" "Beta";
      RG.radio_option ~value:"c" "Gamma";
    ]
  in
  let config =
    {
      (RG.make ~label:"Pick one" ~options:opts ~selected:"a") with
      on_select = Some (fun v -> Selected v);
    }
  in
  let r = render (RG.view config) in
  let radios = find_all (By_tag "radio") (tree r) in
  let disabled_states =
    List.map (fun n -> attr "disabled" n = Some "true") radios
  in
  Alcotest.(check (list bool))
    "only second disabled" [ false; true; false ] disabled_states

(* --- Events --- *)

let test_on_select_dispatches () =
  let config =
    {
      (RG.make ~label:"Pick one" ~options ~selected:"b") with
      on_select = Some (fun v -> Selected v);
    }
  in
  let r = render (RG.view config) in
  let result = click (By_tag "radio") r in
  Alcotest.(check (result unit Test_util.error_testable))
    "click ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "selected first option" [ Selected "a" ] (messages r)

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_radio_group"
    [
      ( "structure",
        [
          Alcotest.test_case "container has radiogroup role" `Quick
            test_container_has_radiogroup_role;
          Alcotest.test_case "container has aria label" `Quick
            test_container_has_aria_label;
          Alcotest.test_case "renders all options" `Quick
            test_renders_all_options;
          Alcotest.test_case "selected radio is checked" `Quick
            test_selected_radio_is_checked;
          Alcotest.test_case "unselected radios not checked" `Quick
            test_unselected_radios_not_checked;
        ] );
      ( "name",
        [
          Alcotest.test_case "name auto generated from label" `Quick
            test_name_auto_generated_from_label;
          Alcotest.test_case "name override" `Quick test_name_override;
        ] );
      ( "disabled",
        [
          Alcotest.test_case "group disabled disables all radios" `Quick
            test_group_disabled_disables_all_radios;
          Alcotest.test_case "group disabled suppresses on_select" `Quick
            test_group_disabled_suppresses_on_select;
          Alcotest.test_case "option disabled disables single radio" `Quick
            test_option_disabled_disables_single_radio;
        ] );
      ( "events",
        [
          Alcotest.test_case "on_select dispatches" `Quick
            test_on_select_dispatches;
        ] );
    ]
