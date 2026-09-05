open Nopal_test.Test_renderer
module E = Nopal_element.Element

type msg =
  | Click
  | DblClick
  | Blur
  | Focus
  | BoxFocus
  | BoxBlur
  | KeyDown of string
  | Toggled of bool
[@@warning "-37"]

let error_testable = Test_util.error_testable

let msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | Click -> Format.fprintf fmt "Click"
      | DblClick -> Format.fprintf fmt "DblClick"
      | Blur -> Format.fprintf fmt "Blur"
      | Focus -> Format.fprintf fmt "Focus"
      | BoxFocus -> Format.fprintf fmt "BoxFocus"
      | BoxBlur -> Format.fprintf fmt "BoxBlur"
      | KeyDown s -> Format.fprintf fmt "KeyDown %S" s
      | Toggled b -> Format.fprintf fmt "Toggled %b" b)
    ( = )

let test_dblclick_dispatches_message () =
  let r = render (E.button ~on_dblclick:DblClick (E.text "ok")) in
  let result = dblclick (By_tag "button") r in
  Alcotest.(check (result unit error_testable))
    "dblclick succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "dblclick message dispatched" [ DblClick ] (messages r)

let test_dblclick_no_handler_returns_error () =
  let r = render (E.button (E.text "no handler")) in
  let result = dblclick (By_tag "button") r in
  Alcotest.(check (result unit error_testable))
    "dblclick returns No_handler"
    (Error (No_handler { tag = "button"; event = "dblclick" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let test_blur_dispatches_message () =
  let r = render (E.input ~on_blur:Blur "val") in
  let result = blur (By_tag "input") r in
  Alcotest.(check (result unit error_testable)) "blur succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "blur message dispatched" [ Blur ] (messages r)

let test_blur_no_handler_returns_error () =
  let r = render (E.input "val") in
  let result = blur (By_tag "input") r in
  Alcotest.(check (result unit error_testable))
    "blur returns No_handler"
    (Error (No_handler { tag = "input"; event = "blur" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let test_input_focus_simulation () =
  let r = render (E.input ~on_focus:Focus "val") in
  let result = focus (By_tag "input") r in
  Alcotest.(check (result unit error_testable)) "focus succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "focus message dispatched" [ Focus ] (messages r)

let test_box_focus_simulation () =
  let r = render (E.box ~on_focus:BoxFocus [ E.text "panel" ]) in
  let result = box_focus (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "box_focus succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "box focus message dispatched" [ BoxFocus ] (messages r)

let test_box_blur_simulation () =
  let r = render (E.box ~on_blur:BoxBlur [ E.text "panel" ]) in
  let result = box_blur (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "box_blur succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "box blur message dispatched" [ BoxBlur ] (messages r)

(* The fixture carries the sibling edge, so the absence below is caused by
   [on_focus] being unset and not by the box failing to register a handler
   entry at all; [box_blur] on the same fixture is the affirmative arm that
   proves it. A [box_focus] copy-pasted from [box_blur] reads [on_blur] here
   and dispatches, which is the defect this case exists to catch. *)
let test_box_focus_no_handler () =
  let r = render (E.box ~on_blur:BoxBlur [ E.text "panel" ]) in
  let result = box_focus (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "box_focus returns No_handler with the focus tag"
    (Error (No_handler { tag = "box"; event = "focus" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r));
  let affirmative = box_blur (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "same fixture is registered and its blur edge fires" (Ok ()) affirmative;
  Alcotest.(check (list msg_testable))
    "box blur message dispatched" [ BoxBlur ] (messages r)

let test_box_blur_no_handler () =
  let r = render (E.box ~on_focus:BoxFocus [ E.text "panel" ]) in
  let result = box_blur (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "box_blur returns No_handler with the blur tag"
    (Error (No_handler { tag = "box"; event = "blur" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r));
  let affirmative = box_focus (By_tag "box") r in
  Alcotest.(check (result unit error_testable))
    "same fixture is registered and its focus edge fires" (Ok ()) affirmative;
  Alcotest.(check (list msg_testable))
    "box focus message dispatched" [ BoxFocus ] (messages r)

let test_keydown_dispatches_message () =
  let handler key = Some (KeyDown key) in
  let r = render (E.input ~on_keydown:handler "val") in
  let result = keydown (By_tag "input") "Escape" r in
  Alcotest.(check (result unit error_testable))
    "keydown succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "keydown message dispatched" [ KeyDown "Escape" ] (messages r)

let test_keydown_handler_returns_none () =
  let handler _key = None in
  let r = render (E.input ~on_keydown:handler "val") in
  let result = keydown (By_tag "input") "a" r in
  Alcotest.(check (result unit error_testable))
    "keydown succeeds" (Ok ()) result;
  Alcotest.(check int) "no messages dispatched" 0 (List.length (messages r))

let test_keydown_no_handler_returns_error () =
  let r = render (E.input "val") in
  let result = keydown (By_tag "input") "Escape" r in
  Alcotest.(check (result unit error_testable))
    "keydown returns No_handler"
    (Error (No_handler { tag = "input"; event = "keydown" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let test_toggle_checked_dispatches_false () =
  let r = render (E.checkbox ~on_toggle:(fun b -> Toggled b) true) in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check (result unit error_testable)) "toggle succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "toggle dispatches Toggled false" [ Toggled false ] (messages r)

let test_toggle_unchecked_dispatches_true () =
  let r = render (E.checkbox ~on_toggle:(fun b -> Toggled b) false) in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check (result unit error_testable)) "toggle succeeds" (Ok ()) result;
  Alcotest.(check (list msg_testable))
    "toggle dispatches Toggled true" [ Toggled true ] (messages r)

let test_toggle_disabled_returns_error () =
  let r =
    render (E.checkbox ~on_toggle:(fun b -> Toggled b) ~disabled:true false)
  in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check (result unit error_testable))
    "toggle returns No_handler"
    (Error (No_handler { tag = "checkbox"; event = "toggle" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let test_toggle_non_checkbox_returns_error () =
  let r = render (E.button ~on_click:Click (E.text "not a checkbox")) in
  let result = toggle (By_tag "button") r in
  Alcotest.(check (result unit error_testable))
    "toggle returns No_handler"
    (Error (No_handler { tag = "button"; event = "toggle" }))
    result;
  Alcotest.(check int) "no messages" 0 (List.length (messages r))

let test_toggle_not_found_returns_error () =
  let r = render (E.box [ E.text "hello" ]) in
  let result = toggle (By_tag "checkbox") r in
  Alcotest.(check (result unit error_testable))
    "toggle returns Not_found" (Error (Not_found (By_tag "checkbox"))) result

let () =
  Alcotest.run "event_simulation"
    [
      ( "dblclick",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_dblclick_dispatches_message;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_dblclick_no_handler_returns_error;
        ] );
      ( "blur",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_blur_dispatches_message;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_blur_no_handler_returns_error;
        ] );
      ( "focus",
        [
          Alcotest.test_case "input_dispatches_message" `Quick
            test_input_focus_simulation;
        ] );
      ( "box_focus",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_box_focus_simulation;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_box_focus_no_handler;
        ] );
      ( "box_blur",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_box_blur_simulation;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_box_blur_no_handler;
        ] );
      ( "keydown",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_keydown_dispatches_message;
          Alcotest.test_case "handler_returns_none" `Quick
            test_keydown_handler_returns_none;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_keydown_no_handler_returns_error;
        ] );
      ( "toggle",
        [
          Alcotest.test_case "checked_dispatches_false" `Quick
            test_toggle_checked_dispatches_false;
          Alcotest.test_case "unchecked_dispatches_true" `Quick
            test_toggle_unchecked_dispatches_true;
          Alcotest.test_case "disabled_returns_error" `Quick
            test_toggle_disabled_returns_error;
          Alcotest.test_case "non_checkbox_returns_error" `Quick
            test_toggle_non_checkbox_returns_error;
          Alcotest.test_case "not_found_returns_error" `Quick
            test_toggle_not_found_returns_error;
        ] );
    ]
