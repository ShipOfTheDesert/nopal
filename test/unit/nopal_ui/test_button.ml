open Nopal_test.Test_renderer
module B = Nopal_ui.Button
module E = Nopal_element.Element
module S = Nopal_style.Style

type msg = Click

let msg_testable =
  Alcotest.testable (fun fmt Click -> Format.fprintf fmt "Click") ( = )

let check_attr msg key expected node =
  Alcotest.(check (option string)) msg expected (attr key node)

let find_button node =
  match find (By_tag "button") node with
  | Some n -> n
  | None -> Alcotest.fail "expected a button element"

(* --- Variant default attrs --- *)

let test_primary_default_attrs () =
  let config = B.default Primary in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "primary") btn;
  Alcotest.(check (option string))
    "no aria-disabled" None (attr "aria-disabled" btn);
  Alcotest.(check (option string)) "no aria-busy" None (attr "aria-busy" btn)

let test_secondary_default_attrs () =
  let config = B.default Secondary in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "secondary") btn

let test_destructive_default_attrs () =
  let config = B.default Destructive in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "destructive") btn

let test_ghost_default_attrs () =
  let config = B.default Ghost in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "ghost") btn

let test_icon_default_attrs () =
  let config = B.default Icon in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-variant" "data-variant" (Some "icon") btn

(* --- Disabled --- *)

let test_disabled_suppresses_click () =
  let config =
    { (B.default Primary) with disabled = true; on_click = Some Click }
  in
  let r = render (B.view config (E.text "ok")) in
  let _result = click (By_tag "button") r in
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

let test_disabled_sets_aria () =
  let config = { (B.default Primary) with disabled = true } in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "aria-disabled" "aria-disabled" (Some "true") btn

(* --- Loading --- *)

let test_loading_suppresses_click () =
  let config =
    { (B.default Primary) with loading = true; on_click = Some Click }
  in
  let r = render (B.view config (E.text "ok")) in
  let _result = click (By_tag "button") r in
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

let test_loading_sets_aria () =
  let config = { (B.default Primary) with loading = true } in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "aria-busy" "aria-busy" (Some "true") btn

(* --- Both disabled and loading --- *)

let test_disabled_and_loading_both_aria () =
  let config = { (B.default Primary) with disabled = true; loading = true } in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "aria-disabled" "aria-disabled" (Some "true") btn;
  check_attr "aria-busy" "aria-busy" (Some "true") btn

(* --- Click dispatches --- *)

let test_click_dispatches_message () =
  let config = { (B.default Primary) with on_click = Some Click } in
  let r = render (B.view config (E.text "ok")) in
  let result = click (By_tag "button") r in
  Alcotest.(check (result unit Test_util.error_testable))
    "click ok" (Ok ()) result;
  Alcotest.(check (list msg_testable)) "one message" [ Click ] (messages r)

(* --- Child text --- *)

let test_child_text_preserved () =
  let config = B.default Primary in
  let r = render (B.view config (E.text "Save")) in
  let btn = find_button (tree r) in
  Alcotest.(check string) "child text" "Save" (text_content btn)

(* --- User attrs merged --- *)

let test_user_attrs_merged_with_aria () =
  let config =
    {
      (B.default Primary) with
      disabled = true;
      attrs = [ ("data-testid", "my-btn") ];
    }
  in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  check_attr "data-testid" "data-testid" (Some "my-btn") btn;
  check_attr "aria-disabled" "aria-disabled" (Some "true") btn

(* --- Custom interaction override --- *)
(* Note: the test renderer does not capture Style.t on Element nodes,
   so we verify the override mechanism via interaction (which it does capture).
   The style override path in Button.view uses the same Option.match pattern. *)

let test_custom_interaction_overrides_variant_default () =
  let custom_interaction =
    {
      Nopal_style.Interaction.default with
      hover =
        Some
          (S.default
          |> S.with_paint (fun p ->
              { p with background = Some (S.hex "#ff0000") }));
    }
  in
  let config =
    { (B.default Primary) with interaction = Some custom_interaction }
  in
  let r = render (B.view config (E.text "ok")) in
  let btn = find_button (tree r) in
  Alcotest.(check (option bool))
    "custom interaction preserved" (Some true)
    (Option.map
       (Nopal_style.Interaction.equal custom_interaction)
       (interaction btn))

(* --- Default config --- *)

let test_default_config_not_disabled_or_loading () =
  let config = B.default Primary in
  Alcotest.(check bool) "not disabled" false config.disabled;
  Alcotest.(check bool) "not loading" false config.loading

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_button"
    [
      ( "variant attrs",
        [
          Alcotest.test_case "primary" `Quick test_primary_default_attrs;
          Alcotest.test_case "secondary" `Quick test_secondary_default_attrs;
          Alcotest.test_case "destructive" `Quick test_destructive_default_attrs;
          Alcotest.test_case "ghost" `Quick test_ghost_default_attrs;
          Alcotest.test_case "icon" `Quick test_icon_default_attrs;
        ] );
      ( "disabled",
        [
          Alcotest.test_case "suppresses click" `Quick
            test_disabled_suppresses_click;
          Alcotest.test_case "sets aria" `Quick test_disabled_sets_aria;
        ] );
      ( "loading",
        [
          Alcotest.test_case "suppresses click" `Quick
            test_loading_suppresses_click;
          Alcotest.test_case "sets aria" `Quick test_loading_sets_aria;
        ] );
      ( "combined",
        [
          Alcotest.test_case "disabled+loading aria" `Quick
            test_disabled_and_loading_both_aria;
        ] );
      ( "events",
        [
          Alcotest.test_case "click dispatches" `Quick
            test_click_dispatches_message;
        ] );
      ( "rendering",
        [
          Alcotest.test_case "child text" `Quick test_child_text_preserved;
          Alcotest.test_case "user attrs merged" `Quick
            test_user_attrs_merged_with_aria;
          Alcotest.test_case "custom interaction override" `Quick
            test_custom_interaction_overrides_variant_default;
        ] );
      ( "defaults",
        [
          Alcotest.test_case "not disabled or loading" `Quick
            test_default_config_not_disabled_or_loading;
        ] );
    ]
