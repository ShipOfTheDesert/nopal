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
let email = By_attr ("data-testid", "auth-email")
let password = By_attr ("data-testid", "auth-password")
let code = By_attr ("data-testid", "auth-code")
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
    [ "type"; "autocomplete"; "required"; "aria-required" ]

let attr_list = Alcotest.(list (pair string (option string)))

let test_fields_carry_typed_type_autocomplete_and_required () =
  let rendered = rendered_for (after []) in
  Alcotest.check attr_list "the email field is a required email field"
    [
      ("type", Some "email");
      ("autocomplete", Some "email");
      ("required", Some "true");
      ("aria-required", Some "true");
    ]
    (field_attrs "the email field" email rendered);
  Alcotest.check attr_list
    "the password field is a required current-password field"
    [
      ("type", Some "password");
      ("autocomplete", Some "current-password");
      ("required", Some "true");
      ("aria-required", Some "true");
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
    ]
    (field_attrs "the one-time code field" code rendered)

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

let test_a_consuming_on_keydown_field_suppresses_the_form_submit () =
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
          Alcotest.test_case
            "email_and_password_fields_carry_typed_type_autocomplete_and_required"
            `Quick test_fields_carry_typed_type_autocomplete_and_required;
          Alcotest.test_case "novalidate_toggle_flips_the_form_attribute" `Quick
            test_novalidate_toggle_flips_the_form_attribute;
          Alcotest.test_case
            "a_consuming_on_keydown_field_suppresses_the_form_submit" `Quick
            test_a_consuming_on_keydown_field_suppresses_the_form_submit;
        ] );
    ]
