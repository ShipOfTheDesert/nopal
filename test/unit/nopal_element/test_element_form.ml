open Nopal_test.Test_renderer
module E = Nopal_element.Element
module Ix = Nopal_style.Interaction

let ix0 = Ix.default
let s0 = Nopal_style.Style.default
let check_node = Test_util.check_node

type msg =
  | Toggled of bool
  | Selected
  | Changed of string
  | Wrapped_toggle of bool
  | Wrapped_selected
  | Wrapped_changed of string

(* --- Checkbox (4) --- *)

let checkbox_renders_as_checkbox_tag () =
  let r = render (E.checkbox true) in
  check_node "checkbox checked=true renders tag checkbox"
    (Element
       {
         tag = "checkbox";
         style = s0;
         attrs = [ ("checked", "true"); ("disabled", "false") ];
         children = [];
         interaction = ix0;
       })
    (tree r)

let checkbox_unchecked_has_checked_false () =
  let r = render (E.checkbox false) in
  Alcotest.(check (option string))
    "checked attr is false" (Some "false")
    (attr "checked" (tree r))

let checkbox_disabled_has_disabled_attr () =
  let r =
    render (E.checkbox ~disabled:true ~on_toggle:(fun b -> Toggled b) false)
  in
  Alcotest.(check (option string))
    "disabled attr is true" (Some "true")
    (attr "disabled" (tree r));
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check bool)
    "disabled checkbox has no handler" true (Result.is_error result)

let checkbox_toggle_fires_negated_state () =
  let r = render (E.checkbox ~on_toggle:(fun b -> Toggled b) true) in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check bool) "toggle succeeds" true (Result.is_ok result);
  (match messages r with
  | [ Toggled false ] -> ()
  | _ -> Alcotest.fail "expected [Toggled false] for checked checkbox");
  clear_messages r;
  let r2 = render (E.checkbox ~on_toggle:(fun b -> Toggled b) false) in
  let result2 = toggle (By_tag "checkbox") r2 in
  Alcotest.(check bool) "toggle succeeds" true (Result.is_ok result2);
  match messages r2 with
  | [ Toggled true ] -> ()
  | _ -> Alcotest.fail "expected [Toggled true] for unchecked checkbox"

(* --- Radio (4) --- *)

let radio_renders_as_radio_tag_with_name () =
  let r = render (E.radio ~name:"color" ()) in
  check_node "radio renders tag radio with name"
    (Element
       {
         tag = "radio";
         style = s0;
         attrs =
           [ ("name", "color"); ("checked", "false"); ("disabled", "false") ];
         children = [];
         interaction = ix0;
       })
    (tree r)

let radio_checked_has_checked_attr () =
  let r = render (E.radio ~name:"color" ~checked:true ()) in
  Alcotest.(check (option string))
    "checked attr is true" (Some "true")
    (attr "checked" (tree r))

let radio_disabled_suppresses_on_select () =
  let r =
    render (E.radio ~name:"color" ~disabled:true ~on_select:Selected ())
  in
  Alcotest.(check (option string))
    "disabled attr is true" (Some "true")
    (attr "disabled" (tree r));
  let result = click (By_tag "radio") r in
  Alcotest.(check bool)
    "disabled radio has no handler" true (Result.is_error result)

let radio_select_fires_message () =
  let r = render (E.radio ~name:"color" ~on_select:Selected ()) in
  let result = click (By_tag "radio") r in
  Alcotest.(check bool) "click succeeds" true (Result.is_ok result);
  match messages r with
  | [ Selected ] -> ()
  | _ -> Alcotest.fail "expected [Selected]"

(* --- Select (5) --- *)

let opts =
  [
    E.select_option ~value:"a" "Alpha";
    E.select_option ~value:"b" "Beta";
    E.select_option ~disabled:true ~value:"c" "Gamma";
  ]

let select_renders_as_select_tag_with_options () =
  let r = render (E.select ~selected:"a" opts) in
  check_node "select renders tag select with option children"
    (Element
       {
         tag = "select";
         style = s0;
         attrs = [ ("selected", "a"); ("disabled", "false") ];
         children =
           [
             Element
               {
                 tag = "option";
                 style = s0;
                 attrs =
                   [ ("value", "a"); ("label", "Alpha"); ("disabled", "false") ];
                 children = [];
                 interaction = ix0;
               };
             Element
               {
                 tag = "option";
                 style = s0;
                 attrs =
                   [ ("value", "b"); ("label", "Beta"); ("disabled", "false") ];
                 children = [];
                 interaction = ix0;
               };
             Element
               {
                 tag = "option";
                 style = s0;
                 attrs =
                   [ ("value", "c"); ("label", "Gamma"); ("disabled", "true") ];
                 children = [];
                 interaction = ix0;
               };
           ];
         interaction = ix0;
       })
    (tree r)

let select_selected_value_in_attrs () =
  let r = render (E.select ~selected:"b" opts) in
  Alcotest.(check (option string))
    "selected attr is b" (Some "b")
    (attr "selected" (tree r))

let select_disabled_option_has_disabled_attr () =
  let r = render (E.select ~selected:"a" opts) in
  let option_nodes = find_all (By_tag "option") (tree r) in
  let third =
    match option_nodes with
    | [ _; _; third ] -> third
    | _ -> Alcotest.fail "expected 3 option children"
  in
  Alcotest.(check (option string))
    "third option disabled" (Some "true") (attr "disabled" third)

let select_disabled_suppresses_on_change () =
  let r =
    render
      (E.select ~disabled:true
         ~on_change:(fun v -> Changed v)
         ~selected:"a" opts)
  in
  Alcotest.(check (option string))
    "disabled attr is true" (Some "true")
    (attr "disabled" (tree r));
  let result = input (By_tag "select") "b" r in
  Alcotest.(check bool)
    "disabled select has no handler" true (Result.is_error result)

let select_change_fires_new_value () =
  let r =
    render (E.select ~on_change:(fun v -> Changed v) ~selected:"a" opts)
  in
  let result = input (By_tag "select") "b" r in
  Alcotest.(check bool) "change succeeds" true (Result.is_ok result);
  match messages r with
  | [ Changed "b" ] -> ()
  | _ -> Alcotest.fail "expected [Changed \"b\"]"

(* --- Map (3) --- *)

let map_transforms_checkbox_msg () =
  let el = E.checkbox ~on_toggle:(fun b -> Toggled b) true in
  let mapped =
    E.map
      (fun m ->
        Wrapped_toggle
          (match m with
          | Toggled b -> b
          | _ -> false))
      el
  in
  let r = render mapped in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check bool) "toggle succeeds" true (Result.is_ok result);
  match messages r with
  | [ Wrapped_toggle false ] -> ()
  | _ -> Alcotest.fail "expected [Wrapped_toggle false]"

let map_transforms_radio_msg () =
  let el = E.radio ~name:"color" ~on_select:Selected () in
  let mapped = E.map (fun _m -> Wrapped_selected) el in
  let r = render mapped in
  let result = click (By_tag "radio") r in
  Alcotest.(check bool) "click succeeds" true (Result.is_ok result);
  match messages r with
  | [ Wrapped_selected ] -> ()
  | _ -> Alcotest.fail "expected [Wrapped_selected]"

let map_transforms_select_msg () =
  let el = E.select ~on_change:(fun v -> Changed v) ~selected:"a" opts in
  let mapped =
    E.map
      (fun m ->
        match m with
        | Changed v -> Wrapped_changed v
        | _ -> Wrapped_changed "?")
      el
  in
  let r = render mapped in
  let result = input (By_tag "select") "b" r in
  Alcotest.(check bool) "change succeeds" true (Result.is_ok result);
  match messages r with
  | [ Wrapped_changed "b" ] -> ()
  | _ -> Alcotest.fail "expected [Wrapped_changed \"b\"]"

(* --- Equal (2) --- *)

let equal_checkbox_same_fields () =
  let make () = E.checkbox ~disabled:true true in
  Alcotest.(check bool)
    "same checkbox fields are equal" true
    (E.equal (make ()) (make ()))

let equal_select_different_options () =
  let a = E.select ~selected:"a" [ E.select_option ~value:"a" "Alpha" ] in
  let b =
    E.select ~selected:"a"
      [ E.select_option ~value:"a" "Alpha"; E.select_option ~value:"b" "Beta" ]
  in
  Alcotest.(check bool) "different options not equal" false (E.equal a b)

(* --- Test runner --- *)

let () =
  Alcotest.run "nopal_element_form"
    [
      ( "checkbox",
        [
          Alcotest.test_case "renders_as_checkbox_tag" `Quick
            checkbox_renders_as_checkbox_tag;
          Alcotest.test_case "unchecked_has_checked_false" `Quick
            checkbox_unchecked_has_checked_false;
          Alcotest.test_case "disabled_has_disabled_attr" `Quick
            checkbox_disabled_has_disabled_attr;
          Alcotest.test_case "toggle_fires_negated_state" `Quick
            checkbox_toggle_fires_negated_state;
        ] );
      ( "radio",
        [
          Alcotest.test_case "renders_as_radio_tag_with_name" `Quick
            radio_renders_as_radio_tag_with_name;
          Alcotest.test_case "checked_has_checked_attr" `Quick
            radio_checked_has_checked_attr;
          Alcotest.test_case "disabled_suppresses_on_select" `Quick
            radio_disabled_suppresses_on_select;
          Alcotest.test_case "select_fires_message" `Quick
            radio_select_fires_message;
        ] );
      ( "select",
        [
          Alcotest.test_case "renders_as_select_tag_with_options" `Quick
            select_renders_as_select_tag_with_options;
          Alcotest.test_case "selected_value_in_attrs" `Quick
            select_selected_value_in_attrs;
          Alcotest.test_case "disabled_option_has_disabled_attr" `Quick
            select_disabled_option_has_disabled_attr;
          Alcotest.test_case "disabled_suppresses_on_change" `Quick
            select_disabled_suppresses_on_change;
          Alcotest.test_case "change_fires_new_value" `Quick
            select_change_fires_new_value;
        ] );
      ( "map",
        [
          Alcotest.test_case "map_transforms_checkbox_msg" `Quick
            map_transforms_checkbox_msg;
          Alcotest.test_case "map_transforms_radio_msg" `Quick
            map_transforms_radio_msg;
          Alcotest.test_case "map_transforms_select_msg" `Quick
            map_transforms_select_msg;
        ] );
      ( "equal",
        [
          Alcotest.test_case "equal_checkbox_same_fields" `Quick
            equal_checkbox_same_fields;
          Alcotest.test_case "equal_select_different_options" `Quick
            equal_select_different_options;
        ] );
    ]
