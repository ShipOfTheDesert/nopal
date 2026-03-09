open Nopal_test.Test_renderer
module E = Nopal_element.Element

type msg = Click | DblClick | Blur | KeyDown of string [@@warning "-37"]

let pp_selector fmt sel =
  match sel with
  | By_tag t -> Format.fprintf fmt "By_tag %S" t
  | By_text t -> Format.fprintf fmt "By_text %S" t
  | By_attr (k, v) -> Format.fprintf fmt "By_attr (%S, %S)" k v
  | First_child -> Format.fprintf fmt "First_child"
  | Nth_child n -> Format.fprintf fmt "Nth_child %d" n

let error_testable =
  Alcotest.testable
    (fun fmt e ->
      match e with
      | Not_found sel -> Format.fprintf fmt "Not_found (%a)" pp_selector sel
      | No_handler { tag; event } ->
          Format.fprintf fmt "No_handler { tag = %S; event = %S }" tag event)
    ( = )

let msg_testable =
  Alcotest.testable
    (fun fmt m ->
      match m with
      | Click -> Format.fprintf fmt "Click"
      | DblClick -> Format.fprintf fmt "DblClick"
      | Blur -> Format.fprintf fmt "Blur"
      | KeyDown s -> Format.fprintf fmt "KeyDown %S" s)
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
      ( "keydown",
        [
          Alcotest.test_case "dispatches_message" `Quick
            test_keydown_dispatches_message;
          Alcotest.test_case "handler_returns_none" `Quick
            test_keydown_handler_returns_none;
          Alcotest.test_case "no_handler_returns_error" `Quick
            test_keydown_no_handler_returns_error;
        ] );
    ]
