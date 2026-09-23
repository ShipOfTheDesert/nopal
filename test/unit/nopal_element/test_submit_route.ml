(** Tests for [Nopal_element.Submit_route] — the single definition of which
    handler answers a keydown on an input.

    Both renderers answer the submit contract from this function, so these cases
    are where the rule is held once: the nearest handler that accepts the Enter
    consumes it, and consumption suppresses the platform default for Enter only.
    Every case asserts the whole route, message and suppression together, so a
    route that dispatches the wrong message or suppresses the wrong key reddens
    it. *)

open Nopal_element

let pp_route ppf (route : string Submit_route.t) =
  match route with
  | Submit_route.Dispatch { msg; prevent_default } ->
      Format.fprintf ppf "Dispatch { msg = %S; prevent_default = %b }" msg
        prevent_default
  | Submit_route.To_enclosing_form ->
      Format.pp_print_string ppf "To_enclosing_form"
  | Submit_route.Nothing -> Format.pp_print_string ppf "Nothing"

let equal_route (a : string Submit_route.t) (b : string Submit_route.t) =
  match (a, b) with
  | ( Submit_route.Dispatch { msg = m1; prevent_default = p1 },
      Submit_route.Dispatch { msg = m2; prevent_default = p2 } ) ->
      String.equal m1 m2 && Bool.equal p1 p2
  | Submit_route.To_enclosing_form, Submit_route.To_enclosing_form -> true
  | Submit_route.Nothing, Submit_route.Nothing -> true
  | ( ( Submit_route.Dispatch _ | Submit_route.To_enclosing_form
      | Submit_route.Nothing ),
      _ ) ->
      false

let route = Alcotest.testable pp_route equal_route

let dispatch msg ~prevent_default =
  Submit_route.Dispatch { msg; prevent_default }

(* A keydown handler that consumes every key, naming the key it consumed. *)
let consume_every_key key = Some ("key:" ^ key)

(* A keydown handler that answers Escape and declines every other key,
   including Enter. *)
let answer_escape_only key =
  match key with
  | "Escape" -> Some "cancel"
  | _ -> None

let test_non_consuming_keydown_falls_through_to_on_submit () =
  Alcotest.check route "a declining keydown lets on_submit answer Enter"
    (dispatch "submit" ~prevent_default:true)
    (Submit_route.of_key ~key:"Enter" ~on_keydown:(Some answer_escape_only)
       ~on_submit:(Some "submit"));
  Alcotest.check route "the same keydown handler still answers its own key"
    (dispatch "cancel" ~prevent_default:false)
    (Submit_route.of_key ~key:"Escape" ~on_keydown:(Some answer_escape_only)
       ~on_submit:(Some "submit"))

let test_consuming_keydown_answers_enter_and_prevents_default () =
  Alcotest.check route "a consuming keydown beats on_submit on Enter"
    (dispatch "key:Enter" ~prevent_default:true)
    (Submit_route.of_key ~key:"Enter" ~on_keydown:(Some consume_every_key)
       ~on_submit:(Some "submit"));
  Alcotest.check route
    "a consuming keydown without on_submit keeps the Enter from the form"
    (dispatch "key:Enter" ~prevent_default:true)
    (Submit_route.of_key ~key:"Enter" ~on_keydown:(Some consume_every_key)
       ~on_submit:None)

let test_consuming_keydown_on_another_key_does_not_prevent_default () =
  Alcotest.check route "a consumed printable key keeps its default"
    (dispatch "key:a" ~prevent_default:false)
    (Submit_route.of_key ~key:"a" ~on_keydown:(Some consume_every_key)
       ~on_submit:(Some "submit"));
  Alcotest.check route "a consumed Tab keeps its default"
    (dispatch "key:Tab" ~prevent_default:false)
    (Submit_route.of_key ~key:"Tab" ~on_keydown:(Some consume_every_key)
       ~on_submit:None)

let test_an_input_on_submit_never_reaches_the_enclosing_form () =
  Alcotest.check route "on_submit alone answers Enter and suppresses the form"
    (dispatch "submit" ~prevent_default:true)
    (Submit_route.of_key ~key:"Enter" ~on_keydown:None
       ~on_submit:(Some "submit"))

let test_a_bare_input_defers_enter_to_the_enclosing_form () =
  Alcotest.check route "no handler at all defers Enter to the form"
    Submit_route.To_enclosing_form
    (Submit_route.of_key ~key:"Enter" ~on_keydown:None ~on_submit:None);
  Alcotest.check route "a declining keydown alone defers Enter to the form"
    Submit_route.To_enclosing_form
    (Submit_route.of_key ~key:"Enter" ~on_keydown:(Some answer_escape_only)
       ~on_submit:None);
  Alcotest.check route "only Enter is deferred; another key reaches nothing"
    Submit_route.Nothing
    (Submit_route.of_key ~key:"a" ~on_keydown:None ~on_submit:None)

let test_on_submit_answers_enter_and_no_other_key () =
  Alcotest.check route "Enter reaches on_submit"
    (dispatch "submit" ~prevent_default:true)
    (Submit_route.of_key ~key:"Enter" ~on_keydown:None
       ~on_submit:(Some "submit"));
  List.iter
    (fun key ->
      Alcotest.check route
        (Printf.sprintf "%S does not reach on_submit" key)
        Submit_route.Nothing
        (Submit_route.of_key ~key ~on_keydown:None ~on_submit:(Some "submit")))
    [ "a"; "Tab"; "Escape"; " " ]

let () =
  Alcotest.run "Submit_route"
    [
      ( "submit_route",
        [
          Alcotest.test_case "non_consuming_keydown_falls_through_to_on_submit"
            `Quick test_non_consuming_keydown_falls_through_to_on_submit;
          Alcotest.test_case
            "consuming_keydown_answers_enter_and_prevents_default" `Quick
            test_consuming_keydown_answers_enter_and_prevents_default;
          Alcotest.test_case
            "consuming_keydown_on_another_key_does_not_prevent_default" `Quick
            test_consuming_keydown_on_another_key_does_not_prevent_default;
          Alcotest.test_case
            "an_input_on_submit_never_reaches_the_enclosing_form" `Quick
            test_an_input_on_submit_never_reaches_the_enclosing_form;
          Alcotest.test_case "a_bare_input_defers_enter_to_the_enclosing_form"
            `Quick test_a_bare_input_defers_enter_to_the_enclosing_form;
          Alcotest.test_case "on_submit_answers_enter_and_no_other_key" `Quick
            test_on_submit_answers_enter_and_no_other_key;
        ] );
    ]
