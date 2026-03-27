open Nopal_test.Test_renderer
module TI = Nopal_ui.TextInput
module E = Nopal_element.Element

type msg = Got of string | Blurred | Submitted

let msg_testable =
  Alcotest.testable
    (fun fmt -> function
      | Got s -> Format.fprintf fmt "Got %s" s
      | Blurred -> Format.fprintf fmt "Blurred"
      | Submitted -> Format.fprintf fmt "Submitted")
    ( = )

let check_attr msg key expected node =
  Alcotest.(check (option string)) msg expected (attr key node)

let find_input node =
  match find (By_tag "input") node with
  | Some n -> n
  | None -> Alcotest.fail "expected an input element"

(* --- Structure --- *)

let test_label_text_rendered () =
  let config = TI.make ~label:"Email" ~value:"" in
  let r = render (TI.view config) in
  let label_node = find (By_text "Email") (tree r) in
  Alcotest.(check bool) "label found" true (Option.is_some label_node)

let test_input_value_forwarded () =
  let config =
    {
      (TI.make ~label:"Email" ~value:"foo@bar.com") with
      on_change = Some (fun s -> Got s);
    }
  in
  let r = render (TI.view config) in
  let result = input (By_tag "input") "hello" r in
  Alcotest.(check (result unit Test_util.error_testable))
    "input ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "got message" [ Got "hello" ] (messages r)

let test_placeholder_forwarded () =
  let config =
    {
      (TI.make ~label:"Email" ~value:"") with
      placeholder = Some "you@example.com";
    }
  in
  let r = render (TI.view config) in
  let inp = find_input (tree r) in
  check_attr "placeholder" "placeholder" (Some "you@example.com") inp

(* --- Error ARIA --- *)

let test_error_renders_role_alert () =
  let config =
    { (TI.make ~label:"Email" ~value:"") with error = Some "Required" }
  in
  let r = render (TI.view config) in
  let alerts = find_all (By_attr ("role", "alert")) (tree r) in
  match alerts with
  | [ node ] ->
      Alcotest.(check string) "alert text" "Required" (text_content node)
  | other ->
      Alcotest.failf "expected exactly one alert element, got %d"
        (List.length other)

let test_error_renders_aria_describedby () =
  let config =
    { (TI.make ~label:"Email" ~value:"") with error = Some "Required" }
  in
  let r = render (TI.view config) in
  let inp = find_input (tree r) in
  check_attr "aria-describedby" "aria-describedby" (Some "email-error") inp

let test_error_id_matches () =
  let config =
    { (TI.make ~label:"Email" ~value:"") with error = Some "Required" }
  in
  let r = render (TI.view config) in
  let inp = find_input (tree r) in
  let error_nodes = find_all (By_attr ("role", "alert")) (tree r) in
  match error_nodes with
  | [ error_node ] ->
      let describedby = attr "aria-describedby" inp in
      let error_elem_id = attr "id" error_node in
      Alcotest.(check (option string)) "ids match" describedby error_elem_id
  | other ->
      Alcotest.failf "expected exactly one alert element, got %d"
        (List.length other)

let test_no_error_omits_alert () =
  let config = TI.make ~label:"Email" ~value:"" in
  let r = render (TI.view config) in
  let inp = find_input (tree r) in
  let alerts = find_all (By_attr ("role", "alert")) (tree r) in
  Alcotest.(check int) "no alerts" 0 (List.length alerts);
  Alcotest.(check (option string))
    "no aria-describedby" None
    (attr "aria-describedby" inp)

(* --- Error ID --- *)

let test_id_from_label_with_spaces () =
  let config = TI.make ~label:"First Name" ~value:"" in
  Alcotest.(check string) "slugified" "first-name-error" (TI.error_id config)

let test_custom_id_override () =
  let config =
    { (TI.make ~label:"Email" ~value:"") with id = Some "email-field" }
  in
  Alcotest.(check string) "custom id" "email-field-error" (TI.error_id config)

(* --- Disabled --- *)

let test_disabled_attr_on_input () =
  let config = { (TI.make ~label:"Email" ~value:"") with disabled = true } in
  let r = render (TI.view config) in
  let inp = find_input (tree r) in
  check_attr "disabled" "disabled" (Some "") inp

let test_disabled_suppresses_on_change () =
  let config =
    {
      (TI.make ~label:"Email" ~value:"") with
      disabled = true;
      on_change = Some (fun s -> Got s);
    }
  in
  let r = render (TI.view config) in
  let result = input (By_tag "input") "hello" r in
  (* Disabled input should have no handler, so we expect No_handler error *)
  Alcotest.(check bool) "no message dispatched" true (Result.is_error result);
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

let test_disabled_suppresses_on_blur () =
  let config =
    {
      (TI.make ~label:"Email" ~value:"") with
      disabled = true;
      on_blur = Some Blurred;
    }
  in
  let r = render (TI.view config) in
  let result = blur (By_tag "input") r in
  Alcotest.(check bool) "no blur dispatched" true (Result.is_error result);
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

let test_disabled_suppresses_on_submit () =
  let config =
    {
      (TI.make ~label:"Email" ~value:"") with
      disabled = true;
      on_submit = Some Submitted;
    }
  in
  let r = render (TI.view config) in
  let result = submit (By_tag "input") r in
  Alcotest.(check bool) "no submit dispatched" true (Result.is_error result);
  Alcotest.(check (list msg_testable)) "no messages" [] (messages r)

(* --- Events --- *)

let test_on_change_dispatches () =
  let config =
    {
      (TI.make ~label:"Email" ~value:"") with
      on_change = Some (fun s -> Got s);
    }
  in
  let r = render (TI.view config) in
  let result = input (By_tag "input") "hello" r in
  Alcotest.(check (result unit Test_util.error_testable))
    "input ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "got message" [ Got "hello" ] (messages r)

let test_on_blur_dispatches () =
  let config =
    { (TI.make ~label:"Email" ~value:"") with on_blur = Some Blurred }
  in
  let r = render (TI.view config) in
  let result = blur (By_tag "input") r in
  Alcotest.(check (result unit Test_util.error_testable))
    "blur ok" (Ok ()) result;
  Alcotest.(check (list msg_testable)) "got message" [ Blurred ] (messages r)

let test_on_submit_dispatches () =
  let config =
    { (TI.make ~label:"Email" ~value:"") with on_submit = Some Submitted }
  in
  let r = render (TI.view config) in
  let result = submit (By_tag "input") r in
  Alcotest.(check (result unit Test_util.error_testable))
    "submit ok" (Ok ()) result;
  Alcotest.(check (list msg_testable)) "got message" [ Submitted ] (messages r)

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_ui_text_input"
    [
      ( "structure",
        [
          Alcotest.test_case "label text rendered" `Quick
            test_label_text_rendered;
          Alcotest.test_case "input value forwarded" `Quick
            test_input_value_forwarded;
          Alcotest.test_case "placeholder forwarded" `Quick
            test_placeholder_forwarded;
        ] );
      ( "error aria",
        [
          Alcotest.test_case "error renders role alert" `Quick
            test_error_renders_role_alert;
          Alcotest.test_case "error renders aria-describedby on input" `Quick
            test_error_renders_aria_describedby;
          Alcotest.test_case "error id matches between input and error element"
            `Quick test_error_id_matches;
          Alcotest.test_case "no error omits alert and aria-describedby" `Quick
            test_no_error_omits_alert;
        ] );
      ( "error id",
        [
          Alcotest.test_case "id from label with spaces" `Quick
            test_id_from_label_with_spaces;
          Alcotest.test_case "custom id override" `Quick test_custom_id_override;
        ] );
      ( "disabled",
        [
          Alcotest.test_case "disabled attr on input" `Quick
            test_disabled_attr_on_input;
          Alcotest.test_case "disabled suppresses on_change" `Quick
            test_disabled_suppresses_on_change;
          Alcotest.test_case "disabled suppresses on_blur" `Quick
            test_disabled_suppresses_on_blur;
          Alcotest.test_case "disabled suppresses on_submit" `Quick
            test_disabled_suppresses_on_submit;
        ] );
      ( "events",
        [
          Alcotest.test_case "on_change dispatches message" `Quick
            test_on_change_dispatches;
          Alcotest.test_case "on_blur dispatches message" `Quick
            test_on_blur_dispatches;
          Alcotest.test_case "on_submit dispatches message" `Quick
            test_on_submit_dispatches;
        ] );
    ]
