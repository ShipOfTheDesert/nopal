open Nopal_test.Test_renderer
module TI = Nopal_ui.TextInput
module E = Nopal_element.Element

type msg =
  | Got of string
  | Blurred
  | Submitted
  | Label_clicked
  | Focused
  | Consumed

let msg_testable =
  Alcotest.testable
    (fun fmt -> function
      | Got s -> Format.fprintf fmt "Got %s" s
      | Blurred -> Format.fprintf fmt "Blurred"
      | Submitted -> Format.fprintf fmt "Submitted"
      | Label_clicked -> Format.fprintf fmt "Label_clicked"
      | Focused -> Format.fprintf fmt "Focused"
      | Consumed -> Format.fprintf fmt "Consumed")
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

let email_with_error error = { (TI.make ~label:"Email" ~value:"") with error }
let input_of config = find_input (tree (render (TI.view config)))

let test_aria_invalid_follows_error () =
  check_attr "an error marks the input invalid" "aria-invalid" (Some "true")
    (input_of (email_with_error (Some "bad")));
  check_attr "no error derives nothing" "aria-invalid" None
    (input_of (email_with_error None))

let test_aria_invalid_absent_uncovers_caller () =
  let config =
    { (email_with_error None) with attrs = [ ("aria-invalid", "true") ] }
  in
  check_attr "the caller's pair stands" "aria-invalid" (Some "true")
    (input_of config)

let test_aria_invalid_caller_replaces () =
  let config =
    {
      (email_with_error (Some "bad")) with
      attrs = [ ("aria-invalid", "false") ];
    }
  in
  check_attr "the caller's later pair replaces the derived one" "aria-invalid"
    (Some "false") (input_of config)

let test_describedby_survives () =
  let config = email_with_error (Some "bad") in
  let inp = input_of config in
  check_attr "aria-invalid is derived" "aria-invalid" (Some "true") inp;
  check_attr "aria-describedby still names the error slot" "aria-describedby"
    (Some (TI.error_id config))
    inp

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

(* --- Label element, identifier and association --- *)

let style_testable = Test_util.style_testable
let text_style_testable = Test_util.text_style_testable
let bold_label_style = Test_util.bold_label_style

let wide_wrapper_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_layout (fun l ->
      { l with Nopal_style.Style.gap = Some 24.0 })

let red_error_style =
  Nopal_style.Style.default
  |> Nopal_style.Style.with_text (fun t ->
      { t with Nopal_style.Text.color = Some (Nopal_style.Style.hex "#b00020") })

let find_or_fail = Test_util.find_or_fail

let test_label_box_carries_the_generated_id () =
  let config = TI.make ~label:"Email" ~value:"" in
  let r = render (TI.view config) in
  let label_node =
    find_or_fail "expected a label element carrying id=email-label"
      (By_attr ("id", "email-label"))
      (tree r)
  in
  Alcotest.(check string) "label text" "Email" (text_content label_node);
  match label_node with
  | Element { tag = "box"; children = [ Text _ ]; _ } -> ()
  | Element { tag; _ } ->
      Alcotest.failf
        "the generated id sits on a %s wrapping the whole field, not on the \
         label element"
        tag
  | Empty
  | Text _ ->
      Alcotest.fail "expected the generated id on an element"

let test_input_is_named_by_labelledby_and_not_by_label () =
  let config = TI.make ~label:"Email" ~value:"" in
  let r = render (TI.view config) in
  let inp = find_input (tree r) in
  match attr "aria-labelledby" inp with
  | None -> Alcotest.fail "expected aria-labelledby on the input"
  | Some target ->
      let named =
        find_or_fail "aria-labelledby names no element in the tree"
          (By_attr ("id", target))
          (tree r)
      in
      Alcotest.(check string)
        "the named element is the visible label" "Email" (text_content named);
      check_attr "aria-label no longer names the control" "aria-label" None inp

let test_explicit_id_moves_both_halves_of_the_association () =
  let config =
    { (TI.make ~label:"Email" ~value:"") with id = Some "billing-email" }
  in
  let r = render (TI.view config) in
  let inp = find_input (tree r) in
  check_attr "input id" "id" (Some "billing-email") inp;
  check_attr "labelledby" "aria-labelledby" (Some "billing-email-label") inp;
  let label_node =
    find_or_fail "expected the label id to move with the explicit id"
      (By_attr ("id", "billing-email-label"))
      (tree r)
  in
  Alcotest.(check string) "label text" "Email" (text_content label_node);
  Alcotest.(check bool)
    "the slug-derived label id is replaced, not joined" false
    (Option.is_some (find (By_attr ("id", "email-label")) (tree r)))

let test_label_click_dispatches_the_configured_message () =
  let base = TI.make ~label:"Email" ~value:"" in
  let without = render (TI.view base) in
  Alcotest.(check bool)
    "no pointer handler on the label without the setter" true
    (Result.is_error
       (box_pointer_down (By_attr ("id", "email-label")) ~x:0.0 ~y:0.0 without));
  let r = render (TI.view (TI.with_on_label_click Label_clicked base)) in
  let result =
    box_pointer_down (By_attr ("id", "email-label")) ~x:3.0 ~y:4.0 r
  in
  Alcotest.(check (result unit Test_util.error_testable))
    "pointer down ok" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "label click dispatched" [ Label_clicked ] (messages r)

let test_control_id_names_the_focus_target () =
  let derived = TI.make ~label:"First Name" ~value:"" in
  Alcotest.(check string)
    "derived from the label" "first-name" (TI.control_id derived);
  Alcotest.(check (option string))
    "the accessor names the rendered input"
    (Some (TI.control_id derived))
    (attr "id" (find_input (tree (render (TI.view derived)))));
  let explicit = TI.with_id "fn" derived in
  Alcotest.(check string) "explicit id wins" "fn" (TI.control_id explicit);
  Alcotest.(check (option string))
    "the accessor follows the explicit id"
    (Some (TI.control_id explicit))
    (attr "id" (find_input (tree (render (TI.view explicit)))))

let test_label_style_reaches_the_label_node () =
  let config =
    TI.with_label_style bold_label_style (TI.make ~label:"Email" ~value:"")
  in
  let r = render (TI.view config) in
  let label_node =
    find_or_fail "expected the label element"
      (By_attr ("id", "email-label"))
      (tree r)
  in
  Alcotest.(check (option style_testable))
    "label style on the label box" (Some bold_label_style) (style label_node);
  let text_node =
    find_or_fail "expected the label's text node" (By_text "Email") label_node
  in
  Alcotest.(check (option text_style_testable))
    "the style's text component reaches the text node"
    (Some bold_label_style.Nopal_style.Style.text) (text_style text_node)

let test_wrapper_style_reaches_the_column () =
  let config =
    TI.with_wrapper_style wide_wrapper_style (TI.make ~label:"Email" ~value:"")
  in
  let r = render (TI.view config) in
  Alcotest.(check (option style_testable))
    "wrapper style on the wrapping column" (Some wide_wrapper_style)
    (style (tree r))

let test_error_style_reaches_the_error_slot () =
  let config =
    TI.with_error_style red_error_style
      { (TI.make ~label:"Email" ~value:"") with error = Some "Required" }
  in
  let r = render (TI.view config) in
  let alert =
    find_or_fail "expected the error slot" (By_attr ("role", "alert")) (tree r)
  in
  Alcotest.(check (option style_testable))
    "error style on the error box" (Some red_error_style) (style alert);
  let text_node =
    find_or_fail "expected the error message text node" (By_text "Required")
      alert
  in
  Alcotest.(check (option text_style_testable))
    "the style's text component reaches the message"
    (Some red_error_style.Nopal_style.Style.text) (text_style text_node)

(* --- Typed input fields --- *)

let password_base () = TI.make ~label:"Password" ~value:""

let typed_fields_config () =
  password_base ()
  |> TI.with_required true
  |> TI.with_autocomplete "current-password"
  |> TI.with_input_type E.Password
  |> TI.with_name "password"

let test_typed_fields_reach_input () =
  let inp = find_input (tree (render (TI.view (typed_fields_config ())))) in
  check_attr "required" "required" (Some "true") inp;
  check_attr "required brings aria-required" "aria-required" (Some "true") inp;
  check_attr "autocomplete" "autocomplete" (Some "current-password") inp;
  check_attr "input type" "type" (Some "password") inp;
  check_attr "name" "name" (Some "password") inp

let test_typed_field_outranks_attrs () =
  let declared = { (password_base ()) with attrs = [ ("type", "text") ] } in
  check_attr "the typed field beats the declared pair" "type" (Some "password")
    (find_input
       (tree (render (TI.view (TI.with_input_type E.Password declared)))));
  check_attr "without the setter the declared pair stands" "type" (Some "text")
    (find_input (tree (render (TI.view declared))))

let test_make_leaves_new_fields_none () =
  let typed = find_input (tree (render (TI.view (typed_fields_config ())))) in
  let bare = find_input (tree (render (TI.view (password_base ())))) in
  List.iter
    (fun key ->
      Alcotest.(check bool)
        (key ^ " is reachable on this fixture")
        true
        (Option.is_some (attr key typed));
      check_attr (key ^ " absent from a make config") key None bare)
    [ "name"; "type"; "autocomplete"; "required"; "aria-required" ];
  let r =
    render
      (TI.view
         { (TI.make ~label:"Code" ~value:"") with on_submit = Some Submitted })
  in
  ignore (focus (By_tag "input") r);
  Alcotest.(check (list msg_testable))
    "make has no on_focus: focus dispatches nothing" [] (messages r);
  ignore (keydown (By_tag "input") "Enter" r);
  Alcotest.(check (list msg_testable))
    "make has no on_keydown: Enter takes only the on_submit path" [ Submitted ]
    (messages r)

let consume_enter key =
  match key with
  | "Enter" -> Some Consumed
  | _ -> None

let test_on_keydown_consumes_enter () =
  let config =
    TI.with_on_keydown consume_enter
      { (TI.make ~label:"Code" ~value:"") with on_submit = Some Submitted }
  in
  let r = render (TI.view config) in
  Alcotest.(check (result unit Test_util.error_testable))
    "enter ok" (Ok ())
    (keydown (By_tag "input") "Enter" r);
  Alcotest.(check (list msg_testable))
    "a consumed Enter does not reach on_submit" [ Consumed ] (messages r);
  Alcotest.(check (result unit Test_util.error_testable))
    "other key ok" (Ok ())
    (keydown (By_tag "input") "a" r);
  Alcotest.(check (list msg_testable))
    "a declined key adds nothing" [ Consumed ] (messages r);
  let declining =
    TI.with_on_keydown
      (fun _ -> None)
      { (TI.make ~label:"Code" ~value:"") with on_submit = Some Submitted }
  in
  let d = render (TI.view declining) in
  Alcotest.(check (result unit Test_util.error_testable))
    "declined enter ok" (Ok ())
    (keydown (By_tag "input") "Enter" d);
  Alcotest.(check (list msg_testable))
    "a declined Enter reaches on_submit" [ Submitted ] (messages d)

let test_on_focus_dispatches () =
  let config = TI.with_on_focus Focused (TI.make ~label:"Email" ~value:"") in
  let r = render (TI.view config) in
  Alcotest.(check (result unit Test_util.error_testable))
    "focus ok" (Ok ()) (focus (By_tag "input") r);
  Alcotest.(check (list msg_testable)) "got message" [ Focused ] (messages r)

let test_disabled_suppresses_new_handlers () =
  let config ~disabled =
    { (TI.make ~label:"Code" ~value:"") with disabled }
    |> TI.with_on_focus Focused
    |> TI.with_on_keydown consume_enter
  in
  let off = render (TI.view (config ~disabled:true)) in
  Alcotest.(check bool)
    "no focus handler while disabled" true
    (Result.is_error (focus (By_tag "input") off));
  Alcotest.(check bool)
    "no keydown handler while disabled" true
    (Result.is_error (keydown (By_tag "input") "Enter" off));
  Alcotest.(check (list msg_testable)) "nothing dispatched" [] (messages off);
  let on = render (TI.view (config ~disabled:false)) in
  Alcotest.(check (result unit Test_util.error_testable))
    "focus ok when enabled" (Ok ())
    (focus (By_tag "input") on);
  Alcotest.(check (result unit Test_util.error_testable))
    "keydown ok when enabled" (Ok ())
    (keydown (By_tag "input") "Enter" on);
  Alcotest.(check (list msg_testable))
    "both dispatch when enabled" [ Focused; Consumed ] (messages on)

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
          Alcotest.test_case "aria-invalid follows error" `Quick
            test_aria_invalid_follows_error;
          Alcotest.test_case "aria-invalid absent uncovers caller" `Quick
            test_aria_invalid_absent_uncovers_caller;
          Alcotest.test_case "aria-invalid caller replaces" `Quick
            test_aria_invalid_caller_replaces;
          Alcotest.test_case "describedby survives" `Quick
            test_describedby_survives;
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
      ( "label and association",
        [
          Alcotest.test_case "label box carries the generated id" `Quick
            test_label_box_carries_the_generated_id;
          Alcotest.test_case "input is named by labelledby and not by label"
            `Quick test_input_is_named_by_labelledby_and_not_by_label;
          Alcotest.test_case "explicit id moves both halves of the association"
            `Quick test_explicit_id_moves_both_halves_of_the_association;
          Alcotest.test_case "label click dispatches the configured message"
            `Quick test_label_click_dispatches_the_configured_message;
          Alcotest.test_case "control_id names the focus target" `Quick
            test_control_id_names_the_focus_target;
        ] );
      ( "style overrides",
        [
          Alcotest.test_case "label style reaches the label node" `Quick
            test_label_style_reaches_the_label_node;
          Alcotest.test_case "wrapper style reaches the column" `Quick
            test_wrapper_style_reaches_the_column;
          Alcotest.test_case "error style reaches the error slot" `Quick
            test_error_style_reaches_the_error_slot;
        ] );
      ( "typed input fields",
        [
          Alcotest.test_case "typed fields reach input" `Quick
            test_typed_fields_reach_input;
          Alcotest.test_case "typed field outranks attrs" `Quick
            test_typed_field_outranks_attrs;
          Alcotest.test_case "make leaves new fields none" `Quick
            test_make_leaves_new_fields_none;
          Alcotest.test_case "on_keydown consumes enter" `Quick
            test_on_keydown_consumes_enter;
          Alcotest.test_case "on_focus dispatches" `Quick
            test_on_focus_dispatches;
          Alcotest.test_case "disabled suppresses new handlers" `Quick
            test_disabled_suppresses_new_handlers;
        ] );
    ]
