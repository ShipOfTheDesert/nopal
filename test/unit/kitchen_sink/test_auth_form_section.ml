(* The auth-shaped form kitchen-sink section, read structurally.

   What this file can see is the submit contract as the structural renderer
   answers it: which handler an Enter in each field reaches, and that the form
   carries the attributes a browser and assistive technology read. What it
   cannot see is the platform's own share in a submission — a browser submits a
   form on Enter only when it has a submit button, blocks a submission a
   required field fails, and navigates unless the default is cancelled. Those
   are browser facts, pinned by the browser spec beside this section, and
   nothing here may be read as evidence for them.

   Every message is taken from a rendered handler rather than named here, and
   compared through the section's own telemetry serializer, so the names this
   file pins are the names the browser spec waits on. A field that stopped
   reaching the form fails at the simulator instead of leaving a case driving
   the section by a message its view can no longer produce. *)

open Nopal_test.Test_renderer
module Sub = Kitchen_sink_app__Sub_auth_form

let vp = Nopal_element.Viewport.desktop
let form = By_attr ("data-testid", "auth-form")
let email = By_attr ("data-field", "auth-email")
let password = By_attr ("data-field", "auth-password")
let code = By_attr ("data-field", "auth-code")
let submit_button = By_attr ("data-testid", "auth-submit")
let novalidate_control = By_attr ("data-testid", "auth-novalidate")
let submit_count = By_attr ("data-testid", "auth-submit-count")
let submitted = "AuthForm:Submitted;"

(* The section driven through the MVU loop rather than by constructing a model,
   so a state the section can no longer reach cannot keep an assertion alive
   here. *)
let after msgs =
  fst (run_app ~init:Sub.init ~update:Sub.update ~view:Sub.view msgs)

let rendered_for model = render (Sub.view vp model)

let fail_on_error label result =
  match result with
  | Ok () -> ()
  | Error (Not_found _) -> Alcotest.fail (label ^ ": no such element")
  | Error (No_handler { tag; event }) ->
      Alcotest.fail
        (Printf.sprintf "%s: the %s element handles no %s" label tag event)

(* The whole ordered dispatch list, never only whether something dispatched,
   so a double dispatch and a silent drop both redden. *)
let dispatched rendered = List.map Sub.serialize_msg (messages rendered)

let node_in label selector parent =
  match find selector parent with
  | Some node -> node
  | None -> Alcotest.fail (label ^ ": the section renders no such element")

let form_node rendered = node_in "the form" form (tree rendered)

(* Each field is looked for inside the form rather than across the whole
   section. A field outside the form reaches no form on Enter at all, so the
   suppression case below would pass for the wrong reason with the one-time
   code field moved out of it. *)
let field_in_form label selector rendered =
  node_in label selector (form_node rendered)

let press label selector key rendered =
  fail_on_error label (keydown selector key rendered)

let test_enter_in_either_field_submits_once () =
  let rendered = rendered_for (after []) in
  press "Enter in the email field" email "Enter" rendered;
  let from_email = messages rendered in
  Alcotest.(check (list string))
    "Enter in the email field submits the form once" [ submitted ]
    (dispatched rendered);
  clear_messages rendered;
  press "Enter in the password field" password "Enter" rendered;
  let from_password = messages rendered in
  Alcotest.(check (list string))
    "Enter in the password field submits the form once" [ submitted ]
    (dispatched rendered);
  let model = after (from_email @ from_password) in
  Alcotest.(check string)
    "two submissions reach the model as two, and nothing else moves"
    "auth_email=\"\"; auth_password_length=0; auth_code_confirms=0; \
     auth_submits=2; auth_novalidate=false;"
    (Sub.serialize_model model);
  Alcotest.(check string)
    "and the visible counter says so" "Submitted 2 times"
    (text_content
       (node_in "the submit counter" submit_count (tree (rendered_for model))))

let test_submit_button_is_inside_the_form () =
  let rendered = rendered_for (after []) in
  let button = field_in_form "the submit button" submit_button rendered in
  Alcotest.(check (option string))
    "the button is a submit button, which is what makes a press submit its form"
    (Some "submit") (attr "type" button);
  fail_on_error "a press on the submit button" (click submit_button rendered);
  (* A message of the button's own would come first, so a list of one also
     pins that the press does not dispatch twice. *)
  Alcotest.(check (list string))
    "a press submits the form, which answers with the section's submit, once"
    [ submitted ] (dispatched rendered)

let test_the_form_carries_an_accessible_name () =
  let rendered = rendered_for (after []) in
  let node = form_node rendered in
  (match node with
  | Element { tag; _ } ->
      Alcotest.(check string) "the section's form is a form" "form" tag
  | Empty
  | Text _ ->
      Alcotest.fail "the form is not an element");
  Alcotest.(check (option string))
    "a form becomes a landmark only once it carries an accessible name"
    (Some "Demo sign-in") (attr "aria-label" node)

let field_attrs label selector rendered =
  let node = field_in_form label selector rendered in
  List.map
    (fun key -> (key, attr key node))
    [ "type"; "autocomplete"; "required"; "aria-required"; "name" ]

let attr_list = Alcotest.(list (pair string (option string)))

(* A field named through an [aria-label] pair would still read as labelled to a
   browser, so the name is followed to the element it points at, and the pair
   the section used to write is asserted gone on the same field. *)
let check_labelled_by label selector expected rendered =
  let field = field_in_form label selector rendered in
  Alcotest.(check (option string))
    (label ^ " is not named by an attribute pair")
    None (attr "aria-label" field);
  match attr "aria-labelledby" field with
  | None -> Alcotest.fail (label ^ " carries no aria-labelledby")
  | Some id ->
      Alcotest.(check string)
        (label ^ " is named by the visible label it points at")
        expected
        (text_content
           (node_in (label ^ "'s label")
              (By_attr ("id", id))
              (form_node rendered)))

let test_fields_are_text_inputs_with_typed_fields () =
  let rendered = rendered_for (after []) in
  Alcotest.check attr_list "the email field is a required email field"
    [
      ("type", Some "email");
      ("autocomplete", Some "email");
      ("required", Some "true");
      ("aria-required", Some "true");
      ("name", Some "email");
    ]
    (field_attrs "the email field" email rendered);
  Alcotest.check attr_list
    "the password field is a required current-password field"
    [
      ("type", Some "password");
      ("autocomplete", Some "current-password");
      ("required", Some "true");
      ("aria-required", Some "true");
      ("name", Some "password");
    ]
    (field_attrs "the password field" password rendered);
  (* The same derivations answer differently for a field that does not ask for
     them, so the two above are the fields' own and not the renderer's. *)
  Alcotest.check attr_list "the one-time code field is typed but not required"
    [
      ("type", Some "text");
      ("autocomplete", Some "one-time-code");
      ("required", None);
      ("aria-required", None);
      ("name", Some "code");
    ]
    (field_attrs "the one-time code field" code rendered);
  check_labelled_by "the email field" email "Email" rendered;
  check_labelled_by "the password field" password "Password" rendered;
  check_labelled_by "the one-time code field" code "One-time code" rendered

(* Every attribute key a [TextInput] input emits from its typed settings. A key
   outside this set can only have come from a raw [~attrs] pair on the field's
   config, which the section promises none of. *)
let component_keys =
  [
    "id";
    "aria-labelledby";
    "data-field";
    "name";
    "type";
    "autocomplete";
    "required";
    "aria-required";
    "aria-describedby";
    "aria-invalid";
    "value";
    "placeholder";
  ]

let test_no_field_carries_raw_attrs () =
  let rendered = rendered_for (after []) in
  List.iter
    (fun (label, selector) ->
      match field_in_form label selector rendered with
      | Element { attrs; _ } ->
          let strays =
            List.filter (fun (k, _) -> not (List.mem k component_keys)) attrs
          in
          Alcotest.(check (list string))
            (label ^ " carries only the component's own attributes")
            [] (List.map fst strays)
      | Empty
      | Text _ ->
          Alcotest.fail (label ^ " is not an element"))
    [
      ("the email field", email);
      ("the password field", password);
      ("the one-time code field", code);
    ]

(* Click-to-focus: the label press dispatches the section's message and update
   answers it with a focus command on that field's own control. *)
let test_label_click_focuses_its_field () =
  List.iter
    (fun (label, control_id) ->
      let model = after [] in
      let rendered = rendered_for model in
      (match
         box_pointer_down
           (By_attr ("id", control_id ^ "-label"))
           ~x:4.0 ~y:4.0 rendered
       with
      | Ok () -> ()
      | Error (Not_found _) -> Alcotest.fail (label ^ ": no label element")
      | Error (No_handler { tag; event }) ->
          Alcotest.failf "%s: the label (%s) has no %s handler" label tag event);
      match messages rendered with
      | [ msg ] ->
          let _model, cmd = Sub.update model msg in
          Alcotest.(check (option string))
            (label ^ ": update answers the label click with Cmd.focus")
            (Some control_id)
            (Nopal_mvu.Cmd.extract_focus cmd)
      | msgs ->
          Alcotest.failf "%s: expected one message, got %d" label
            (List.length msgs))
    [
      ("email", "auth-email");
      ("password", "auth-password");
      ("code", "auth-code");
    ]

let toggle_novalidate label model =
  let rendered = rendered_for model in
  fail_on_error label (toggle novalidate_control rendered);
  messages rendered

let novalidate_of model = attr "novalidate" (form_node (rendered_for model))

let test_novalidate_toggle_flips_the_form_attribute () =
  let initial = after [] in
  Alcotest.(check (option string))
    "the form validates by default" None (novalidate_of initial);
  let on = toggle_novalidate "switching validation off" initial in
  let off_model = after on in
  Alcotest.(check (option string))
    "the toggle makes the form skip validation" (Some "true")
    (novalidate_of off_model);
  let back = toggle_novalidate "switching validation back on" off_model in
  let back_model = after (on @ back) in
  Alcotest.(check string)
    "the model reports validation off"
    "auth_email=\"\"; auth_password_length=0; auth_code_confirms=0; \
     auth_submits=0; auth_novalidate=true;"
    (Sub.serialize_model off_model);
  Alcotest.(check (option string))
    "and the toggle takes it away again" None (novalidate_of back_model)

let test_code_field_consumes_enter () =
  let rendered = rendered_for (after []) in
  let (_ : node) = field_in_form "the one-time code field" code rendered in
  press "Enter in the one-time code field" code "Enter" rendered;
  let consumed = messages rendered in
  Alcotest.(check (list string))
    "the field's own handler consumes the Enter, and the form is not submitted"
    [ "AuthForm:Code_confirmed;" ]
    (dispatched rendered);
  clear_messages rendered;
  press "a digit in the one-time code field" code "7" rendered;
  Alcotest.(check (list string))
    "a key the field's handler declines reaches nothing" []
    (dispatched rendered);
  (* The same render, one field over: the form is reachable from here, so the
     Enter above was stopped by the field's handler and not by a form that
     could not have been submitted anyway. *)
  press "Enter in the email field" email "Enter" rendered;
  Alcotest.(check (list string))
    "Enter in a field that declines nothing still submits the form"
    [ submitted ] (dispatched rendered);
  Alcotest.(check string)
    "a consumed Enter is counted as a confirmation and not as a submission"
    "auth_email=\"\"; auth_password_length=0; auth_code_confirms=1; \
     auth_submits=0; auth_novalidate=false;"
    (Sub.serialize_model (after consumed))

let () =
  Alcotest.run "kitchen_sink_auth_form_section"
    [
      ( "auth_form_section",
        [
          Alcotest.test_case "enter_in_either_field_submits_once" `Quick
            test_enter_in_either_field_submits_once;
          Alcotest.test_case "submit_button_is_inside_the_form" `Quick
            test_submit_button_is_inside_the_form;
          Alcotest.test_case "the_form_carries_an_accessible_name" `Quick
            test_the_form_carries_an_accessible_name;
          Alcotest.test_case "fields_are_text_inputs_with_typed_fields" `Quick
            test_fields_are_text_inputs_with_typed_fields;
          Alcotest.test_case "no_field_carries_raw_attrs" `Quick
            test_no_field_carries_raw_attrs;
          Alcotest.test_case "label_click_focuses_its_field" `Quick
            test_label_click_focuses_its_field;
          Alcotest.test_case "novalidate_toggle_flips_the_form_attribute" `Quick
            test_novalidate_toggle_flips_the_form_attribute;
          Alcotest.test_case "code_field_consumes_enter" `Quick
            test_code_field_consumes_enter;
        ] );
    ]
