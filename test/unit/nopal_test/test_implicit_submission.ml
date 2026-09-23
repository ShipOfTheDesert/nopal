module E = Nopal_element.Element
module VL = Nopal_element.Virtual_list
module IS = Nopal_test_internal.Implicit_submission

type msg = First | Second | Pushed | Submitted

let msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | First -> Format.fprintf fmt "First"
      | Second -> Format.fprintf fmt "Second"
      | Pushed -> Format.fprintf fmt "Pushed"
      | Submitted -> Format.fprintf fmt "Submitted")
    ( = )

let dispatched = Alcotest.(list msg_testable)
let enter children = IS.deferred_enter ~on_submit:(Some Submitted) children
let field () = E.input "v"

let submit_button ?(disabled = false) msg =
  E.button ~button_type:E.Submit ~disabled ~on_click:msg (E.text "go")

(* The first submit button sits one level deeper than the second, so a walk
   that visited siblings before descendants would reach the second first. *)
let test_default_button_is_first_submit_button_in_tree_order () =
  Alcotest.check dispatched
    "the first submit button in tree order is clicked, then the form submits"
    [ First; Submitted ]
    (enter
       [
         field (); E.row [ E.box [ submit_button First ] ]; submit_button Second;
       ])

let test_push_buttons_are_not_default_buttons () =
  Alcotest.check dispatched "the push button before it is passed over"
    [ First; Submitted ]
    (enter
       [
         field ();
         E.button ~on_click:Pushed (E.text "untyped");
         E.button ~button_type:E.Push ~on_click:Pushed (E.text "push");
         submit_button First;
       ])

let test_enabled_default_button_enter_dispatches_its_click_then_form () =
  (* Two fields, so the submission is the default button's and not the
     single-field rule's. *)
  Alcotest.check dispatched "its click, then the form" [ First; Submitted ]
    (enter [ field (); field (); submit_button First ])

let test_disabled_default_button_blocks_enter () =
  let form ~disabled = [ field (); submit_button ~disabled First ] in
  Alcotest.check dispatched "a disabled default button blocks the Enter" []
    (enter (form ~disabled:true));
  Alcotest.check dispatched "its enabled twin submits" [ First; Submitted ]
    (enter (form ~disabled:false))

let test_disabled_default_before_enabled_submit_blocks_enter () =
  let form ~disabled =
    [ field (); submit_button ~disabled First; submit_button Second ]
  in
  Alcotest.check dispatched
    "the enabled submit button after it does not become the default" []
    (enter (form ~disabled:true));
  Alcotest.check dispatched "with the first enabled, the first is clicked"
    [ First; Submitted ]
    (enter (form ~disabled:false))

let test_no_submit_button_one_field_enter_submits () =
  Alcotest.check dispatched "one field and only a push button: the form submits"
    [ Submitted ]
    (enter [ field (); E.button ~on_click:Pushed (E.text "push") ])

let test_no_submit_button_two_fields_enter_submits_nothing () =
  let fields n = List.init n (fun _ -> field ()) in
  Alcotest.check dispatched "two fields and no submit button: nothing" []
    (enter (fields 2));
  Alcotest.check dispatched "one field of the same shape submits" [ Submitted ]
    (enter (fields 1))

let test_checkbox_radio_select_file_do_not_count_as_blocking_fields () =
  let others =
    [
      E.checkbox false;
      E.radio ~name:"r" ();
      E.select ~selected:"a" [ E.select_option ~value:"a" "A" ];
      E.file_input ();
    ]
  in
  Alcotest.check dispatched "one field among the four others still submits"
    [ Submitted ]
    (enter (field () :: others));
  Alcotest.check dispatched "a second field among them blocks" []
    (enter ((field () :: others) @ [ field () ]))

let test_password_input_counts_as_a_blocking_field () =
  let password = E.input ~input_type:E.Password "" in
  Alcotest.check dispatched "a text field and a password field: nothing" []
    (enter [ field (); password ]);
  Alcotest.check dispatched "the password field alone submits" [ Submitted ]
    (enter [ password ])

(* One wrapper per arm that holds children, each around a second field and
   then around a submit button, so a walk that skipped any arm would count one
   field too few, or find no default button. *)
let test_every_container_arm_is_walked () =
  let wrappers : (string * (msg E.t -> msg E.t)) list =
    [
      ("box", fun c -> E.box [ c ]);
      ("row", fun c -> E.row [ c ]);
      ("column", fun c -> E.column [ c ]);
      ("scroll", fun c -> E.scroll c);
      ("keyed", fun c -> E.keyed "k" c);
      ("button", fun c -> E.button c);
    ]
  in
  List.iter
    (fun (name, wrap) ->
      Alcotest.check dispatched
        (name ^ ": a wrapped second field blocks")
        []
        (enter [ field (); wrap (field ()) ]);
      Alcotest.check dispatched
        (name ^ ": a wrapped submit button is the default")
        [ First; Submitted ]
        (enter [ field (); field (); wrap (submit_button First) ]))
    wrappers

let natural n =
  match VL.Natural.of_int n with
  | Some v -> v
  | None -> Alcotest.failf "not a natural: %d" n

let positive f =
  match VL.Positive_float.of_float f with
  | Some v -> v
  | None -> Alcotest.failf "not positive: %f" f

(* A window of rows 10..14 out of 100. Row 12 renders a submit button; row 3,
   outside the window, renders one that would otherwise come first. *)
let test_only_rendered_virtual_list_rows_are_walked () =
  let rows =
    E.virtual_list ~item_count:(natural 100) ~row_height:(positive 10.0)
      ~container_height:(positive 50.0)
      ~scroll_state:(VL.scroll_state ~offset:100.0) ~overscan:(natural 0)
      (fun i ->
        match i with
        | 3 -> submit_button First
        | 12 -> submit_button Second
        | _ -> E.text "row")
  in
  Alcotest.check dispatched "the rendered row's button is the default"
    [ Second; Submitted ]
    (enter [ field (); field (); rows ])

let test_a_nested_forms_controls_are_not_the_outer_forms () =
  Alcotest.check dispatched "the inner form's field and button are not counted"
    [ Submitted ]
    (enter [ field (); E.form [ field (); submit_button First ] ]);
  Alcotest.check dispatched "the same controls outside it are"
    [ First; Submitted ]
    (enter [ field (); field (); submit_button First ])

let test_click () =
  let click = IS.click in
  Alcotest.check dispatched "an enabled submit button: its click, then the form"
    [ First; Submitted ]
    (click ~button_type:E.Submit ~disabled:false ~on_click:(Some First)
       ~form_submit:(Some Submitted));
  Alcotest.check dispatched "a submit button with no on_click: the form alone"
    [ Submitted ]
    (click ~button_type:E.Submit ~disabled:false ~on_click:None
       ~form_submit:(Some Submitted));
  Alcotest.check dispatched "an enabled push button: its click alone" [ First ]
    (click ~button_type:E.Push ~disabled:false ~on_click:(Some First)
       ~form_submit:(Some Submitted));
  Alcotest.check dispatched "a disabled submit button: nothing" []
    (click ~button_type:E.Submit ~disabled:true ~on_click:(Some First)
       ~form_submit:(Some Submitted));
  Alcotest.check dispatched "a disabled push button: nothing" []
    (click ~button_type:E.Push ~disabled:true ~on_click:(Some First)
       ~form_submit:(Some Submitted))

let () =
  Alcotest.run "implicit_submission"
    [
      ( "deferred_enter",
        [
          Alcotest.test_case
            "default_button_is_first_submit_button_in_tree_order" `Quick
            test_default_button_is_first_submit_button_in_tree_order;
          Alcotest.test_case "push_buttons_are_not_default_buttons" `Quick
            test_push_buttons_are_not_default_buttons;
          Alcotest.test_case
            "enabled_default_button_enter_dispatches_its_click_then_form" `Quick
            test_enabled_default_button_enter_dispatches_its_click_then_form;
          Alcotest.test_case "disabled_default_button_blocks_enter" `Quick
            test_disabled_default_button_blocks_enter;
          Alcotest.test_case
            "disabled_default_before_enabled_submit_blocks_enter" `Quick
            test_disabled_default_before_enabled_submit_blocks_enter;
          Alcotest.test_case "no_submit_button_one_field_enter_submits" `Quick
            test_no_submit_button_one_field_enter_submits;
          Alcotest.test_case "no_submit_button_two_fields_enter_submits_nothing"
            `Quick test_no_submit_button_two_fields_enter_submits_nothing;
          Alcotest.test_case
            "checkbox_radio_select_file_do_not_count_as_blocking_fields" `Quick
            test_checkbox_radio_select_file_do_not_count_as_blocking_fields;
          Alcotest.test_case "password_input_counts_as_a_blocking_field" `Quick
            test_password_input_counts_as_a_blocking_field;
          Alcotest.test_case "every_container_arm_is_walked" `Quick
            test_every_container_arm_is_walked;
          Alcotest.test_case "only_rendered_virtual_list_rows_are_walked" `Quick
            test_only_rendered_virtual_list_rows_are_walked;
          Alcotest.test_case "a_nested_forms_controls_are_not_the_outer_forms"
            `Quick test_a_nested_forms_controls_are_not_the_outer_forms;
        ] );
      ("click", [ Alcotest.test_case "click" `Quick test_click ]);
    ]
