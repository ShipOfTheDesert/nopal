open Nopal_test.Test_renderer
module E = Nopal_element.Element

type msg = Pressed | Wrapped of msg

let label_carries_control_id_and_children () =
  let r = render (E.label ~control_id:"plan-pro" [ E.text "Pro plan" ]) in
  Test_util.check_node "a label names its control and renders its children"
    (Element
       {
         tag = "label";
         style = Nopal_style.Style.default;
         attrs = [ ("for", "plan-pro") ];
         children = [ Text { content = "Pro plan"; text_style = None } ];
         interaction = Nopal_style.Interaction.default;
       })
    (tree r)

let label_map_keeps_control_id_and_maps_the_control_message () =
  let mapped =
    E.map
      (fun m -> Wrapped m)
      (E.row
         [
           E.radio
             ~attrs:[ ("id", "plan-pro") ]
             ~on_select:Pressed ~name:"plan" ();
           E.label ~control_id:"plan-pro" [ E.text "Choose" ];
         ])
  in
  let r = render mapped in
  Alcotest.(check (option string))
    "the mapped label still names its control" (Some "plan-pro")
    (attr "for" (Option.get (find (By_tag "label") (tree r))));
  (match click (By_tag "label") r with
  | Ok () -> ()
  | Error (Not_found _ | No_handler _) ->
      Alcotest.fail "the mapped label's press found no control handler");
  match messages r with
  | [ Wrapped Pressed ] -> ()
  | _ -> Alcotest.fail "expected the control's message wrapped by map"

let label_equal_compares_control_id () =
  let label_for id = E.label ~control_id:id [ E.text "Pro plan" ] in
  Alcotest.(check bool)
    "labels naming the same control are equal" true
    (E.equal (label_for "plan-pro") (label_for "plan-pro"));
  Alcotest.(check bool)
    "labels naming different controls differ" false
    (E.equal (label_for "plan-pro") (label_for "plan-team"))

let structural_label_press_activates_its_control () =
  let r =
    render
      (E.row
         [
           E.radio
             ~attrs:[ ("id", "plan-pro") ]
             ~on_select:Pressed ~name:"plan" ();
           E.label ~control_id:"plan-pro" [ E.text "Pro plan" ];
         ])
  in
  (match click (By_tag "label") r with
  | Ok () -> ()
  | Error (Not_found _ | No_handler _) ->
      Alcotest.fail "a label press found no control to activate");
  match messages r with
  | [ Pressed ] -> ()
  | _ -> Alcotest.fail "expected the radio's message from the label press"

let structural_label_naming_no_control_answers_no_handler () =
  let r = render (E.label ~control_id:"missing" [ E.text "Pro plan" ]) in
  (match click (By_tag "label") r with
  | Error (No_handler { tag = "label"; event = "click" }) -> ()
  | Ok ()
  | Error (Not_found _ | No_handler _) ->
      Alcotest.fail "expected the label's own No_handler");
  Alcotest.(check int) "nothing was dispatched" 0 (List.length (messages r))

(* A button is a control a label activates: the press reaches the button's own
   click handler and dispatches what pressing the button would, once. *)
let labelled_button ~disabled =
  E.row
    [
      E.label ~control_id:"alerts" [ E.text "Send an alert" ];
      E.button
        ~attrs:[ ("id", "alerts") ]
        ~disabled ~on_click:Pressed (E.text "Alerts");
    ]

let structural_label_press_activates_a_button () =
  let r = render (labelled_button ~disabled:false) in
  (match click (By_tag "label") r with
  | Ok () -> ()
  | Error (Not_found _ | No_handler _) ->
      Alcotest.fail "a label press found no button to activate");
  match messages r with
  | [ Pressed ] -> ()
  | _ -> Alcotest.fail "expected the button's message once from the label press"

(* A disabled button keeps no click handler, so the label naming it answers its
   own [No_handler] and dispatches nothing. The enabled twin above, on the same
   fixture, is the arm that shows the press reaches the button at all. *)
let structural_label_press_on_disabled_button_answers_no_handler () =
  let r = render (labelled_button ~disabled:true) in
  (match click (By_tag "label") r with
  | Error (No_handler { tag = "label"; event = "click" }) -> ()
  | Ok ()
  | Error (Not_found _ | No_handler _) ->
      Alcotest.fail "expected the label's own No_handler");
  Alcotest.(check int) "nothing was dispatched" 0 (List.length (messages r))

let () =
  Alcotest.run "Element.label"
    [
      ( "label",
        [
          Alcotest.test_case "label_carries_control_id_and_children" `Quick
            label_carries_control_id_and_children;
          Alcotest.test_case
            "label_map_keeps_control_id_and_maps_the_control_message" `Quick
            label_map_keeps_control_id_and_maps_the_control_message;
          Alcotest.test_case "label_equal_compares_control_id" `Quick
            label_equal_compares_control_id;
          Alcotest.test_case "structural_label_press_activates_its_control"
            `Quick structural_label_press_activates_its_control;
          Alcotest.test_case
            "structural_label_naming_no_control_answers_no_handler" `Quick
            structural_label_naming_no_control_answers_no_handler;
          Alcotest.test_case "structural_label_press_activates_a_button" `Quick
            structural_label_press_activates_a_button;
          Alcotest.test_case
            "structural_label_press_on_disabled_button_answers_no_handler"
            `Quick structural_label_press_on_disabled_button_answers_no_handler;
        ] );
    ]
