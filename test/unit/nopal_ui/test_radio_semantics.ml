open Nopal_test.Test_renderer

(* The core is deliberately not re-exported from [Nopal_ui], so these tests
   reach the library's internal module path directly. *)
module RS = Nopal_ui__Radio_semantics
module E = Nopal_element.Element

type msg = Selected of string

let msg_testable =
  Alcotest.testable
    (fun fmt (Selected v) -> Format.fprintf fmt "Selected %s" v)
    ( = )

let derived = RS.make ~id:None ~label:"Pick one" ~name:None
let explicit = RS.make ~id:(Some "fruit") ~label:"Pick one" ~name:None

let test_group_name_defaults_to_slug_and_honours_name () =
  Alcotest.(check string)
    "name is slugified label" "pick-one" (RS.group_name derived);
  Alcotest.(check string)
    "name is custom" "custom"
    (RS.group_name (RS.make ~id:None ~label:"Pick one" ~name:(Some "custom")));
  Alcotest.(check string)
    "an explicit id leaves the name on the label" "pick-one"
    (RS.group_name explicit)

let test_ids_derive_from_control_id () =
  List.iter
    (fun (mode, group, control) ->
      Alcotest.(check string)
        (mode ^ ": control id") control (RS.control_id group);
      Alcotest.(check string)
        (mode ^ ": group label id")
        (control ^ "-label") (RS.group_label_id group);
      Alcotest.(check string)
        (mode ^ ": option id") (control ^ "-b")
        (RS.option_id group ~value:"b");
      Alcotest.(check string)
        (mode ^ ": option label id")
        (control ^ "-b-label")
        (RS.option_label_id group ~value:"b"))
    [ ("derived", derived, "pick-one"); ("explicit", explicit, "fruit") ]

let test_group_attrs_role_naming_id () =
  List.iter
    (fun (mode, naming, expected_naming) ->
      Alcotest.(check (list (pair string string)))
        (mode ^ ": role, name, id, then the caller's attrs")
        [
          ("role", "radiogroup");
          expected_naming;
          ("id", "fruit");
          ("data-testid", "fruit-group");
        ]
        (RS.group_attrs explicit ~naming
           ~attrs:[ ("data-testid", "fruit-group") ]))
    [
      ( "visible label",
        RS.Named_by_visible_label,
        ("aria-labelledby", "fruit-label") );
      ("no visible label", RS.Named_by_aria_label, ("aria-label", "Pick one"));
    ]

let on_select_of (el : msg E.t) =
  match el with
  | E.Radio { on_select; _ } -> on_select
  | E.Empty
  | E.Text _
  | E.Box _
  | E.Row _
  | E.Column _
  | E.Button _
  | E.Link _
  | E.Heading _
  | E.Input _
  | E.Image _
  | E.Checkbox _
  | E.Select _
  | E.File_input _
  | E.Scroll _
  | E.Keyed _
  | E.Draw _
  | E.Form _
  | E.Label _
  | E.Virtual_list _ ->
      Alcotest.fail "expected a radio"

let radio ~value ~selected ~disabled ~presentation =
  RS.option_radio derived ~value ~selected ~disabled ~presentation
    ~on_select:(Some (fun v -> Selected v))

let test_option_radio_checked_only_when_selected () =
  List.iter
    (fun (value, checked) ->
      let r =
        render
          (radio ~value ~selected:"b" ~disabled:false
             ~presentation:Nopal_style.Presentation.Visually_hidden)
      in
      let node = tree r in
      Alcotest.(check (option string))
        (value ^ ": checked follows selected = value")
        (Some checked) (attr "checked" node);
      Alcotest.(check (option string))
        (value ^ ": id")
        (Some ("pick-one-" ^ value))
        (attr "id" node);
      Alcotest.(check (option string))
        (value ^ ": named by its label")
        (Some ("pick-one-" ^ value ^ "-label"))
        (attr "aria-labelledby" node);
      Alcotest.(check (option string))
        (value ^ ": E2E anchor on the group name")
        (Some "pick-one") (attr "data-field" node);
      Alcotest.(check (option string))
        (value ^ ": grouped by name")
        (Some "pick-one") (attr "name" node);
      Alcotest.(
        check (result Test_util.presentation_testable Test_util.error_testable))
        (value ^ ": presentation passes through")
        (Ok Nopal_style.Presentation.Visually_hidden)
        (radio_presentation (By_tag "radio") r);
      Alcotest.(check (result unit Test_util.error_testable))
        (value ^ ": click ok") (Ok ()) (click (By_tag "radio") r);
      Alcotest.(check (list msg_testable))
        (value ^ ": selecting dispatches its value")
        [ Selected value ] (messages r))
    [ ("a", "false"); ("b", "true") ];
  let visible =
    render
      (radio ~value:"a" ~selected:"b" ~disabled:false
         ~presentation:Nopal_style.Presentation.Visible)
  in
  Alcotest.(
    check (result Test_util.presentation_testable Test_util.error_testable))
    "a visible presentation passes through"
    (Ok Nopal_style.Presentation.Visible)
    (radio_presentation (By_tag "radio") visible);
  let radio_at ~disabled =
    radio ~value:"a" ~selected:"b" ~disabled
      ~presentation:Nopal_style.Presentation.Visible
  in
  Alcotest.(check (option string))
    "disabled is true" (Some "true")
    (attr "disabled" (tree (render (radio_at ~disabled:true))));
  (* Read off the element rather than by a click: the test renderer refuses a
     click on a disabled radio whatever handler it carries. *)
  Alcotest.(check (option msg_testable))
    "an enabled radio carries its selection" (Some (Selected "a"))
    (on_select_of (radio_at ~disabled:false));
  Alcotest.(check (option msg_testable))
    "a disabled radio carries no selection handler" None
    (on_select_of (radio_at ~disabled:true))

let test_option_label_names_its_control () =
  let node =
    tree (render (RS.option_label derived ~value:"b" [ E.text "Beta" ]))
  in
  Alcotest.(check string)
    "a native label" "label"
    (Test_util.tag_of "label" node);
  Alcotest.(check (list (pair string string)))
    "the label id, then the control it names"
    [ ("id", "pick-one-b-label"); ("for", "pick-one-b") ]
    (match node with
    | Element { attrs; _ } -> attrs
    | Empty
    | Text _ ->
        Alcotest.fail "expected the label element");
  Alcotest.(check string)
    "the label wraps its content" "Beta" (text_content node)

let () =
  Alcotest.run "Radio_semantics"
    [
      ( "radio_semantics",
        [
          Alcotest.test_case "group name defaults to slug and honours name"
            `Quick test_group_name_defaults_to_slug_and_honours_name;
          Alcotest.test_case "ids derive from control id" `Quick
            test_ids_derive_from_control_id;
          Alcotest.test_case "group attrs: role, naming, id" `Quick
            test_group_attrs_role_naming_id;
          Alcotest.test_case "option radio checked only when selected" `Quick
            test_option_radio_checked_only_when_selected;
          Alcotest.test_case "option label names its control" `Quick
            test_option_label_names_its_control;
        ] );
    ]
